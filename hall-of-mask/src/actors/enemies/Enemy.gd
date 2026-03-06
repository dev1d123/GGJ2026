extends CharacterBody3D
class_name Enemy

# ------------------------------------------------------------------------------
# CONFIGURACIÓN
# ------------------------------------------------------------------------------
@export_group("Loadout Inicial")
@export var loadout_weapon_r: WeaponData 
@export var loadout_weapon_l: WeaponData 
@export var loadout_mask: MaskData       

@export_group("Equipamiento de Máscara")
enum MaskHandling { EQUIP_ON_SPAWN, EN_INVENTARIO, SIN_MASCARA }
@export var mask_handling: MaskHandling = MaskHandling.EQUIP_ON_SPAWN

enum MaskEquipCondition { 
	NONE, 
	HALF_HEALTH, 
	FIRST_ATTACK, 
	FIRST_HIT_RECEIVED, 
	ANY,
	LOW_HEALTH_DESPERATION, # Desespero: Vida menor al 25%
	ON_PROXIMITY,           # Si el jugador se le acerca demasiado (Melee range)
	AFTER_TIME_IN_COMBAT    # Si la pelea dura mucho tiempo activo
}
@export var mask_equip_condition: MaskEquipCondition = MaskEquipCondition.NONE

# --- COMPONENTES ---
@onready var combat_manager: CombatManager = $CombatManager
@onready var health_component: HealthComponent = $HealthComponent
@onready var stamina: Node = get_node_or_null("StaminaComponent")
@onready var mana: Node = get_node_or_null("ManaComponent")
@onready var mask_manager: MaskManager = get_node_or_null("MaskManager")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: RayCast3D = $VisionManager/Eyes
@export var visual_mesh: Node3D 
@export var anim_tree: AnimationTree

const P_MOVIMIENTO = "parameters/StateMachine/Standing/blend_position"

# ------------------------------------------------------------------------------
# VARIABLES IA
# ------------------------------------------------------------------------------
@export_category("Personalidad IA")
@export var vision_range: float = 20.0
@export var aim_speed: float = 8.0  # ⚡ AUMENTADO: Giran más rápido para no fallar
@export var base_speed: float = 3.5 # ⚡ AUMENTADO: Un poco más rápidos

@export_group("Capacidades de Movimiento")
@export var can_walk: bool = true
@export var can_sprint: bool = false
@export var can_jump: bool = false

@export_group("Parámetros de Movimiento")
@export var walk_speed: float = 2.0
@export var sprint_speed: float = 5.0
@export var jump_force: float = 8.0

@export_group("Puntería Inteligente (Ranged)")
@export var aim_delay_seconds: float = 0.3
@export var aim_inaccuracy_bloom: float = 0.7
@export var aim_bloom_update_rate: float = 0.2

enum Archetype { MELEE_1H, MELEE_2H, RANGED_PROJECTILE, RANGED_BEAM }
var current_archetype: Archetype = Archetype.MELEE_1H

var current_speed: float = 0.0
var preferred_range: float = 1.5 
var strafe_timer: float = 0.0
var strafe_dir: int = 1

# Variable para controlar la agresividad (1.0 normal, 2.0 frenético)
var aggression: float = 1.2 

enum State { IDLE, PATROL, CHASE, COMBAT_MANEUVER, ATTACKING, COOLDOWN, STUNNED }
var current_state = State.PATROL
var player_ref: Node3D = null

# Temporizadores
var patrol_timer: float = 0.0
var ai_decision_timer: float = 0.0 
var ai_cooldown_timer: float = 0.0

# 🟢 FIX BUCLE INFINITO
var safety_attack_timer: float = 0.0 

var is_holding_attack: bool = false
var hold_attack_timer: float = 0.0

var gravity = 9.8
var knockback_velocity: Vector3 = Vector3.ZERO
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween
var original_colors: Dictionary = {}

# Variables para control de puntería con retraso
var _position_history: Array[Vector3] = []
var _position_timer: float = 0.0

var _current_bloom_offset: Vector3 = Vector3.ZERO
var _target_bloom_offset: Vector3 = Vector3.ZERO
var _bloom_change_timer: float = 0.0

var _time_in_combat_timer: float = 0.0

