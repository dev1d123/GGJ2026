extends CharacterBody3D
@onready var footstep_audio: AudioStreamPlayer3D = $FootStep
@export var footstep_sounds: Array[AudioStream] = []

@onready var attack_audio: AudioStreamPlayer3D = $WeaponAudio
## Array de sonidos para asignar a los ataques.
@export var attack_sounds: Array[AudioStream] = []

# ── SFX de UI (pociones / ulti) ──────────────────────────────────────────────
var sfx_ui_player: AudioStreamPlayer
const SOUND_HEALTH_POTION  := preload("res://assets/sfx/healthPotion.wav")
const SOUND_MAGIC_POTION   := preload("res://assets/sfx/magicPotion.mp3")
const SOUND_STAMINA_POTION := preload("res://assets/sfx/staminaPotion.wav")
const SOUND_ULTI           := preload("res://assets/sfx/ulti.wav")

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

# --- SISTEMA DE VIÑETA Y DAÑO ---
var damage_vignette: ColorRect

# --- CONFIGURACIÓN FÍSICA ---
@export_category("Movimiento Base")
## Velocidad base del jugador al caminar de frente.
@export var speed_walk: float = 6.5
## Multiplicador de velocidad al correr hacia adelante. (Correr hacia atrás usa la mitad).
@export var speed_sprint_mult: float = 1.6
## Fuerza vertical del salto.
@export var jump_force: float = 18.0 
## Multiplicador artificial de la gravedad para hacer el salto menos "flotante".
@export var gravity_multiplier: float = 3.0

@export_category("Evasión (Dodge & Dive)")
## Fuerza horizontal impulsada al hacer Dodge (Rodar).
@export var dodge_power: float = 15.0 
## Costo de Estamina para realizar un Dodge.
@export var dodge_cost: float = 15.0
## Fricción aplicada al finalizar el Dive (Lanzarse al piso).
@export var dive_sprint_damp: float = 0.8

@export_category("Cámara Estabilización")
## Suaviza la posición del HeadMount para reducir jitter de animaciones bruscas.
@export var camera_stabilization_enabled: bool = true
## Velocidad de seguimiento horizontal (X/Z) del HeadMount hacia el objetivo animado.
@export var camera_follow_speed: float = 14.0
## Multiplicador de seguimiento vertical (Y). Menor valor = menos "rebote" al saltar/aterrizar.
@export var camera_vertical_damping: float = 0.45

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
var _time_ulti_active: bool = false

# --- VARIABLES INTERNAS ---
var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false 
var _toast_canvas: CanvasLayer = null
var _active_toasts: int = 0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const MOUSE_SENSITIVITY: float = 0.003
var _cam_pitch: float = 0.0 
var _camera_smoothed_pos: Vector3 = Vector3.ZERO
var _camera_stabilizer_ready: bool = false
var _camera_stability_blend: float = 1.0
var _camera_stability_tween: Tween = null
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

func show_toast(message: String, color: Color = Color(1.0, 0.85, 0.1)) -> void:
	if not _toast_canvas:
		_toast_canvas = CanvasLayer.new()
		_toast_canvas.layer = 20
		add_child(_toast_canvas)

	var slot := _active_toasts
	_active_toasts += 1

	var strip := CenterContainer.new()
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 0.0
	strip.anchor_bottom = 0.0
	strip.offset_top = 120.0 + slot * 52.0
	strip.offset_bottom = 165.0 + slot * 52.0
	_toast_canvas.add_child(strip)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.82)
	style.border_width_top = 2; style.border_width_bottom = 2
	style.border_width_left = 2; style.border_width_right = 2
	style.border_color = color
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left = 18; style.content_margin_right = 18
	style.content_margin_top = 7; style.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", style)
	strip.add_child(panel)

	var lbl := Label.new()
	lbl.text = message
	var font = load("res://assets/imagesGUI/font.TTF")
	if font: lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", color)
	panel.add_child(lbl)

	strip.modulate.a = 0.0
	var _s := strip
	var tween := create_tween()
	tween.tween_property(strip, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.1)
	tween.tween_property(strip, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		_active_toasts -= 1
		if is_instance_valid(_s): _s.queue_free()
	)

