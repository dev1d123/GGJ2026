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
@export var mask_manager: MaskManager 

# --- CONFIGURACIÓN ---
@export_category("Reglas de Combate")
@export_flags_3d_physics var attack_layer_mask: int = 0 
@export var damage_multiplier: float = 1.0 

@export_category("Recompensas")
## Cantidad de carga de Ulti que da este personaje al morir
@export var ult_charge_reward: float = 10.0

# --- INVENTARIO ---
@export_category("Inventario Armas")
@export var slot_1_left: WeaponData
@export var slot_1_right: WeaponData
@export var slot_2: WeaponData 
@export var slot_3: WeaponData 
@export var slot_4: WeaponData 

@export_category("Inventario Máscaras")
@export var mask_slot_1: MaskData

signal on_weapon_changed(hand, weapon_data) # Nueva Señal

# --- STATS DINÁMICOS ---
var attack_speed_multiplier: float = 1.0
var crit_chance: float = 0.0
var crit_damage: float = 2.0

# --- ESTADO PÚBLICO ---
var is_attacking_r: bool = false
var is_attacking_l: bool = false
var is_movement_locked: bool = false 

var is_attacking: bool:
	get: return is_attacking_r or is_attacking_l

# Internas
var weapon_r: WeaponData
var weapon_l: WeaponData
var cd_timer_r: float = 0.0
var cd_timer_l: float = 0.0
var owner_node: Node = null 
var anim_player_node: AnimationPlayer = null 

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
	if owner_node.has_node("AnimationPlayer"):
		anim_player_node = owner_node.get_node("AnimationPlayer")
	if not mask_manager and owner_node.has_node("MaskManager"):
		mask_manager = owner_node.get_node("MaskManager")

	if animation_tree:
		animation_tree.set(BLEND_R, 0.0)
		animation_tree.set(BLEND_L, 0.0)
		animation_tree.set(BLEND_2H, 0.0)
	
	if slot_1_right: equip_weapon(slot_1_right, "right")
	if slot_1_left: equip_weapon(slot_1_left, "left")

func _process(delta):
	if cd_timer_r > 0: cd_timer_r -= delta
	if cd_timer_l > 0: cd_timer_l -= delta

func _input(event):
	if not is_player_controlled: return
	if "is_dead" in owner_node and owner_node.is_dead: return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: try_attack("right")
		elif event.button_index == MOUSE_BUTTON_LEFT: try_attack("left")

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U:
			if mask_manager and mask_slot_1:
				if mask_manager.current_mask == mask_slot_1:
					mask_manager.remove_mask()
				else:
					mask_manager.equip_mask(mask_slot_1)
		
		var tab = Input.is_physical_key_pressed(KEY_TAB)
		var mano = "left" if tab else "right"
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return

		match event.keycode:
			KEY_1: unequip_weapon(mano)
			KEY_2: if slot_2: equip_weapon(slot_2, mano)
			KEY_3: if slot_3: equip_weapon(slot_3, mano)
			KEY_4: if slot_4: equip_weapon(slot_4, mano)

func equip_weapon(data: WeaponData, mano: String):
	if not right_hand_bone or not left_hand_bone: return
	if data.is_two_handed:
		if is_attacking_r or is_attacking_l: return
		_crear_tween(BLEND_2H, 1.0); _crear_tween(BLEND_R, 0.0); _crear_tween(BLEND_L, 0.0)
		_limpiar_manos()
		weapon_r = data; weapon_l = null
		_instanciar_visual(data, right_hand_bone)
	else:
		_crear_tween(BLEND_2H, 0.0)
		if mano == "right":
			if is_attacking_r: return
			weapon_r = data
			_crear_tween(BLEND_R, 0.0); _limpiar_nodo(right_hand_bone); _instanciar_visual(data, right_hand_bone)
			_viajar_animacion(PLAYBACK_R, data.anim_idle)
		else:
			if is_attacking_l: return
			weapon_l = data
			_crear_tween(BLEND_L, 0.0); _limpiar_nodo(left_hand_bone); _instanciar_visual(data, left_hand_bone)
			_viajar_animacion(PLAYBACK_L, data.anim_idle)
	emit_signal("on_weapon_changed", mano, data)

func unequip_weapon(mano: String):
	if mano == "left": weapon_l = null; _limpiar_nodo(left_hand_bone); _crear_tween(BLEND_L, 0.0)
	else: weapon_r = null; _limpiar_nodo(right_hand_bone); _crear_tween(BLEND_R, 0.0)
	emit_signal("on_weapon_changed", mano, null)

