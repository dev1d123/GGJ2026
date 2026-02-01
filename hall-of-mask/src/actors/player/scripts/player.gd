extends CharacterBody3D
@onready var footstep_audio: AudioStreamPlayer3D = $FootStep
@export var footstep_sounds: Array[AudioStream] = []

@onready var attack_audio: AudioStreamPlayer3D = $WeaponAudio
@export var attack_sounds: Array[AudioStream] = []

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN Y REFERENCIAS
# ------------------------------------------------------------------------------
@onready var head_mount: Node3D = $HeadMount
@onready var camera: Camera3D = $HeadMount/Camera3D
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var state_machine = anim_tree["parameters/StateMachine/playback"]
@onready var skeleton_3d: Skeleton3D = $Ranger/Rig_Medium/Skeleton3D 
@onready var attributes: Node = $AttributeManager 
@onready var stamina: Node = $StaminaComponent
@onready var health_component: HealthComponent = $HealthComponent 
@onready var combat_manager: CombatManager = $CombatManager 
@onready var mask_manager: MaskManager = $MaskManager

@onready var distortion: ColorRect = $ColorRect
@onready var distortion_mat: ShaderMaterial = distortion.material
var transitioning := false

# --- CONFIGURACIÓN FÍSICA ---
@export_category("Movimiento Base")
@export var speed_walk: float = 500.0
@export var jump_force: float = 15.0 
@export var gravity_multiplier: float = 2.0 

@export_category("Evasión (Dodge & Dive)")
@export var dodge_power: float = 15.0 
@export var dodge_cost: float = 15.0
@export var dive_sprint_damp: float = 0.8

# --- CONFIGURACIÓN DE MOMENTO ---
const MAX_MOMENTUM_TIME: float = 0.9 
const MIN_MOMENTUM_MULT: float = 0.1 

# --- MULTIPLICADORES ---
var mask_speed_mult: float = 1.0
var mask_jump_mult: float = 1.0
var mask_defense_mult: float = 1.0:
	set(value):
		mask_defense_mult = value
		if health_component: health_component.defense_multiplier = value

# --- VARIABLES SHOOTER ---
var base_fov: float = 75.0
var aim_fov: float = 50.0 
var sprint_fov: float = 85.0
var current_speed_mult: float = 1.0 
var aim_sensitivity_mult: float = 0.4 # 🟢 Sensibilidad reducida

var trauma: float = 0.0
var trauma_power: float = 2.0 
var shake_decay: float = 1.5  

# --- VARIABLES VISUALES DE MÁSCARAS ---
@onready var fighter_overlay: ColorRect = $fighterMask
@onready var shooter_overlay: ColorRect = $shooterMask
@onready var undead_overlay: ColorRect = $undeadMask
@onready var time_overlay: ColorRect = $timeMask
var current_mask_visual: String = "" # "fighter", "shooter", "undead", "time", o ""

# --- VARIABLES INTERNAS ---
var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false 
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const MOUSE_SENSITIVITY: float = 0.003
var _cam_pitch: float = 0.0 
var spine_bone_id: int = -1
var knockback_velocity: Vector3 = Vector3.ZERO

# Tiempos
const TIME_TO_PRONE: float = 0.4
const DIVE_MIN_TIME: float = 0.5 
var crouch_pressed_time: float = 0.0 
var dive_timer: float = 0.0
var sprint_timer: float = 0.0 
var was_in_air: bool = false
var can_dodge: bool = true 

# Estados
enum State { NORMAL, SPRINT, CROUCH, PRONE, DODGING, DIVING, DEAD }
var current_state: State = State.NORMAL

signal on_state_changed(new_state_name)

# Rutas AnimationTree
const PATH_STANDING = "parameters/StateMachine/Standing/blend_position"
const PATH_SNEAKING = "parameters/StateMachine/Sneaking/blend_position"
const PATH_CRAWLING = "parameters/StateMachine/Crawling/blend_position"
const PATH_DODGE    = "parameters/StateMachine/Dodge/blend_position"
var smooth_blend: Vector2 = Vector2.ZERO
var blend_speed: float = 10.0