# ------------------------------------------------------------------------------
# 2. CICLO DE VIDA E INPUTS
# ------------------------------------------------------------------------------
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	anim_tree.active = true
	if head_mount:
		_camera_smoothed_pos = head_mount.global_position
		_camera_stabilizer_ready = true
	if combat_manager and not combat_manager.on_stop_movement_camera_mode.is_connected(_on_stop_movement_camera_mode):
		combat_manager.on_stop_movement_camera_mode.connect(_on_stop_movement_camera_mode)
	if skeleton_3d: spine_bone_id = skeleton_3d.find_bone("chest")
	
	if health_component:
		health_component.on_death.connect(morir)
		if "max_health" in health_component:
			max_health = health_component.max_health
			current_health = health_component.current_health

	footstep_audio.volume_db = 6.0
	attack_audio.volume_db = 8.0
	sfx_ui_player = AudioStreamPlayer.new()
	sfx_ui_player.bus = "Master"
	add_child(sfx_ui_player)

	
	if attributes:
		attributes.base_stats["move_speed"] = speed_walk
		
	# --- GENERACIÓN DE VIÑETA NEGRA (DAÑO) ---
	var canvas_vignette = CanvasLayer.new()
	canvas_vignette.layer = -1 
	damage_vignette = ColorRect.new()
	damage_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float vignette_intensity = 0.0; // Controlado por _update_damage_vignette (rango 0.0 a 1.0)
uniform float vignette_opacity : hint_range(0.0, 1.0) = 1.0;
uniform vec4 vignette_rgb : source_color = vec4(0.0, 0.0, 0.0, 1.0); 

float create_vignette(vec2 uv, float time) {
	vec2 center = uv - vec2(0.5);
	// Relación de aspecto brutalmente ancha para liberar espacio arriba/abajo y limpiar el centro
	center.x *= 1.777; 
	float dist = length(center);
	
	// TIEMPOS MÁS LENTOS (Pulsos relajados hasta el borde de la muerte)
	float cycle_duration = 2.0; // Por defecto a 50%
	
	// Intensidad mapea desde 0.0(50% vida) a 1.0(0% vida)
	if (vignette_intensity > 0.8) {
		cycle_duration = 0.6; // 10% Vida (Rápido pero no epiléptico)
	} else if (vignette_intensity > 0.6) {
		cycle_duration = 0.9; // 20% Vida
	} else if (vignette_intensity > 0.4) {
		cycle_duration = 1.3; // 30% Vida
	} else if (vignette_intensity > 0.2) {
		cycle_duration = 1.6; // 40% Vida
	}
	
	// Generamos el pulso de 0.0 a 1.0 basado en el tiempo exacto solicitado
	float time_factor = mod(time, cycle_duration) / cycle_duration;
	
	// Sinusoidal pura para latidos
	float pulse = (sin(time_factor * 6.28318) + 1.0) * 0.5; // Va de 0.0 a 1.0
	
	float beat_effect = pulse * (0.1 + (vignette_intensity * 0.3)); 
	
	// 'inner_edge' se empuja un poco más lejos para dejar el centro más limpio
	float inner_edge = clamp(0.7 - (vignette_intensity * 0.2) - beat_effect, 0.0, 0.9);
	float outer_edge = 1.0; 
	
	// 'smoothstep' normal más un exponente (pow) hace que la esquina se llene de NEGRO PURO 
	float v = smoothstep(inner_edge, outer_edge, dist);
	v = pow(v, 1.5); // Acentúa el contraste de los bordes (menos gris en el medio, mucho negro a los lados)
	
	return v;
}

