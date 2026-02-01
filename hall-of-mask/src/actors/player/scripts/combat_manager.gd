extends Node3D
class_name CombatManager

# ------------------------------------------------------------------------------
# 1. DEPENDENCIAS
# ------------------------------------------------------------------------------
@export_category("Referencias Obligatorias")
@export var animation_tree: AnimationTree
@export var right_hand_bone: Node3D 
@export var left_hand_bone: Node3D  

@export_category("Control de Input")
@export var is_player_controlled: bool = false 

@export_category("Componentes Opcionales")
@export var stamina_component: Node 
@export var mana_component: Node 
@export var attribute_manager: Node 
@export var mask_manager: MaskManager 

# ------------------------------------------------------------------------------
# 2. CONFIGURACIÓN
# ------------------------------------------------------------------------------
@export_category("Reglas de Combate")
@export_flags_3d_physics var attack_layer_mask: int = 1 
@export var damage_multiplier: float = 1.0 
@export var ult_charge_reward: float = 10.0

# ------------------------------------------------------------------------------
# 3. INVENTARIO
# ------------------------------------------------------------------------------
@export_category("Inventario Armas")
@export var slot_1_left: WeaponData
@export var slot_1_right: WeaponData
@export var slot_2: WeaponData 
@export var slot_3: WeaponData 
@export var slot_4: WeaponData 
@export var mask_slot_1: MaskData

signal on_weapon_changed(hand, weapon_data)

# ------------------------------------------------------------------------------
# 4. VARIABLES INTERNAS
# ------------------------------------------------------------------------------
# --- BLOOM & APUNTADO ---
var current_spread: float = 0.0
var target_spread: float = 0.0
const SPREAD_MOVE: float = 1.5
const SPREAD_AIR: float = 3.0
const SPREAD_DODGE: float = 5.0
const AIM_SPREAD_MULTIPLIER: float = 0.1 

var is_aiming: bool = false
@export var reticle_ui: Control

# --- VARIABLES BEAM (RAYO) ---
var active_beam_node: Node3D = null
var beam_tick_timer: float = 0.0
var beam_current_fuel: float = 6.0 # Combustible actual (segundos)
var beam_is_overheated: bool = false
var beam_overheat_timer: float = 0.0
var beam_firing_state: bool = false # Si el jugador mantiene el botón

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
var ai_target: Node3D = null

# --- RUTAS ANIMATION TREE ---
const BLEND_R = "parameters/Mezcla_R/blend_amount"
const BLEND_L = "parameters/Mezcla_L/blend_amount"
const BLEND_2H = "parameters/Mezcla_2H/blend_amount"
const BLEND_RANGED = "parameters/Mezcla_Ranged/blend_amount"
const BLEND_STATIC = "parameters/Mezcla_Static/blend_amount"

const PLAYBACK_R = "parameters/Combat_R/playback"
const PLAYBACK_L = "parameters/Combat_L/playback"
const PLAYBACK_2H = "parameters/Combat_2H/playback"
const PLAYBACK_RANGED = "parameters/Combat_Ranged/playback"
const PLAYBACK_STATIC = "parameters/Combat_Static/playback"

# ------------------------------------------------------------------------------
# 5. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready():
	owner_node = get_parent()
	if not animation_tree and owner_node.has_node("AnimationTree"):
		animation_tree = owner_node.get_node("AnimationTree")
	if owner_node.has_node("AnimationPlayer"):
		anim_player_node = owner_node.get_node("AnimationPlayer")
	
	if not mask_manager and owner_node.has_node("MaskManager"): mask_manager = owner_node.get_node("MaskManager")
	if not mana_component and owner_node.has_node("ManaComponent"): mana_component = owner_node.get_node("ManaComponent")
	if not stamina_component and owner_node.has_node("StaminaComponent"): stamina_component = owner_node.get_node("StaminaComponent")

	if animation_tree:
		_safe_set_blend(BLEND_R, 0.0)
		_safe_set_blend(BLEND_L, 0.0)
		_safe_set_blend(BLEND_2H, 0.0)
		_safe_set_blend(BLEND_RANGED, 0.0)
	
	if slot_1_right: equip_weapon(slot_1_right, "right")
	if slot_1_left: equip_weapon(slot_1_left, "left")

