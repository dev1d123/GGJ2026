extends Enemy
class_name BossOrc

# ----------------------------------------------------------------
# CONFIGURACIÓN DE COMBATE
# ----------------------------------------------------------------
@export_group("Mecánica de Carga (Sprint)")
@export var min_sprint_time: float = 5.0
@export var max_sprint_time: float = 60.0
@export var sprint_speed_mult: float = 2.5 # Corre mucho más rápido

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

# Variables de Carga
var sprint_timer: float = 0.0
var is_sprinting: bool = false

# Variable de Velocidad de Animación (Empieza lento 0.6)
var current_anim_scale: float = 0.6 
var internal_anim_player: AnimationPlayer = null # Referencia para cambiar velocidad visual

# ----------------------------------------------------------------
# 1. INICIO
# ----------------------------------------------------------------
func _ready():
	# 1. Asignar AnimationTree manualmente si falla
	if not anim_tree: anim_tree = $OrcBrute/AnimationTree 
	
	# -------------------------------------------------------------
	# EL TRUCO PARA EVITAR EL EQUIPAMIENTO AUTOMÁTICO
	# -------------------------------------------------------------
	# A. Guardamos la máscara en una variable temporal
	var mask_temp = loadout_mask
	
	# B. Le decimos al script padre que NO tenemos máscara
	loadout_mask = null 
	
	# C. Iniciamos la IA Genérica (EnemyAI). 
	# Como loadout_mask es null, NO equipará nada ni activará el aura roja.
	super._ready() 
	
	# D. Recuperamos la máscara para usarla nosotros cuando baje la vida
	loadout_mask = mask_temp
	# -------------------------------------------------------------
	
	print("👹 JEFE ORCO LISTO: ", name)
	
	# Asignar AnimationPlayer para ralentizar visualmente
	internal_anim_player = $OrcBrute/AnimationPlayer
	
	archetype = "Verdugo"
	current_speed = base_speed * 0.9
	attack_range = 3.5 
	
	_reiniciar_timer_sprint()
	_actualizar_velocidad_fases(100.0)
	
	# NOTA: Ya no necesitas el bloque de "remove_mask" aquí abajo,
	# porque con el truco de arriba, nunca se la llegó a poner.
	
	if health_component:
		health_component.on_damage_received.connect(_check_fases_vida)

# ----------------------------------------------------------------
# 2. PHYSICS PROCESS (SPRINT)
# ----------------------------------------------------------------
func _physics_process(delta):
	# Lógica base (gravedad, knockback, cooldowns)
	super._physics_process(delta)
	
	# Lógica del Timer de Sprint (Solo si está vivo y no está atacando)
	if not is_doing_boss_attack and health_component.current_health > 0:
		sprint_timer -= delta
		
		if sprint_timer <= 0 and not is_sprinting:
			_iniciar_carga()

# ----------------------------------------------------------------
# 3. LÓGICA DE CARGA
# ----------------------------------------------------------------
func _reiniciar_timer_sprint():
	# Elige un tiempo aleatorio entre 5 y 60 segundos
	sprint_timer = randf_range(min_sprint_time, max_sprint_time)
	# print("⏳ Próxima carga en: ", snapped(sprint_timer, 0.1), "s")

func _iniciar_carga():
	is_sprinting = true
	print("😡 JEFE: ¡CARGA FURIOSA!")
	flash_red() # Feedback visual rápido
	current_speed = base_speed * sprint_speed_mult
	current_state = State.CHASE

# Sobrescribimos persecución para manejar la carga
func _procesar_persecucion(delta):
	if not player_ref: return
	
	if is_sprinting:
		# Ignoramos distancias lejanas, corre directo a matar
		nav_agent.target_position = player_ref.global_position
		_mover_hacia_destino(delta, current_speed)
		_rotar_hacia(player_ref.global_position, delta * 8.0)
		
		var dist = global_position.distance_to(player_ref.global_position)
		
		# Si alcanza al jugador
		if dist <= attack_range:
			print("😡 JEFE: ¡TE TENGO!")
			is_sprinting = false
			_reiniciar_timer_sprint() # Reiniciamos el timer aleatorio
			current_speed = base_speed * 0.9 # Volver a velocidad base
			
			# Castigo inmediato: Ataque giratorio
			_realizar_ataque_3_spin()
	else:
		# Comportamiento normal si no está cargando
		super._procesar_persecucion(delta)

