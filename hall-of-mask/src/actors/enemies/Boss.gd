extends Enemy
class_name BossOrc
signal boss_died

# ----------------------------------------------------------------
# CONFIGURACIÓN DE COMBATE
# ----------------------------------------------------------------
@export_group("Mecánica de Carga (Sprint)")
## Tiempo mínimo en segundos para volver a realizar un ataque de sprint/carga.
@export var min_sprint_time: float = 5.0
## Tiempo máximo en segundos para volver a realizar un ataque de sprint/carga.
@export var max_sprint_time: float = 60.0

@export_group("Tiempos de Ataque Base")
## Segundos de preparación antes del golpe Atk1.
@export var atk1_windup: float = 0.4
## Segundos que dura el daño del golpe Atk1.
@export var atk1_active: float = 0.2
## Multiplicador de daño del Atk1.
@export var atk1_mult_dmg: float = 1.0      

## Segundos de preparación antes del golpe Atk2.
@export var atk2_windup: float = 0.25
## Segundos que dura el daño del golpe Atk2.
@export var atk2_active: float = 0.3
## Multiplicador de daño del Atk2.
@export var atk2_mult_dmg: float = 1.25

## Segundos de preparación antes del golpe Atk3.
@export var atk3_windup: float = 0.55
## Segundos que dura el daño del golpe Atk3.
@export var atk3_active: float = 0.4
## Multiplicador de daño del Atk3.
@export var atk3_mult_dmg: float = 1.5

@export_group("Compensación de XFade")
## Compensación local para sincronizar hit timing con xfade del AnimationTree del boss.
@export var xfade_delay_compensation: float = 0.1

# Estado interno
var is_doing_boss_attack: bool = false
var has_equipped_mask: bool = false
var _phase2_initialized: bool = false

var _boss_attack_count: int = 0
var _boss_received_hit_count: int = 0
var _boss_any_event_count: int = 0

var _boss_half_health_thresholds: Array[float] = [40.0, 25.0, 10.0]
var _boss_half_health_index: int = 0

var _boss_desperation_thresholds: Array[float] = [25.0, 15.0, 10.0]
var _boss_desperation_index: int = 0

var _boss_first_attack_next: int = 3
var _boss_first_attack_step: int = 6

var _boss_first_hit_next: int = 3
var _boss_first_hit_step: int = 3

var _boss_any_next: int = 3
var _boss_any_step: int = 4

var _boss_proximity_time: float = 0.0
var _boss_proximity_next: float = 4.0
var _boss_proximity_step: float = 5.0

var _boss_combat_time: float = 0.0
var _boss_combat_next: float = 8.0
var _boss_combat_step: float = 10.0

# Variables de IA Avanzada
var sprint_timer: float = 0.0
var is_sprinting: bool = false

# Variable de Velocidad de Animación
var current_anim_scale: float = 0.6 
var internal_anim_player: AnimationPlayer = null 

# ----------------------------------------------------------------
# 1. INICIO
# ----------------------------------------------------------------
func _ready():
	super._ready() 
	has_equipped_mask = mask_manager != null and mask_manager.current_mask != null
	_phase2_initialized = has_equipped_mask
	print("👹 JEFE ORCO TÁCTICO LISTO: ", name)
	
	if has_node("OrcBrute/AnimationPlayer"):
		internal_anim_player = $OrcBrute/AnimationPlayer
	
	current_archetype = Archetype.MELEE_2H 
	current_speed = base_speed
	preferred_range = 3.5
	
	# ACTIVAR MECÁNICAS HEREDADAS DE ENEMY
	can_sprint = true
	can_jump = true
	can_dodge = true
	sprint_speed_mult = 2.0 # Garantizar que llega al BlendPosition 2 (Correr)
	dodge_power = 15.0
	jump_force = 12.0
	gravity_multiplier = 3.0
	
	_reiniciar_timer_sprint()
	_actualizar_velocidad_fases(100.0)
	
	if anim_tree:
		var playback = anim_tree["parameters/StateMachine/playback"]
		if playback: playback.travel("Standing")
	
	if health_component:
		health_component.on_damage_received.connect(_check_fases_vida)
		health_component.on_damage_received.connect(_on_boss_hit)

