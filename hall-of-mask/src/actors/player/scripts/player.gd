extends CharacterBody3D

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
@onready var distortion: ColorRect = $ColorRect
@onready var distortion_mat: ShaderMaterial = distortion.material
var transitioning := false

# --- CONFIGURACIÓN FÍSICA ---
@export_category("Movimiento Base")
@export var speed_walk: float = 5.0
@export var jump_force: float = 9.0 
@export var gravity_multiplier: float = 2.0 

@export_category("Evasión (Dodge & Dive)")
@export var dodge_power: float = 15.0 
@export var dodge_cost: float = 15.0

# --- FUSIÓN DE MECÁNICAS ---
## Penalizador base: El Dive tendrá como MÁXIMO este % de fuerza del Dodge.
## (0.8 = El dive llega al 80% de lejos que un dodge normal).
@export var dive_sprint_damp: float = 0.8

# --- CONFIGURACIÓN DE MOMENTO (NUEVO) ---
# Tiempo necesario corriendo para alcanzar el 100% de impulso
const MAX_MOMENTUM_TIME: float = 0.9 
# Impulso mínimo al empezar a correr (0.1 = 10%)
const MIN_MOMENTUM_MULT: float = 0.1 

# --- MULTIPLICADORES DE MÁSCARA ---
var mask_speed_mult: float = 1.0
var mask_jump_mult: float = 1.0
var mask_defense_mult: float = 1.0:
	set(value):
		mask_defense_mult = value
		if health_component: health_component.defense_multiplier = value

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
var sprint_timer: float = 0.0 # Cronómetro para calcular el impulso
var was_in_air: bool = false
var can_dodge: bool = true 

# Estados
enum State { NORMAL, SPRINT, CROUCH, PRONE, DODGING, DIVING, DEAD }
var current_state: State = State.NORMAL

signal on_state_changed(new_state_name)

const PATH_STANDING = "parameters/StateMachine/Standing/blend_position"
const PATH_SNEAKING = "parameters/StateMachine/Sneaking/blend_position"
const PATH_CRAWLING = "parameters/StateMachine/Crawling/blend_position"
const PATH_DODGE    = "parameters/StateMachine/Dodge/blend_position"
var smooth_blend: Vector2 = Vector2.ZERO
var blend_speed: float = 10.0

func start_distortion_transition(duration: float = 1.0) -> void:
	if transitioning:
		return

	transitioning = true

	set_physics_process(false)
	set_process(false)

	distortion.visible = true
	distortion_mat.set_shader_parameter("strength", 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		distortion_mat,
		"shader_parameter/strength",
		1.0,
		duration
	)



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

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_cam_pitch -= event.relative.y * MOUSE_SENSITIVITY
		_cam_pitch = clamp(_cam_pitch, deg_to_rad(-55.0), deg_to_rad(70.0))
		camera.rotation.x = _cam_pitch
		rotar_columna_hacia_camara()
	
	if event.is_action_pressed("ui_cancel"): 
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				combat_manager.try_attack("right")
			elif event.button_index == MOUSE_BUTTON_LEFT:
				combat_manager.try_attack("left")
	
	
	#COMENTADO PRUEBA DE ARMAS EN BOTONES EN PLAYER
	
	#if event is InputEventKey and event.pressed:
	#	var tab = Input.is_physical_key_pressed(KEY_TAB)
	#	var mano = "left" if tab else "right"
	#	if mano == "right" and combat_manager.is_attacking_r: return
	#	if mano == "left" and combat_manager.is_attacking_l: return

	#	match event.keycode:
	#		KEY_1: combat_manager.unequip_weapon(mano)
	#		KEY_2: if combat_manager.slot_2: combat_manager.equip_weapon(combat_manager.slot_2, mano)
	#		KEY_3: if combat_manager.slot_3: combat_manager.equip_weapon(combat_manager.slot_3, mano)
	#		KEY_4: if combat_manager.slot_4: combat_manager.equip_weapon(combat_manager.slot_4, mano)