func start_distortion_transition(duration: float = 1.0) -> void:
	if transitioning: return
	transitioning = true
	set_physics_process(false)
	set_process(false)
	distortion.visible = true
	distortion_mat.set_shader_parameter("strength", 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(distortion_mat, "shader_parameter/strength", 1.0, duration)

# ------------------------------------------------------------------------------
# 2. CICLO DE VIDA E INPUTS
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
			
	emit_signal("on_state_changed", "NORMAL")

func _input(event: InputEvent) -> void:
	if is_dead: return 

	# CÁMARA + Sensibilidad
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens = 1.0
		if combat_manager and combat_manager.is_aiming:
			sens = aim_sensitivity_mult
			
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY * sens)
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY * sens
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(-55.0), deg_to_rad(70.0))
		camera.rotation.x = _cam_pitch
		rotar_columna_hacia_camara()
	
	if event.is_action_pressed("ui_cancel"): 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# CONTROL DE COMBATE HÍBRIDO
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			combat_manager.handle_right_click(event.pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			combat_manager.handle_left_click(event.pressed)

	# INPUTS UI
	if event.is_action_pressed("ultimate_ability"):
		var mgr = mask_manager if "mask_manager" in self else get_node_or_null("MaskManager")
		if mgr: mgr.activate_ultimate()
	if event.is_action_pressed("usar_pocion_1"): usar_pocion(0)
	elif event.is_action_pressed("usar_pocion_2"): usar_pocion(1)
	elif event.is_action_pressed("usar_pocion_3"): usar_pocion(2)

# ------------------------------------------------------------------------------
# 3. FÍSICAS Y LÓGICA
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead: return 
	
	_apply_shake(delta)
	_procesar_modificadores_combate(delta)

	if is_on_floor() and (abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1):
		if not footstep_audio.playing and footstep_sounds.size() > 0:
			footstep_audio.stream = footstep_sounds.pick_random()
			footstep_audio.play()
	else:
		footstep_audio.stop()
	# Gravedad
	if not is_on_floor():
		velocity.y -= (gravity * gravity_multiplier) * delta
		was_in_air = true
	elif was_in_air:
		was_in_air = false
		refrescar_animacion_aterrizaje()

	# Knockback
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	# Estados Bloqueantes
	if current_state == State.DODGING: procesar_dodge(delta); return
	if current_state == State.DIVING: procesar_dive(delta); return
	
	if combat_manager.is_movement_locked:
		velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
		move_and_slide()
		actualizar_blendspaces(Vector2.ZERO, delta)
		return 
	
	# Movimiento
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	controlar_inputs_postura(delta, input_dir.y > 0)
	
	if current_state == State.DODGING or current_state == State.DIVING: return 
	
	if current_state == State.SPRINT:
		sprint_timer = min(sprint_timer + delta, MAX_MOMENTUM_TIME)
	else:
		sprint_timer = 0.0

	procesar_movimiento_normal(delta, input_dir)
	actualizar_blendspaces(input_dir, delta)

# ------------------------------------------------------------------------------
# FOV y VELOCIDAD
# ------------------------------------------------------------------------------
func _procesar_modificadores_combate(delta):
	var target_fov = base_fov
	current_speed_mult = 1.0 
	
	if combat_manager.is_aiming:
		target_fov = aim_fov
		current_speed_mult = 0.5 
		if current_state == State.SPRINT: cambiar_estado(State.NORMAL)
	elif current_state == State.SPRINT:
		target_fov = sprint_fov
	
	if camera: camera.fov = lerp(camera.fov, target_fov, 8.0 * delta)

func procesar_movimiento_normal(delta, input_dir):
	var base_spd = speed_walk
	if attributes and attributes.has_method("get_stat"):
		base_spd = attributes.get_stat("move_speed")
	
	var final_speed = base_spd * mask_speed_mult * current_speed_mult
	match current_state:
		State.SPRINT: final_speed *= 1.6
		State.CROUCH: final_speed *= 0.5
		State.PRONE: final_speed *= 0.3
	
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if dir:
		velocity.x = dir.x * final_speed
		velocity.z = dir.z * final_speed
	else:
		velocity.x = move_toward(velocity.x, 0, final_speed)
		velocity.z = move_toward(velocity.z, 0, final_speed)
	move_and_slide()

# ------------------------------------------------------------------------------
# ESTADOS
# ------------------------------------------------------------------------------
func controlar_inputs_postura(delta, moving_back): 
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match current_state:
			State.PRONE: cambiar_estado(State.CROUCH)
			State.CROUCH: cambiar_estado(State.NORMAL)
			State.NORMAL, State.SPRINT:
				if is_on_floor() and stamina.try_consume(15):
					velocity.y = jump_force * mask_jump_mult 
					state_machine.travel("Jump_Start")
		return
	
	if Input.is_action_just_pressed("dodge") and can_dodge and is_on_floor():
		iniciar_dodge()
		return
	
	var is_moving = velocity.x != 0 or velocity.z != 0
	var aiming_block = combat_manager.is_aiming
	
	if Input.is_action_pressed("sprint") and is_on_floor() and not moving_back and current_state == State.NORMAL and is_moving and not aiming_block:
		cambiar_estado(State.SPRINT)
	
	if current_state == State.SPRINT:
		if not Input.is_action_pressed("sprint") or not is_moving or aiming_block:
			cambiar_estado(State.NORMAL)
		else:
			if not stamina.try_consume(15 * delta):
				cambiar_estado(State.NORMAL) 

	if Input.is_action_just_pressed("crouch"):
		if current_state == State.SPRINT: iniciar_dive(); return 

	if Input.is_action_pressed("crouch") and current_state != State.SPRINT:
		crouch_pressed_time += delta
		if crouch_pressed_time > TIME_TO_PRONE:
			if current_state != State.PRONE: cambiar_estado(State.PRONE)
	
	elif Input.is_action_just_released("crouch"):
		if crouch_pressed_time <= TIME_TO_PRONE and current_state != State.DIVING:
			if current_state == State.CROUCH: cambiar_estado(State.NORMAL)
			elif current_state != State.PRONE: cambiar_estado(State.CROUCH)
		crouch_pressed_time = 0.0

# ------------------------------------------------------------------------------
# UTILS
# ------------------------------------------------------------------------------
func add_camera_trauma(amount: float):
	trauma = min(trauma + amount, 1.0)
	
func _apply_shake(delta):
	if trauma > 0:
		trauma = max(trauma - shake_decay * delta, 0)
		var shake = pow(trauma, trauma_power)
		if camera:
			camera.h_offset = 0.1 * shake * randf_range(-1, 1)
			camera.v_offset = 0.1 * shake * randf_range(-1, 1)
			camera.rotation.z = 0.05 * shake * randf_range(-1, 1)

func iniciar_dodge():
	if not stamina.try_consume(dodge_cost): return
	current_state = State.DODGING
	can_dodge = false
	emit_signal("on_state_changed", "DODGE")
	var i = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if i == Vector2.ZERO: i = Vector2(0, 1) 
	anim_tree.set(PATH_DODGE, i)
	state_machine.travel("Dodge")
	var dir_3d = (transform.basis * Vector3(i.x, 0, i.y)).normalized()
	velocity.x = dir_3d.x * dodge_power
	velocity.z = dir_3d.z * dodge_power

func procesar_dodge(delta):
	velocity.x = move_toward(velocity.x, 0, 40.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 40.0 * delta)
	move_and_slide()
	if str(state_machine.get_current_node()) != "Dodge": 
		current_state = State.NORMAL
		emit_signal("on_state_changed", "NORMAL")
		iniciar_cooldown_dodge()

func iniciar_cooldown_dodge(): 
	await get_tree().create_timer(0.5).timeout; can_dodge = true

func iniciar_dive():
	if not stamina.try_consume(dodge_cost): return
	current_state = State.DIVING
	dive_timer = 0.0
	emit_signal("on_state_changed", "DIVING")
	var i = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var d = Vector3.ZERO
	if i != Vector2.ZERO: d = (transform.basis * Vector3(i.x, 0, i.y)).normalized()
	else: d = -transform.basis.z 
	var momentum_percent = clamp(sprint_timer / MAX_MOMENTUM_TIME, 0.0, 1.0)
	var impulso_final = lerp(MIN_MOMENTUM_MULT, 1.0, momentum_percent)
	var fuerza_dive = dodge_power * impulso_final * dive_sprint_damp
	velocity = d * fuerza_dive
	velocity.y = 5.0 
	state_machine.travel("Jump_Start") 
	await get_tree().create_timer(0.2).timeout
	if current_state == State.DIVING: state_machine.travel("Crawling")
	
func procesar_dive(delta):
	if not is_on_floor(): velocity.y -= (gravity * gravity_multiplier) * delta
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	move_and_slide()
	dive_timer += delta
	if is_on_floor() and dive_timer > 0.3: cambiar_estado(State.PRONE)

func cambiar_estado(nuevo):
	if current_state == nuevo: return
	current_state = nuevo
	match current_state:
		State.NORMAL, State.SPRINT: state_machine.travel("Standing")
		State.CROUCH: state_machine.travel("Sneaking")
		State.PRONE:  state_machine.travel("Crawling")
	emit_signal("on_state_changed", str(current_state))

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

func take_damage(amount: float):
	if health_component: health_component.take_damage(amount)
	else: morir()

func morir():
	if is_dead: return
	is_dead = true
	current_state = State.DEAD
	emit_signal("on_state_changed", "MUERTO")
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)
	var death_cam = Camera3D.new()
	get_tree().current_scene.add_child(death_cam)
	death_cam.global_transform = camera.global_transform
	death_cam.current = true; camera.visible = false 
	var t = create_tween()
	t.tween_property(death_cam, "global_position:y", death_cam.global_position.y + 3.0, 3.0).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(death_cam, "rotation_degrees:x", -90.0, 2.5)
	await get_tree().create_timer(4.0).timeout
	death_cam.queue_free()
	get_tree().reload_current_scene()