func _uses_enemy_ultimate_roll_system() -> bool:
	return false

# ----------------------------------------------------------------
# 2. PHYSICS PROCESS (MODIFICADO PARA SPRINT INFINITO)
# ----------------------------------------------------------------
func _physics_process(delta):
	zigzag_time += delta
	
	super._physics_process(delta)
	_process_boss_conditioned_ultimate(delta)
	
	# Solo gestionamos sprint si está vivo y no está en otros estados críticos
	var can_manage_sprint = current_state != State.ATTACKING and current_state != State.DODGING and current_state != State.PRE_DODGE

	
	if can_manage_sprint and health_component.current_health > 0:
		
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
		# Se quita el flash_red() aquí porque confundía al jugador, parecía que recibía daño.
	
	current_speed = base_speed * sprint_speed_mult
	current_state = State.CHASE

func _comportamiento_persecucion(delta: float):
	if not is_instance_valid(player_ref): return
	
	var dist = global_position.distance_to(player_ref.global_position)
	var target_pos = player_ref.global_position
	var dir_to_player = (player_ref.global_position - global_position).normalized()
	
	# INTENTAR MANIOBRAS OFENSIVAS (SALTO / DODGE-ATTACK)
	if _intentar_maniobra_ofensiva(dist, dir_to_player, "Persecución (Jefe)"):
		return
	
	# 🔴 MEJORA: ZIG-ZAG COMPATIBLE CON SPRINT (FASE 2)
	var aplicar_zigzag = false
	if dist > 5.0:
		if has_equipped_mask: aplicar_zigzag = true # Fase 2: Siempre esquiva
		elif not is_sprinting: aplicar_zigzag = true # Fase 1: Solo si camina
	
	if aplicar_zigzag:
		var right_vec = dir_to_player.cross(Vector3.UP)
		var speed_zigzag = 8.0 if has_equipped_mask else 5.0
		var offset = right_vec * sin(zigzag_time * speed_zigzag) * 2.0
		target_pos += offset
	
	nav_agent.target_position = target_pos
	
	# Velocidad dinámica
	var final_speed = base_speed
	if is_sprinting: final_speed = base_speed * sprint_speed_mult
	
	_mover_hacia(nav_agent.get_next_path_position(), delta, final_speed)
	
	# Mirar al jugador siempre
	_mirar_hacia(player_ref.global_position, delta * 10.0)
	
	if dist <= preferred_range:
		# Si llega corriendo, golpe inmediato
		if is_sprinting:
			if not has_equipped_mask: print("😡 JEFE: ¡TE ALCANCÉ!")
			
			is_sprinting = false
			_reiniciar_timer_sprint()
			current_speed = base_speed 
			_realizar_ataque_3_spin()
		else:
			current_state = State.COMBAT_MANEUVER

func _on_boss_hit(amount, current_hp):
	if is_doing_boss_attack or current_hp <= 0: return
	_register_boss_received_hit_for_ult()
	
	if current_state == State.PATROL or current_state == State.COOLDOWN:
		current_state = State.CHASE
		if is_instance_valid(player_ref):
			var dist = global_position.distance_to(player_ref.global_position)
			if dist > 10.0 and not is_sprinting:
				_iniciar_carga()