func try_attack(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	if w.is_two_handed:
		if is_attacking_r or is_attacking_l: return
	else:
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return
	
	if mano == "right" and cd_timer_r > 0: return
	if mano == "left" and cd_timer_l > 0: return
	
	if stamina_component and stamina_component.has_method("try_consume"):
		if not stamina_component.try_consume(w.stamina_cost): return 

	_ejecutar_secuencia_ataque(w, mano)

func _ejecutar_secuencia_ataque(w: WeaponData, mano: String):
	if w.is_two_handed: is_attacking_r = true; is_attacking_l = true
	elif mano == "right": is_attacking_r = true
	else: is_attacking_l = true
	
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
	
	# =================================================================
	# ⚡ VELOCIDAD VARIABLE (TIME WARPING) ⚡
	# =================================================================
	
	var target_speed = attack_speed_multiplier
	
	# 1. VELOCIDAD VISUAL TOPE (CAP)
	# Si la velocidad es extrema (>1.7), limitamos la velocidad visual del Windup
	# a 1.7x para asegurar que el ojo humano vea el arma subir.
	var visual_windup_speed = target_speed
	if target_speed > 1.7:
		visual_windup_speed = 1.7 
	
	# 2. CALCULAR TIEMPO REAL BASADO EN VELOCIDAD VISUAL
	# El tiempo de espera será un poco más largo para permitir que la animación se vea.
	var real_windup = w.windup_time / visual_windup_speed
	
	# 3. EL BLEND TIME (Transición)
	# Lo mantenemos muy corto en velocidades altas para no comer frames.
	var visual_blend = w.blend_time
	if target_speed > 1.5: visual_blend = 0.05
	
	# =================================================================
	# FASE 1: WINDUP (Levantar el arma - Velocidad Controlada)
	# =================================================================
	
	if anim_player_node: 
		anim_player_node.speed_scale = visual_windup_speed
	
	_crear_tween(blend_path, 1.0, visual_blend)
	if animation_tree:
		animation_tree[playback].start(anim_name)
		animation_tree.advance(0.0) # Sincronización forzada
	
	# Esperamos el tiempo necesario para ver el arma arriba
	await get_tree().create_timer(real_windup).timeout
	
	# =================================================================
	# FASE 2: GOLPE (Hitbox ON)
	# =================================================================
	
	var hitbox = _buscar_hitbox(hand_node)
	if hitbox:
		hitbox.collision_mask = attack_layer_mask
		var final_damage = w.damage
		if attribute_manager and attribute_manager.has_method("get_stat"):
			final_damage += attribute_manager.get_stat("melee_damage")
		final_damage *= damage_multiplier
		
		if randf() < crit_chance:
			final_damage *= crit_damage
			print("💥 CRÍTICO! Daño: ", final_damage)
		
		hitbox.activate(final_damage, w.knockback_force, w.jump_force, owner_node)
	
	# =================================================================
	# FASE 3: RECUPERACIÓN (Velocidad Extrema)
	# =================================================================
	# Aquí compensamos el tiempo perdido. Aceleramos mucho la bajada.
	
	var recovery_speed = target_speed
	if target_speed > 1.7:
		# Si limitamos el windup, aceleramos el recovery x3 para mantener el DPS
		recovery_speed = target_speed * 1.5 
	
	if anim_player_node: 
		anim_player_node.speed_scale = recovery_speed
	
	var real_active = w.active_time / recovery_speed
	var real_total = w.total_animation_time / target_speed # El total global se respeta aprox
	
	# Esperar duración del hitbox
	await get_tree().create_timer(real_active).timeout
	if hitbox: hitbox.deactivate()
	
	# Esperar resto del tiempo (si queda)
	var tiempo_gastado = real_windup + real_active
	var tiempo_restante = real_total - tiempo_gastado
	
	if tiempo_restante > 0:
		await get_tree().create_timer(tiempo_restante).timeout
	
	# --- RESET ---
	if anim_player_node: anim_player_node.speed_scale = 1.0
	
	if w.is_two_handed: is_attacking_r = false; is_attacking_l = false
	elif mano == "right": is_attacking_r = false
	else: is_attacking_l = false
	
	if not is_attacking_r and not is_attacking_l: is_movement_locked = false
	
	_crear_tween(blend_path, 0.0, 0.2)
	
	var real_cooldown = w.cooldown / target_speed
	if mano == "right": cd_timer_r = real_cooldown
	else: cd_timer_l = real_cooldown

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