func _process(delta):
	if cd_timer_r > 0: cd_timer_r -= delta
	if cd_timer_l > 0: cd_timer_l -= delta
	_calcular_bloom(delta)
	
	# LÓGICA DE CALOR Y RAYO
	_process_beam_heat(delta)
	
	# 🟢 FIX: FORZAR CONGELADO DE ANIMACIÓN
	# Si estamos disparando el rayo, aseguramos que la animación no avance
	if active_beam_node and anim_player_node:
		anim_player_node.speed_scale = 0.0
		
	# Si NO hay ningún ataque activo, forzamos que todos los blends bajen a 0.
	# Esto corrige que se vean raros al caminar/correr si una animación se cortó.
	if not is_attacking:
		_limpiar_blends_residuales(delta)

# Función auxiliar para borrar rastros de ataques anteriores
func _limpiar_blends_residuales(delta):
	if not animation_tree: return
	
	# Lista de todos tus blends de combate
	var paths = [BLEND_R, BLEND_L, BLEND_2H, BLEND_RANGED, BLEND_STATIC]
	
	for path in paths:
		# Obtenemos valor actual (si existe el path)
		var val = animation_tree.get(path)
		if val != null and val > 0.0:
			# Lo bajamos a 0 rápidamente (pero suave para que no "popee")
			var nuevo_val = move_toward(val, 0.0, 5.0 * delta)
			animation_tree.set(path, nuevo_val)

func _input(event):
	if not is_player_controlled: return
	if "is_dead" in owner_node and owner_node.is_dead: return

	# Tecla U para máscara (Lógica original)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_U:
			if mask_manager and mask_slot_1:
				if mask_manager.current_mask == mask_slot_1:
					mask_manager.remove_mask()
				else:
					mask_manager.equip_mask(mask_slot_1)

# ------------------------------------------------------------------
# EQUIPAMIENTO
# ------------------------------------------------------------------
func equip_weapon(data: WeaponData, mano: String):
	if not right_hand_bone or not left_hand_bone: return

	# Limpieza preventiva de blends
	_safe_set_tween(BLEND_2H, 0.0)
	_safe_set_tween(BLEND_RANGED, 0.0)
	_safe_set_tween(BLEND_R, 0.0)
	_safe_set_tween(BLEND_L, 0.0)
	
	if data.is_two_handed:
		if is_attacking_r or is_attacking_l: return
		
		_safe_set_tween(BLEND_2H, 1.0)
		_limpiar_manos()
		weapon_r = data
		weapon_l = null 
		_instanciar_visual(data, right_hand_bone)
		
	else:
		if weapon_r and weapon_r.is_two_handed:
			weapon_r = null
			_limpiar_nodo(right_hand_bone)

		if mano == "right":
			if is_attacking_r: return
			weapon_r = data
			_safe_set_tween(BLEND_R, 1.0)
			_limpiar_nodo(right_hand_bone)
			_instanciar_visual(data, right_hand_bone)
			_viajar_animacion(PLAYBACK_R, data.anim_idle)
		else:
			if is_attacking_l: return
			weapon_l = data
			_safe_set_tween(BLEND_L, 1.0)
			_limpiar_nodo(left_hand_bone)
			_instanciar_visual(data, left_hand_bone)
			_viajar_animacion(PLAYBACK_L, data.anim_idle)

	emit_signal("on_weapon_changed", mano, data)