# ----------------------------------------------------------------
# 5. ESTRATEGIA DE COMBATE
# ----------------------------------------------------------------
func _comportamiento_combate(delta: float):
	if not is_instance_valid(player_ref): 
		current_state = State.PATROL
		return

	_mirar_hacia(player_ref.global_position, delta * aim_speed)
	
	ai_decision_timer -= delta
	if ai_decision_timer > 0: return

	if is_doing_boss_attack: return

	var dist = global_position.distance_to(player_ref.global_position)
	var dir = (player_ref.global_position - global_position).normalized()
	
	if _intentar_maniobra_ofensiva(dist, dir, "Combate (Jefe)"):
		return

	# Acercarse si el jugador huye un poco
	if dist > preferred_range + 0.5:
		var speed_to_use = base_speed
		if is_sprinting: speed_to_use = base_speed * sprint_speed_mult
		
		velocity.x = dir.x * speed_to_use
		velocity.z = dir.z * speed_to_use
		return

	# Respetar condición de máscara por primer ataque igual que Enemy.gd
	_check_mask_condition(MaskEquipCondition.FIRST_ATTACK)
	_iniciar_ataque_melee()

# ----------------------------------------------------------------
# OVERRIDES DE ESTADOS PADRE Y ENEMIGO PARA JEFES
# ----------------------------------------------------------------
func _procesar_ataque_en_curso(delta: float):
	# Los Jefes usan corutinas (await) para los ataques con is_doing_boss_attack.
	# Nos movemos lentamente hacia el jugador, pero NO llamamos a super para evitar 
	# que la lógica del enemigo corte el ataque prematuramente al pasar a COOLDOWN.
	if is_on_floor():
		if is_instance_valid(player_ref):
			var dir = (player_ref.global_position - global_position).normalized()
			var speed_to_use = base_speed * attack_movement_mult
			velocity.x = dir.x * speed_to_use
			velocity.z = dir.z * speed_to_use
		else:
			velocity.x = move_toward(velocity.x, 0, base_speed * delta)
			velocity.z = move_toward(velocity.z, 0, base_speed * delta)

func _comportamiento_cooldown(delta: float):
	# Jefes no tienen cooldown de strafe. Si caen aquí, regresan directo a combatir
	current_state = State.CHASE

func _iniciar_ataque_melee():
	var roll = randf()
	if roll < 0.4: _realizar_ataque_1_chop()
	elif roll < 0.7: _realizar_ataque_2_thrust()
	else: _realizar_ataque_3_spin()

func _intentar_maniobra_ofensiva(dist: float, dir: Vector3, estado_origen: String) -> bool:
	if can_jump and is_on_floor() and dist <= 6.5 and dist >= 3.5 and _next_combat_maneuver == "JUMP_ATTACK":
		print("👹 BOSS OFFENSIVE-JUMP en ", estado_origen)
		velocity.y = jump_force
		velocity.x = dir.x * base_speed * sprint_speed_mult
		velocity.z = dir.z * base_speed * sprint_speed_mult
		_next_combat_maneuver = ""
		
		# Disparamos ataque pesado inmediatamente y dejamos que la gravedad lo aterrice
		_realizar_ataque_1_chop()
		return true

	if can_dodge and dist <= 3.75 and dist >= 2.0 and _next_combat_maneuver == "DODGE_ATTACK":
		print("👹 BOSS DODGE-ATTACK en ", estado_origen)
		_next_combat_maneuver = ""
		_iniciar_esquive_ofensivo()
		return true

	return false

# ----------------------------------------------------------------
# 6. ATAQUES
# ----------------------------------------------------------------
func _realizar_ataque_1_chop():
	_iniciar_secuencia("Orc_Axe_2H_Attack_1", atk1_windup, atk1_active, atk1_mult_dmg, 6.0)

func _realizar_ataque_2_thrust():
	_iniciar_secuencia("Orc_Axe_2H_Attack_2", atk2_windup, atk2_active, atk2_mult_dmg, 9.0)

func _realizar_ataque_3_spin():
	_iniciar_secuencia("Orc_Axe_2H_Attack_3", atk3_windup, atk3_active, atk3_mult_dmg, 14.0)