# ----------------------------------------------------------------
# 4. CONTROL DE FASES (VIDA Y VELOCIDAD)
# ----------------------------------------------------------------
func _check_fases_vida(amount, current_hp):
	var max_hp = health_component.max_health
	var percent = (current_hp / max_hp) * 100.0
	
	# --- ACTUALIZAR VELOCIDAD SEGÚN TU TABLA ---
	_actualizar_velocidad_fases(percent)
	
	# --- EVENTOS DE FASES ---
	if percent <= 50.0 and not has_equipped_mask:
		_evento_equipar_mascara()
	
	if percent <= 30.0 and not has_triggered_ult_30:
		has_triggered_ult_30 = true
		_evento_activar_ulti("Furia del 30%")

	if percent <= 10.0 and not has_triggered_ult_10:
		has_triggered_ult_10 = true
		_evento_activar_ulti("Desesperación del 10%")

func _actualizar_velocidad_fases(percent: float):
	var anterior = current_anim_scale
	
	if percent > 80.0:
		current_anim_scale = 0.6 # Muy lento y pesado
	elif percent > 50.0:
		current_anim_scale = 0.8 # Un poco más ágil
	elif percent > 10.0:
		current_anim_scale = 1.0 # Velocidad normal
	else:
		current_anim_scale = 1.2 # Frenético (Berserk final)
		
	# Aplicar visualmente al AnimationPlayer si existe
	if internal_anim_player and anterior != current_anim_scale:
		internal_anim_player.speed_scale = current_anim_scale
		# print("⚙️ JEFE: Velocidad ajustada a x", current_anim_scale)

func _evento_equipar_mascara():
	if not mask_manager or not loadout_mask: return
	print("👺 JEFE: Equipando máscara...")
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

# ----------------------------------------------------------------
# 5. ESTRATEGIA DE COMBATE
# ----------------------------------------------------------------
func _ejecutar_estrategia_combate():
	if is_doing_boss_attack or is_sprinting: return
	
	var roll = randf()
	if roll < 0.4: _realizar_ataque_1_chop()
	elif roll < 0.7: _realizar_ataque_2_thrust()
	else: _realizar_ataque_3_spin()

func _realizar_ataque_1_chop():
	_iniciar_secuencia("Orc_Axe_2H_Attack_1", atk1_windup, atk1_active, atk1_dmg, 10.0)

func _realizar_ataque_2_thrust():
	_iniciar_secuencia("Orc_Axe_2H_Attack_2", atk2_windup, atk2_active, atk2_dmg, 15.0)

func _realizar_ataque_3_spin():
	_iniciar_secuencia("Orc_Axe_2H_Attack_3", atk3_windup, atk3_active, atk3_dmg, 25.0)

func _iniciar_secuencia(anim_name: String, windup: float, active: float, dmg_mult: float, knockback: float):
	is_doing_boss_attack = true
	var vel_original = current_speed
	current_speed = 0.0 
	
	var playback = anim_tree["parameters/StateMachine/playback"]
	playback.travel(anim_name)
	
	# --- CÁLCULO DE TIEMPOS DINÁMICO ---
	# Si current_anim_scale es 0.6 (lento), el tiempo debe ser MAYOR.
	# Fórmula: tiempo_real = tiempo_base / escala
	
	var combat_speed = 1.0
	if combat_manager: combat_speed = combat_manager.attack_speed_multiplier
	
	# Factor total = (Escala Fase Vida) * (Velocidad Stats Máscara)
	var total_speed_scale = current_anim_scale * combat_speed
	
	# Evitamos división por cero
	total_speed_scale = max(0.1, total_speed_scale)
	
	var real_windup = windup / total_speed_scale
	var real_active = active / total_speed_scale
	
	# Esperar Windup
	await get_tree().create_timer(real_windup).timeout
	
	if combat_manager:
		combat_manager.manual_hitbox_activation(dmg_mult, real_active, knockback, combat_manager.right_hand_bone)
	
	# Esperar Active + un pequeño recovery
	await get_tree().create_timer(real_active + 0.2).timeout
	
	current_speed = vel_original
	is_doing_boss_attack = false
	
	# El cooldown también depende de qué tan rápido se mueve ahora
	var cooldown_time = 1.5 / current_anim_scale
	if mask_manager and mask_manager.is_ultimate_active:
		cooldown_time = 0.5 
		
	_entrar_cooldown(cooldown_time)
