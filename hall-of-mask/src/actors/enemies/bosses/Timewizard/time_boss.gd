extends CharacterBody3D
class_name BossWizard
signal boss_died

const MagicProjectileScene = preload("res://src/actors/enemies/bosses/Timewizard/MagicProjectile.gd")
const LaserRainProjectileScene = preload("res://src/actors/enemies/bosses/Timewizard/LaserRainProjectile.gd")
const HomingMagicOrbScene = preload("res://src/actors/enemies/bosses/Timewizard/HomingMagicOrb.gd")

# ----------------------------------------------------------------
# CONFIGURACIÓN
# ----------------------------------------------------------------
@export var chase_speed: float = 4.0
@export var patrol_speed: float = 2.0
@export var health_component_path: NodePath
@export var back_recoil_time: float = 0.2
@export var detect_distance: float = 15.0
@export var patrol_radius: float = 5.0
@export var welcome_time: float = 1.5

# Ataque a distancia
@export var safe_distance: float = 4.0
@export var attack_range: float = 12.0
@export var attack_cooldown: float = 1.5
@export var ranged_cast_delay: float = 0.25
@export var rain_attack_chance: float = 0.25
@export var homing_attack_chance: float = 0.2
@export var projectile_speed: float = 10.0
@export var projectile_damage: float = 10.0
@export var projectile_lifetime: float = 3.0
@export var projectile_spawn_height: float = 1.4
@export var projectile_color: Color = Color(0.4, 0.7, 1.0, 1.0)
@export var attack_anim_name: String = "NlaTrack_003"

# Lluvia de lasers
@export var rain_count: int = 15
@export var rain_radius: float = 20
@export var rain_spawn_height: float = 7.0
@export var rain_speed: float = 8.0
@export var rain_damage: float = 8.0
@export var rain_lifetime: float = 2.5
@export var rain_color: Color = Color(0.8, 0.2, 1.0, 1.0)

# Orbe perseguidor
@export var homing_speed: float = 4.0
@export var homing_damage: float = 15.0
@export var homing_lifetime: float = 5.0
@export var homing_color: Color = Color(1.0, 0.4, 0.9, 1.0)
@export var homing_radius: float = 0.5
@export var homing_update_interval: float = 0.4

# Teleport
@export var teleport_damage_threshold: float = 30.0
@export var teleport_cooldown: float = 4.0
@export var teleport_min_distance: float = 6.0
@export var teleport_max_distance: float = 16.0
@export var teleport_points_path: NodePath

# Recompensa
@export var ult_charge_reward: float = 10.0

# Referencias
var nav_agent: NavigationAgent3D
var player_ref: Node3D
var health_component: HealthComponent
var anim_player: AnimationPlayer

# Físicas
const GRAVITY: float = 9.8

# Estados
enum State { IDLE, PATROL, CHASE, RANGED, RECOIL, DEAD, WELCOME }
var current_state: State = State.WELCOME

# Tipos de ataque
enum AttackType { BASIC, RAIN, HOMING }

# Knockback
var recoil_timer: float = 0.0
var recoil_dir: Vector3 = Vector3.ZERO
var recoil_speed: float = 0.0

# Patrulla
var patrol_point: Vector3 = Vector3.ZERO

# Animación (evitar reinicio constante)
var last_anim: String = ""

# Cooldown de ataque
var attack_timer: float = 0.0

# Ataque no interrumpible
var attack_in_progress: bool = false
var attack_lock_timer: float = 0.0

# Teleport por daño
var damage_since_teleport: float = 0.0
var teleport_timer: float = 0.0

