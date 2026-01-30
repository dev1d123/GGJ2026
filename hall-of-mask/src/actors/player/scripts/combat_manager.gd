extends Node3D
class_name CombatManager

# --- DEPENDENCIAS ---
@export_category("Referencias Obligatorias")
@export var animation_tree: AnimationTree
@export var right_hand_bone: Node3D 
@export var left_hand_bone: Node3D  

@export_category("Control de Input")
@export var is_player_controlled: bool = false 

@export_category("Componentes Opcionales")
@export var stamina_component: Node 
@export var attribute_manager: Node 

# --- CONFIGURACIÓN ---
@export_category("Reglas de Combate")
@export_flags_3d_physics var attack_layer_mask: int = 0 
@export var damage_multiplier: float = 1.0 

# --- INVENTARIO ---
@export_category("Inventario Inicial")
@export var slot_1_left: WeaponData
@export var slot_1_right: WeaponData
@export var slot_2: WeaponData 
@export var slot_3: WeaponData 
@export var slot_4: WeaponData 

# --- ESTADO PÚBLICO ---
var is_attacking_r: bool = false
var is_attacking_l: bool = false
var is_movement_locked: bool = false 

# Getter para compatibilidad con otros scripts que buscan "is_attacking"
var is_attacking: bool:
	get: return is_attacking_r or is_attacking_l

# Internas
var weapon_r: WeaponData
var weapon_l: WeaponData
var cd_timer_r: float = 0.0
var cd_timer_l: float = 0.0
var owner_node: Node = null 

const BLEND_R = "parameters/Mezcla_R/blend_amount"
const BLEND_L = "parameters/Mezcla_L/blend_amount"
const BLEND_2H = "parameters/Mezcla_2H/blend_amount"
const PLAYBACK_R = "parameters/Combat_R/playback"
const PLAYBACK_L = "parameters/Combat_L/playback"
const PLAYBACK_2H = "parameters/Combat_2H/playback"

func _ready():
	owner_node = get_parent()
	
	if not animation_tree and owner_node.has_node("AnimationTree"):
		animation_tree = owner_node.get_node("AnimationTree")

	if animation_tree:
		animation_tree.set(BLEND_R, 0.0)
		animation_tree.set(BLEND_L, 0.0)
		animation_tree.set(BLEND_2H, 0.0)
	
	if slot_1_right: equip_weapon(slot_1_right, "right")
	if slot_1_left: equip_weapon(slot_1_left, "left")

func _process(delta):
	if cd_timer_r > 0: cd_timer_r -= delta
	if cd_timer_l > 0: cd_timer_l -= delta

# --- INPUT ---
func _input(event):
	if not is_player_controlled: return
	if "is_dead" in owner_node and owner_node.is_dead: return

	# Ataque
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: try_attack("right")
		elif event.button_index == MOUSE_BUTTON_LEFT: try_attack("left")

	# Cambio de Arma (Bloqueado si se está atacando con ESA mano)
	if event is InputEventKey and event.pressed:
		var tab = Input.is_physical_key_pressed(KEY_TAB)
		var mano = "left" if tab else "right"
		
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return

		match event.keycode:
			KEY_1: unequip_weapon(mano)
			KEY_2: if slot_2: equip_weapon(slot_2, mano)
			KEY_3: if slot_3: equip_weapon(slot_3, mano)
			KEY_4: if slot_4: equip_weapon(slot_4, mano)

# --- SISTEMA DE EQUIPAMIENTO ---
func equip_weapon(data: WeaponData, mano: String):
	if not right_hand_bone or not left_hand_bone: return

	if data.is_two_handed:
		if is_attacking_r or is_attacking_l: return
		_crear_tween(BLEND_2H, 1.0); _crear_tween(BLEND_R, 0.0); _crear_tween(BLEND_L, 0.0)
		_limpiar_manos()
		weapon_r = data
		weapon_l = null
		_instanciar_visual(data, right_hand_bone)
	else:
		_crear_tween(BLEND_2H, 0.0)
		if mano == "right":
			if is_attacking_r: return
			weapon_r = data
			_crear_tween(BLEND_R, 0.0)
			_limpiar_nodo(right_hand_bone)
			_instanciar_visual(data, right_hand_bone)
			_viajar_animacion(PLAYBACK_R, data.anim_idle)
		else:
			if is_attacking_l: return
			weapon_l = data
			_crear_tween(BLEND_L, 0.0)
			_limpiar_nodo(left_hand_bone)
			_instanciar_visual(data, left_hand_bone)
			_viajar_animacion(PLAYBACK_L, data.anim_idle)

func unequip_weapon(mano: String):
	if mano == "left": weapon_l = null; _limpiar_nodo(left_hand_bone); _crear_tween(BLEND_L, 0.0)
	else: weapon_r = null; _limpiar_nodo(right_hand_bone); _crear_tween(BLEND_R, 0.0)

