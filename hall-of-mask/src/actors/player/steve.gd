extends CharacterBody3D

# --- REFERENCIAS ---
@onready var anim_player = $AnimationPlayer2
# Asegúrate de que la cámara sea hija de HeadMount (para la inmersión)
@onready var camera = $HeadMount/Camera3D 

# --- CONFIGURACIÓN ---
const MOUSE_SENSITIVITY = 0.003
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Límites (Grados)
const MIN_PITCH = -55.0
const MAX_PITCH = 85.0

# --- VARIABLE MAESTRA DE ROTACIÓN (NUEVO) ---
# Esta variable almacena el ángulo vertical acumulado.
# Es mucho más estable que leer camera.rotation cada vez.
var _cam_pitch: float = 0.0 

#var attack_anims = [
	#"Melee_1H_Attack_Chop", "Melee_1H_Attack_Jump_Chop", 
	#"Melee_1H_Attack_Slice_Diagonal", "Melee_1H_Attack_Slice_Horizontal",
	#"Melee_1H_Attack_Stab", "Melee_2H_Attack_Chop", 
	#"Melee_2H_Attack_Slice", "Melee_2H_Attack_Spin",
	#"Melee_2H_Attack_Spinning", "Melee_2H_Attack_Stab"
#]

var attack_anims = [
	"Ranged_1H_Aiming", "Ranged_1H_Reload", 
	"Ranged_1H_Shoot", "Ranged_1H_Shooting",
	"Ranged_2H_Aiming", "Ranged_2H_Reload", 
	"Ranged_2H_Shoot", "Ranged_2H_Shooting",
	"Ranged_Bow_Aiming_Idle", "Ranged_Bow_Draw"
]

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# RE-CAPTURAR MOUSE
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# CONTROL CÁMARA
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# 1. CUERPO (Horizontal - Eje Y)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# 2. CÁMARA (Vertical - Eje X)
		# En lugar de rotar el objeto directamente, sumamos a nuestra variable.
		# El signo -= es para que Mouse Arriba mire Arriba.
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY
		
		# 3. CLAMP (EL COLLARÍN)
		# Limitamos la variable. Como es un simple número float, esto nunca falla.
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(MIN_PITCH), deg_to_rad(MAX_PITCH))
		
		# 4. APLICAR
		# Asignamos el valor final a la cámara.
		camera.rotation.x = _cam_pitch
	
	# ANIMACIONES (1-0)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			play_attack(event.keycode - KEY_1)
		elif event.keycode == KEY_0:
			play_attack(9)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func play_attack(index: int):
	if index >= 0 and index < attack_anims.size():
		anim_player.play(attack_anims[index], 0.1)
