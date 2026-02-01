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
const BLEND_STATIC = "parameters/Mezcla_Static/blend_amount"
const PLAYBACK_STATIC = "parameters/Combat_Static/playback"

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
		
		#var tab = Input.is_physical_key_pressed(KEY_TAB)
		#var mano = "left" if tab else "right"
		#if mano == "right" and is_attacking_r: return
		#if mano == "left" and is_attacking_l: return

		#match event.keycode:
		#	KEY_1: unequip_weapon(mano)
		#	KEY_2: if slot_2: equip_weapon(slot_2, mano)
		#	KEY_3: if slot_3: equip_weapon(slot_3, mano)
		#	KEY_4: if slot_4: equip_weapon(slot_4, mano)

func equip_weapon(data: WeaponData, mano: String):
	if not right_hand_bone or not left_hand_bone: return

	# CASO 1: EL NUEVO ARMA ES DE 2 MANOS
	if data.is_two_handed:
		if is_attacking_r or is_attacking_l: return
		
		# Desactivamos mezclas de 1 mano y activamos la de 2 manos
		_crear_tween(BLEND_2H, 1.0)
		_crear_tween(BLEND_R, 0.0)
		_crear_tween(BLEND_L, 0.0)
		
		_limpiar_manos() # Borra visuales de ambas manos
		weapon_r = data
		weapon_l = null  # Aseguramos que la izquierda sea null lógica
		
		_instanciar_visual(data, right_hand_bone)

	# CASO 2: EL NUEVO ARMA ES DE 1 MANO
	else:
		# 🚨 VERIFICACIÓN DE SEGURIDAD NUEVA 🚨
		# Si actualmente llevamos un arma de 2 manos, hay que quitarla por completo
		# antes de poner una de 1 mano, sin importar en qué slot vaya.
		if weapon_r and weapon_r.is_two_handed:
			weapon_r = null
			_limpiar_nodo(right_hand_bone)
			_crear_tween(BLEND_2H, 0.0) # Apagamos la mezcla de 2H
			
		_crear_tween(BLEND_2H, 0.0) # Aseguramos que 2H esté apagado

		if mano == "right":
			if is_attacking_r: return
			weapon_r = data
			_crear_tween(BLEND_R, 1.0) # Activamos mezcla Derecha (OJO: estaba en 0.0 en tu script)
			_limpiar_nodo(right_hand_bone)
			_instanciar_visual(data, right_hand_bone)
			_viajar_animacion(PLAYBACK_R, data.anim_idle)
		else:
			if is_attacking_l: return
			weapon_l = data
			_crear_tween(BLEND_L, 1.0) # Activamos mezcla Izquierda (OJO: estaba en 0.0 en tu script)
			_limpiar_nodo(left_hand_bone)
			_instanciar_visual(data, left_hand_bone)
			_viajar_animacion(PLAYBACK_L, data.anim_idle)

	emit_signal("on_weapon_changed", mano, data)

func unequip_weapon(mano: String):
	if mano == "left": weapon_l = null; _limpiar_nodo(left_hand_bone); _crear_tween(BLEND_L, 0.0)
	else: weapon_r = null; _limpiar_nodo(right_hand_bone); _crear_tween(BLEND_R, 0.0)
	emit_signal("on_weapon_changed", mano, null)