# ------------------------------------------------------------------------------
# 3. FÍSICAS
# ------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if is_dead: return 

	# 0. Gravedad
	if not is_on_floor():
		velocity.y -= (gravity * gravity_multiplier) * delta
		was_in_air = true
	elif was_in_air:
		was_in_air = false
		refrescar_animacion_aterrizaje()

	# 1. Empuje (Knockback)
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 15.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	# 2. Estados Bloqueantes
	if current_state == State.DODGING: procesar_dodge(delta); return
	if current_state == State.DIVING: procesar_dive(delta); return
	
	# 3. Ataque Congelado
	if combat_manager.is_movement_locked:
		velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
		move_and_slide()
		actualizar_blendspaces(Vector2.ZERO, delta)
		return 
	
	# 4. Inputs y Estados
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Detectar cambios (Sprint, Dive, Crouch)
	controlar_inputs_postura(delta, input_dir.y > 0)
	
	# Seguridad: Si cambiamos a Dodge/Dive, no caminar
	if current_state == State.DODGING or current_state == State.DIVING:
		return 
	
	# 5. Lógica del Timer de Momento (Sprint)
	if current_state == State.SPRINT:
		# Aumentamos el contador hasta llegar al tope (0.9s)
		sprint_timer = min(sprint_timer + delta, MAX_MOMENTUM_TIME)
	else:
		# Si dejamos de correr, perdemos el impulso instantáneamente (o podrías hacerlo gradual)
		sprint_timer = 0.0

	# 6. Moverse
	procesar_movimiento_normal(delta, input_dir)
	actualizar_blendspaces(input_dir, delta)

# ------------------------------------------------------------------------------
# 4. CONTROL DE ESTADOS
# ------------------------------------------------------------------------------
func controlar_inputs_postura(delta, moving_back): 
	# --- SALTO ---
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		match current_state:
			State.PRONE: cambiar_estado(State.CROUCH)
			State.CROUCH: cambiar_estado(State.NORMAL)
			State.NORMAL, State.SPRINT:
				if is_on_floor() and stamina.try_consume(15):
					velocity.y = jump_force * mask_jump_mult 
					state_machine.travel("Jump_Start")
		return
	
	# --- DODGE ---
	if Input.is_action_just_pressed("dodge") and can_dodge and is_on_floor():
		iniciar_dodge()
		return
	
	# --- SPRINT ---
	var is_moving = velocity.x != 0 or velocity.z != 0
	
	if Input.is_action_pressed("sprint") and is_on_floor() and not moving_back and current_state == State.NORMAL and is_moving:
		cambiar_estado(State.SPRINT)
	
	if current_state == State.SPRINT:
		if not Input.is_action_pressed("sprint") or not is_moving:
			cambiar_estado(State.NORMAL)
		else:
			if not stamina.try_consume(10 * delta):
				cambiar_estado(State.NORMAL) 

	# --- INPUT DE AGACHARSE (Dual: Dive vs Crouch) ---
	
	# CASO 1: PRESIONAR (Just Pressed)
	if Input.is_action_just_pressed("crouch"):
		# SOLO si estamos corriendo, iniciamos el DIVE
		if current_state == State.SPRINT:
			iniciar_dive()
			return # Importante: salir para no procesar el crouch normal abajo

	# CASO 2: MANTENER (Hold) para ir al suelo (Prone)
	# Solo funciona si NO estamos corriendo (si corremos, ya nos tiramos en el paso anterior)
	if Input.is_action_pressed("crouch") and current_state != State.SPRINT:
		crouch_pressed_time += delta
		if crouch_pressed_time > TIME_TO_PRONE:
			if current_state != State.PRONE: cambiar_estado(State.PRONE)
	
	# CASO 3: SOLTAR (Release) para alternar Crouch/Stand
	elif Input.is_action_just_released("crouch"):
		# Solo si fue un toque rápido y no un dive
		if crouch_pressed_time <= TIME_TO_PRONE and current_state != State.DIVING:
			if current_state == State.CROUCH: cambiar_estado(State.NORMAL)
			elif current_state != State.PRONE: cambiar_estado(State.CROUCH)
		crouch_pressed_time = 0.0

