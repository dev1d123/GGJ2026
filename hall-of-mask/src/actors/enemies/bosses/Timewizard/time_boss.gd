extends CharacterBody3D
class_name BossWizard

const MagicProjectileScene = preload("res://src/actors/enemies/bosses/Timewizard/MagicProjectile.gd")

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
@export var projectile_speed: float = 10.0
@export var projectile_damage: float = 10.0
@export var projectile_lifetime: float = 3.0
@export var projectile_spawn_height: float = 1.4
@export var projectile_color: Color = Color(0.4, 0.7, 1.0, 1.0)
@export var attack_anim_name: String = "NlaTrack_003"

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

# ----------------------------------------------------------------
# INICIO
# ----------------------------------------------------------------
func _ready():
	nav_agent = $NavigationAgent3D
	player_ref = get_node_or_null("../Player")
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("Player")
	health_component = get_node_or_null(health_component_path)
	anim_player = $time_wizard/AnimationPlayer
	
	if not nav_agent:
		push_error("⚠️ BossWizard: No se encontró NavigationAgent3D.")
	if not player_ref:
		push_warning("⚠️ BossWizard: No se encontró un nodo con grupo 'Player'.")
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
		_start_ranged_attack()

# ----------------------------------------------------------------
# INICIO DE ATAQUE
# ----------------------------------------------------------------
func _start_ranged_attack():
	attack_in_progress = true
	attack_lock_timer = _get_attack_anim_length()
	_play_anim(attack_anim_name, true)
	_shoot_magic()
	attack_timer = attack_cooldown

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
	
	var proj = MagicProjectileScene.new()
	proj.direction = dir
	proj.speed = projectile_speed
	proj.damage = projectile_damage
	proj.lifetime = projectile_lifetime
	proj.color = projectile_color
	
	get_tree().current_scene.add_child(proj)
	proj.global_position = spawn_pos

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
	current_state = State.DEAD
	velocity = Vector3.ZERO
	_play_anim("NlaTrack")
	set_physics_process(false)
	queue_free()