func try_attack(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	# Verificaciones de Bloqueo
	if w.is_two_handed:
		if is_attacking_r or is_attacking_l: return
	else:
		if mano == "right" and is_attacking_r: return
		if mano == "left" and is_attacking_l: return
	
	# Verificación de Cooldown
	if mano == "right" and cd_timer_r > 0: return
	if mano == "left" and cd_timer_l > 0: return
	
	# 🔴 NUEVO: Restricción de Suelo para armas pesadas
	# Si el arma detiene el movimiento, exigimos estar tocando el piso.
	if w.stop_movement:
		if owner_node.has_method("is_on_floor") and not owner_node.is_on_floor():
			return # ¡No puedes usar armas pesadas en el aire!

	# Consumo de Stamina
	if stamina_component and stamina_component.has_method("try_consume"):
		if not stamina_component.try_consume(w.stamina_cost): return
		
	_ejecutar_secuencia_ataque(w, mano)

func _ejecutar_secuencia_ataque(w: WeaponData, mano: String):
	# 1. Configurar Estados
	if w.is_two_handed: is_attacking_r = true; is_attacking_l = true
	elif mano == "right": is_attacking_r = true
	else: is_attacking_l = true
	
	# Bloquear movimiento si el arma lo requiere (Armas 2H)
	if w.stop_movement: is_movement_locked = true
	
	# 2. Seleccionar Animación y Huesos
	var playback = ""
	var blend_path = ""
	var anim_name = w.anim_attack
	var hand_node = null
	
	# Detectamos si es un ataque estático (Pesado)
	var es_ataque_estatico = w.stop_movement
	
	if es_ataque_estatico:
		# RUTA NUEVA: Cuerpo Completo (Override)
		# Usamos la nueva máquina y el nuevo blend sin filtros
		playback = PLAYBACK_STATIC
		blend_path = BLEND_STATIC
		hand_node = right_hand_bone # Asumimos mano derecha para 2H
	
	elif w.is_two_handed:
		# 🔵 RUTA ANTIGUA: 2H Móvil (Filtrado)
		playback = PLAYBACK_2H
		blend_path = BLEND_2H
		hand_node = right_hand_bone
		
	elif mano == "right":
		playback = PLAYBACK_R; blend_path = BLEND_R; hand_node = right_hand_bone
	else:
		playback = PLAYBACK_L; blend_path = BLEND_L; hand_node = left_hand_bone; anim_name += "_L"
	
	# 3. Calcular Velocidades (Time Warping)
	var target_speed = attack_speed_multiplier
	
	# Límite visual para el Windup (para que se vea la preparación)
	var visual_windup_speed = target_speed
	if target_speed > 1.7: visual_windup_speed = 1.7 
	
	var real_windup = w.windup_time / visual_windup_speed
	
	# Transición de entrada (Blend In) rápida
	var visual_blend = w.blend_time
	if target_speed > 1.5: visual_blend = 0.05
	
	# --- FASE 1: WINDUP (Preparación) ---
	if anim_player_node: anim_player_node.speed_scale = visual_windup_speed
	
	_crear_tween(blend_path, 1.0, visual_blend)
	if animation_tree:
		animation_tree[playback].start(anim_name)
		animation_tree.advance(0.0) # Forzar inicio desde frame 0
	
	await get_tree().create_timer(real_windup).timeout
	
	# --- FASE 2: GOLPE (Active) ---
	var hitbox = _buscar_hitbox(hand_node)
	if hitbox:
		hitbox.collision_mask = attack_layer_mask
		var final_damage = w.damage
		
		# Sumar daño base de atributos (si existe)
		if attribute_manager and attribute_manager.has_method("get_stat"):
			final_damage += attribute_manager.get_stat("melee_damage")
		
		final_damage *= damage_multiplier
		
		if randf() < crit_chance:
			final_damage *= crit_damage
			print("💥 CRÍTICO! Daño: ", final_damage)
		
		hitbox.activate(final_damage, w.knockback_force, w.jump_force, owner_node)
	
	# --- FASE 3: RECUPERACIÓN Y MEZCLA (Simultáneas) ---
	
	# Aceleramos la recuperación si tenemos mucha velocidad de ataque
	var recovery_speed = target_speed
	if target_speed > 1.7: recovery_speed = target_speed * 1.5 
	
	if anim_player_node: anim_player_node.speed_scale = recovery_speed
	
	var real_active = w.active_time / recovery_speed
	var real_total = w.total_animation_time / target_speed
	
	# Esperamos a que termine el Hitbox activo
	await get_tree().create_timer(real_active).timeout
	if hitbox: hitbox.deactivate()
	
	# =========================================================
	# 🟢 SOLUCIÓN AL CORTE BRUSCO (MEZCLA SIMULTÁNEA)
	# =========================================================
	# En lugar de esperar a que termine la animación para mezclar,
	# empezamos a mezclar hacia 0.0 MIENTRAS termina la animación.
	
	var tiempo_gastado = real_windup + real_active
	var tiempo_restante_anim = real_total - tiempo_gastado
	
	# La transición durará lo que le quede a la animación o un mínimo de 0.15s
	# para asegurar suavidad.
	var duracion_fade = max(0.15, tiempo_restante_anim)
	
	# Iniciamos el apagado del blend YA MISMO
	_crear_tween(blend_path, 0.0, duracion_fade)
	
	# Esperamos visualmente a que termine esa transición
	if duracion_fade > 0:
		await get_tree().create_timer(duracion_fade).timeout
	
	# --- RESET FINAL ---
	if anim_player_node: anim_player_node.speed_scale = 1.0
	
	if w.is_two_handed: is_attacking_r = false; is_attacking_l = false
	elif mano == "right": is_attacking_r = false
	else: is_attacking_l = false
	
	if not is_attacking_r and not is_attacking_l: 
		is_movement_locked = false # Liberamos movimiento
	
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

# Función para que los Jefes activen el hitbox manualmente con tiempos personalizados
func manual_hitbox_activation(damage_mult_override: float, duration: float, knockback_force: float, hand_node: Node3D):
	var hitbox = _buscar_hitbox(hand_node)
	if hitbox:
		hitbox.collision_mask = attack_layer_mask
		
		# Calculamos daño base
		var base_dmg = 10.0
		if weapon_r: base_dmg = weapon_r.damage # Usamos el daño del arma equipada
		
		# Sumamos atributos
		if attribute_manager and attribute_manager.has_method("get_stat"):
			base_dmg += attribute_manager.get_stat("melee_damage")
		
		# Aplicamos multiplicadores
		var final_damage = base_dmg * damage_multiplier * damage_mult_override
		
		# Activar
		hitbox.activate(final_damage, knockback_force, 5.0, owner_node)
		
		# Esperar y desactivar
		await get_tree().create_timer(duration).timeout
		if hitbox: hitbox.deactivate()
