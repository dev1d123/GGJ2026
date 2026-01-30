extends CharacterBody3D

# --- REFERENCIAS ---
@onready var head_mount: Node3D = $HeadMount
@onready var camera: Camera3D = $HeadMount/Camera3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine = anim_tree["parameters/StateMachine/playback"]
@onready var skeleton_3d: Skeleton3D = $Ranger/Rig_Medium/Skeleton3D 
@onready var attributes: Node = $AttributeManager 
@onready var stamina: Node = $StaminaComponent
@onready var health_component: HealthComponent = $HealthComponent 
@onready var combat_manager: CombatManager = $CombatManager # Referencia al Manager

# --- VARIABLES ---
var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false 

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const MOUSE_SENSITIVITY: float = 0.003
var _cam_pitch: float = 0.0 
var spine_bone_id: int = -1
var knockback_velocity: Vector3 = Vector3.ZERO
var knockback_friction: float = 8.0

const TIME_TO_PRONE: float = 0.4
const DIVE_MIN_TIME: float = 0.6 
var crouch_pressed_time: float = 0.0 
var dive_timer: float = 0.0
var was_in_air: bool = false

enum State { NORMAL, SPRINT, CROUCH, PRONE, DODGING, DIVING, DEAD }
var current_state: State = State.NORMAL
var can_dodge: bool = true 
var dodge_power: float = 25.0 

const PATH_STANDING = "parameters/StateMachine/Standing/blend_position"
const PATH_SNEAKING = "parameters/StateMachine/Sneaking/blend_position"
const PATH_CRAWLING = "parameters/StateMachine/Crawling/blend_position"
const PATH_DODGE    = "parameters/StateMachine/Dodge/blend_position"
var smooth_blend: Vector2 = Vector2.ZERO
var blend_speed: float = 7.0

# ------------------------------------------------------------------------------
# 3. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.active = true
	if skeleton_3d: spine_bone_id = skeleton_3d.find_bone("chest")
	
	if health_component:
		health_component.on_death.connect(morir)
		if "max_health" in health_component:
			max_health = health_component.max_health
			current_health = health_component.current_health
	print("✅ PLAYER LISTO.")

func _input(event: InputEvent) -> void:
	if is_dead: return 

	# 1. CÁMARA (Mouse Motion)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(-55.0), deg_to_rad(70.0))
		camera.rotation.x = _cam_pitch
		rotar_columna_hacia_camara()
	
	# 2. UI Y MOUSE MODE
	if event.is_action_pressed("ui_cancel"): 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# 3. ATAQUE (Delegado al Manager)
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				combat_manager.try_attack("right")
			elif event.button_index == MOUSE_BUTTON_LEFT:
				combat_manager.try_attack("left")

	# ----------------------------------------------------------------------
	# 4. INPUTS DE ARMAS (RESTAURADOS)
	# Leemos los slots del CombatManager y le decimos qué equipar.
	# ----------------------------------------------------------------------
	if event is InputEventKey and event.pressed:
		var tab = Input.is_physical_key_pressed(KEY_TAB)
		var mano = "left" if tab else "right"
		
		# Verificamos si podemos cambiar (si no estamos atacando con esa mano)
		# Accedemos a las variables públicas del manager
		if mano == "right" and combat_manager.is_attacking_r: return
		if mano == "left" and combat_manager.is_attacking_l: return

		match event.keycode:
			KEY_1: 
				combat_manager.unequip_weapon(mano)
			KEY_2: 
				# Accedemos al slot guardado en el manager
				if combat_manager.slot_2: 
					combat_manager.equip_weapon(combat_manager.slot_2, mano)
			KEY_3: 
				if combat_manager.slot_3: 
					combat_manager.equip_weapon(combat_manager.slot_3, mano)
			KEY_4: 
				if combat_manager.slot_4: 
					combat_manager.equip_weapon(combat_manager.slot_4, mano)

func _physics_process(delta: float) -> void:
	# 0. Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta
		was_in_air = true
	elif was_in_air:
		was_in_air = false
		refrescar_animacion_aterrizaje()

	if is_dead:
		velocity.x = 0; velocity.z = 0; move_and_slide(); return 

	# 1. Empuje
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	# 2. Estados Bloqueantes
	if current_state == State.DODGING: procesar_dodge(delta); return
	if current_state == State.DIVING: procesar_dive(delta); return
	
	# 3. LÓGICA DE MOVIMIENTO DURANTE ATAQUE
	# Usamos la variable del Manager para saber si el arma actual nos congela
	if combat_manager.is_movement_locked:
		velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
		move_and_slide()
		actualizar_blendspaces(Vector2.ZERO, delta)
		return 
	
	# 4. Movimiento Normal
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	controlar_inputs_postura(delta, input_dir.y > 0)
	procesar_movimiento_normal(delta, input_dir)
	actualizar_blendspaces(input_dir, delta)