func procesar_movimiento_normal(delta, input_dir):
	var base_spd = speed_walk
	if attributes and attributes.has_method("get_stat"):
		base_spd = attributes.get_stat("move_speed")
	
	var final_speed = base_spd * mask_speed_mult
	
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
# 5. SISTEMAS DE EVASIÓN
# ------------------------------------------------------------------------------
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

# --- DIVE (Con Momento Realista) ---
func iniciar_dive():
	if not stamina.try_consume(dodge_cost): return
	
	current_state = State.DIVING
	dive_timer = 0.0
	emit_signal("on_state_changed", "DIVING")
	
	# 1. Dirección: Basada en INPUT, no solo en hacia donde miro
	# Esto permite correr adelante y tirarse hacia la izquierda si cambias rápido
	var i = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Si no hay input (raro si corres), usamos hacia donde miramos
	var d = Vector3.ZERO
	if i != Vector2.ZERO:
		d = (transform.basis * Vector3(i.x, 0, i.y)).normalized()
	else:
		d = -transform.basis.z 
	
	# 2. CÁLCULO DE MOMENTO (REALISMO)
	# Calculamos el porcentaje de carga (0.0 a 1.0)
	var momentum_percent = clamp(sprint_timer / MAX_MOMENTUM_TIME, 0.0, 1.0)
	
	# Interpolamos entre el mínimo (10%) y el máximo (100%)
	# lerp(min, max, weight)
	var impulso_final = lerp(MIN_MOMENTUM_MULT, 1.0, momentum_percent)
	
	# Aplicamos al poder total
	var fuerza_dive = dodge_power * impulso_final * dive_sprint_damp
	
	print("🚀 DIVE! Tiempo carga: ", snapped(sprint_timer, 0.01), "s | Impulso: ", int(impulso_final * 100), "%")
	
	velocity = d * fuerza_dive
	velocity.y = 5.0 # Salto vertical constante para la parábola
	
	state_machine.travel("Jump_Start") 
	
	await get_tree().create_timer(0.2).timeout
	if current_state == State.DIVING: state_machine.travel("Crawling")
	
func procesar_dive(delta):
	if not is_on_floor(): 
		velocity.y -= (gravity * gravity_multiplier) * delta
	
	velocity.x = move_toward(velocity.x, 0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 5.0 * delta)
	move_and_slide()
	dive_timer += delta
	
	if is_on_floor() and dive_timer > 0.3: 
		cambiar_estado(State.PRONE)

# ------------------------------------------------------------------------------
# 6. UTILIDADES Y DAÑO
# ------------------------------------------------------------------------------
func cambiar_estado(nuevo):
	if current_state == nuevo: return
	current_state = nuevo
	
	match current_state:
		State.NORMAL, State.SPRINT: state_machine.travel("Standing")
		State.CROUCH: state_machine.travel("Sneaking")
		State.PRONE:  state_machine.travel("Crawling")
	
	var state_names = {
		State.NORMAL: "NORMAL", State.SPRINT: "CORRIENDO", State.CROUCH: "AGACHADO",
		State.PRONE: "SUELO", State.DODGING: "ESQUIVA", State.DIVING: "SALTO", State.DEAD: "MUERTO"
	}
	emit_signal("on_state_changed", state_names.get(current_state, "UNKNOWN"))

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

func apply_knockback(dir: Vector3, force: float, up_force: float = 2.0):
	if is_dead: return
	knockback_velocity = dir * force
	if is_on_floor(): velocity.y = up_force 

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

# ==============================================================================
# SECCIÓN UI INYECTADA (NO MODIFICAR LÓGICA CORE)
# ==============================================================================

# --- SEÑALES PARA HUD ---
signal vida_cambiada(nueva_vida)
signal mana_cambiado(nuevo_mana, max_mana)
signal stamina_cambiada(nueva_stamina, max_stamina)
signal pociones_cambiadas(slot_index, cantidad)
signal ulti_cambiada(nueva_carga, max_carga)
signal mascara_cambiada(mask_data) # Nueva para el icono grande

