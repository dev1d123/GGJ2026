extends Enemy
class_name BossOrc
signal boss_died

# ----------------------------------------------------------------
# CONFIGURACIÓN DE COMBATE
# ----------------------------------------------------------------
@export_group("Mecánica de Carga (Sprint)")
@export var min_sprint_time: float = 5.0
@export var max_sprint_time: float = 60.0
@export var sprint_speed_mult: float = 2.2 

@export_group("Tiempos de Ataque Base")
@export var atk1_windup: float = 0.6
@export var atk1_active: float = 0.2
@export var atk1_dmg: float = 1.0      

@export var atk2_windup: float = 0.4
@export var atk2_active: float = 0.3
@export var atk2_dmg: float = 0.8

@export var atk3_windup: float = 0.8
@export var atk3_active: float = 0.4
@export var atk3_dmg: float = 1.5

# Estado interno
var is_doing_boss_attack: bool = false
var has_equipped_mask: bool = false
var has_triggered_ult_30: bool = false
var has_triggered_ult_10: bool = false

# Variables de IA Avanzada
var sprint_timer: float = 0.0
var is_sprinting: bool = false
var zigzag_time: float = 0.0 

# Variable de Velocidad de Animación
var current_anim_scale: float = 0.6 
var internal_anim_player: AnimationPlayer = null 

# ----------------------------------------------------------------
# 1. INICIO
# ----------------------------------------------------------------
func _ready():
	var mask_temp = loadout_mask
	loadout_mask = null 
	
	super._ready() 
	
	loadout_mask = mask_temp
	print("👹 JEFE ORCO TÁCTICO LISTO: ", name)
	
	if has_node("OrcBrute/AnimationPlayer"):
		internal_anim_player = $OrcBrute/AnimationPlayer
	
	current_archetype = Archetype.MELEE_2H 
	current_speed = base_speed * 0.9
	preferred_range = 3
	
	_reiniciar_timer_sprint()
	_actualizar_velocidad_fases(100.0)
	
	if anim_tree:
		var playback = anim_tree["parameters/StateMachine/playback"]
		if playback: playback.travel("Standing")
	
	if health_component:
		health_component.on_damage_received.connect(_check_fases_vida)
		health_component.on_damage_received.connect(_on_boss_hit)

# ----------------------------------------------------------------
# 2. PHYSICS PROCESS (MODIFICADO PARA SPRINT INFINITO)
# ----------------------------------------------------------------
func _physics_process(delta):
	super._physics_process(delta)
	
	zigzag_time += delta
	
	if is_doing_boss_attack:
		velocity.x = 0
		velocity.z = 0
		# Nota: No tocamos velocity.y para que la gravedad siga funcionando
	
	# Solo gestionamos sprint si está vivo y no está atacando
	if current_state != State.ATTACKING and health_component.current_health > 0:
		
		# 🔴 LÓGICA DE SPRINT HÍBRIDA 🔴
		if has_equipped_mask:
			# FASE 2: MODO BERSERKER (Máscara Puesta)
			# Ignoramos el timer. Si no está corriendo, empieza a correr YA.
			if not is_sprinting:
				_iniciar_carga()
		else:
			# FASE 1: LÓGICA NORMAL (Timer Aleatorio)
			sprint_timer -= delta
			if sprint_timer <= 0 and not is_sprinting:
				_iniciar_carga()

func _procesar_ataque_en_curso(delta):
	pass 

# ----------------------------------------------------------------
# 3. LÓGICA DE MOVIMIENTO AVANZADO
# ----------------------------------------------------------------
func _reiniciar_timer_sprint():
	sprint_timer = randf_range(min_sprint_time, max_sprint_time)

func _iniciar_carga():
	if is_sprinting: return # Evitar spam si ya corre
	
	is_sprinting = true
	
	# Solo imprimimos y flasheamos si es un inicio de carga "real" (no spam de frame)
	if not has_equipped_mask: 
		print("😡 JEFE: ¡CARGA FURIOSA!")
		flash_red() 
	
	current_speed = base_speed * sprint_speed_mult
	current_state = State.CHASE

func _comportamiento_persecucion(delta):
	if not player_ref: return
	
	var dist = global_position.distance_to(player_ref.global_position)
	var target_pos = player_ref.global_position
	
	# 🔴 MEJORA: ZIG-ZAG COMPATIBLE CON SPRINT (FASE 2)
	# - Fase 1: ZigZag solo si camina.
	# - Fase 2 (Máscara): ZigZag INCLUSO si corre (esprinta en serpiente).
	var aplicar_zigzag = false
	
	if dist > 5.0:
		if has_equipped_mask: aplicar_zigzag = true # Fase 2: Siempre esquiva
		elif not is_sprinting: aplicar_zigzag = true # Fase 1: Solo si camina
	
	if aplicar_zigzag:
		var dir_to_player = (player_ref.global_position - global_position).normalized()
		var right_vec = dir_to_player.cross(Vector3.UP)
		# ZigZag más rápido en fase 2
		var speed_zigzag = 8.0 if has_equipped_mask else 5.0
		var offset = right_vec * sin(zigzag_time * speed_zigzag) * 2.0
		target_pos += offset
	
	nav_agent.target_position = target_pos
	
	# Velocidad dinámica
	var final_speed = current_speed
	if is_sprinting: final_speed = base_speed * sprint_speed_mult
	
	_mover_hacia(nav_agent.get_next_path_position(), delta, final_speed)
	
	# Mirar al jugador siempre
	_mirar_hacia(player_ref.global_position, delta * 10.0)
	
	if dist <= preferred_range:
		# Si llega corriendo, golpe inmediato
		if is_sprinting:
			# En fase máscara no imprimimos texto para no saturar consola
			if not has_equipped_mask: print("😡 JEFE: ¡TE ALCANCÉ!")
			
			is_sprinting = false
			_reiniciar_timer_sprint()
			current_speed = base_speed * 0.9 
			_realizar_ataque_3_spin()
		else:
			current_state = State.COMBAT_MANEUVER