# ------------------------------------------------------------------------------
# INICIO
# ------------------------------------------------------------------------------
func _ready():
	current_speed = base_speed
	
	if not anim_tree:
		if has_node("Visual/AnimationTree"): anim_tree = $Visual/AnimationTree
		elif has_node("OrcBrute/AnimationTree"): anim_tree = $OrcBrute/AnimationTree
		elif has_node("Rig/AnimationTree"): anim_tree = $Rig/AnimationTree
	
	if anim_tree: 
		anim_tree.active = true
		var playback_path = "parameters/StateMachine/playback"
		if anim_tree.get(playback_path):
			anim_tree[playback_path].travel("Standing")
	
	if combat_manager:
		combat_manager.is_player_controlled = false
		combat_manager.owner_node = self
		combat_manager.stamina_component = stamina
		combat_manager.mana_component = mana
		combat_manager.mask_manager = mask_manager
		combat_manager.animation_tree = anim_tree 
		combat_manager.attack_layer_mask = 2 
		
		if loadout_weapon_r: combat_manager.equip_weapon(loadout_weapon_r, "right")
		if loadout_weapon_l: combat_manager.equip_weapon(loadout_weapon_l, "left")
		
		_definir_arquetipo()

		mask_manager.on_mask_changed.connect(_on_mask_changed_event)
		
		if loadout_mask:
			if mask_handling == MaskHandling.EQUIP_ON_SPAWN:
				mask_manager.equip_mask(loadout_mask, true) # true = instant spawn, no delay
			elif mask_handling == MaskHandling.SIN_MASCARA:
				loadout_mask = null # Ignorar la máscara asignada

	if health_component:
		health_component.on_death.connect(_morir)
		health_component.on_damage_received.connect(_on_damage_received)

	_setup_unique_materials()
	if eyes: eyes.add_exception(self)
	
	call_deferred("_buscar_punto_patrulla")

func _definir_arquetipo():
	var w = combat_manager.weapon_r
	if not w: return
	if w is RangedWeaponData:
		current_archetype = Archetype.RANGED_BEAM if w.is_beam_weapon else Archetype.RANGED_PROJECTILE
		preferred_range = 8.0
	elif w.is_two_handed:
		current_archetype = Archetype.MELEE_2H
		preferred_range = 2.5 # Rango un poco mayor para 2H
	else:
		current_archetype = Archetype.MELEE_1H
		preferred_range = 1.8

# ------------------------------------------------------------------------------
# FÍSICA
# ------------------------------------------------------------------------------
func _physics_process(delta: float):
	if not is_on_floor(): velocity.y -= gravity * delta

	# Procesamiento de subsistemas
	_process_aim_history(delta)
	_process_mask_triggers(delta)

	# Físicas de knockback
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	if is_instance_valid(player_ref): 
		combat_manager.ai_target = player_ref
		if current_state != State.PATROL:
			_mirar_hacia(player_ref.global_position, delta * aim_speed)

	match current_state:
		State.PATROL:
			_comportamiento_patrulla(delta)
			_buscar_jugador()
		State.CHASE:
			_comportamiento_persecucion(delta)
		State.COMBAT_MANEUVER:
			_comportamiento_combate(delta)
		State.ATTACKING:
			_procesar_ataque_en_curso(delta)
		State.COOLDOWN:
			_comportamiento_cooldown(delta)

	move_and_slide()
	_animar_movimiento(delta)

# ------------------------------------------------------------------------------
# SUBSISTEMAS DE IA
# ------------------------------------------------------------------------------
func _process_aim_history(delta: float):
	if not is_instance_valid(player_ref): return
	if current_archetype != Archetype.RANGED_PROJECTILE and current_archetype != Archetype.RANGED_BEAM: return
	
	_position_timer += delta
	if _position_timer >= 0.05:
		_position_timer = 0.0
		_position_history.append(player_ref.global_position + Vector3(0, 1.2, 0))
		var max_history_size = max(1, int(aim_delay_seconds / 0.05))
		if _position_history.size() > max_history_size:
			_position_history.pop_front()
	
	if aim_inaccuracy_bloom > 0.0:
		_bloom_change_timer -= delta
		if _bloom_change_timer <= 0:
			_bloom_change_timer = aim_bloom_update_rate
			var dist = global_position.distance_to(player_ref.global_position)
			var b = aim_inaccuracy_bloom * (dist / 10.0)
			_target_bloom_offset = Vector3(randf_range(-b, b), 0.0, randf_range(-b, b))
		_current_bloom_offset = _current_bloom_offset.lerp(_target_bloom_offset, delta * 3.0)