# --- UI CONNECTIONS ---
signal vida_cambiada(nueva_vida)
signal mana_cambiado(nuevo_mana, max_mana)
signal stamina_cambiada(nueva_stamina, max_stamina)
signal pociones_cambiadas(slot_index, cantidad)
signal ulti_cambiada(nueva_carga, max_carga)
signal mascara_cambiada(mask_data) 

var pociones_ui = [3, 1, 0] 

func _ready_ui_connections():
	if health_component:
		health_component.on_damage_received.connect(func(_amt, curr): emit_signal("vida_cambiada", curr))
		emit_signal("vida_cambiada", health_component.current_health)
	if stamina:
		stamina.on_value_changed.connect(func(curr, max_val): emit_signal("stamina_cambiada", curr, max_val))
		if "current_value" in stamina: emit_signal("stamina_cambiada", stamina.current_value, stamina.max_value)
	var mana_comp = get_node_or_null("ManaComponent")
	if mana_comp:
		mana_comp.on_value_changed.connect(func(curr, max_val): emit_signal("mana_cambiado", curr, max_val))
		emit_signal("mana_cambiado", mana_comp.current_value, mana_comp.max_value)
	var mask_mgr = get_node_or_null("MaskManager")
	if not mask_mgr and get_parent().has_node("MaskManager"): mask_mgr = get_parent().get_node("MaskManager")
	if mask_mgr:
		mask_mgr.on_mask_changed.connect(func(mask): emit_signal("mascara_cambiada", mask))
		mask_mgr.on_ult_charge_changed.connect(func(val): emit_signal("ulti_cambiada", val, 100.0))
		emit_signal("mascara_cambiada", mask_mgr.current_mask)
		emit_signal("ulti_cambiada", mask_mgr.current_ult_charge, 100.0)
	emit_signal("pociones_cambiadas", 1, pociones_ui[0])
	emit_signal("pociones_cambiadas", 2, pociones_ui[1])
	emit_signal("pociones_cambiadas", 3, pociones_ui[2])