void fragment() {
	float v = create_vignette(UV, TIME);
	v = clamp(v, 0.0, 1.0); // Protección extra contra colores locos
	// El rgb.rgb se mezcla al 100% de la fuerza 'v'
	COLOR = vec4(vignette_rgb.rgb, v * vignette_opacity);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = shader
	damage_vignette.material = mat
	damage_vignette.visible = false
	
	canvas_vignette.add_child(damage_vignette)
	add_child(canvas_vignette)
	# ----------------------------------------
			
	emit_signal("on_state_changed", "NORMAL")

func _process(delta: float) -> void:
	_actualizar_estabilizador_camara(delta)

func _actualizar_estabilizador_camara(delta: float) -> void:
	if not camera_stabilization_enabled:
		return
	if not head_mount:
		return
	if not _camera_stabilizer_ready:
		_camera_smoothed_pos = head_mount.global_position
		_camera_stabilizer_ready = true
		return

	var target_pos: Vector3 = head_mount.global_position

	# Si hubo un cambio grande (teleport/respawn), evitar arrastre visual.
	if _camera_smoothed_pos.distance_to(target_pos) > 3.0:
		_camera_smoothed_pos = target_pos
		head_mount.global_position = _camera_smoothed_pos
		return

	var follow_speed: float = maxf(camera_follow_speed, 0.01)
	var horizontal_alpha: float = clampf(follow_speed * delta, 0.0, 1.0)
	var vertical_alpha: float = clampf(follow_speed * maxf(camera_vertical_damping, 0.01) * delta, 0.0, 1.0)

	_camera_smoothed_pos.x = lerp(_camera_smoothed_pos.x, target_pos.x, horizontal_alpha)
	_camera_smoothed_pos.z = lerp(_camera_smoothed_pos.z, target_pos.z, horizontal_alpha)
	_camera_smoothed_pos.y = lerp(_camera_smoothed_pos.y, target_pos.y, vertical_alpha)

	var stability_blend: float = clampf(_camera_stability_blend, 0.0, 1.0)
	var final_pos: Vector3 = target_pos.lerp(_camera_smoothed_pos, stability_blend)
	head_mount.global_position = final_pos

func _on_stop_movement_camera_mode(active: bool, transition_time: float) -> void:
	var target_blend: float = 1.0

	if _camera_stability_tween:
		_camera_stability_tween.kill()

	var duration: float = maxf(transition_time, 0.01)
	_camera_stability_tween = create_tween()
	_camera_stability_tween.set_trans(Tween.TRANS_SINE)
	_camera_stability_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_stability_tween.tween_property(self, "_camera_stability_blend", target_blend, duration)

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
	if event.is_action_pressed("ulti"):
		var tipo = mask_manager.current_mask.mask_name if mask_manager and mask_manager.current_mask else "Sin máscara"
		print(tipo + " activo ulti")
		_intentar_activar_ulti()
	if event.is_action_pressed("usar_pocion_1"): usar_pocion(0)
	elif event.is_action_pressed("usar_pocion_2"): usar_pocion(1)
	elif event.is_action_pressed("usar_pocion_3"): usar_pocion(2)
	# DEBUG: Tecla N = +25 carga de ulti
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		if mask_manager: mask_manager.add_charge(25.0)

# ------------------------------------------------------------------------------
# 3. FÍSICAS Y LÓGICA
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead: return
	# ed = delta real compensado: cuando el ulti de tiempo está activo el player
	# usa delta sin escalar para moverse a velocidad normal.
	var ed: float = delta / Engine.time_scale if _time_ulti_active else delta

	_apply_shake(ed)
	_procesar_modificadores_combate(ed)

	if is_on_floor() and (abs(velocity.x) > 0.1 or abs(velocity.z) > 0.1):
		if not footstep_audio.playing and footstep_sounds.size() > 0:
			footstep_audio.stream = footstep_sounds.pick_random()
			footstep_audio.play()
	else:
		footstep_audio.stop()
	# Gravedad
	if not is_on_floor():
		velocity.y -= (gravity * gravity_multiplier) * ed
		was_in_air = true
	elif was_in_air:
		was_in_air = false
		refrescar_animacion_aterrizaje()

	# Knockback (Con control parcial del jugador)
	if knockback_velocity.length() > 2.5: # ⚡ 2.5 y NO 0.5 para cortar en seco ese desliz baboso
		var friction = 20.0 if is_on_floor() else 2.5 # Fricción brutal en el suelo para frenar el "patinaje"
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, friction * delta)
		
		# Leer el input del jugador para darle "Air Strafe" (Luchar contra el empuje)
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var player_resistance = dir * speed_walk # 100% de fuerza para contra-restar
		
		velocity.x = knockback_velocity.x + player_resistance.x
		velocity.z = knockback_velocity.z + player_resistance.z
		move_and_slide()
		return
	else:
		# ¡Restaurar la velocidad total instantaneamente para liberar al jugador!
		knockback_velocity = Vector3.ZERO

	# Estados Bloqueantes
	if current_state == State.DODGING: procesar_dodge(ed); return
	if current_state == State.DIVING: procesar_dive(ed); return

	if combat_manager.is_movement_locked:
		velocity.x = move_toward(velocity.x, 0, 20.0 * ed)
		velocity.z = move_toward(velocity.z, 0, 20.0 * ed)
		_cms()
		actualizar_blendspaces(Vector2.ZERO, ed)
		return

	# Movimiento
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	controlar_inputs_postura(ed, input_dir.y > 0)

	if current_state == State.DODGING or current_state == State.DIVING: return

	if current_state == State.SPRINT:
		sprint_timer = min(sprint_timer + ed, MAX_MOMENTUM_TIME)
	else:
		sprint_timer = 0.0

	procesar_movimiento_normal(ed, input_dir)
	actualizar_blendspaces(input_dir, ed)

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
		State.SPRINT: 
			final_speed *= speed_sprint_mult
			if input_dir.y > 0: # Corriendo hacia atrás (+Y en Vector2 del joystick/teclado)
				final_speed *= 0.5 
		State.CROUCH: final_speed *= 0.5
		State.PRONE: final_speed *= 0.3
	
	var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if dir:
		velocity.x = dir.x * final_speed
		velocity.z = dir.z * final_speed
	else:
		velocity.x = move_toward(velocity.x, 0, final_speed)
		velocity.z = move_toward(velocity.z, 0, final_speed)
	_cms()