func _on_boss_hit(amount, current_hp):
	if is_doing_boss_attack or current_hp <= 0: return
	
	if current_state == State.PATROL or current_state == State.COOLDOWN:
		current_state = State.CHASE
		if player_ref:
			var dist = global_position.distance_to(player_ref.global_position)
			if dist > 10.0 and not is_sprinting:
				_iniciar_carga()

# ----------------------------------------------------------------
# 5. ESTRATEGIA DE COMBATE
# ----------------------------------------------------------------
func _comportamiento_combate(delta):
	if not player_ref: 
		current_state = State.PATROL
		return

	_mirar_hacia(player_ref.global_position, delta * aim_speed)
	
	ai_decision_timer -= delta
	if ai_decision_timer > 0: return

	if is_doing_boss_attack: return

	# Acercarse si el jugador huye un poco
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > preferred_range + 0.5:
		var dir = (player_ref.global_position - global_position).normalized()
		velocity.x = dir.x * current_speed
		velocity.z = dir.z * current_speed
		return 

	var roll = randf()
	if roll < 0.4: _realizar_ataque_1_chop()
	elif roll < 0.7: _realizar_ataque_2_thrust()
	else: _realizar_ataque_3_spin()

# ----------------------------------------------------------------
# 6. ATAQUES
# ----------------------------------------------------------------
func _realizar_ataque_1_chop():
	_iniciar_secuencia("Orc_Axe_2H_Attack_1", atk1_windup, atk1_active, atk1_dmg, 6.0)

func _realizar_ataque_2_thrust():
	_iniciar_secuencia("Orc_Axe_2H_Attack_2", atk2_windup, atk2_active, atk2_dmg, 9.0)

func _realizar_ataque_3_spin():
	_iniciar_secuencia("Orc_Axe_2H_Attack_3", atk3_windup, atk3_active, atk3_dmg, 14.0)

func _iniciar_secuencia(anim_name: String, windup: float, active: float, dmg_mult: float, knockback: float):
	is_doing_boss_attack = true
	current_state = State.ATTACKING 
	
	var vel_original = current_speed
	current_speed = 0.0 
	
	var playback = anim_tree["parameters/StateMachine/playback"]
	playback.travel(anim_name)
	
	var combat_speed = 1.0
	if combat_manager: combat_speed = combat_manager.attack_speed_multiplier
	var total_speed_scale = max(0.1, current_anim_scale * combat_speed)
	
	var real_windup = windup / total_speed_scale
	var real_active = active / total_speed_scale
	
	# Tracking inicial
	var timer = 0.0
	var track_time = real_windup * 0.5 
	
	while timer < track_time:
		var dt = get_physics_process_delta_time()
		if player_ref: _mirar_hacia(player_ref.global_position, dt * 5.0)
		velocity.x = 0
		velocity.z = 0
		timer += dt
		await get_tree().process_frame 
	
	if real_windup > track_time:
		await get_tree().create_timer(real_windup - track_time).timeout
	
	if combat_manager:
		combat_manager.manual_hitbox_activation(dmg_mult, real_active, knockback, combat_manager.right_hand_bone)
	
	await get_tree().create_timer(real_active + 0.2).timeout
	
	current_speed = vel_original
	is_doing_boss_attack = false
	
	# Cooldown reducido en Fase 2
	var cooldown_time = 1.2 / current_anim_scale 
	if mask_manager and mask_manager.is_ultimate_active: cooldown_time = 0.3 # ¡Casi sin pausa!
	_entrar_cooldown(cooldown_time)

# ----------------------------------------------------------------
# 7. FASES
# ----------------------------------------------------------------
func _check_fases_vida(amount, current_hp):
	var max_hp = health_component.max_health
	var percent = (current_hp / max_hp) * 100.0
	_actualizar_velocidad_fases(percent)
	
	if percent <= 50.0 and not has_equipped_mask: _evento_equipar_mascara()
	if percent <= 30.0 and not has_triggered_ult_30:
		has_triggered_ult_30 = true
		_evento_activar_ulti("Furia del 30%")
	if percent <= 10.0 and not has_triggered_ult_10:
		has_triggered_ult_10 = true
		_evento_activar_ulti("Desesperación del 10%")

func _actualizar_velocidad_fases(percent: float):
	var anterior = current_anim_scale
	if percent > 80.0:   current_anim_scale = 0.6 
	elif percent > 50.0: current_anim_scale = 0.8 
	elif percent > 10.0: current_anim_scale = 1.0 
	else:                current_anim_scale = 1.2 
	
	if internal_anim_player and anterior != current_anim_scale:
		internal_anim_player.speed_scale = current_anim_scale

func _evento_equipar_mascara():
	if not mask_manager or not loadout_mask: return
	print("👺 JEFE: FASE 2 - ¡SPRINT INFINITO!")
	has_equipped_mask = true
	
	current_state = State.COOLDOWN 
	ai_cooldown_timer = 1.0
	
	mask_manager.equip_mask(loadout_mask)
	_activar_aura_mascara()
	mask_manager.current_ult_charge = mask_manager.max_ult_charge

func _evento_activar_ulti(motivo):
	if not mask_manager: return
	print("🔥 JEFE: ULTI - ", motivo)
	mask_manager.current_ult_charge = mask_manager.max_ult_charge
	mask_manager.activate_ultimate()

