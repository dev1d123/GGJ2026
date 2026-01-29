extends CharacterBody3D

# ------------------------------------------------------------------------------
# SECCIÓN 1: NODOS Y DEPENDENCIAS
# ------------------------------------------------------------------------------
@onready var head_mount: Node3D = $HeadMount
@onready var camera: Camera3D = $HeadMount/Camera3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/StateMachine/playback"]
@onready var skeleton_3d: Skeleton3D = $Ranger/Rig_Medium/Skeleton3D 
@onready var attributes: Node = $AttributeManager # Asumo que es un Node o script personalizado
@onready var stamina: Node = $StaminaComponent
@onready var visual_fx: Node = $VisualEffectManager

# ------------------------------------------------------------------------------
# SECCIÓN 2: CONFIGURACIÓN
# ------------------------------------------------------------------------------
# Cámara
const MOUSE_SENSITIVITY: float = 0.003
const MIN_PITCH: float = -55.0 
const MAX_PITCH: float = 70.0  
var _cam_pitch: float = 0.0 

# IK / Huesos
var spine_bone_name: String = "chest" 
var spine_bone_id: int = -1

# Movimiento
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var dodge_power: float = 25.0 
var blend_speed: float = 7.0 
var smooth_blend: Vector2 = Vector2.ZERO 

# Tiempos y Cooldowns
const TIME_TO_PRONE: float = 0.4 # Tiempo manteniendo botón para reptar
const DIVE_MIN_TIME: float = 0.6 # Tiempo mínimo en el suelo antes de terminar el dive

# ------------------------------------------------------------------------------
# SECCIÓN 3: ESTADOS
# ------------------------------------------------------------------------------
enum State { NORMAL, SPRINT, CROUCH, PRONE, DODGING, DIVING }
var current_state: State = State.NORMAL

# Variables de control
var can_dodge: bool = true 
var was_in_air: bool = false 
var crouch_pressed_time: float = 0.0 
var dive_timer: float = 0.0

# Rutas de Animación (Strings cacheados)
const PATH_STANDING = "parameters/StateMachine/Standing/blend_position"
const PATH_SNEAKING = "parameters/StateMachine/Sneaking/blend_position"
const PATH_CRAWLING = "parameters/StateMachine/Crawling/blend_position"
const PATH_DODGE    = "parameters/StateMachine/Dodge/blend_position"

# ------------------------------------------------------------------------------
# MÉTODOS DE CICLO DE VIDA (_ready, _input, _physics_process)
# ------------------------------------------------------------------------------

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.active = true
	spine_bone_id = skeleton_3d.find_bone(spine_bone_name)

func _input(event: InputEvent) -> void:
	# Gestión del ratón (Capturar/Liberar)
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event.is_action_pressed("ui_cancel"): 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Rotación de Cámara
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
		camera.rotation.x = _cam_pitch
		rotar_columna_hacia_camara()

func _physics_process(delta: float) -> void:
	# 1. Leer Inputs básicos
	var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_moving_backwards: bool = input_dir.y > 0
	
	# 2. Aplicar Gravedad
	aplicar_gravedad(delta)

	# 3. Procesar Estados Bloqueantes (Dodge/Dive)
	# Si estamos en uno de estos estados, salimos de la función aquí para no procesar movimiento normal
	if current_state == State.DODGING:
		procesar_dodge(delta)
		return
	if current_state == State.DIVING:
		procesar_dive(delta)
		return

	# 4. Lógica de Cambio de Postura (Input del jugador)
	controlar_inputs_postura(delta, is_moving_backwards)

	# 5. Movimiento Estándar
	procesar_movimiento_normal(delta, input_dir)
	
	# 6. Actualizar Animaciones
	actualizar_blendspaces(input_dir, delta)

# ------------------------------------------------------------------------------
# LÓGICA DE MOVIMIENTO Y GRAVEDAD
# ------------------------------------------------------------------------------