# ------------------------------------------------------------------------------
# ESTADOS
# ------------------------------------------------------------------------------
func controlar_inputs_postura(delta, moving_back): 
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match current_state:
			State.PRONE: cambiar_estado(State.CROUCH)
			State.CROUCH: cambiar_estado(State.NORMAL)
			State.NORMAL, State.SPRINT:
				if is_on_floor():
					if stamina.try_consume(15):
						velocity.y = jump_force * mask_jump_mult 
						state_machine.travel("Jump_Start")
					else:
						show_toast("Stamina required!", Color(1.0, 0.55, 0.1))
		return
	
	if Input.is_action_just_pressed("dodge") and can_dodge and is_on_floor():
		iniciar_dodge()
		return
	
	var is_moving = velocity.x != 0 or velocity.z != 0
	var aiming_block = combat_manager.is_aiming
	
	if Input.is_action_pressed("sprint") and is_on_floor() and current_state == State.NORMAL and is_moving and not aiming_block:
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

# Compensa Engine.time_scale en move_and_slide para que el player no se ralentice
# durante el ulti de tiempo. Infla velocity antes y la restaura después.
func _cms() -> void:
	if _time_ulti_active:
		velocity /= Engine.time_scale
	move_and_slide()
	if _time_ulti_active:
		velocity *= Engine.time_scale
	
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
	_cms()
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
	_cms()
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

func _intentar_activar_ulti() -> void:
	if not mask_manager or not mask_manager.current_mask: return
	if mask_manager.current_ult_charge < mask_manager.max_ult_charge:
		show_toast("Ultimate not ready!", Color(0.5, 0.2, 1.0))
		return
	var mask_name_lower = mask_manager.current_mask.mask_name.to_lower()
	mask_manager.activate_ultimate()
	_play_sfx_ui(SOUND_ULTI)
	if mask_name_lower.contains("fighter"):
		combat_manager.ejecutar_animacion_ulti("Melee_2H_Attack_Spin", 2.0)
		_mostrar_area_fighter_ulti(2.0)
		_aplicar_dano_area_fighter_ulti()
	if mask_name_lower.contains("time") or mask_name_lower.contains("tiempo"):
		_activar_ulti_tiempo(5.0)
	if mask_name_lower.contains("undead") or mask_name_lower.contains("muerto"):
		_activar_ulti_undead()
	if mask_name_lower.contains("shooter") or mask_name_lower.contains("tirador"):
		_activar_ulti_shooter()

func _activar_ulti_undead() -> void:
	const NUM_SKELETONS  := 3
	const SUMMON_RADIUS  := 3.5
	const SKELETON_SCENE := "res://src/actors/enemies/Skeleton_Minion.tscn"

	# ── 1. Círculo de invocación ──────────────────────────────────────
	var ring := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius     = SUMMON_RADIUS
	cyl.bottom_radius  = SUMMON_RADIUS
	cyl.height         = 0.04
	cyl.radial_segments = 80
	ring.mesh = cyl
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color   = Color(0.5, 0.0, 0.9, 0.55)
	ring_mat.emission_enabled = true
	ring_mat.emission       = Color(0.55, 0.0, 1.0)
	ring_mat.emission_energy = 3.0
	ring_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.cull_mode      = BaseMaterial3D.CULL_DISABLED
	ring.material_override  = ring_mat
	ring.scale = Vector3.ZERO
	add_child(ring)
	ring.position = Vector3(0.0, 0.05, 0.0)

	# Escalar hacia afuera rápido
	var t_ring := create_tween()
	t_ring.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_ring.tween_property(ring, "scale", Vector3.ONE, 0.35)

	await get_tree().create_timer(0.4).timeout

	# ── 2. Invocar esqueletos en círculo ─────────────────────────────
	var scene: PackedScene = load(SKELETON_SCENE)
	if not scene:
		push_warning("AlliedSkeleton: no se encontró la escena en " + SKELETON_SCENE)
		ring.queue_free()
		return

	for i in NUM_SKELETONS:
		var angle: float = (TAU / NUM_SKELETONS) * i
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * SUMMON_RADIUS

		var ally: Node = scene.instantiate()
		# Reemplaza el script Enemy por AlliedSkeleton
		ally.set_script(load("res://src/actors/enemies/AlliedSkeleton.gd"))
		get_tree().current_scene.add_child(ally)
		ally.global_position = global_position + offset
		ally.global_position.y = global_position.y

		# Asignar referencia al jugador para que no nos ataque
		if "player_ref" in ally:
			ally.player_ref = self

		# Invulnerabilidad al player: cambiamos capas DESPUÉS del _ready
		ally.collision_layer = 64
		ally.collision_mask  = 4

		# Tiempo de vida: cuando acabe el ulti se auto-destruyen
		if "lifetime" in ally:
			ally.lifetime = mask_manager.current_mask.ultimate_duration

		# Partícula de aparición sencilla (flash morado)
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.6, 0.0, 1.0)
		flash.light_energy = 8.0
		flash.omni_range = 3.0
		ally.add_child(flash)
		var t_flash := create_tween()
		t_flash.tween_property(flash, "light_energy", 0.0, 0.5)
		t_flash.tween_callback(flash.queue_free)

		# Pequeño stagger de spawn para que no aparezcan todos a la vez
		await get_tree().create_timer(0.08).timeout

	# ── 3. Disolver el círculo ────────────────────────────────────────
	var t_out := create_tween()
	t_out.tween_property(ring_mat, "albedo_color:a", 0.0, 0.5)
	await t_out.finished
	ring.queue_free()