func unequip_weapon(mano: String):
	if mano == "left": weapon_l = null; _limpiar_nodo(left_hand_bone); _safe_set_tween(BLEND_L, 0.0)
	else: weapon_r = null; _limpiar_nodo(right_hand_bone); _safe_set_tween(BLEND_R, 0.0)
	emit_signal("on_weapon_changed", mano, null)

# ------------------------------------------------------------------
# GESTIÓN DE INPUT INTELIGENTE (HÍBRIDO)
# ------------------------------------------------------------------

# CLICK DERECHO (HOLD Rango / PRESS Melee)
func handle_right_click(pressed: bool):
	var w = weapon_r
	
	# CASO 1: RANGO -> APUNTAR
	if w is RangedWeaponData:
		is_aiming = pressed
		if w.has_aim_animation:
			if is_aiming:
				_safe_set_tween(BLEND_RANGED, 1.0, 0.1)
				var aim_anim = w.anim_attack + "_Aim"
				_viajar_animacion(PLAYBACK_RANGED, aim_anim)
			else:
				if not is_attacking_r:
					_safe_set_tween(BLEND_RANGED, 0.0, 0.2)
	
	# CASO 2: MELEE -> ATACAR DERECHA
	else:
		is_aiming = false 
		if pressed: _try_melee_attack("right")

# CLICK IZQUIERDO (PRESS Disparar / PRESS Melee)
func handle_left_click(pressed: bool):
	var w = weapon_r
	if not w: return
	
	# CASO 1: ARMA DE RANGO
	if w is RangedWeaponData:
		# A. MODO RAYO (BEAM)
		if w.is_beam_weapon:
			if pressed:
				_start_beam_sequence(w)
			else:
				_stop_beam_sequence()
			return
		
		# B. MODO DISPARO NORMAL
		if pressed: 
			if is_attacking_r or cd_timer_r > 0: return 
			if w.mana_cost > 0:
				if mana_component and mana_component.has_method("try_consume"):
					if not mana_component.try_consume(w.mana_cost): return
			_ejecutar_disparo_rango(w, "right")
	
	# CASO 2: MELEE
	else:
		if pressed: _try_melee_attack("left")