func aplicar_gravedad(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_in_air = true 
	elif was_in_air:
		was_in_air = false
		refrescar_animacion_aterrizaje()

func procesar_movimiento_normal(delta: float, input_dir: Vector2) -> void:
	# Calcular velocidad base según estado
	var final_speed: float = attributes.get_stat("move_speed")
	
	match current_state:
		State.SPRINT: final_speed *= 1.5
		State.CROUCH: final_speed *= 0.5
		State.PRONE:  final_speed *= 0.3

	# Calcular dirección relativa a la cámara
	var direction: Vector3 = (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * final_speed
		velocity.z = direction.z * final_speed
	else:
		velocity.x = move_toward(velocity.x, 0, final_speed)
		velocity.z = move_toward(velocity.z, 0, final_speed)

	move_and_slide()

# ------------------------------------------------------------------------------
# LÓGICA DE INPUTS (POSTURA Y ACCIONES)
# ------------------------------------------------------------------------------

func controlar_inputs_postura(delta: float, moving_back: bool) -> void:
	# A. SALTO / LEVANTARSE
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match current_state:
			State.PRONE:
				cambiar_estado(State.CROUCH)
			State.CROUCH:
				cambiar_estado(State.NORMAL)
			State.NORMAL, State.SPRINT:
				if is_on_floor() and stamina.try_consume(15):
					velocity.y = attributes.get_stat("jump_force")
					state_machine.travel("Jump_Start")
		return # Consumimos input

	# B. AGACHARSE / DIVE / REPTAR
	# 1. DIVE INSTANTÁNEO (Si corres y pulsas C)
	if Input.is_action_just_pressed("crouch"):
		if current_state == State.SPRINT:
			iniciar_dive()
			return 

	# 2. MANTENER PARA REPTAR
	if Input.is_action_pressed("crouch"):
		crouch_pressed_time += delta
		if crouch_pressed_time > TIME_TO_PRONE:
			if current_state != State.PRONE:
				cambiar_estado(State.PRONE)
	
	# 3. SOLTAR RÁPIDO (TOGGLE CROUCH)
	elif Input.is_action_just_released("crouch"):
		if crouch_pressed_time <= TIME_TO_PRONE:
			if current_state == State.CROUCH:
				cambiar_estado(State.NORMAL)
			elif current_state != State.PRONE: # Si estábamos reptando, no hacemos nada
				cambiar_estado(State.CROUCH)
		crouch_pressed_time = 0.0 # Resetear timer

	# C. SPRINT
	if Input.is_action_pressed("sprint") and is_on_floor() and not moving_back and current_state == State.NORMAL:
		if stamina.try_consume(10 * delta):
			if current_state != State.SPRINT: cambiar_estado(State.SPRINT)
	elif current_state == State.SPRINT and not Input.is_action_pressed("sprint"):
		cambiar_estado(State.NORMAL)

	# D. DODGE
	if Input.is_action_just_pressed("dodge") and can_dodge and is_on_floor():
		if stamina.try_consume(10): iniciar_dodge()

# ------------------------------------------------------------------------------
# MÁQUINA DE ESTADOS Y TRANSICIONES
# ------------------------------------------------------------------------------

func cambiar_estado(nuevo_estado: State) -> void:
	current_state = nuevo_estado
	match current_state:
		State.NORMAL, State.SPRINT: state_machine.travel("Standing")
		State.CROUCH: state_machine.travel("Sneaking")
		State.PRONE:  state_machine.travel("Crawling")

func refrescar_animacion_aterrizaje() -> void:
	# Fuerza la animación correcta al tocar suelo
	match current_state:
		State.NORMAL, State.SPRINT: state_machine.travel("Standing")
		State.CROUCH: state_machine.travel("Sneaking")
		State.PRONE:  state_machine.travel("Crawling")

# ------------------------------------------------------------------------------
# LÓGICA ESPECIAL: DIVE (SALTO DEL TIGRE)
# ------------------------------------------------------------------------------

func iniciar_dive() -> void:
	current_state = State.DIVING
	dive_timer = 0.0
	
	# Dirección del impulso
	var dive_dir: Vector3 = velocity.normalized()
	if dive_dir == Vector3.ZERO:
		dive_dir = -transform.basis.z 
	
	# Física de impacto
	velocity = dive_dir * 18.0 
	velocity.y = 6.0 
	
	# Ilusión visual: Salto -> Transición a Reptar
	state_machine.travel("Jump_Start")
	print("🌊 DIVE: Inicio aéreo")

	# Esperar brevemente en el aire antes de cambiar la pose
	await get_tree().create_timer(0.15).timeout
	
	# Verificación de seguridad por si el estado cambió durante el await
	if current_state == State.DIVING:
		state_machine.travel("Crawling")

func procesar_dive(delta: float) -> void:
	# Fricción aérea y terrestre
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	
	# Gravedad extra para sensación de peso
	if not is_on_floor():
		velocity.y -= gravity * 1.5 * delta
	
	move_and_slide()
	
	dive_timer += delta
	
	# Terminar Dive
	if is_on_floor() and dive_timer > DIVE_MIN_TIME:
		print("✅ DIVE: Aterrizaje completado")
		cambiar_estado(State.PRONE)

# ------------------------------------------------------------------------------
# LÓGICA ESPECIAL: DODGE (ESQUIVA)
# ------------------------------------------------------------------------------

func iniciar_dodge() -> void:
	current_state = State.DODGING
	can_dodge = false 
	
	# Calcular dirección del esquive (relativo a input, no a cámara)
	var input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input == Vector2.ZERO: input = Vector2(0, 1) # Si no toca nada, esquiva atrás
	
	# Animación BlendSpace
	var dodge_vec: Vector2 = Vector2(input.x, -input.y)
	anim_tree.set(PATH_DODGE, dodge_vec)
	state_machine.travel("Dodge")
	
	# Impulso físico
	var direction_3d: Vector3 = (transform.basis * Vector3(-input.x, 0, -input.y)).normalized()
	velocity.x = direction_3d.x * dodge_power
	velocity.z = direction_3d.z * dodge_power

func procesar_dodge(delta: float) -> void:
	var nodo_actual: String = str(state_machine.get_current_node())
	
	if nodo_actual != "Dodge":
		current_state = State.NORMAL
		iniciar_cooldown_dodge() 
	else:
		# Fricción fuerte para frenar al final del dodge
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta) 
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		move_and_slide()

func iniciar_cooldown_dodge() -> void:
	await get_tree().create_timer(0.5).timeout
	can_dodge = true

# ------------------------------------------------------------------------------
# VISUALES Y HELPERS
# ------------------------------------------------------------------------------

func actualizar_blendspaces(input_dir: Vector2, delta: float) -> void:
	# Mapear input 2D al BlendSpace 1D/2D
	var target_vector: Vector2 = Vector2.ZERO
	
	# Lógica para BlendSpace 2D o 1D según lo tengas configurado
	if input_dir.y < 0: target_vector.y = 1  
	if input_dir.y > 0: target_vector.y = -1 
	if input_dir.x != 0: target_vector.y = 1 
	
	if current_state == State.SPRINT: target_vector.y = 2
	
	# Interpolación suave
	smooth_blend = smooth_blend.lerp(target_vector, blend_speed * delta)
	
	anim_tree.set(PATH_STANDING, smooth_blend)
	anim_tree.set(PATH_SNEAKING, smooth_blend)
	anim_tree.set(PATH_CRAWLING, smooth_blend)

func rotar_columna_hacia_camara() -> void:
	if spine_bone_id == -1: return
	
	var mirada: Quaternion = Quaternion(Vector3.RIGHT, -_cam_pitch)
	var rest: Quaternion = skeleton_3d.get_bone_rest(spine_bone_id).basis.get_rotation_quaternion()
	
	skeleton_3d.set_bone_pose_rotation(spine_bone_id, rest * mirada)