# ----------------------------------------------------------------
# INICIO
# ----------------------------------------------------------------
func _ready():
	nav_agent = $NavigationAgent3D
	player_ref = _get_player_ref()
	if health_component_path != NodePath():
		health_component = get_node_or_null(health_component_path)
	if not health_component:
		health_component = get_node_or_null("HealthComponent")
	anim_player = $time_wizard/AnimationPlayer
	
	if not nav_agent:
		push_error("⚠️ BossWizard: No se encontró NavigationAgent3D.")
	if not player_ref:
		push_warning("⚠️ BossWizard: No se encontró el nodo 'Player' en la escena actual.")
	if not health_component:
		push_error("⚠️ BossWizard: No se encontró HealthComponent.")
	else:
		health_component.on_damage_received.connect(_on_damage_received)
		health_component.on_death.connect(_morir)
	
	# Animación de bienvenida (no bloquear si es loop)
	if anim_player and anim_player.has_animation("NlaTrack_004"):
		_play_anim("NlaTrack_004")
		await get_tree().create_timer(welcome_time).timeout
	
	current_state = State.PATROL
	_play_anim("NlaTrack_002")
	
	print("✨ BossWizard listo!")

# ----------------------------------------------------------------
# PHYSICS PROCESS
# ----------------------------------------------------------------
func _physics_process(delta):
	if not player_ref:
		player_ref = _get_player_ref()
	if teleport_timer > 0.0:
		teleport_timer -= delta
	_apply_gravity(delta)
	_update_attack_cooldown(delta)
	_update_attack_lock(delta)

	match current_state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.RANGED:
			_ranged_attack(delta)
		State.RECOIL:
			_recoil(delta)
		State.WELCOME:
			velocity.x = 0
			velocity.z = 0
		State.DEAD:
			velocity = Vector3.ZERO
	
	move_and_slide()

# ----------------------------------------------------------------
# PLAYER REF
# ----------------------------------------------------------------
func _get_player_ref() -> Node3D:
	var scene_root = get_tree().current_scene
	if scene_root:
		var player = scene_root.get_node_or_null("Player")
		if player:
			return player
	if has_node("Player"):
		return $Player
	return null

func _get_teleport_points() -> Array[Node3D]:
	var points: Array[Node3D] = []
	var scene_root = get_tree().current_scene
	if scene_root and teleport_points_path != NodePath():
		var container = scene_root.get_node_or_null(teleport_points_path)
		if container:
			for child in container.get_children():
				if child is Node3D:
					points.append(child)
	return points

func _teleport_random_nearby():
	var target_pos = global_position
	var points = _get_teleport_points()
	if points.size() > 0:
		var valid: Array[Node3D] = []
		for p in points:
			var d = global_position.distance_to(p.global_position)
			if d >= teleport_min_distance and d <= teleport_max_distance:
				valid.append(p)
		var pool = valid if valid.size() > 0 else points
		var chosen = pool[randi() % pool.size()]
		target_pos = chosen.global_position
	else:
		var angle = randf() * TAU
		var radius = randf_range(teleport_min_distance, teleport_max_distance)
		target_pos = global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius

	if nav_agent:
		var nav_map = nav_agent.get_navigation_map()
		if nav_map.is_valid():
			target_pos = NavigationServer3D.map_get_closest_point(nav_map, target_pos)

	velocity = Vector3.ZERO
	global_position = target_pos

# ----------------------------------------------------------------
# GRAVEDAD
# ----------------------------------------------------------------
func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

# ----------------------------------------------------------------
# COOLDOWN
# ----------------------------------------------------------------
func _update_attack_cooldown(delta):
	if attack_timer > 0.0:
		attack_timer -= delta

func _update_attack_lock(delta):
	if attack_in_progress:
		attack_lock_timer -= delta
		if attack_lock_timer <= 0.0:
			attack_in_progress = false
			if current_state == State.RANGED:
				current_state = State.CHASE