# Wrapper Interno Melee
func _try_melee_attack(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	# Bloqueos Melee (Lógica original)
	if w.is_two_handed:
		if is_attacking_r or is_attacking_l: return
	else:
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return
	
	if mano == "right" and cd_timer_r > 0: return
	if mano == "left" and cd_timer_l > 0: return
	
	# Restricción Suelo
	if w.stop_movement:
		if owner_node.has_method("is_on_floor") and not owner_node.is_on_floor(): return
	
	# Stamina
	if stamina_component and stamina_component.has_method("try_consume"):
		if not stamina_component.try_consume(w.stamina_cost): return
		
	_ejecutar_secuencia_ataque(w, mano)

# Alias para compatibilidad con IA
func try_attack(mano: String):
	if mano == "right": _try_melee_attack("right")
	else: _try_melee_attack("left")

# ------------------------------------------------------------------
# LÓGICA DE DISPARO (RANGO - SHOOTER)
# ------------------------------------------------------------------
func _ejecutar_disparo_rango(w: RangedWeaponData, mano: String):
	if mano == "right": is_attacking_r = true
	else: is_attacking_l = true
	
	var anim_name = w.anim_attack
	_safe_set_blend(BLEND_RANGED, 1.0) 
	_viajar_animacion(PLAYBACK_RANGED, anim_name)
	
	var visual_speed = max(attack_speed_multiplier, 1.0)
	var real_windup = w.windup_time / visual_speed
	
	if anim_player_node: anim_player_node.speed_scale = visual_speed
	await get_tree().create_timer(real_windup).timeout
	
	# Instanciar
	var hand_node = right_hand_bone
	var spawn_pos = hand_node.global_position
	var muzzle = _find_muzzle(hand_node)
	if muzzle: spawn_pos = muzzle.global_position
	
	var aim_target = _get_aim_target()
	
	for i in range(w.projectile_count):
		if w.projectile_scene:
			var proj = w.projectile_scene.instantiate()
			get_tree().current_scene.add_child(proj)
			proj.global_position = spawn_pos
			proj.shooter_node = owner_node
			
			# Esto asegura que la máscara se aplique aunque el Area3D sea un hijo
			_aplicar_mascara_recursiva(proj, attack_layer_mask)
			
			# --- CORRECCIÓN AQUÍ ---
			# Le pasamos la máscara que tiene configurada este CombatManager.
			# Si soy Enemigo, mi mask es 2 (Player). Si soy Player, es 4 (Enemigo).
			if "collision_mask" in proj:
				proj.collision_mask = attack_layer_mask
			
			# Opcional: Si el proyectil es un Area3D, asegúrate de que no choque con quien dispara
			if proj.has_method("add_exception"):
				proj.add_exception(owner_node)
			# -----------------------
			
			var final_damage = w.damage
			if attribute_manager and attribute_manager.has_method("get_stat"):
				final_damage += attribute_manager.get_stat("ranged_damage")
			proj.damage = final_damage * damage_multiplier
			proj.speed = w.launch_speed
			proj.use_gravity = w.use_gravity
			
			var dest = _apply_spread(aim_target, current_spread, spawn_pos)
			var dir = (dest - spawn_pos).normalized()
			
			if "movement_direction" in proj: proj.movement_direction = dir
			proj.look_at(spawn_pos + dir, Vector3.UP)
			
	if w.muzzle_flash_scene:
		var flash = w.muzzle_flash_scene.instantiate()
		get_tree().current_scene.add_child(flash)
		flash.global_position = spawn_pos
		if muzzle: flash.global_rotation = muzzle.global_rotation
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(flash): flash.queue_free()
	
	if w.recoil_shake > 0 and owner_node.has_method("add_camera_trauma"):
		owner_node.add_camera_trauma(w.recoil_shake)
	
	print("🪄 Disparo: ", w.name)

	if anim_player_node: anim_player_node.speed_scale = 1.0
	cd_timer_r = w.cooldown / attack_speed_multiplier
	
	await get_tree().create_timer(w.active_time).timeout
	
	if is_aiming and w.has_aim_animation:
		var aim_anim = w.anim_attack + "_Aim"
		_viajar_animacion(PLAYBACK_RANGED, aim_anim)
	else:
		_safe_set_tween(BLEND_RANGED, 0.0, 0.3)
	
	is_attacking_r = false

# ------------------------------------------------------------------
# LÓGICA MELEE (RESTAURADA 1:1 DE TU CÓDIGO FUNCIONAL)
# ------------------------------------------------------------------
func _ejecutar_secuencia_ataque(w: WeaponData, mano: String):
	# 1. Configurar Estados
	if w.is_two_handed: is_attacking_r = true; is_attacking_l = true
	elif mano == "right": is_attacking_r = true
	else: is_attacking_l = true
	
	if w.stop_movement: is_movement_locked = true
	
	# 2. Seleccionar Animación y Huesos
	var playback = ""
	var blend_path = ""
	var anim_name = w.anim_attack
	var hand_node = null
	
	if w.stop_movement:
		playback = PLAYBACK_STATIC; blend_path = BLEND_STATIC; hand_node = right_hand_bone 
	elif w.is_two_handed:
		playback = PLAYBACK_2H; blend_path = BLEND_2H; hand_node = right_hand_bone
	elif mano == "right":
		playback = PLAYBACK_R; blend_path = BLEND_R; hand_node = right_hand_bone
	else:
		playback = PLAYBACK_L; blend_path = BLEND_L; hand_node = left_hand_bone; anim_name += "_L"
	
	# 3. Calcular Velocidades (Time Warping)
	var target_speed = attack_speed_multiplier
	var visual_windup_speed = target_speed
	if target_speed > 1.7: visual_windup_speed = 1.7 
	
	var real_windup = w.windup_time / visual_windup_speed
	
	# 🟢 RESTAURADO: Cálculo dinámico de Blend (Clave para atacar corriendo)
	var visual_blend = w.blend_time
	if target_speed > 1.5: visual_blend = 0.05
	
	# --- FASE 1: WINDUP ---
	if anim_player_node: anim_player_node.speed_scale = visual_windup_speed
	
	_safe_set_tween(blend_path, 1.0, visual_blend)
	if animation_tree:
		animation_tree[playback].start(anim_name)
		animation_tree.advance(0.0)
	
	await get_tree().create_timer(real_windup).timeout
	
	# --- FASE 2: GOLPE (Active) ---
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
	
	# --- FASE 3: RECUPERACIÓN ---
	var recovery_speed = target_speed
	if target_speed > 1.7: recovery_speed = target_speed * 1.5 
	
	if anim_player_node: anim_player_node.speed_scale = recovery_speed
	
	var real_active = w.active_time / recovery_speed
	var real_total = w.total_animation_time / target_speed
	
	await get_tree().create_timer(real_active).timeout
	if hitbox: hitbox.deactivate()
	
	# Solución al corte brusco (Mezcla simultánea)
	var tiempo_gastado = real_windup + real_active
	var tiempo_restante_anim = real_total - tiempo_gastado
	var duracion_fade = max(0.15, tiempo_restante_anim)
	
	_safe_set_tween(blend_path, 0.0, duracion_fade)
	
	if duracion_fade > 0:
		await get_tree().create_timer(duracion_fade).timeout
	
	# --- RESET FINAL ---
	if anim_player_node: anim_player_node.speed_scale = 1.0
	
	if w.is_two_handed: is_attacking_r = false; is_attacking_l = false
	elif mano == "right": is_attacking_r = false
	else: is_attacking_l = false
	
	is_movement_locked = false
	
	var real_cooldown = w.cooldown / target_speed
	if mano == "right": cd_timer_r = real_cooldown
	else: cd_timer_l = real_cooldown

# ------------------------------------------------------------------
# UTILIDADES Y SEGURIDAD
# ------------------------------------------------------------------
func _get_aim_target() -> Vector3:
	# 1. LÓGICA PARA EL JUGADOR (Cámara y Mouse)
	if is_player_controlled:
		var cam = get_viewport().get_camera_3d()
		if not cam: return owner_node.global_position + (owner_node.global_transform.basis.z * 10.0)
		
		var screen_center = get_viewport().get_visible_rect().size / 2.0
		var from = cam.project_ray_origin(screen_center)
		var to = from + cam.project_ray_normal(screen_center) * 1000.0
		
		var space = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [owner_node.get_rid()] 
		
		var result = space.intersect_ray(query)
		if result: return result.position
		return to 

	# 2. LÓGICA PARA LA IA (ENEMIGOS) 🤖
	elif ai_target:
		# Apuntamos al pecho/cabeza del objetivo (offset vertical)
		# Si no ponemos el Vector3(0, 1.2, 0), le dispararán a tus pies y fallarán mucho.
		return ai_target.global_position + Vector3(0, 1.2, 0)
	
	# 3. FALLBACK (Si no hay target, disparan hacia adelante)
	else:
		# Dispara hacia donde está mirando el modelo (Forward vector)
		# Nota: En Godot -Z suele ser "Adelante"
		return owner_node.global_position - (owner_node.global_transform.basis.z * 10.0)

func _apply_spread(target: Vector3, spread_deg: float, origin: Vector3) -> Vector3:
	if spread_deg <= 0.01: return target
	var direction = (target - origin).normalized()
	var rng_x = deg_to_rad(randf_range(-spread_deg, spread_deg))
	var rng_y = deg_to_rad(randf_range(-spread_deg, spread_deg))
	var up = Vector3.UP
	var right = direction.cross(up).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	up = direction.cross(right).normalized()
	direction = direction.rotated(up, rng_x)
	direction = direction.rotated(right, rng_y)
	return origin + (direction * 2000.0)

func _calcular_bloom(delta):
	var w = weapon_r
	if not w or not (w is RangedWeaponData):
		if reticle_ui: reticle_ui.visible = false
		return
	var base = w.spread_degrees
	var penalty = 0.0
	if owner_node.velocity.length() > 0.5: penalty += SPREAD_MOVE
	if not owner_node.is_on_floor(): penalty += SPREAD_AIR
	
	target_spread = base + penalty
	if is_aiming: target_spread *= AIM_SPREAD_MULTIPLIER
	
	current_spread = lerp(current_spread, target_spread, 10.0 * delta)
	if reticle_ui:
		reticle_ui.visible = true
		reticle_ui.update_reticle_state(current_spread, w.reticle_style)

func _safe_set_blend(path: String, value: float):
	if animation_tree and animation_tree.get(path) != null: animation_tree.set(path, value)
func _safe_set_tween(path, val, tiempo = 0.2):
	if animation_tree and animation_tree.get(path) != null:
		var t = create_tween()
		t.tween_property(animation_tree, path, val, tiempo)
func _viajar_animacion(path, anim_name):
	if animation_tree and animation_tree.get(path) != null: animation_tree[path].travel(anim_name)
func _crear_tween(path, val, tiempo = 0.2): _safe_set_tween(path, val, tiempo) 

func _find_muzzle(parent) -> Node3D:
	if parent and parent.get_child_count() > 0:
		var weapon_model = parent.get_child(0)
		if weapon_model.has_node("Muzzle"): return weapon_model.get_node("Muzzle")
	return null

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

func manual_hitbox_activation(damage_mult_override: float, duration: float, knockback_force: float, hand_node: Node3D):
	var hitbox = _buscar_hitbox(hand_node)
	if hitbox:
		hitbox.collision_mask = attack_layer_mask
		var base_dmg = 10.0
		if weapon_r: base_dmg = weapon_r.damage 
		if attribute_manager and attribute_manager.has_method("get_stat"):
			base_dmg += attribute_manager.get_stat("melee_damage")
		var final_damage = base_dmg * damage_multiplier * damage_mult_override
		hitbox.activate(final_damage, knockback_force, 5.0, owner_node)
		await get_tree().create_timer(duration).timeout
		if hitbox: hitbox.deactivate()
	else:
		print("⚠️ CombatManager: manual_hitbox_activation no encontró hitbox en ", hand_node.name)


# ------------------------------------------------------------------
# LÓGICA DE RAYO CONTINUO (BEAM)
# ------------------------------------------------------------------
func _start_beam(w: RangedWeaponData):
	if active_beam_node: return # Ya estamos disparando
	if not w.projectile_scene: return
	
	print("⚡ INICIANDO RAYO")
	is_attacking_r = true # Bloqueamos otras acciones
	
	# 1. Instanciar el Rayo
	active_beam_node = w.projectile_scene.instantiate()
	right_hand_bone.add_child(active_beam_node) # Lo pegamos a la mano
	
	# Buscamos el muzzle si existe para posicionarlo bien
	var muzzle = _find_muzzle(right_hand_bone)
	if muzzle: 
		active_beam_node.global_position = muzzle.global_position
		active_beam_node.global_rotation = muzzle.global_rotation
	else:
		active_beam_node.position = Vector3.ZERO
		
	# Configurar datos del rayo
	active_beam_node.owner_node = owner_node
	active_beam_node.damage = w.damage + (attribute_manager.get_stat("ranged_damage") if attribute_manager else 0)
	active_beam_node.damage *= damage_multiplier
	
	# Animación (Loop de disparo o Aim)
	if w.has_aim_animation:
		var loop_anim = w.anim_attack + "_Aim" # Usamos la de Aim como loop de disparo
		_viajar_animacion(PLAYBACK_RANGED, loop_anim)
		_safe_set_tween(BLEND_RANGED, 1.0, 0.2)

func _stop_beam():
	if not active_beam_node: return
	
	print("⚡ DETENIENDO RAYO")
	active_beam_node.queue_free()
	active_beam_node = null
	is_attacking_r = false
	
	# Bajar brazo
	if not is_aiming:
		_safe_set_tween(BLEND_RANGED, 0.0, 0.3)

# Lógica que se ejecuta cada frame en _process
func _process_beam_logic(delta):
	if not active_beam_node: return
	var w = weapon_r
	if not w: 
		_stop_beam()
		return

	# 1. Drenaje de Maná por segundo
	if w.mana_cost_per_second > 0:
		if mana_component and mana_component.has_method("try_consume_continuous"):
			# Asumiendo que tienes una función para drenar float
			# Si no, usa try_consume normal pero acumulando el costo
			if not mana_component.try_consume(w.mana_cost_per_second * delta):
				_stop_beam() # Se acabó el maná
				return

	# 2. Apuntar el Rayo (Hacia donde mira la cámara)
	var aim_target = _get_aim_target()
	active_beam_node.look_at(aim_target, Vector3.UP)
	
	# 3. Aplicar Daño por Ticks
	beam_tick_timer -= delta
	if beam_tick_timer <= 0:
		beam_tick_timer = w.beam_tick_rate
		if active_beam_node.has_method("apply_damage"):
			active_beam_node.apply_damage()
			
	# 4. Camera Shake suave continuo
	if owner_node.has_method("add_camera_trauma"):
		owner_node.add_camera_trauma(0.05 * delta) # Vibración constante

# ------------------------------------------------------------------
# ⚡ LÓGICA DE RAYO (BEAM) - REFINADA
# ------------------------------------------------------------------

func _start_beam_sequence(w: RangedWeaponData):
	beam_firing_state = true # Marcamos que queremos disparar
	
	if beam_is_overheated: return
	if active_beam_node: return
	if is_attacking_r: return
	
	is_attacking_r = true
	
	# 1. Animación INICIO
	var anim_name = w.anim_attack
	_safe_set_blend(BLEND_RANGED, 1.0)
	_viajar_animacion(PLAYBACK_RANGED, anim_name)
	
	# 2. CALCULAR WINDUP
	var visual_speed = max(attack_speed_multiplier, 1.0)
	var real_windup = w.windup_time / visual_speed
	
	# Aseguramos velocidad normal para el windup
	if anim_player_node: anim_player_node.speed_scale = visual_speed
	
	# 🟢 ESPERA OBLIGATORIA (Aquí ocurre la magia del retraso)
	await get_tree().create_timer(real_windup).timeout
	
	# 🟢 CHEQUEO DE SEGURIDAD
	# Si soltamos el click DURANTE el windup, cancelamos todo.
	if not beam_firing_state:
		is_attacking_r = false # Liberar bloqueo
		_stop_beam_sequence()  # Limpiar
		return
	
	# 3. SI LLEGAMOS AQUÍ -> INSTANCIAR RAYO Y CONGELAR
	if w.projectile_scene:
		active_beam_node = w.projectile_scene.instantiate()
		right_hand_bone.add_child(active_beam_node)
		
		active_beam_node.owner_node = owner_node
		
		_aplicar_mascara_recursiva(active_beam_node, attack_layer_mask)
		
		# CALCULAR DAÑO FINAL AQUI
		var base_dmg = w.damage
		if attribute_manager: base_dmg += attribute_manager.get_stat("ranged_damage")
		
		var final_damage = base_dmg * damage_multiplier
		
		# Intentamos asignar a la variable que tenga el script del rayo
		if "damage" in active_beam_node: 
			active_beam_node.damage = final_damage
		elif "damage_per_tick" in active_beam_node: 
			active_beam_node.damage_per_tick = final_damage
		# -------------------------------------------------------
		
		# Posicionamiento (Muzzle)
		var muzzle = _find_muzzle(right_hand_bone)
		if muzzle:
			active_beam_node.global_position = muzzle.global_position
			active_beam_node.global_rotation = muzzle.global_rotation
		else:
			active_beam_node.position = Vector3.ZERO

func _stop_beam_sequence():
	beam_firing_state = false
	is_attacking_r = false
	
	# Reactivar animación
	if anim_player_node: anim_player_node.speed_scale = 1.0
	
	if active_beam_node:
		active_beam_node.queue_free()
		active_beam_node = null
	
	# Si no apuntamos, bajar brazo
	if not is_aiming:
		_safe_set_tween(BLEND_RANGED, 0.0, 0.3)

func _update_beam_aim_and_damage(w: RangedWeaponData, delta):
	if not active_beam_node: return
	
	# Apuntar
	var aim_target = _get_aim_target()
	active_beam_node.look_at(aim_target, Vector3.UP)
	
	# DAÑO POR TICKS
	beam_tick_timer -= delta
	if beam_tick_timer <= 0:
		beam_tick_timer = w.beam_tick_rate # Reset timer
		
		# LLAMADA AL SCRIPT DEL RAYO
		if active_beam_node.has_method("apply_damage_tick"):
			active_beam_node.apply_damage_tick()
	
	if owner_node.has_method("add_camera_trauma"):
		owner_node.add_camera_trauma(0.02 * delta)

func _process_beam_heat(delta):
	var w = weapon_r
	if not w or not (w is RangedWeaponData) or not w.is_beam_weapon: return
	
	# --- ESTADO: SOBRECALENTADO ---
	if beam_is_overheated:
		_stop_beam_sequence() # Forzar apagado
		
		beam_overheat_timer -= delta
		if beam_overheat_timer <= 0:
			# RECUPERACIÓN (3 segs después)
			beam_is_overheated = false
			beam_current_fuel = w.overheat_recovery_start # Empieza en 2.0s
			print("✅ ENFRIADO: Listo para disparar (Combustible: ", beam_current_fuel, "s)")
		return

	# --- ESTADO: DISPARANDO ---
	if active_beam_node:
		# 1. Drenaje de Combustible (Calor)
		beam_current_fuel -= delta
		
		if beam_current_fuel <= 0:
			beam_is_overheated = true
			beam_overheat_timer = w.overheat_cooldown # Esperar 3s
			print("🔥 ¡SOBRECALENTAMIENTO! Bloqueado 3s")
			_stop_beam_sequence()
			return
			
		# 2. Drenaje de Maná
		if w.mana_cost_per_second > 0 and mana_component:
			if not mana_component.try_consume(w.mana_cost_per_second * delta):
				_stop_beam_sequence() # Sin maná
				return
		
		# 3. Apuntar y Daño
		_update_beam_aim_and_damage(w, delta)
		
	# --- ESTADO: REPOSO (Recarga) ---
	else:
		if beam_current_fuel < w.max_beam_duration:
			beam_current_fuel += delta # Recarga 1 seg por seg
			# Opcional: Multiplicador de recarga rápida
			
		if beam_current_fuel > w.max_beam_duration:
			beam_current_fuel = w.max_beam_duration
			
func _aplicar_mascara_recursiva(nodo: Node, mascara: int):
	# 1. Si el nodo mismo tiene collision_mask (es Area3D, RayCast3D, CharacterBody3D)
	if "collision_mask" in nodo:
		nodo.collision_mask = mascara
		print("✅ Máscara ", mascara, " aplicada a: ", nodo.name)
		
		# Si es RayCast, añadir excepción
		if nodo is RayCast3D:
			nodo.add_exception(owner_node)
			
	# 2. Si no, buscamos en sus hijos (útil si el raíz es un contenedor Node3D)
	for child in nodo.get_children():
		_aplicar_mascara_recursiva(child, mascara)
