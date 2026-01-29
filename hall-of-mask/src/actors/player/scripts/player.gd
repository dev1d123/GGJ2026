extends CharacterBody3D

# ------------------------------------------------------------------------------
# 1. REFERENCIAS
# ------------------------------------------------------------------------------
@onready var head_mount: Node3D = $HeadMount
@onready var camera: Camera3D = $HeadMount/Camera3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine = anim_tree["parameters/StateMachine/playback"]
@onready var skeleton_3d: Skeleton3D = $Ranger/Rig_Medium/Skeleton3D 
@onready var attributes: Node = $AttributeManager 
@onready var stamina: Node = $StaminaComponent

# ¡IMPORTANTE! Referencia al componente de salud
@onready var health_component: HealthComponent = $HealthComponent 

# ------------------------------------------------------------------------------
# 2. VARIABLES DE ESTADO Y CONFIGURACIÓN
# ------------------------------------------------------------------------------

# --- SALUD ---
var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false 

# --- MOVIMIENTO ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const MOUSE_SENSITIVITY: float = 0.003
var _cam_pitch: float = 0.0 
var spine_bone_id: int = -1
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_friction: float = 8.0

# --- TIEMPOS Y COOLDOWNS (¡ESTO FALTABA!) ---
const TIME_TO_PRONE: float = 0.4
const DIVE_MIN_TIME: float = 0.6 
var crouch_pressed_time: float = 0.0 
var dive_timer: float = 0.0
var was_in_air: bool = false

# --- ESTADOS ---
enum State { NORMAL, SPRINT, CROUCH, PRONE, DODGING, DIVING, DEAD }
var current_state: State = State.NORMAL
var can_dodge: bool = true 
var dodge_power: float = 25.0 # Faltaba declarar esto también

# --- RUTAS ANIMATION TREE ---
const PATH_STANDING = "parameters/StateMachine/Standing/blend_position"
const PATH_SNEAKING = "parameters/StateMachine/Sneaking/blend_position"
const PATH_CRAWLING = "parameters/StateMachine/Crawling/blend_position"
const PATH_DODGE    = "parameters/StateMachine/Dodge/blend_position"
var smooth_blend: Vector2 = Vector2.ZERO
var blend_speed: float = 7.0

# ------------------------------------------------------------------------------
# 3. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.active = true
	if skeleton_3d:
		spine_bone_id = skeleton_3d.find_bone("chest")
	
	# Conexión con HealthComponent
	if health_component:
		print("✅ HealthComponent conectado al Player.")
		health_component.on_death.connect(morir)
		# Inicializamos la vida visual con la del componente
		if "max_health" in health_component:
			max_health = health_component.max_health
			current_health = health_component.current_health
	else:
		print("❌ ERROR: Falta HealthComponent en Player")

func _input(event: InputEvent) -> void:
	if is_dead: return 

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(-55.0), deg_to_rad(70.0))
		camera.rotation.x = _cam_pitch
		rotar_columna_hacia_camara()
	
	if event.is_action_pressed("ui_cancel"): 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# 0. GRAVEDAD
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_in_air = true
	elif was_in_air:
		was_in_air = false
		refrescar_animacion_aterrizaje()

	# --- BLOQUEO POR MUERTE ---
	if is_dead:
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return 

	# 1. EMPUJE (Knockback)
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	# 2. Lógica Normal
	if current_state == State.DODGING: procesar_dodge(delta); return
	if current_state == State.DIVING: procesar_dive(delta); return
	
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	# Pasamos true si se mueve hacia atrás (input_dir.y > 0)
	controlar_inputs_postura(delta, input_dir.y > 0)
	procesar_movimiento_normal(delta, input_dir)
	actualizar_blendspaces(input_dir, delta)

# ------------------------------------------------------------------------------
#  SISTEMA DE DAÑO Y MUERTE (CÁMARA FANTASMA)
# ------------------------------------------------------------------------------
# Esta función es un "puente" por si algo llama take_damage en el player directamente
func take_damage(amount: float):
	if health_component:
		health_component.take_damage(amount)
	else:
		morir() # Fallback

func apply_knockback(direction: Vector3, force: float, up_force: float = 2.0):
	if is_dead: return
	knockback_velocity = direction * force
	if is_on_floor():
		velocity.y = up_force 