# --- LÓGICA DE ATAQUE ---
func try_attack(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	# 1. Chequeo de estado independiente
	if w.is_two_handed:
		if is_attacking_r or is_attacking_l: return
	else:
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return
	
	# 2. Cooldown
	if mano == "right" and cd_timer_r > 0: return
	if mano == "left" and cd_timer_l > 0: return
	
	# 3. Stamina
	if stamina_component and stamina_component.has_method("try_consume"):
		if not stamina_component.try_consume(w.stamina_cost): return 

	_ejecutar_secuencia_ataque(w, mano)

func _ejecutar_secuencia_ataque(w: WeaponData, mano: String):
	# Bloquear estado
	if w.is_two_handed:
		is_attacking_r = true; is_attacking_l = true
	elif mano == "right":
		is_attacking_r = true
	else:
		is_attacking_l = true
	
	if w.stop_movement: is_movement_locked = true
	
	var playback = ""
	var blend_path = ""
	var anim_name = w.anim_attack
	var hand_node = null
	
	if w.is_two_handed:
		playback = PLAYBACK_2H; blend_path = BLEND_2H; hand_node = right_hand_bone
	elif mano == "right":
		playback = PLAYBACK_R; blend_path = BLEND_R; hand_node = right_hand_bone
	else:
		playback = PLAYBACK_L; blend_path = BLEND_L; hand_node = left_hand_bone; anim_name += "_L" 
	
	# --- FASE 1: SUAVIZADO (XFADE) ---
	# Subimos el blend suavemente. Esto evita el golpe visual brusco.
	_crear_tween(blend_path, 1.0, w.blend_time)
	
	if animation_tree:
		# .start() fuerza el reinicio desde el frame 0. 
		# Como ya estamos haciendo un Xfade con el blend_amount, se verá suave.
		animation_tree[playback].start(anim_name)
	
	# Esperamos que se mezcle un poco antes de calcular lógica
	await get_tree().create_timer(w.blend_time).timeout
	
	# --- FASE 2: WINDUP ---
	await get_tree().create_timer(w.windup_time).timeout
	
	# --- FASE 3: HITBOX ACTIVADA (CORRECCIÓN DE DAÑO) ---
	var hitbox = _buscar_hitbox(hand_node)
	if hitbox:
		hitbox.collision_mask = attack_layer_mask
		
		# --- FÓRMULA DE DAÑO CORREGIDA ---
		var final_damage = w.damage
		
		# Si tenemos stats, las SUMAMOS (o multiplicamos, según tu preferencia)
		# Aquí las sumo para que sea más fácil de entender: 10 arma + 5 fuerza = 15 total
		if attribute_manager and attribute_manager.has_method("get_stat"):
			final_damage += attribute_manager.get_stat("melee_damage")
		
		# Aplicamos el multiplicador global (Críticos, buffos, etc)
		final_damage *= damage_multiplier
		
		hitbox.activate(final_damage, w.knockback_force, w.jump_force, owner_node)
	
	# --- FASE 4: DURACIÓN DE GOLPE ---
	await get_tree().create_timer(w.active_time).timeout
	if hitbox: hitbox.deactivate()
	
	# --- FASE 5: COMPLETAR ANIMACIÓN ---
	var tiempo_usado = w.blend_time + w.windup_time + w.active_time
	var tiempo_restante = w.total_animation_time - tiempo_usado
	
	if tiempo_restante > 0:
		await get_tree().create_timer(tiempo_restante).timeout
	
	# --- FASE 6: FINALIZAR ---
	# Liberamos la mano correcta
	if w.is_two_handed:
		is_attacking_r = false; is_attacking_l = false
	elif mano == "right":
		is_attacking_r = false
	else:
		is_attacking_l = false
	
	# Liberamos movimiento solo si ambas manos están libres
	if not is_attacking_r and not is_attacking_l:
		is_movement_locked = false
	
	# Bajamos la mezcla suavemente para volver a Idle/Walk
	_crear_tween(blend_path, 0.0, 0.2)
	
	if mano == "right": cd_timer_r = w.cooldown
	else: cd_timer_l = w.cooldown

# --- UTILIDADES ---
func _crear_tween(path, val, tiempo = 0.2):
	if animation_tree:
		var t = create_tween()
		t.tween_property(animation_tree, path, val, tiempo)

func _limpiar_manos():
	_limpiar_nodo(right_hand_bone); _limpiar_nodo(left_hand_bone)

func _limpiar_nodo(node):
	if node: for c in node.get_children(): c.queue_free()

func _instanciar_visual(data, parent):
	if data.weapon_scene and parent:
		var scn = data.weapon_scene.instantiate()
		parent.add_child(scn)

func _buscar_hitbox(parent):
	if parent and parent.get_child_count() > 0:
		var weapon = parent.get_child(0)
		return weapon.find_child("Hitbox")
	return null

func _viajar_animacion(path, anim_name):
	if animation_tree: animation_tree[path].travel(anim_name)