func _activar_ulti_tiempo(duracion: float) -> void:
	const SLOW := 0.12
	_time_ulti_active = true
	Engine.time_scale = SLOW
	# NOTA: NO se cambia process_mode → el menú radial puede pausar normalmente

	# ── UI ────────────────────────────────────────────────────────────
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader : Shader = load("res://src/actors/player/time_ulti_overlay.gdshader")
	var smat := ShaderMaterial.new()
	smat.shader = shader
	smat.set_shader_parameter("strength", 0.0)
	overlay.material = smat
	canvas.add_child(overlay)

	var bar_container := VBoxContainer.new()
	bar_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar_container.offset_top    = -72.0
	bar_container.offset_bottom = -16.0
	bar_container.offset_left   = 220.0
	bar_container.offset_right  = -220.0
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(bar_container)

	var lbl := Label.new()
	lbl.text = "⏳ TIEMPO DETENIDO"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.modulate = Color(0.3, 0.9, 1.0, 1.0)
	bar_container.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.custom_minimum_size = Vector2(0.0, 14.0)
	bar.modulate = Color(0.1, 0.7, 1.0, 0.9)
	bar_container.add_child(bar)

	var t_in := create_tween()
	t_in.tween_method(func(v: float): smat.set_shader_parameter("strength", v), 0.0, 1.0, 0.05)

	# ── Cuenta atrás con tiempo REAL de pared ────────────────────────
	# Time.get_ticks_msec() es inmune a Engine.time_scale.
	# Cap de 100ms por frame evita saltos al cerrar el menú radial.
	# Si el menú está abierto (paused) la barra se congela.
	var elapsed_ms: int = 0
	var last_ms: int = Time.get_ticks_msec()
	var duration_ms: int = int(duracion * 1000.0)

	while elapsed_ms < duration_ms:
		await get_tree().process_frame
		var now: int = Time.get_ticks_msec()
		var frame_ms: int = mini(now - last_ms, 100)
		last_ms = now
		if not get_tree().paused:
			elapsed_ms += frame_ms
		var ratio: float = 1.0 - clamp(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		bar.value = ratio
		if elapsed_ms > duration_ms - 1000:
			var blink: float = sin(float(elapsed_ms) * 0.02) * 0.5 + 0.5
			bar.modulate = Color(1.0, blink * 0.3 + 0.1, 0.1, 0.9)
			lbl.text = "⚡ TIEMPO REGRESANDO..."
			lbl.modulate = Color(1.0, 0.5 + blink * 0.5, 0.1, 1.0)

	# ── Restaurar ─────────────────────────────────────────────────────
	_time_ulti_active = false
	Engine.time_scale = 1.0

	var t_out := create_tween()
	t_out.tween_method(func(v: float): smat.set_shader_parameter("strength", v), 1.0, 0.0, 0.35)
	await t_out.finished
	canvas.queue_free()

func _aplicar_dano_area_fighter_ulti() -> void:
	# Pequeño windup antes del golpe (mitad de la animación)
	await get_tree().create_timer(0.35).timeout

	var radio := 6.0
	var damage_ulti := 50.0
	if combat_manager and combat_manager.weapon_r:
		damage_ulti = combat_manager.weapon_r.damage * 2.5 * combat_manager.damage_multiplier

	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = radio
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = global_transform
	params.exclude = [get_rid()]

	var hits := space.intersect_shape(params, 32)
	for hit in hits:
		var body = hit.get("collider")
		if not body or body == self: continue

		# Daño
		if body.has_method("take_damage"):
			body.take_damage(damage_ulti)
		elif body.has_node("HealthComponent"):
			body.get_node("HealthComponent").take_damage(damage_ulti)

		# Expulsión hacia afuera del centro
		if body.has_method("apply_knockback"):
			var dir: Vector3 = (body.global_position - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			body.apply_knockback(dir, 20.0, 7.0)

func _mostrar_area_fighter_ulti(duracion: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius     = 6.0
	cylinder.bottom_radius  = 6.0
	cylinder.height         = 0.04
	cylinder.radial_segments = 96
	mesh_inst.mesh = cylinder

	var shader : Shader = load("res://src/actors/player/fighter_ulti_area.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mesh_inst.material_override = mat

	add_child(mesh_inst)
	mesh_inst.position = Vector3(0.0, 0.05, 0.0)

	# Fade in via scale (el shader es aditivo, escalamos el nodo)
	mesh_inst.scale = Vector3.ZERO
	var t_in := create_tween()
	t_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_in.tween_property(mesh_inst, "scale", Vector3.ONE, 0.2)

	await get_tree().create_timer(duracion - 0.4).timeout

	# Fade out via scale
	var t_out := create_tween()
	t_out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t_out.tween_property(mesh_inst, "scale", Vector3.ZERO, 0.4)
	await t_out.finished
	mesh_inst.queue_free()

# ------------------------------------------------------------------------------
# ULTIMATE: SHOOTER — AUTO-LASER
# ------------------------------------------------------------------------------
func _activar_ulti_shooter() -> void:
	const LASER_RADIUS   := 12.0   # radio reducido
	const FIRE_INTERVAL  := 0.5    # segundos entre salvas
	const MAX_TARGETS    := 2      # objetivos simultáneos por salva
	const DAMAGE_PER_HIT := 10.0   # daño base por impacto

	var damage_scaled := DAMAGE_PER_HIT
	if combat_manager:
		damage_scaled = DAMAGE_PER_HIT * combat_manager.damage_multiplier

	# ── 1. Disco de área en el suelo ─────────────────────────────────
	var area_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius      = LASER_RADIUS
	disc.bottom_radius   = LASER_RADIUS
	disc.height          = 0.04
	disc.radial_segments = 128
	area_mesh.mesh = disc
	var area_shader : Shader = load("res://src/actors/player/shooter_ulti_area.gdshader")
	var area_mat := ShaderMaterial.new()
	area_mat.shader = area_shader
	area_mesh.material_override = area_mat
	add_child(area_mesh)
	area_mesh.position = Vector3(0.0, 0.05, 0.0)
	area_mesh.scale = Vector3.ZERO
	var t_in := create_tween()
	t_in.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t_in.tween_property(area_mesh, "scale", Vector3.ONE, 0.3)

	# ── 2. HUD de duración ───────────────────────────────────────────
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var bar_container := VBoxContainer.new()
	bar_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar_container.offset_top    = -72.0
	bar_container.offset_bottom = -16.0
	bar_container.offset_left   = 220.0
	bar_container.offset_right  = -220.0
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	canvas.add_child(bar_container)

	var lbl := Label.new()
	lbl.text = "⚡ AUTO-LASER"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.modulate = Color(0.0, 1.0, 0.9, 1.0)
	bar_container.add_child(lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value     = 1.0
	bar.custom_minimum_size = Vector2(0.0, 12.0)
	bar.modulate = Color(0.0, 0.9, 1.0, 0.9)
	bar_container.add_child(bar)

	# ── 3. Luz ambiental tenue mientras dure ─────────────────────────
	var ambient_light := OmniLight3D.new()
	ambient_light.light_color  = Color(0.0, 0.85, 1.0)
	ambient_light.light_energy = 1.2
	ambient_light.omni_range   = LASER_RADIUS * 0.6
	add_child(ambient_light)
	ambient_light.position = Vector3.ZERO

	# ── 4. Loop de disparo automático ────────────────────────────────
	var elapsed_ms: int = 0
	var last_ms: int    = Time.get_ticks_msec()
	var duration_ms: int = int(5.0 * 1000.0)  # 5 segundos fijos

	while elapsed_ms < duration_ms and mask_manager and mask_manager.is_ultimate_active:
		await get_tree().create_timer(FIRE_INTERVAL).timeout
		var now: int      = Time.get_ticks_msec()
		elapsed_ms       += now - last_ms
		last_ms           = now

		var ratio: float = 1.0 - clamp(float(elapsed_ms) / float(duration_ms), 0.0, 1.0)
		bar.value = ratio
		if ratio < 0.25:
			var blink := sin(float(elapsed_ms) * 0.025) * 0.5 + 0.5
			bar.modulate  = Color(0.3, 1.0 - blink * 0.5, blink * 0.5 + 0.5, 0.9)
			lbl.text      = "⚡ RECARGANDO..."
			lbl.modulate  = Color(1.0, 0.6 + blink * 0.4, 0.1, 1.0)

		if not (mask_manager and mask_manager.is_ultimate_active): break

		var targets := _shooter_buscar_targets(LASER_RADIUS, MAX_TARGETS)
		for tgt in targets:
			_shooter_disparar_laser(tgt, damage_scaled)

	# ── 5. Limpieza ───────────────────────────────────────────────────
	var t_out := create_tween()
	t_out.tween_property(area_mesh, "scale", Vector3.ZERO, 0.35)
	t_out.parallel().tween_property(lbl, "modulate:a", 0.0, 0.35)
	t_out.parallel().tween_property(bar_container, "modulate:a", 0.0, 0.35)
	t_out.parallel().tween_property(ambient_light, "light_energy", 0.0, 0.35)
	await t_out.finished
	area_mesh.queue_free()
	ambient_light.queue_free()
	canvas.queue_free()

func _shooter_buscar_targets(radio: float, max_count: int) -> Array:
	var space  := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = radio
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape           = sphere
	params.transform       = global_transform
	params.collision_mask  = 0xFFFFFFFF  # detectar todas las capas
	params.exclude         = [get_rid()]
	var hits := space.intersect_shape(params, 64)

	var candidatos: Array = []
	var vistos: Array = []  # evitar duplicados
	for hit in hits:
		var body = hit.get("collider")
		if not body or body == self or body in vistos: continue
		if body.is_in_group("Player") or body.is_in_group("allied_skeleton"): continue
		# Aceptar cualquier cuerpo que pueda recibir daño
		if not (body.has_method("take_damage") or body.has_node("HealthComponent")): continue
		# Descartar si ya muerto
		if body.has_node("HealthComponent"):
			var hc = body.get_node("HealthComponent")
			if "current_health" in hc and hc.current_health <= 0: continue
		vistos.append(body)
		candidatos.append(body)

	candidatos.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	return candidatos.slice(0, max_count)

func _shooter_disparar_laser(target: Node3D, damage: float) -> void:
	# ── Daño ─────────────────────────────────────────────────────────
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage(damage)

	# ── Visual del rayo ───────────────────────────────────────────────
	var origin := global_position + Vector3(0.0, 1.2, 0.0)
	var dest   := target.global_position + Vector3(0.0, 1.0, 0.0)
	var diff   := dest - origin
	var length := diff.length()
	if length < 0.3: return
	var dir := diff / length

	# Construir base: Y local apunta en 'dir' (eje del CylinderMesh)
	var ref_up := Vector3.UP
	if abs(dir.dot(ref_up)) > 0.98:
		ref_up = Vector3.RIGHT
	var x_axis := ref_up.cross(dir).normalized()
	var z_axis := x_axis.cross(dir).normalized()

	var beam := MeshInstance3D.new()
	var cyl  := CylinderMesh.new()
	cyl.top_radius      = 0.055
	cyl.bottom_radius   = 0.055
	cyl.height          = length
	cyl.radial_segments = 8
	beam.mesh = cyl

	var laser_mat := ShaderMaterial.new()
	laser_mat.shader = load("res://src/actors/player/shooter_laser_beam.gdshader")
	laser_mat.set_shader_parameter("alpha_mult", 1.0)
	beam.material_override = laser_mat

	get_tree().current_scene.add_child(beam)
	beam.global_transform = Transform3D(Basis(x_axis, dir, z_axis), (origin + dest) * 0.5)

	# Luz de impacto en el objetivo
	var impact := OmniLight3D.new()
	impact.light_color  = Color(0.0, 0.9, 1.0)
	impact.light_energy = 9.0
	impact.omni_range   = 4.5
	beam.add_child(impact)
	impact.global_position = dest

	# Fade out → destruir (lambda en variable para evitar problemas de parseo)
	var _lmat := laser_mat
	var _beam := beam
	var fade_fn := func(v: float):
		if is_instance_valid(_lmat): _lmat.set_shader_parameter("alpha_mult", v)
	var t := create_tween()
	t.tween_method(fade_fn, 1.0, 0.0, 0.22)
	t.parallel().tween_property(impact, "light_energy", 0.0, 0.18)
	t.tween_callback(_beam.queue_free)

func take_damage(amount: float):
	add_camera_trauma(0.6) # Tiembla la pantalla al recibir daño bruto
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
	
	# Transición suave a negro
	var death_canvas = CanvasLayer.new()
	death_canvas.layer = 100 # Por encima de todos los HUDs y menús
	var black_screen = ColorRect.new()
	black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_screen.color = Color(0, 0, 0, 0)
	death_canvas.add_child(black_screen)
	get_tree().current_scene.add_child(death_canvas)
	
	var death_cam = Camera3D.new()
	get_tree().current_scene.add_child(death_cam)
	death_cam.global_transform = camera.global_transform
	death_cam.current = true; camera.visible = false 
	
	var t = create_tween()
	t.tween_property(death_cam, "global_position:y", death_cam.global_position.y + 3.0, 3.0).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(death_cam, "rotation_degrees:x", -90.0, 2.5)
	
	# Oscurecer progresivamente toda la pantalla a negro absoluto en los 4 segundos
	t.parallel().tween_property(black_screen, "color:a", 1.0, 3.8)
	
	await get_tree().create_timer(4.0).timeout
	death_cam.queue_free()
	death_canvas.queue_free()
	get_tree().reload_current_scene()

# --- UI CONNECTIONS ---
signal vida_cambiada(nueva_vida)
signal mana_cambiado(nuevo_mana, max_mana)
signal stamina_cambiada(nueva_stamina, max_stamina)
signal pociones_cambiadas(slot_index, cantidad)
signal ulti_cambiada(nueva_carga, max_carga)
signal mascara_cambiada(mask_data) 

var pociones_ui = [10, 10, 10] 

func _ready_ui_connections():
	vida_cambiada.connect(_update_damage_vignette)
	
	if health_component:
		health_component.on_damage_received.connect(func(_amt, curr): emit_signal("vida_cambiada", curr))
		emit_signal("vida_cambiada", health_component.current_health)

func _update_damage_vignette(curr_hp: float):
	if not damage_vignette or not damage_vignette.material: return
	var max_hp = max_health if max_health > 0 else 100.0
	var percent = curr_hp / max_hp
	
	if percent <= 0.5:
		damage_vignette.visible = true
		# Entre 0.5 y 0.0 de vida, la intensidad va de 0.0 a 1.0
		var danger_level = (0.5 - percent) * 2.0 
		
		# Opacidad máxima es 1.0 (Bordes totalmente oscuros)
		damage_vignette.material.set_shader_parameter("vignette_opacity", danger_level * 1.0)
		# Acelera y expande el latido
		damage_vignette.material.set_shader_parameter("vignette_intensity", danger_level * 1.0)
	else:
		damage_vignette.visible = false
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
			_play_sfx_ui(SOUND_HEALTH_POTION)
		elif index == 1:
			var mana_comp = get_node_or_null("ManaComponent")
			if mana_comp and "current_value" in mana_comp:
				mana_comp.current_value = min(mana_comp.current_value + 50.0, mana_comp.max_value)
				mana_comp.on_value_changed.emit(mana_comp.current_value, mana_comp.max_value)
			_play_sfx_ui(SOUND_MAGIC_POTION)
		elif index == 2:
			if stamina and "current_value" in stamina:
				stamina.current_value = min(stamina.current_value + 50.0, stamina.max_value)
				stamina.on_value_changed.emit(stamina.current_value, stamina.max_value)
			_play_sfx_ui(SOUND_STAMINA_POTION)
		emit_signal("pociones_cambiadas", index + 1, pociones_ui[index])
	else:
		show_toast("You don't have that potion!", Color(1.0, 0.4, 0.1))

func _play_sfx_ui(stream: AudioStream) -> void:
	if not sfx_ui_player: return
	sfx_ui_player.stream = stream
	sfx_ui_player.play()
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
		print("🔍 Player: Intentando cargar icono: ", icon_path)
		if ResourceLoader.exists(icon_path):
			icon_texture = load(icon_path)
			print("✅ Player: Icono cargado exitosamente")
		else:
			print("❌ Player: No se encontró el icono en: ", icon_path)
	
	# Buscar el HUD2 que es hijo del player (el HUD visible)
	var hud = get_node_or_null("HUD2")
	if not hud:
		# Si no existe HUD2, buscar en el root como fallback
		hud = get_tree().root.find_child("HUD", true, false)
	
	if hud:
		print("✅ Player: HUD encontrado")
		if hud.has_node("GameUI/StatsPanel"):
			var stats_panel = hud.get_node("GameUI/StatsPanel")
			print("✅ Player: StatsPanel encontrado")
			if stats_panel.has_method("update_life_icons_texture"):
				stats_panel.update_life_icons_texture(icon_texture)
				print("🎭 Player: Iconos de vida actualizados para máscara: ", mask_name)
			else:
				print("❌ Player: StatsPanel no tiene método update_life_icons_texture")
		else:
			print("❌ Player: No se encontró GameUI/StatsPanel en HUD")
	else:
		print("❌ Player: No se encontró el HUD2 ni el HUD en la escena")

func _play_attack_sound():
	if attack_sounds.is_empty():
		return

	attack_audio.stream = attack_sounds.pick_random()
	attack_audio.pitch_scale = randf_range(0.95, 1.05)
	attack_audio.play()