# --- VARIABLES UI ---
var pociones_ui = [3, 1, 0] # Inventario interno de pociones

# --- INICIALIZACIÓN DE CONEXIONES UI ---
func _ready_ui_connections():
	# 1. VIDA
	if health_component:
		health_component.on_damage_received.connect(func(_amt, curr): emit_signal("vida_cambiada", curr))
		# Emitir estado inicial
		emit_signal("vida_cambiada", health_component.current_health)

	# 2. STAMINA
	if stamina:
		stamina.on_value_changed.connect(func(curr, max_val): emit_signal("stamina_cambiada", curr, max_val))
		# Emitir estado inicial (Asumiendo que stamina tiene current_value accesible)
		if "current_value" in stamina:
			emit_signal("stamina_cambiada", stamina.current_value, stamina.max_value)

	# 3. MANA (Si existe, si no, ignora)
	var mana_comp = get_node_or_null("ManaComponent")
	if mana_comp:
		mana_comp.on_value_changed.connect(func(curr, max_val): emit_signal("mana_cambiado", curr, max_val))
		emit_signal("mana_cambiado", mana_comp.current_value, mana_comp.max_value)

	# 4. MÁSCARAS Y ULTI (¡Conectado al MaskManager real!)
	var mask_mgr = get_node_or_null("MaskManager") # O busca en el padre si está fuera
	if not mask_mgr and get_parent().has_node("MaskManager"): mask_mgr = get_parent().get_node("MaskManager")
	
	if mask_mgr:
		# Conectar cambio de máscara
		mask_mgr.on_mask_changed.connect(func(mask): emit_signal("mascara_cambiada", mask))
		# Conectar carga de ulti
		mask_mgr.on_ult_charge_changed.connect(func(val): emit_signal("ulti_cambiada", val, 100.0))
		
		# Estado inicial
		emit_signal("mascara_cambiada", mask_mgr.current_mask)
		emit_signal("ulti_cambiada", mask_mgr.current_ult_charge, 100.0)

	# 5. POCIONES
	emit_signal("pociones_cambiadas", 1, pociones_ui[0])
	emit_signal("pociones_cambiadas", 2, pociones_ui[1])
	emit_signal("pociones_cambiadas", 3, pociones_ui[2])

# --- SOBREESCRIBIR _READY (TRUCO) ---
# Como no podemos borrar su _ready, llamamos a nuestra init al final de su _ready original.
# Búscalo en su código y agrega: _ready_ui_connections() al final.
# SI NO QUIERES TOCAR SU _READY: Usa un call_deferred en _enter_tree o _ready
func _enter_tree():
	call_deferred("_ready_ui_connections")

# --- INPUTS DE UI (ADICIONALES) ---
func _unhandled_input(event):
	# Usamos _unhandled_input para que no pelee con su _input
	if event.is_action_pressed("usar_pocion_1"): usar_pocion(0)
	elif event.is_action_pressed("usar_pocion_2"): usar_pocion(1)
	elif event.is_action_pressed("usar_pocion_3"): usar_pocion(2)

# --- FUNCIONES PUENTE PARA HUD ---

func equipar_desde_ui(weapon_data, hand_side):
	if combat_manager:
		combat_manager.equip_weapon(weapon_data, hand_side.to_lower())

func desequipar_desde_ui(hand_side):
	if combat_manager:
		combat_manager.unequip_weapon(hand_side.to_lower())

func usar_pocion(index):
	if index >= 0 and index < pociones_ui.size() and pociones_ui[index] > 0:
		pociones_ui[index] -= 1
		
		# Efecto (Vida)
		if index == 0 and health_component:
			health_component.current_health += 20
			if health_component.current_health > health_component.max_health:
				health_component.current_health = health_component.max_health
			emit_signal("vida_cambiada", health_component.current_health)
			
		emit_signal("pociones_cambiadas", index + 1, pociones_ui[index])
