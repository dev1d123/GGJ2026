extends CharacterBody3D

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN Y REFERENCIAS
# ------------------------------------------------------------------------------
@export_group("Configuración de IA")
@export var weapon_data: WeaponData # ¡ASIGNA ESTO EN EL INSPECTOR DEL ESQUELETO!
@export var skeleton_mesh: Node3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: RayCast3D = $VisionManager/Eyes

# --- SISTEMAS MODULARES ---
@onready var combat_manager: CombatManager = $CombatManager
@onready var health_component: HealthComponent = $HealthComponent
@onready var anim_tree: AnimationTree = $Skeleton_Minion/AnimationTree

# Rutas de Animación
const P_MOVIMIENTO = "parameters/StateMachine/Standing/blend_position"

# ------------------------------------------------------------------------------
# 2. VARIABLES (TU LÓGICA ORIGINAL)
# ------------------------------------------------------------------------------
var speed = 2.5
var gravity = 9.8
var attack_range = 1.8 
var vision_range = 15.0

enum State { PATROL, CHASE, ATTACK }
var current_state = State.PATROL
var player_ref: Node3D = null
var patrol_timer = 0.0
var _last_vision_blocker = ""

# Físicas y Efectos
var knockback_velocity: Vector3 = Vector3.ZERO
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween

# ------------------------------------------------------------------------------
# 3. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready():
	print("\n💀 --- INICIANDO IA ESQUELETO ---")
	
	if anim_tree:
		anim_tree.active = true
		
	# 1. EQUIPAR ARMA (CRÍTICO: Cada esqueleto lo hace por su cuenta)
	if combat_manager and weapon_data:
		combat_manager.equip_weapon(weapon_data, "right")
	else:
		print("⚠️ ALERTA: Esqueleto sin WeaponData o CombatManager asignado.")
	
	# 2. CONECTAR SALUD
	if health_component:
		health_component.on_death.connect(_morir)
		health_component.on_damage_received.connect(_on_damage_visual)
	
	# 3. VISUALES Y VISIÓN
	_setup_unique_materials()
	if eyes: eyes.add_exception(self)
	
	call_deferred("_buscar_punto_patrulla")

func _physics_process(delta):
	# 1. Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Empuje (Knockback)
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	# 3. Si está atacando (Controlado por CombatManager)
	if combat_manager.is_attacking:
		
		# Solo paramos al esqueleto si el arma actual tiene 'stop_movement = true'
		if combat_manager.is_movement_locked:
			velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
		else:
			# Si el arma permite moverse, el esqueleto avanza lento hacia el jugador
			# (Opcional: puedes dejarlo en 0 si prefieres que siempre pare)
			velocity.x = move_toward(velocity.x, 0, 1.0) 
			velocity.z = move_toward(velocity.z, 0, 1.0)
		
		# Siempre girar hacia el jugador al atacar
		if player_ref:
			_rotar_hacia(player_ref.global_position, delta * 5.0)
		
		move_and_slide()
		return

	# 4. Máquina de Estados (TU LÓGICA INTACTA)
	match current_state:
		State.PATROL:
			_procesar_patrulla(delta)
			_buscar_jugador()
		
		State.CHASE:
			_procesar_persecucion(delta)
	
	move_and_slide()
	_animar_movimiento(delta)

# ------------------------------------------------------------------------------
# 4. LÓGICA DE IA (TU CÓDIGO ORIGINAL)
# ------------------------------------------------------------------------------
func _mover_hacia_destino(delta, velocidad_base):
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
		return true 

	var next_pos = nav_agent.get_next_path_position()
	var vector_direccion = next_pos - global_position
	vector_direccion.y = 0 
	
	if vector_direccion.length() > 0.01:
		var dir = vector_direccion.normalized()
		velocity.x = dir.x * velocidad_base
		velocity.z = dir.z * velocidad_base
		_rotar_hacia(next_pos, delta * 8.0)
	
	return false