func _process_mask_triggers(delta: float):
	if not is_instance_valid(player_ref) or current_state == State.PATROL: return
	
	_time_in_combat_timer += delta
	if _time_in_combat_timer >= 8.0:
		_check_mask_condition(MaskEquipCondition.AFTER_TIME_IN_COMBAT)
		
	if global_position.distance_to(player_ref.global_position) <= 6.5:
		_check_mask_condition(MaskEquipCondition.ON_PROXIMITY)

# ------------------------------------------------------------------------------
# LÓGICA DE ESTADOS
# ------------------------------------------------------------------------------
func _comportamiento_patrulla(delta):
	if nav_agent.is_navigation_finished():
		patrol_timer -= delta
		if patrol_timer <= 0:
			_buscar_punto_patrulla()
			patrol_timer = 4.0
	else:
		var speed_to_use = walk_speed if can_walk else base_speed
		_mover_hacia(nav_agent.get_next_path_position(), delta, speed_to_use)

func _comportamiento_persecucion(delta: float):
	if not is_instance_valid(player_ref): return
	var dist = global_position.distance_to(player_ref.global_position)
	
	# MEJORA: Entrar en combate un poco ANTES de llegar al límite
	# Esto evita que se frenen en seco antes de decidir atacar
	if dist <= preferred_range:
		current_state = State.COMBAT_MANEUVER
		ai_decision_timer = 0.0 # ⚡ CERO espera. ¡Ataca ya!
	else:
		nav_agent.target_position = player_ref.global_position
		
		# Decidir qué velocidad usar
		var speed_to_use = base_speed
		if can_sprint: speed_to_use = sprint_speed
		elif can_walk: speed_to_use = walk_speed
		
		_mover_hacia(nav_agent.get_next_path_position(), delta, speed_to_use)
		_mirar_hacia(player_ref.global_position, delta * 8.0)
		
		# Lógica simple de salto si está atascado:
		if can_jump and is_on_floor() and velocity.length() < 0.5 and randf() < 0.05:
			velocity.y = jump_force

func _comportamiento_combate(delta: float):
	if not is_instance_valid(player_ref): current_state = State.PATROL; return
	_mirar_hacia(player_ref.global_position, delta * aim_speed)
	
	ai_decision_timer -= delta
	if ai_decision_timer > 0: return

	var dist = global_position.distance_to(player_ref.global_position)
	
	# LÓGICA DE DECISIÓN AGRESIVA
	var can_attack = false
	
	if current_archetype == Archetype.MELEE_2H:
		if dist <= 3.2: can_attack = true # Margen generoso
	elif current_archetype == Archetype.MELEE_1H:
		if dist <= 2.5: can_attack = true # Margen generoso
	else:
		# Rango
		if dist < 15.0 and dist > 4.0: can_attack = true
		elif dist <= 4.0:
			_maniobra_alejarse(delta) # Demasiado cerca
			return 

	if can_attack:
		# Lógica de equipar máscara al atacar por primera vez
		_check_mask_condition(MaskEquipCondition.FIRST_ATTACK)
		
		# ¡ATACAR!
		if current_archetype == Archetype.MELEE_2H or current_archetype == Archetype.MELEE_1H:
			_iniciar_ataque_melee()
		elif current_archetype == Archetype.RANGED_BEAM:
			_iniciar_ataque_rayo()
		else:
			_iniciar_ataque_rango_unico()
	else:
		# ESTÁ CERCA PERO NO SUFICIENTE: ACERCARSE SIN CAMBIAR ESTADO
		var dir = (player_ref.global_position - global_position).normalized()
		var speed_to_use = base_speed
		if can_sprint: speed_to_use = sprint_speed
		elif can_walk: speed_to_use = walk_speed
		
		velocity.x = dir.x * speed_to_use
		velocity.z = dir.z * speed_to_use
		# No cambiamos a STATE.CHASE, nos movemos manualmente en modo combate