func _iniciar_secuencia(anim_name: String, windup: float, active: float, dmg_mult: float, knockback: float):
	_register_boss_attack_for_ult()
	is_doing_boss_attack = true
	current_state = State.ATTACKING 
	
	# Sobreescribir el temporizador padre para no entrar en conflicto con la lógica manual del Boss
	safety_attack_timer = 0.0
	
	# Reiniciar cualquier ataque erróneo atrapado en el CombatManager proveniente del Enemy.gd
	if combat_manager:
		combat_manager.is_attacking_r = false
		combat_manager.is_attacking_l = false 
	
	var vel_original = current_speed
	current_speed = 0.0 
	
	var playback = anim_tree["parameters/StateMachine/playback"]
	playback.travel(anim_name)
	
	var combat_speed = 1.0
	if combat_manager: combat_speed = combat_manager.attack_speed_multiplier
	var total_speed_scale = max(0.1, current_anim_scale * combat_speed)
	
	var real_windup = max(0.01, (windup / total_speed_scale) - maxf(xfade_delay_compensation, 0.0))
	var real_active = active / total_speed_scale
	
	# Tracking inicial
	var timer = 0.0
	var track_time = real_windup * 0.5 
	
	while timer < track_time:
		if not is_inside_tree(): return
		await get_tree().process_frame 
		var dt = get_process_delta_time()
		if is_instance_valid(player_ref): _mirar_hacia(player_ref.global_position, dt * 5.0)
		timer += dt
	
	if real_windup > track_time:
		await get_tree().create_timer(real_windup - track_time).timeout
	
	if combat_manager:
		combat_manager.manual_hitbox_activation(dmg_mult, real_active, knockback, combat_manager.right_hand_bone)
	
	await get_tree().create_timer(real_active).timeout
	
	current_speed = vel_original
	is_doing_boss_attack = false
	current_state = State.CHASE

# ----------------------------------------------------------------
# 7. FASES
# ----------------------------------------------------------------
func _check_fases_vida(amount, current_hp):
	var max_hp = health_component.max_health
	var percent = (current_hp / max_hp) * 100.0
	_actualizar_velocidad_fases(percent)
	_check_boss_health_condition_for_ult(percent)

func _can_try_boss_ultimate() -> bool:
	if not mask_manager or not mask_manager.current_mask:
		return false
	if mask_manager.is_ultimate_active:
		return false
	return true

func _trigger_boss_ultimate(reason: String) -> bool:
	if not _can_try_boss_ultimate():
		return false
	_evento_activar_ulti(reason)
	return mask_manager != null and mask_manager.is_ultimate_active

func _register_boss_attack_for_ult():
	_boss_attack_count += 1
	_boss_any_event_count += 1

	if mask_equip_condition == MaskEquipCondition.FIRST_ATTACK:
		if _boss_attack_count >= _boss_first_attack_next:
			if _trigger_boss_ultimate("FIRST_ATTACK_%d" % _boss_attack_count):
				_boss_first_attack_next += _boss_first_attack_step
				_boss_first_attack_step += 3

	elif mask_equip_condition == MaskEquipCondition.ANY:
		if _boss_any_event_count >= _boss_any_next:
			if _trigger_boss_ultimate("ANY_EVENT_%d" % _boss_any_event_count):
				_boss_any_next += _boss_any_step
				_boss_any_step += 2

func _register_boss_received_hit_for_ult():
	_boss_received_hit_count += 1
	_boss_any_event_count += 1

	if mask_equip_condition == MaskEquipCondition.FIRST_HIT_RECEIVED:
		if _boss_received_hit_count >= _boss_first_hit_next:
			if _trigger_boss_ultimate("FIRST_HIT_%d" % _boss_received_hit_count):
				_boss_first_hit_next += _boss_first_hit_step
				_boss_first_hit_step += 2

	elif mask_equip_condition == MaskEquipCondition.ANY:
		if _boss_any_event_count >= _boss_any_next:
			if _trigger_boss_ultimate("ANY_EVENT_%d" % _boss_any_event_count):
				_boss_any_next += _boss_any_step
				_boss_any_step += 2