func _rotar_hacia(target, speed_rot):
	var target_flat = Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(target_flat) > 0.1:
		var new_transform = global_transform.looking_at(target_flat, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(new_transform.basis, speed_rot)

func _animar_movimiento(delta):
	if not anim_tree: return
	var vel_real = Vector2(velocity.x, velocity.z).length()
	var target = Vector2(0, 1) if vel_real > 0.1 else Vector2(0, 0)
	var actual = anim_tree.get(P_MOVIMIENTO)
	if actual == null: actual = Vector2.ZERO
	anim_tree.set(P_MOVIMIENTO, actual.lerp(target, delta * 8.0))

func _procesar_patrulla(delta):
	var llego = _mover_hacia_destino(delta, speed * 0.5)
	if llego:
		patrol_timer += delta
		if patrol_timer > 3.0:
			_buscar_punto_patrulla()
			patrol_timer = 0.0

func _buscar_punto_patrulla():
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var destino = global_position + (random_dir * 5.0)
	nav_agent.target_position = destino

func _procesar_persecucion(delta):
	if not player_ref: return
	nav_agent.target_position = player_ref.global_position
	
	_mover_hacia_destino(delta, speed)
	
	var dist = global_position.distance_to(player_ref.global_position)
	
	# AQUÍ ES DONDE USAMOS EL NUEVO SISTEMA
	if dist <= attack_range:
		combat_manager.try_attack("right") # Atacamos con la derecha
	elif dist > vision_range * 1.5:
		current_state = State.PATROL
		_buscar_punto_patrulla()

func _buscar_jugador():
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("Player")
		if not player_ref: return
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > vision_range: return 
	
	eyes.look_at(player_ref.global_position + Vector3(0, 1.0, 0))
	eyes.force_raycast_update()
	
	if eyes.is_colliding():
		var col = eyes.get_collider()
		if col and (col == player_ref or col.is_in_group("Player")):
			# print("👁️ ¡TE VEO!")
			current_state = State.CHASE
			_last_vision_blocker = "" 

# ------------------------------------------------------------------------------
# 5. RESPUESTA A EVENTOS (DAÑO Y MUERTE)
# ------------------------------------------------------------------------------
func apply_knockback(dir: Vector3, knock: float, jump: float):
	knockback_velocity = dir * knock
	if is_on_floor(): velocity.y += jump

func _on_damage_visual(amount, current):
	flash_red()

# Esta función se activa cuando HealthComponent emite "on_death"
func _morir():
	print("💀 Esqueleto destruido.")
	
	# 1. Obtener la cantidad de recompensa del CombatManager
	var reward_amount = 0.0
	if combat_manager:
		reward_amount = combat_manager.ult_charge_reward
	
	# 2. Buscar al Jugador para darle la carga
	# Usamos la referencia que ya tiene la IA, o buscamos por grupo si es nula
	var target_player = player_ref
	if not target_player:
		target_player = get_tree().get_first_node_in_group("Player")
	
	# 3. Entregar la carga al MaskManager del jugador
	if target_player and target_player.has_node("MaskManager"):
		var mask_mgr = target_player.get_node("MaskManager")
		if mask_mgr.has_method("add_charge"):
			mask_mgr.add_charge(reward_amount)
			print("⚡ Carga entregada: +", reward_amount)
	
	# 4. Desactivar y borrar enemigo
	set_physics_process(false)
	# Aquí podrías poner una animación de muerte antes del queue_free
	queue_free()

# --- EFECTOS VISUALES ---
func _setup_unique_materials():
	if not skeleton_mesh: return
	unique_materials.clear()
	for child in skeleton_mesh.get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat is StandardMaterial3D:
				var unique = mat.duplicate()
				child.set_surface_override_material(0, unique)
				unique_materials.append(unique)

func flash_red():
	if unique_materials.is_empty(): return
	if flash_tween: flash_tween.kill()
	for mat in unique_materials: mat.albedo_color = Color(1, 0.2, 0.2)
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	for mat in unique_materials: flash_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.2)