# --- API PUNTERÍA (Retraso) ---
func get_aim_position() -> Vector3:
	var pos_to_shoot = global_position # Fallback
	
	if _position_history.size() > 0:
		pos_to_shoot = _position_history[0] # Usar la posición más vieja (retraso)
	elif is_instance_valid(player_ref):
		pos_to_shoot = player_ref.global_position + Vector3(0, 1.2, 0)
		
	if aim_inaccuracy_bloom > 0.0:
		pos_to_shoot += _current_bloom_offset
		
	return pos_to_shoot

func _iniciar_ataque_melee():
	if combat_manager.weapon_r:
		combat_manager.handle_right_click(true)
		combat_manager.handle_right_click(false)
	if combat_manager.weapon_l:
		combat_manager.handle_left_click(true)
		combat_manager.handle_left_click(false)
	
	current_state = State.ATTACKING
	safety_attack_timer = 0.2 

func _iniciar_ataque_rango_unico():
	combat_manager.handle_left_click(true)
	combat_manager.handle_left_click(false)
	current_state = State.ATTACKING
	safety_attack_timer = 0.2

func _iniciar_ataque_rayo():
	combat_manager.handle_left_click(true)
	is_holding_attack = true
	hold_attack_timer = 3.0
	current_state = State.ATTACKING
	safety_attack_timer = 0.5

func _procesar_ataque_en_curso(delta):
	# Si el ataque apenas empezó, obligamos a esperar un poco
	if safety_attack_timer > 0:
		safety_attack_timer -= delta
		return

	if is_holding_attack:
		hold_attack_timer -= delta
		if hold_attack_timer <= 0: _finalizar_ataque_hold()
	else:
		if not combat_manager.is_attacking:
			# Cooldown reducido por agresividad
			var cd = randf_range(1.0, 2.0) / aggression
			_entrar_cooldown(cd)

func _finalizar_ataque_hold():
	combat_manager.handle_left_click(false)
	is_holding_attack = false
	_entrar_cooldown(2.0 / aggression)

func _maniobra_alejarse(delta):
	var dir = (global_position - player_ref.global_position).normalized()
	velocity.x = dir.x * 3.5; velocity.z = dir.z * 3.5
	_mirar_hacia(player_ref.global_position, delta * 8.0)
	move_and_slide()
	if global_position.distance_to(player_ref.global_position) > 7.0:
		current_state = State.COMBAT_MANEUVER

func _entrar_cooldown(tiempo):
	current_state = State.COOLDOWN
	ai_cooldown_timer = tiempo
func _comportamiento_cooldown(delta):
	ai_cooldown_timer -= delta
	if is_instance_valid(player_ref): _mirar_hacia(player_ref.global_position, delta * 5.0)
	
	# Strafe lateral rápido
	var side = transform.basis.x * strafe_dir
	velocity.x = side.x * 2.5; velocity.z = side.z * 2.5
	move_and_slide()
	
	if ai_cooldown_timer <= 0:
		strafe_dir *= -1
		current_state = State.COMBAT_MANEUVER
		ai_decision_timer = 0.0 # ¡Atacar inmediatamente al terminar CD!

# ------------------------------------------------------------------------------
# 6. MOVIMIENTO BASE Y UTILIDADES
# ------------------------------------------------------------------------------
func _mover_hacia_destino(delta, velocidad):
	var nav_map = nav_agent.get_navigation_map()
	var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
	var dist_to_nav = global_position.distance_to(closest)

	if dist_to_nav > 3.0: # ajusta este umbral
		velocity.x = 0
		velocity.z = 0
		return true
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
		return true 

	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * velocidad
	velocity.z = dir.z * velocidad
	_mirar_hacia(next_pos, delta * 8.0)
	return false

# ------------------------------------------------------------------------------
# UTILIDADES Y EVENTOS
# ------------------------------------------------------------------------------
func _mover_hacia(target, delta, vel):
	var dir = (target - global_position).normalized()
	velocity.x = dir.x * vel; velocity.z = dir.z * vel
	_mirar_hacia(target, delta * 8.0)

func _mirar_hacia(target, factor_velocidad):
	var t_flat = Vector3(target.x, global_position.y, target.z)
	
	# Evitamos errores si el enemigo está exactamente sobre el jugador
	if global_position.distance_to(t_flat) < 0.1: return

	# Calculamos hacia dónde debería mirar
	var target_xform = global_transform.looking_at(t_flat, Vector3.UP)
	
	# Interpolamos suavemente (Slerp)
	# IMPORTANTE: Usamos 'factor_velocidad' directamente porque ya incluye el delta
	global_transform.basis = global_transform.basis.slerp(target_xform.basis, factor_velocidad)