func _check_boss_health_condition_for_ult(percent: float):
	if mask_equip_condition == MaskEquipCondition.HALF_HEALTH:
		while _boss_half_health_index < _boss_half_health_thresholds.size() and percent <= _boss_half_health_thresholds[_boss_half_health_index]:
			if _trigger_boss_ultimate("HALF_HEALTH_%d" % int(_boss_half_health_thresholds[_boss_half_health_index])):
				_boss_half_health_index += 1
			else:
				break

	elif mask_equip_condition == MaskEquipCondition.LOW_HEALTH_DESPERATION:
		while _boss_desperation_index < _boss_desperation_thresholds.size() and percent <= _boss_desperation_thresholds[_boss_desperation_index]:
			if _trigger_boss_ultimate("DESPERATION_%d" % int(_boss_desperation_thresholds[_boss_desperation_index])):
				_boss_desperation_index += 1
			else:
				break

func _process_boss_conditioned_ultimate(delta: float):
	if not is_instance_valid(player_ref):
		return
	if current_state == State.PATROL:
		return

	if mask_equip_condition == MaskEquipCondition.ON_PROXIMITY:
		if global_position.distance_to(player_ref.global_position) <= 6.5:
			_boss_proximity_time += delta
			if _boss_proximity_time >= _boss_proximity_next:
				if _trigger_boss_ultimate("PROXIMITY_%.1fs" % _boss_proximity_time):
					_boss_proximity_next += _boss_proximity_step
					_boss_proximity_step += 2.0

	elif mask_equip_condition == MaskEquipCondition.AFTER_TIME_IN_COMBAT:
		_boss_combat_time += delta
		if _boss_combat_time >= _boss_combat_next:
			if _trigger_boss_ultimate("TIME_IN_COMBAT_%.1fs" % _boss_combat_time):
				_boss_combat_next += _boss_combat_step
				_boss_combat_step += 4.0

func _actualizar_velocidad_fases(percent: float):
	var anterior = current_anim_scale
	if percent > 80.0:   current_anim_scale = 0.6 
	elif percent > 50.0: current_anim_scale = 0.8 
	elif percent > 10.0: current_anim_scale = 1.0 
	else:                current_anim_scale = 1.2 
	
	if internal_anim_player and anterior != current_anim_scale:
		internal_anim_player.speed_scale = current_anim_scale

func _on_phase2_mask_equipped():
	if not is_inside_tree() or not has_equipped_mask:
		return
	print("👺 JEFE: FASE 2 - ¡SPRINT INFINITO!")
	current_state = State.COOLDOWN
	ai_cooldown_timer = 1.0
	if mask_manager:
		mask_manager.current_ult_charge = mask_manager.max_ult_charge

func _on_mask_changed_event(data: MaskData):
	super._on_mask_changed_event(data)
	has_equipped_mask = data != null
	if has_equipped_mask and not _phase2_initialized:
		_phase2_initialized = true
		call_deferred("_on_phase2_mask_equipped")

func _evento_activar_ulti(motivo):
	if not mask_manager: return
	print("🔥 JEFE: ULTI - ", motivo)
	mask_manager.current_ult_charge = mask_manager.max_ult_charge
	mask_manager.activate_ultimate()

# ----------------------------------------------------------------
# 8. MUERTE
# ----------------------------------------------------------------
func _morir():
	print("💀 Boss Orc derrotado!")
	boss_died.emit(self)
	
	# Recompensa de carga
	if player_ref and player_ref.has_node("MaskManager"):
		player_ref.get_node("MaskManager").add_charge(combat_manager.ult_charge_reward)
	
	set_physics_process(false)
	queue_free()