func _enter_tree(): call_deferred("_ready_ui_connections")

func equipar_desde_ui(item_data, hand_side):
	if item_data is MaskData:
		var mask_mgr = get_node_or_null("MaskManager")
		if not mask_mgr and get_parent().has_node("MaskManager"): mask_mgr = get_parent().get_node("MaskManager")
		if mask_mgr: mask_mgr.equip_mask(item_data)
		return
	if combat_manager: combat_manager.equip_weapon(item_data, hand_side.to_lower())

func desequipar_desde_ui(hand_side):
	if combat_manager: combat_manager.unequip_weapon(hand_side.to_lower())

func usar_pocion(index):
	if index >= 0 and index < pociones_ui.size() and pociones_ui[index] > 0:
		pociones_ui[index] -= 1
		if index == 0 and health_component:
			health_component.current_health += 20
			if health_component.current_health > health_component.max_health:
				health_component.current_health = health_component.max_health
			emit_signal("vida_cambiada", health_component.current_health)
		emit_signal("pociones_cambiadas", index + 1, pociones_ui[index])
func apply_knockback(direction: Vector3, force: float, vertical_force: float):
	if is_dead: return
	
	# 1. Asegurar dirección horizontal pura para el deslizamiento
	direction.y = 0
	direction = direction.normalized()
	
	# 2. Aplicar fuerza de empuje
	knockback_velocity = direction * force  * 1.3 
	
	# 3. Aplicar salto (Levantamiento)
	if vertical_force > 0:
		# TRUCO: Si estamos en el suelo, reseteamos la velocidad Y actual
		# para que el salto sea "seco" y no luche contra la gravedad acumulada.
		velocity.y = vertical_force
		was_in_air = true # Forzamos estado aire para animaciones

	# 4. Feedback
	add_camera_trauma(0.5) 