# ------------------------------------------------------------------------------
# 4. LÓGICA DE MOVIMIENTO (TU CÓDIGO ORIGINAL)
# ------------------------------------------------------------------------------
func controlar_inputs_postura(delta, moving_back): 
	# Salto
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match current_state:
			State.PRONE: cambiar_estado(State.CROUCH)
			State.CROUCH: cambiar_estado(State.NORMAL)
			State.NORMAL, State.SPRINT:
				if is_on_floor() and stamina.try_consume(15):
					velocity.y = 5.0 # Salto
					state_machine.travel("Jump_Start")
		return
	
	# Agacharse / Dive / Reptar
	if Input.is_action_just_pressed("crouch"):
		if current_state == State.SPRINT: iniciar_dive(); return

	if Input.is_action_pressed("crouch"):
		crouch_pressed_time += delta
		if crouch_pressed_time > TIME_TO_PRONE:
			if current_state != State.PRONE: cambiar_estado(State.PRONE)
	elif Input.is_action_just_released("crouch"):
		if crouch_pressed_time <= TIME_TO_PRONE:
			if current_state == State.CROUCH: cambiar_estado(State.NORMAL)
			elif current_state != State.PRONE: cambiar_estado(State.CROUCH)
		crouch_pressed_time = 0.0
	
	# Sprint
	if Input.is_action_pressed("sprint") and is_on_floor() and not moving_back and current_state == State.NORMAL:
		if stamina.try_consume(10 * delta):
			if current_state != State.SPRINT: cambiar_estado(State.SPRINT)
	elif current_state == State.SPRINT and not Input.is_action_pressed("sprint"):
		cambiar_estado(State.NORMAL)
	
	# Dodge
	if Input.is_action_just_pressed("dodge") and can_dodge and is_on_floor():
		if stamina.try_consume(10): iniciar_dodge()

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

# --- FUNCIONES DE DODGE Y DIVE ---
func iniciar_dodge():
	current_state = State.DODGING; can_dodge = false
	var i = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if i == Vector2.ZERO: i = Vector2(0, 1)
	anim_tree.set(PATH_DODGE, Vector2(i.x, -i.y))
	state_machine.travel("Dodge")
	var d = (transform.basis * Vector3(-i.x, 0, -i.y)).normalized()
	velocity.x = d.x * dodge_power; velocity.z = d.z * dodge_power

func procesar_dodge(delta):
	if str(state_machine.get_current_node()) != "Dodge": 
		current_state = State.NORMAL; iniciar_cooldown_dodge()
	else: 
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		move_and_slide()

func iniciar_cooldown_dodge(): 
	await get_tree().create_timer(0.5).timeout; can_dodge = true

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

# --- UTILIDADES ---
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

func rotar_columna_hacia_camara():
	if spine_bone_id != -1 and not is_dead:
		var m = Quaternion(Vector3.RIGHT, -_cam_pitch)
		var r = skeleton_3d.get_bone_rest(spine_bone_id).basis.get_rotation_quaternion()
		skeleton_3d.set_bone_pose_rotation(spine_bone_id, r * m)

# ------------------------------------------------------------------------------
# 5. SISTEMA DE DAÑO Y MUERTE (INTEGRADO)
# ------------------------------------------------------------------------------
func take_damage(amount: float):
	if health_component: health_component.take_damage(amount)
	else: morir()

func apply_knockback(dir: Vector3, force: float, up_force: float = 2.0):
	if is_dead: return
	knockback_velocity = dir * force
	if is_on_floor(): velocity.y = up_force 

func morir():
	if is_dead: return
	is_dead = true
	current_state = State.DEAD
	print("💀 --- HAS MUERTO (CÁMARA FANTASMA) ---")
	
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	var hb = find_child("Hurtbox", true, false)
	if hb: hb.find_child("CollisionShape3D").set_deferred("disabled", true)

	# Cámara Fantasma
	var death_cam = Camera3D.new()
	get_tree().current_scene.add_child(death_cam)
	death_cam.global_transform = camera.global_transform
	death_cam.current = true
	camera.visible = false 
	
	var t = create_tween()
	t.tween_property(death_cam, "global_position:y", death_cam.global_position.y + 4.0, 2.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(death_cam, "rotation_degrees:x", -90.0, 2.0)
	
	await get_tree().create_timer(4.0).timeout
	death_cam.queue_free()
	get_tree().reload_current_scene()