# ----------------------------------------------------------------
# IA DE PATRULLA
# ----------------------------------------------------------------
func _patrol(delta):
	if not player_ref:
		return
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist < detect_distance:
		current_state = State.CHASE
		_play_anim("NlaTrack_001") # correr
		return
	
	if patrol_point == Vector3.ZERO or global_position.distance_to(patrol_point) < 0.5:
		patrol_point = global_position + Vector3(
			randf_range(-patrol_radius, patrol_radius),
			0,
			randf_range(-patrol_radius, patrol_radius)
		)
	
	var dir = (patrol_point - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	_rotar_hacia(patrol_point, delta * 4.0)
	
	_play_anim("NlaTrack_002") # caminar

# ----------------------------------------------------------------
# IA DE PERSECUCIÓN
# ----------------------------------------------------------------
func _chase(delta):
	if not player_ref:
		return
	
	var dist = global_position.distance_to(player_ref.global_position)
	
	if dist <= attack_range and dist >= safe_distance:
		current_state = State.RANGED
		return
	
	if dist < safe_distance:
		var away = (global_position - player_ref.global_position).normalized()
		velocity.x = away.x * chase_speed
		velocity.z = away.z * chase_speed
		_rotar_hacia(player_ref.global_position, delta * 8.0)
		_play_anim("NlaTrack_001")
		return
	
	nav_agent.target_position = player_ref.global_position
	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0
	
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	
	_rotar_hacia(player_ref.global_position, delta * 8.0)
	_play_anim("NlaTrack_001")

# ----------------------------------------------------------------
# ATAQUE A DISTANCIA
# ----------------------------------------------------------------
func _ranged_attack(delta):
	if not player_ref:
		return
	
	# No interrumpir ataque mientras se ejecuta
	if attack_in_progress:
		velocity.x = 0
		velocity.z = 0
		_rotar_hacia(player_ref.global_position, delta * 8.0)
		return
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > attack_range or dist < safe_distance:
		current_state = State.CHASE
		return
	
	velocity.x = 0
	velocity.z = 0
	_rotar_hacia(player_ref.global_position, delta * 8.0)
	
	if attack_timer <= 0.0:
		var roll = randf()
		var attack_type: AttackType = AttackType.BASIC
		if roll < rain_attack_chance:
			attack_type = AttackType.RAIN
		elif roll < (rain_attack_chance + homing_attack_chance):
			attack_type = AttackType.HOMING
		_start_ranged_attack(attack_type)

# ----------------------------------------------------------------
# INICIO DE ATAQUE
# ----------------------------------------------------------------
func _start_ranged_attack(attack_type: AttackType = AttackType.BASIC):
	attack_in_progress = true
	attack_lock_timer = max(_get_attack_anim_length(), ranged_cast_delay + 0.1)
	_play_anim(attack_anim_name, true)
	_perform_ranged_attack(attack_type)
	attack_timer = attack_cooldown

func _perform_ranged_attack(attack_type: AttackType):
	if ranged_cast_delay > 0.0:
		await get_tree().create_timer(ranged_cast_delay).timeout
	if current_state == State.DEAD:
		return
	match attack_type:
		AttackType.RAIN:
			_cast_rain_lasers()
		AttackType.HOMING:
			_shoot_homing_orb()
		_:
			_shoot_magic()

func _get_attack_anim_length() -> float:
	if anim_player and anim_player.has_animation(attack_anim_name):
		return anim_player.get_animation(attack_anim_name).length
	return 0.6

# ----------------------------------------------------------------
# DISPARO
# ----------------------------------------------------------------
func _shoot_magic():
	if not player_ref:
		return
	
	var target_pos = player_ref.global_position
	var spawn_pos = global_position + Vector3.UP * projectile_spawn_height
	var dir = (target_pos - spawn_pos).normalized()
	if dir.length_squared() <= 0.0001:
		dir = -global_transform.basis.z.normalized()
	
	var proj = MagicProjectileScene.new()
	proj.direction = dir
	proj.speed = projectile_speed
	proj.damage = projectile_damage
	proj.lifetime = projectile_lifetime
	proj.color = projectile_color

	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_tree().root
	if scene_root:
		scene_root.add_child(proj)
	else:
		add_child(proj)
	proj.global_position = spawn_pos

func _cast_rain_lasers():
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_tree().root
	if not scene_root:
		return

	var count = max(1, rain_count)
	for i in range(count):
		var angle = randf() * TAU
		var radius = randf_range(0.0, rain_radius)
		var offset = Vector3(cos(angle), 0.0, sin(angle)) * radius
		var spawn_pos = global_position + offset + Vector3.UP * rain_spawn_height
		var laser = LaserRainProjectileScene.new()
		laser.direction = Vector3.DOWN
		laser.speed = rain_speed
		laser.damage = rain_damage
		laser.lifetime = rain_lifetime
		laser.color = rain_color
		scene_root.add_child(laser)
		laser.global_position = spawn_pos

func _shoot_homing_orb():
	if not player_ref:
		return
	var scene_root = get_tree().current_scene
	if not scene_root:
		scene_root = get_tree().root
	if not scene_root:
		return

	var spawn_pos = global_position + Vector3.UP * projectile_spawn_height
	var orb = HomingMagicOrbScene.new()
	orb.target = player_ref
	orb.speed = homing_speed
	orb.damage = homing_damage
	orb.lifetime = homing_lifetime
	orb.color = homing_color
	orb.radius = homing_radius
	orb.update_interval = homing_update_interval
	scene_root.add_child(orb)
	orb.global_position = spawn_pos

# ----------------------------------------------------------------
# RECOIL (knockback)
# ----------------------------------------------------------------
func _recoil(delta):
	if recoil_timer > 0.0:
		velocity.x = recoil_dir.x * recoil_speed
		velocity.z = recoil_dir.z * recoil_speed
		recoil_timer -= delta
	else:
		current_state = State.CHASE

# ----------------------------------------------------------------
# DAÑO
# ----------------------------------------------------------------
func _on_damage_received(amount, current_health):
	if current_state == State.PATROL:
		current_state = State.CHASE
	if amount > 0.0:
		damage_since_teleport += amount
		if teleport_damage_threshold > 0.0 and teleport_timer <= 0.0 and damage_since_teleport >= teleport_damage_threshold:
			damage_since_teleport = 0.0
			teleport_timer = teleport_cooldown
			_teleport_random_nearby()

# ----------------------------------------------------------------
# KNOCKBACK DESDE HURTBOX
# ----------------------------------------------------------------
func apply_knockback(dir: Vector3, knockback: float, jump: float):
	recoil_dir = dir.normalized()
	recoil_speed = knockback / max(back_recoil_time, 0.01)
	recoil_timer = back_recoil_time
	velocity.y = jump
	current_state = State.RECOIL

# ----------------------------------------------------------------
# ROTACIÓN
# ----------------------------------------------------------------
func _rotar_hacia(target: Vector3, speed_rot):
	var target_flat = Vector3(target.x, global_position.y, target.z)
	var new_transform = global_transform.looking_at(target_flat, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(new_transform.basis, speed_rot)

# ----------------------------------------------------------------
# ANIMACIONES
# ----------------------------------------------------------------
func _play_anim(name: String, force: bool = false):
	if not anim_player:
		return
	if not force and last_anim == name:
		return
	if anim_player.has_animation(name):
		anim_player.play(name)
		last_anim = name

# ----------------------------------------------------------------
# MUERTE
# ----------------------------------------------------------------
func _morir():
	print("💀 BossWizard destruido.")
	var reward_amount = ult_charge_reward
	var target_player = player_ref
	if not target_player:
		target_player = _get_player_ref()
	if target_player and target_player.has_node("MaskManager"):
		target_player.get_node("MaskManager").add_charge(reward_amount)
	boss_died.emit(self)
	current_state = State.DEAD
	velocity = Vector3.ZERO
	_play_anim("NlaTrack")
	set_physics_process(false)
	set_process(false)
	queue_free()