# ------------------------------------------------------------------------------
# SISTEMA VISUAL DE MÁSCARAS (Solo visual, sin stats)
# ------------------------------------------------------------------------------
func equip_mask_visual(mask_name: String):
	# Ocultar todas las máscaras primero
	if fighter_overlay: fighter_overlay.visible = false
	if shooter_overlay: shooter_overlay.visible = false
	if undead_overlay: undead_overlay.visible = false
	if time_overlay: time_overlay.visible = false
	
	# Activar la máscara seleccionada
	match mask_name:
		"fighter":
			if fighter_overlay: fighter_overlay.visible = true
			current_mask_visual = "fighter"
			_update_health_icons("fighter")
		"shooter":
			if shooter_overlay: shooter_overlay.visible = true
			current_mask_visual = "shooter"
			_update_health_icons("shooter")
		"undead":
			if undead_overlay: undead_overlay.visible = true
			current_mask_visual = "undead"
			_update_health_icons("undead")
		"time":
			if time_overlay: time_overlay.visible = true
			current_mask_visual = "time"
			_update_health_icons("time")
		_:
			current_mask_visual = ""
			_update_health_icons("")
	
	print("🎭 Player: Máscara visual equipada: ", mask_name)

func _update_health_icons(mask_name: String):
	# Emitir señal para que el HUD actualice los iconos de vida
	var icon_texture = null
	if mask_name != "":
		var icon_path = "res://assets/imagesGUI/" + mask_name + "_mask.png"
		if ResourceLoader.exists(icon_path):
			icon_texture = load(icon_path)
	
	# Notificar al HUD (si tiene el método)
	var hud = get_node_or_null("HUD")
	if hud and hud.has_node("GameUI/StatsPanel"):
		var stats_panel = hud.get_node("GameUI/StatsPanel")
		if stats_panel.has_method("update_life_icons_texture"):
			stats_panel.update_life_icons_texture(icon_texture)

func _play_attack_sound():
	if attack_sounds.is_empty():
		return

	attack_audio.stream = attack_sounds.pick_random()
	attack_audio.pitch_scale = randf_range(0.95, 1.05)
	attack_audio.play()
