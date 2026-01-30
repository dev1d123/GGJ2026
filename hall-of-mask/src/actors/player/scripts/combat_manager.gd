extends Node3D
class_name CombatManager

# --- DEPENDENCIAS ---
@export_category("Referencias Obligatorias")
@export var animation_tree: AnimationTree
@export var right_hand_bone: Node3D 
@export var left_hand_bone: Node3D  

@export_category("Control de Input")
## Marca TRUE solo en el Player. FALSE en Enemigos.
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
# AHORA SON INDEPENDIENTES
var is_attacking_r: bool = false
var is_attacking_l: bool = false
var is_movement_locked: bool = false # Si CUALQUIERA de las dos bloquea movimiento

# --- SOLUCIÓN AL ERROR ---
# Esta variable "falsa" devuelve true si alguna de las dos manos ataca.
# Así tus otros scripts (Esqueleto/Player) no se rompen.
var is_attacking: bool:
	get:
		return is_attacking_r or is_attacking_l

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
	# Cooldowns independientes
	if cd_timer_r > 0: cd_timer_r -= delta
	if cd_timer_l > 0: cd_timer_l -= delta

# --- INPUT (LÓGICA BLINDADA DE CAMBIO DE ARMA) ---
func _input(event):
	if not is_player_controlled: return
	if "is_dead" in owner_node and owner_node.is_dead: return

	# 1. ATAQUE (Mouse)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: try_attack("right")
		elif event.button_index == MOUSE_BUTTON_LEFT: try_attack("left")

	# 2. CAMBIO DE ARMA (Teclado)
	if event is InputEventKey and event.pressed:
		var tab = Input.is_physical_key_pressed(KEY_TAB)
		var mano_objetivo = "left" if tab else "right"
		
		# --- VERIFICACIÓN CRÍTICA: BLOQUEO DE CAMBIO ---
		# Si esa mano está atacando, NO permitimos cambiar el arma.
		if mano_objetivo == "right" and is_attacking_r:
			print("🚫 Mano Derecha ocupada, no puedes cambiar.")
			return
		if mano_objetivo == "left" and is_attacking_l:
			print("🚫 Mano Izquierda ocupada, no puedes cambiar.")
			return
		# -----------------------------------------------
		
		match event.keycode:
			KEY_1: unequip_weapon(mano_objetivo)
			KEY_2: if slot_2: equip_weapon(slot_2, mano_objetivo)
			KEY_3: if slot_3: equip_weapon(slot_3, mano_objetivo)
			KEY_4: if slot_4: equip_weapon(slot_4, mano_objetivo)

# --- SISTEMA DE EQUIPAMIENTO ---
func equip_weapon(data: WeaponData, mano: String):
	if not right_hand_bone or not left_hand_bone: return

	# Si es 2 manos, ocupa ambos espacios
	if data.is_two_handed:
		# Verificamos que AMBAS manos estén libres de ataque
		if is_attacking_r or is_attacking_l: return 
		
		_crear_tween(BLEND_2H, 1.0); _crear_tween(BLEND_R, 0.0); _crear_tween(BLEND_L, 0.0)
		_limpiar_manos()
		weapon_r = data
		weapon_l = null # La izquierda queda técnicamente vacía o ocupada por la 2H
		_instanciar_visual(data, right_hand_bone)
	else:
		_crear_tween(BLEND_2H, 0.0)
		if mano == "right":
			weapon_r = data
			_crear_tween(BLEND_R, 0.0)
			_limpiar_nodo(right_hand_bone)
			_instanciar_visual(data, right_hand_bone)
			_viajar_animacion(PLAYBACK_R, data.anim_idle)
		else:
			weapon_l = data
			_crear_tween(BLEND_L, 0.0)
			_limpiar_nodo(left_hand_bone)
			_instanciar_visual(data, left_hand_bone)
			_viajar_animacion(PLAYBACK_L, data.anim_idle)

func unequip_weapon(mano: String):
	if mano == "left": weapon_l = null; _limpiar_nodo(left_hand_bone); _crear_tween(BLEND_L, 0.0)
	else: weapon_r = null; _limpiar_nodo(right_hand_bone); _crear_tween(BLEND_R, 0.0)

# --- SISTEMA DE ATAQUE INDEPENDIENTE ---
func try_attack(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	# 1. CHECK DE ESTADO INDEPENDIENTE
	# Si es 2 manos, revisamos si CUALQUIERA está ocupada
	if w.is_two_handed:
		if is_attacking_r or is_attacking_l: return
	else:
		# Si es 1 mano, solo revisamos ESA mano
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return
	
	# 2. CHECK COOLDOWN
	if mano == "right" and cd_timer_r > 0: return
	if mano == "left" and cd_timer_l > 0: return
	
	# 3. CONSUMO
	if stamina_component and stamina_component.has_method("try_consume"):
		if not stamina_component.try_consume(w.stamina_cost): return 

	_ejecutar_secuencia_ataque(w, mano)

func _ejecutar_secuencia_ataque(w: WeaponData, mano: String):
	# BLOQUEO DE ESTADO
	if w.is_two_handed:
		is_attacking_r = true
		is_attacking_l = true
	elif mano == "right":
		is_attacking_r = true
	else:
		is_attacking_l = true
	
	# BLOQUEO DE MOVIMIENTO (Si cualquiera de las armas lo pide, paramos)
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
	
	# --- FASE 1: INICIO SUAVE ---
	_crear_tween(blend_path, 1.0, w.blend_time)
	if animation_tree:
		animation_tree[playback].travel(anim_name) # Travel es más suave
	
	await get_tree().create_timer(w.blend_time).timeout
	
	# --- FASE 2: WINDUP ---
	await get_tree().create_timer(w.windup_time).timeout
	
	# --- FASE 3: HITBOX ON ---
	var hitbox = _buscar_hitbox(hand_node)
	if hitbox:
		hitbox.collision_mask = attack_layer_mask
		var total_damage = w.damage * damage_multiplier
		if attribute_manager and attribute_manager.has_method("get_stat"):
			total_damage = attribute_manager.get_stat("melee_damage") * (w.damage / 10.0) 
		
		hitbox.activate(total_damage, w.knockback_force, w.jump_force, owner_node)
	
	# --- FASE 4: ACTIVE TIME ---
	await get_tree().create_timer(w.active_time).timeout
	if hitbox: hitbox.deactivate()
	
	# --- FASE 5: COMPLETAR ANIMACIÓN (Tiempo restante manual) ---
	var tiempo_usado = w.blend_time + w.windup_time + w.active_time
	var tiempo_restante = w.total_animation_time - tiempo_usado
	
	if tiempo_restante > 0:
		await get_tree().create_timer(tiempo_restante).timeout
	
	# --- FASE 6: FINALIZAR (LIBERAR LA MANO CORRECTA) ---
	if w.is_two_handed:
		is_attacking_r = false
		is_attacking_l = false
	elif mano == "right":
		is_attacking_r = false
	else:
		is_attacking_l = false
	
	# Solo liberamos movimiento si no hay OTRA mano atacando que requiera bloqueo
	if not is_attacking_r and not is_attacking_l:
		is_movement_locked = false
	
	_crear_tween(blend_path, 0.0, 0.2)
	
	# COOLDOWN INDEPENDIENTE
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