func _buscar_punto_patrulla():
	nav_agent.target_position = global_position + Vector3(randf_range(-5,5), 0, randf_range(-5,5))

func _buscar_jugador():
	if not is_instance_valid(player_ref): player_ref = get_tree().get_first_node_in_group("Player") as Node3D
	if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) < vision_range:
		current_state = State.CHASE

func _animar_movimiento(delta):
	if not anim_tree: return
	var spd = Vector2(velocity.x, velocity.z).length()
	# Permitir que el blend pase de 1.0 (para llegar a estado correr = 2.0)
	var blend = clamp(spd / base_speed, 0.0, 3.0)
	anim_tree.set(P_MOVIMIENTO, anim_tree.get(P_MOVIMIENTO).lerp(Vector2(0, blend), delta * 5.0))

# --- KNOCKBACK Y DAÑO ---
func apply_knockback(direction: Vector3, force: float, vertical_force: float):
	knockback_velocity = direction * force
	if vertical_force > 0 and is_on_floor(): velocity.y += vertical_force
	
	# Interrupción (Stagger)
	if force > 6.0:
		combat_manager.is_attacking_r = false
		combat_manager.is_attacking_l = false
		current_state = State.COOLDOWN
		ai_cooldown_timer = 0.4
		flash_red()

func equipar_mascara_guardada():
	if mask_manager and loadout_mask and mask_handling == MaskHandling.EN_INVENTARIO:
		mask_manager.equip_mask(loadout_mask, false) # false = animate spawn

func _check_mask_condition(trigger: MaskEquipCondition):
	if mask_handling != MaskHandling.EN_INVENTARIO: return
	if mask_manager and mask_manager.current_mask: return # Ya equipada
	if not loadout_mask: return # No tiene nada
	
	if mask_equip_condition == trigger or mask_equip_condition == MaskEquipCondition.ANY:
		equipar_mascara_guardada()

func _on_damage_received(a, c):
	flash_red()
	if current_state == State.PATROL: current_state = State.CHASE
	
	_check_mask_condition(MaskEquipCondition.FIRST_HIT_RECEIVED)
	
	if health_component:
		if health_component.current_health <= health_component.max_health * 0.5:
			_check_mask_condition(MaskEquipCondition.HALF_HEALTH)
		if health_component.current_health <= health_component.max_health * 0.25:
			_check_mask_condition(MaskEquipCondition.LOW_HEALTH_DESPERATION)

func _morir():
	if is_instance_valid(player_ref) and player_ref.has_node("MaskManager"):
		player_ref.get_node("MaskManager").add_charge(combat_manager.ult_charge_reward)
	set_physics_process(false)
	queue_free()

# --- VISUALES ---
func _setup_unique_materials():
	if not visual_mesh: return
	unique_materials.clear()
	original_colors.clear()
	_buscar_meshes_recursivo(visual_mesh)

func _buscar_meshes_recursivo(n):
	if n is MeshInstance3D:
		for i in range(n.get_surface_override_material_count()):
			var m = n.get_active_material(i)
			if m:
				var u = m.duplicate(); n.set_surface_override_material(i, u)
				unique_materials.append(u); original_colors[u] = u.albedo_color
	for c in n.get_children(): _buscar_meshes_recursivo(c)

func flash_red():
	if flash_tween: flash_tween.kill()
	for m in unique_materials: m.albedo_color = Color(1, 0.2, 0.2)
	flash_tween = create_tween()
	for m in unique_materials:
		if m in original_colors: flash_tween.parallel().tween_property(m, "albedo_color", original_colors[m], 0.2)

func _activar_aura_mascara():
	if not mask_manager or not mask_manager.current_mask: return
	if unique_materials.is_empty(): _setup_unique_materials()
	var c = mask_manager.current_mask.screen_tint; c.a = 0.2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = c; mat.emission = c; mat.emission_enabled = true; mat.emission_energy = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_FRONT; mat.grow = true; mat.grow_amount = 0.03
	for m in unique_materials: m.next_pass = mat

func _on_mask_changed_event(data: MaskData):
	if data != null:
		_activar_aura_mascara()
	else:
		for m in unique_materials: m.next_pass = null

func _on_ultimate_visuals(a): pass