func morir():
	if is_dead: return
	is_dead = true
	current_state = State.DEAD
	
	print("\n💀 --- INICIO SECUENCIA DE MUERTE (CÁMARA FANTASMA) ---")
	
	# 1. PARALIZAR JUGADOR
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	
	var hurtbox = find_child("Hurtbox", true, false)
	if hurtbox: 
		var hb_shape = hurtbox.find_child("CollisionShape3D")
		if hb_shape: hb_shape.set_deferred("disabled", true)

	# 2. CREAR CÁMARA FANTASMA
	var death_camera = Camera3D.new()
	get_tree().current_scene.add_child(death_camera)
	death_camera.global_transform = camera.global_transform
	death_camera.current = true
	camera.visible = false 
	print("📷 Cámara fantasma creada y activada.")

	# 3. ANIMACIÓN
	var t = create_tween()
	t.tween_property(death_camera, "global_position:y", death_camera.global_position.y + 20.0, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(death_camera, "rotation_degrees:x", -90.0, 2.0)
	
	# 4. REINICIAR
	print("⏳ Reiniciando en 4 segundos...")
	await get_tree().create_timer(4.0).timeout
	death_camera.queue_free()
	get_tree().reload_current_scene()

# ------------------------------------------------------------------------------
# FUNCIONES DE MOVIMIENTO (RESTAURADAS CON LAS VARIABLES)
# ------------------------------------------------------------------------------
func rotar_columna_hacia_camara():
	if spine_bone_id != -1 and not is_dead:
		var m = Quaternion(Vector3.RIGHT, -_cam_pitch)
		var r = skeleton_3d.get_bone_rest(spine_bone_id).basis.get_rotation_quaternion()
		skeleton_3d.set_bone_pose_rotation(spine_bone_id, r * m)

func procesar_movimiento_normal(delta, input_dir):
	var speed = attributes.get_stat("move_speed") if attributes else 5.0
	match current_state:
		State.SPRINT: speed *= 1.5
		State.CROUCH: speed *= 0.5
		State.PRONE: speed *= 0.3
	var dir = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()
	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()

# --- AQUÍ ESTABA EL ERROR ANTES, AHORA ESTÁN LAS VARIABLES DECLARADAS ARRIBA ---
func controlar_inputs_postura(delta, mb): 
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match current_state:
			State.PRONE: cambiar_estado(State.CROUCH)
			State.CROUCH: cambiar_estado(State.NORMAL)
			State.NORMAL, State.SPRINT:
				if is_on_floor() and stamina.try_consume(15):
					velocity.y = 5.0
					state_machine.travel("Jump_Start")
		return
	if Input.is_action_just_pressed("crouch"):
		if current_state == State.SPRINT: iniciar_dive(); return
	if Input.is_action_pressed("crouch"):
		crouch_pressed_time += delta # AHORA SÍ EXISTE LA VARIABLE
		if crouch_pressed_time > TIME_TO_PRONE: # AHORA SÍ EXISTE LA CONSTANTE
			if current_state != State.PRONE: cambiar_estado(State.PRONE)
	elif Input.is_action_just_released("crouch"):
		if crouch_pressed_time <= TIME_TO_PRONE:
			if current_state == State.CROUCH: cambiar_estado(State.NORMAL)
			elif current_state != State.PRONE: cambiar_estado(State.CROUCH)
		crouch_pressed_time = 0.0
	if Input.is_action_pressed("sprint") and is_on_floor() and not mb and current_state == State.NORMAL:
		if stamina.try_consume(10 * delta):
			if current_state != State.SPRINT: cambiar_estado(State.SPRINT)
	elif current_state == State.SPRINT and not Input.is_action_pressed("sprint"):
		cambiar_estado(State.NORMAL)
	if Input.is_action_just_pressed("dodge") and can_dodge and is_on_floor():
		if stamina.try_consume(10): iniciar_dodge()

func cambiar_estado(nuevo):
	current_state = nuevo
	match current_state:
		State.NORMAL, State.SPRINT: state_machine.travel("Standing")
		State.CROUCH: state_machine.travel("Sneaking")
		State.PRONE:  state_machine.travel("Crawling")

func refrescar_animacion_aterrizaje():
	match current_state:
		State.NORMAL, State.SPRINT: state_machine.travel("Standing")
		State.CROUCH: state_machine.travel("Sneaking")
		State.PRONE:  state_machine.travel("Crawling")

func iniciar_dive():
	current_state = State.DIVING; dive_timer = 0.0
	var d = velocity.normalized(); if d == Vector3.ZERO: d = -transform.basis.z
	velocity = d * 18.0; velocity.y = 6.0; state_machine.travel("Jump_Start")
	await get_tree().create_timer(0.15).timeout
	if current_state == State.DIVING: state_machine.travel("Crawling")
	
func procesar_dive(delta):
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	if not is_on_floor(): velocity.y -= gravity * 1.5 * delta
	move_and_slide(); dive_timer += delta
	if is_on_floor() and dive_timer > DIVE_MIN_TIME: cambiar_estado(State.PRONE)

func iniciar_dodge():
	current_state = State.DODGING; can_dodge = false
	var i = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if i == Vector2.ZERO: i = Vector2(0, 1)
	anim_tree.set(PATH_DODGE, Vector2(i.x, -i.y)); state_machine.travel("Dodge")
	var d = (transform.basis * Vector3(-i.x, 0, -i.y)).normalized()
	velocity.x = d.x * dodge_power; velocity.z = d.z * dodge_power

func procesar_dodge(delta):
	if str(state_machine.get_current_node()) != "Dodge": current_state = State.NORMAL; iniciar_cooldown_dodge()
	else: 
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		move_and_slide()

func iniciar_cooldown_dodge(): await get_tree().create_timer(0.5).timeout; can_dodge = true

func actualizar_blendspaces(input_dir, delta):
	var t = Vector2.ZERO
	if input_dir.y < 0: t.y = 1
	if input_dir.y > 0: t.y = -1
	if input_dir.x != 0: t.y = 1
	if current_state == State.SPRINT: t.y = 2
	smooth_blend = smooth_blend.lerp(t, blend_speed * delta)
	anim_tree.set(PATH_STANDING, smooth_blend)
	anim_tree.set(PATH_SNEAKING, smooth_blend)
	anim_tree.set(PATH_CRAWLING, smooth_blend)
