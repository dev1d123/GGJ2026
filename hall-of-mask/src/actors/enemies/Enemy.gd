extends CharacterBody3D
class_name Enemy

# ------------------------------------------------------------------------------
# CONFIGURACIÓN
# ------------------------------------------------------------------------------
@export_group("Loadout Inicial")
## Arma que el enemigo llevará en la mano derecha.
@export var loadout_weapon_r: WeaponData 
## Arma que el enemigo llevará en la mano izquierda.
@export var loadout_weapon_l: WeaponData 
## Máscara que el enemigo tendrá configurada.
@export var loadout_mask: MaskData       

@export_group("Equipamiento de Máscara")
enum MaskHandling { EQUIP_ON_SPAWN, EN_INVENTARIO, SIN_MASCARA }
## Define cómo el enemigo maneja su máscara inicial (Aparecer con ella, guardarla o ignorarla).
@export var mask_handling: MaskHandling = MaskHandling.EN_INVENTARIO

enum MaskEquipCondition { 
	NONE, 
	HALF_HEALTH, 
	FIRST_ATTACK, 
	FIRST_HIT_RECEIVED, 
	ANY,
	LOW_HEALTH_DESPERATION, # Desespero: Vida menor al 25%
	ON_PROXIMITY,           # Si el jugador se le acerca demasiado (Melee range)
	AFTER_TIME_IN_COMBAT    # Si la pelea dura mucho tiempo activo
}
## Condición bajo la cual el enemigo se equipará la máscara si la tiene en inventario.
@export var mask_equip_condition: MaskEquipCondition = MaskEquipCondition.NONE

@export_group("Ultimate IA (Enemigos)")
## Probabilidad (%) de que ESTA instancia de enemigo pueda usar ultimate si tiene máscara equipada.
@export_range(0.0, 100.0, 1.0) var ultimate_instance_chance_with_mask: float = 35.0

# --- COMPONENTES ---
@onready var combat_manager: CombatManager = $CombatManager
@onready var health_component: HealthComponent = $HealthComponent
@onready var stamina: Node = get_node_or_null("StaminaComponent")
@onready var mana: Node = get_node_or_null("ManaComponent")
@onready var mask_manager: MaskManager = get_node_or_null("MaskManager")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: RayCast3D = $VisionManager/Eyes
## El nodo 3D visual principal del enemigo.
@export var visual_mesh: Node3D 
## Controlador de animaciones (AnimationTree).
@export var anim_tree: AnimationTree

const P_MOVIMIENTO = "parameters/StateMachine/Standing/blend_position"

# ------------------------------------------------------------------------------
# VARIABLES IA
# ------------------------------------------------------------------------------
@export_category("Personalidad IA")
## Distancia en metros a la que el enemigo puede detectar al jugador.
@export var vision_range: float = 20.0
## Qué tan rápido el enemigo rota para encarar al jugador.
@export var aim_speed: float = 8.0  
## Velocidad base de movimiento (Patrullar = Mitad. Combate = Normal).
@export var base_speed: float = 3.5 

@export_group("Capacidades de Movimiento")
## Si está activo, el enemigo puede esprintar al atacar o perseguir.
@export var can_sprint: bool = false
## Si está activo, el enemigo puede saltar obstáculos.
@export var can_jump: bool = false

@export_group("Parámetros de Movimiento")
## Multiplicador de la base_speed cuando el enemigo esprinta.
@export var sprint_speed_mult: float = 1.5
## Multiplicador de la base_speed mientras el enemigo realiza una animación de ataque (1 = normal, 0.25 = cámara lenta).
@export var attack_movement_mult: float = 1
## Fuerza vertical aplicada al saltar.
@export var jump_force: float = 10
## Multiplicador artificial de la gravedad para hacer el salto menos "flotante" (Unificado con: player.gd)
@export var gravity_multiplier: float = 3.0

@export_group("Anti-Stuck sobre Player")
## Evita que el enemigo/jefe se quede encima del jugador tras saltos ofensivos.
@export var anti_stack_enabled: bool = true
## Diferencia mínima en Y para considerar que está "encima" del jugador.
@export var anti_stack_max_vertical_delta: float = 1.0
## Distancia horizontal máxima para activar la separación.
@export var anti_stack_horizontal_radius: float = 1.1
## Velocidad extra al separarse del jugador.
@export var anti_stack_escape_speed_mult: float = 1.15

@export_group("Capacidades de Evasión")
## Si está activo, el enemigo puede esquivar ataques del jugador.
@export var can_dodge: bool = false
## Probabilidad base (0.0 a 1.0) de esquivar un ataque cuando tiene la vida llena.
@export var dodge_chance_base: float = 0.3
## Tiempo de reacción en segundos antes de ejecutar el esquive (hacerlo instantáneo parece irreal).
@export var dodge_reaction_time: float = 0.15
## Multiplicador de la velocidad de evasión (impulso al rodar).
@export var dodge_power: float = 12.0

@export_group("Dinámicas Avanzadas (Melee)")
## Probabilidad por CABADA ATAQUE de realizar un salto-ataque sorpresivo (0.5 = 50% de saltar).
@export var jump_attack_chance: float = 0.2
## Probabilidad por CADA ATAQUE de rodar ofensivamente hacia ti (0.5 = 50% de esquivar).
@export var dodge_attack_chance: float = 0.2

@export_group("Puntería Inteligente (Ranged)")
## Segundos de retraso al apuntar (0 = Aimbot instantáneo).
@export var aim_delay_seconds: float = 0.3
## Frecuencia con la que cambia el margen de error del bloom.
@export var aim_bloom_update_rate: float = 0.2
## Radio máximo de imprecisión al apuntar (escala con la distancia).
@export var aim_inaccuracy_bloom: float = 1.52

enum Archetype { MELEE_1H, MELEE_2H, RANGED_PROJECTILE, RANGED_BEAM }
var current_archetype: Archetype = Archetype.MELEE_1H

var current_speed: float = 0.0
var preferred_range: float = 1.5 
var strafe_timer: float = 0.0
var strafe_dir: int = 1

# Variable para controlar la agresividad (1.0 normal, 2.0 frenético)
var aggression: float = 1.2 

enum State { IDLE, PATROL, CHASE, COMBAT_MANEUVER, ATTACKING, COOLDOWN, STUNNED, DODGING, PRE_DODGE }
var current_state = State.PATROL
var player_ref: Node3D = null

# Temporizadores
var patrol_timer: float = 0.0
var ai_decision_timer: float = 0.0 
var ai_cooldown_timer: float = 0.0

# 🟢 FIX BUCLE INFINITO
var safety_attack_timer: float = 0.0 

var is_holding_attack: bool = false
var hold_attack_timer: float = 0.0

# Variables de IA Avanzada
var zigzag_time: float = 0.0
var _zigzag_amp: float = 2.5
var _zigzag_freq: float = 6.0
var _dodge_is_aggressive: bool = false

var gravity = 9.8
var knockback_velocity: Vector3 = Vector3.ZERO
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween
var original_colors: Dictionary = {}

# Variables para control de puntería con retraso
var _position_history: Array[Vector3] = []
var _position_timer: float = 0.0

var _current_bloom_offset: Vector3 = Vector3.ZERO
var _target_bloom_offset: Vector3 = Vector3.ZERO
var _bloom_change_timer: float = 0.0

var _time_in_combat_timer: float = 0.0
var _next_combat_maneuver: String = ""

var _has_ultimate_roll: bool = false
var _can_activate_ultimate: bool = false
var _ultimate_proc_chance: float = 0.0
var _ultimate_hits_dealt: int = 0
var _ultimate_hits_received: int = 0
var _forced_low_health_ultimate_used: bool = false

# --- VARIABLES DE EVASIÓN ---
var evade_cooldown: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _dodge_timer: float = 0.0

# ------------------------------------------------------------------------------
# INICIO
# ------------------------------------------------------------------------------
func _ready():
	add_to_group("Enemy") # 🛡️ Garantizar que el fuego amigo aplique siempre
	current_speed = base_speed
	
	if not anim_tree:
		if has_node("Visual/AnimationTree"): anim_tree = $Visual/AnimationTree
		elif has_node("OrcBrute/AnimationTree"): anim_tree = $OrcBrute/AnimationTree
		elif has_node("Rig/AnimationTree"): anim_tree = $Rig/AnimationTree
	
	if anim_tree: 
		anim_tree.active = true
		var playback_path = "parameters/StateMachine/playback"
		if anim_tree.get(playback_path):
			anim_tree[playback_path].travel("Standing")
	
	if combat_manager:
		combat_manager.is_player_controlled = false
		combat_manager.owner_node = self
		combat_manager.stamina_component = stamina
		combat_manager.mana_component = mana
		combat_manager.mask_manager = mask_manager
		combat_manager.animation_tree = anim_tree 
		combat_manager.attack_layer_mask = 2 
		
		if loadout_weapon_r: combat_manager.equip_weapon(loadout_weapon_r, "right")
		if loadout_weapon_l: combat_manager.equip_weapon(loadout_weapon_l, "left")
		
		_definir_arquetipo()
		_decidir_proxima_maniobra()

		if mask_manager:
			mask_manager.on_mask_changed.connect(_on_mask_changed_event)
			mask_manager.on_ultimate_state.connect(_on_ultimate_visuals)
		
		if loadout_mask and mask_manager:
			if mask_handling == MaskHandling.EQUIP_ON_SPAWN:
				mask_manager.equip_mask(loadout_mask, true) # true = instant spawn, no delay
			elif mask_handling == MaskHandling.SIN_MASCARA:
				loadout_mask = null # Ignorar la máscara asignada
		elif mask_handling == MaskHandling.SIN_MASCARA:
			loadout_mask = null

	_initialize_enemy_ultimate_roll()

	if health_component:
		health_component.on_death.connect(_morir)
		health_component.on_damage_received.connect(_on_damage_received)

	_setup_unique_materials()
	if eyes: eyes.add_exception(self)
	
	call_deferred("_buscar_punto_patrulla")

func _definir_arquetipo():
	var w = combat_manager.weapon_r
	if not w: return
	if w is RangedWeaponData:
		current_archetype = Archetype.RANGED_BEAM if w.is_beam_weapon else Archetype.RANGED_PROJECTILE
		preferred_range = 8.0
	elif w.is_two_handed:
		current_archetype = Archetype.MELEE_2H
		preferred_range = 2.5 # Rango un poco mayor para 2H
	else:
		current_archetype = Archetype.MELEE_1H
		preferred_range = 1.8

# ------------------------------------------------------------------------------
# FÍSICA
# ------------------------------------------------------------------------------
func _physics_process(delta: float):
	if not is_on_floor(): velocity.y -= (gravity * gravity_multiplier) * delta

	# Procesamiento de subsistemas
	_process_aim_history(delta)
	_process_mask_triggers(delta)
	if can_dodge: _process_evasion_logic(delta)

	# Físicas de knockback
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		move_and_slide()
		return 

	if is_instance_valid(player_ref): 
		combat_manager.ai_target = player_ref
		if current_state != State.PATROL:
			_mirar_hacia(player_ref.global_position, delta * aim_speed)

	# Si el enemigo está en el aire por un salto-ataque, bloqueamos que los estados
	# modifiquen su inercia horizontal abruptamente, pero permitimos un "homing aéreo" suave.
	var is_airborne_attacking = not is_on_floor() and current_state == State.ATTACKING
	
	if is_airborne_attacking:
		if is_instance_valid(player_ref):
			# Extraemos la velocidad actual (su empuje) para no aumentarlo o disminuirlo
			var current_xz_speed = Vector2(velocity.x, velocity.z).length()
			if current_xz_speed > 0:
				var dir_to_player = (player_ref.global_position - global_position).normalized()
				var target_dir_2d = Vector2(dir_to_player.x, dir_to_player.z).normalized()
				var current_dir_2d = Vector2(velocity.x, velocity.z).normalized()
				
				# Lerp direccional suave (dobla la trayectoria en el aire como si fuera slerp)
				var new_dir_2d = current_dir_2d.lerp(target_dir_2d, delta * 2.5).normalized() 
				
				velocity.x = new_dir_2d.x * current_xz_speed
				velocity.z = new_dir_2d.y * current_xz_speed
			
			# Hacemos que siga mirando al jugador visualmente
			_mirar_hacia(player_ref.global_position, delta * aim_speed)
	else:
		match current_state:
			State.PATROL:
				_comportamiento_patrulla(delta)
				_buscar_jugador()
			State.CHASE:
				_comportamiento_persecucion(delta)
			State.COMBAT_MANEUVER:
				_comportamiento_combate(delta)
			State.ATTACKING:
				_procesar_ataque_en_curso(delta)
			State.COOLDOWN:
				_comportamiento_cooldown(delta)
			State.PRE_DODGE:
				_procesar_pre_dodge(delta)
			State.DODGING:
				_procesar_dodging(delta)
			
	if current_state != State.DODGING:
		_resolver_superposicion_con_player()
		move_and_slide()
		
	_animar_movimiento(delta)

func _resolver_superposicion_con_player():
	if not anti_stack_enabled:
		return
	if not is_instance_valid(player_ref):
		return

	var vertical_delta: float = global_position.y - player_ref.global_position.y
	if vertical_delta <= anti_stack_max_vertical_delta:
		return

	var to_player: Vector3 = player_ref.global_position - global_position
	var horizontal_delta: Vector2 = Vector2(to_player.x, to_player.z)
	var horizontal_dist: float = horizontal_delta.length()
	if horizontal_dist > anti_stack_horizontal_radius:
		return

	var escape_dir_2d: Vector2
	if horizontal_dist > 0.05:
		escape_dir_2d = (-horizontal_delta).normalized()
	else:
		var fallback_2d: Vector2 = Vector2(global_transform.basis.x.x, global_transform.basis.x.z)
		if fallback_2d.length() < 0.01:
			fallback_2d = Vector2(1, 0)
		escape_dir_2d = fallback_2d.normalized() * (1.0 if strafe_dir >= 0 else -1.0)

	var escape_speed: float = base_speed * maxf(anti_stack_escape_speed_mult, 0.1)
	if can_sprint:
		escape_speed *= 1.1

	velocity.x = escape_dir_2d.x * escape_speed
	velocity.z = escape_dir_2d.y * escape_speed

	# Pequeño impulso para descolgarse del cuerpo del player sin romper ataques.
	if is_on_floor() and current_state != State.DODGING and current_state != State.PRE_DODGE:
		velocity.y = maxf(velocity.y, jump_force * 0.35)

# ------------------------------------------------------------------------------
# SUBSISTEMAS DE IA
# ------------------------------------------------------------------------------
func _process_aim_history(delta: float):
	if not is_instance_valid(player_ref): return
	if current_archetype != Archetype.RANGED_PROJECTILE and current_archetype != Archetype.RANGED_BEAM: return
	
	_position_timer += delta
	if _position_timer >= 0.05:
		_position_timer = 0.0
		_position_history.append(player_ref.global_position + Vector3(0, 1.2, 0))
		var max_history_size = max(1, int(aim_delay_seconds / 0.05))
		if _position_history.size() > max_history_size:
			_position_history.pop_front()
	
	if aim_inaccuracy_bloom > 0.0:
		_bloom_change_timer -= delta
		if _bloom_change_timer <= 0:
			_bloom_change_timer = aim_bloom_update_rate
			var dist = global_position.distance_to(player_ref.global_position)
			var b = aim_inaccuracy_bloom * (dist / 10.0)
			_target_bloom_offset = Vector3(randf_range(-b, b), 0.0, randf_range(-b, b))
		_current_bloom_offset = _current_bloom_offset.lerp(_target_bloom_offset, delta * 3.0)

func _process_mask_triggers(delta: float):
	if not is_instance_valid(player_ref) or current_state == State.PATROL: return
	
	_time_in_combat_timer += delta
	if _time_in_combat_timer >= 8.0:
		_check_mask_condition(MaskEquipCondition.AFTER_TIME_IN_COMBAT)
		
	if global_position.distance_to(player_ref.global_position) <= 6.5:
		_check_mask_condition(MaskEquipCondition.ON_PROXIMITY)

	_check_enemy_emergency_ultimate()

func _process_evasion_logic(delta: float):
	if evade_cooldown > 0.0: evade_cooldown -= delta
	if evade_cooldown > 0.0 or not is_instance_valid(player_ref): return
	if current_state == State.DODGING or current_state == State.PRE_DODGE or current_state == State.STUNNED: return

	var p_combat = player_ref.get_node_or_null("CombatManager")
	if not p_combat: return
	
	if p_combat.is_attacking_r or p_combat.is_attacking_l:
		# Mirar si el arma es a distancia
		var w_r = p_combat.slot_1_right
		var w_l = p_combat.slot_1_left
		var is_ranged_attack = false
		if (p_combat.is_attacking_r and w_r is RangedWeaponData) or (p_combat.is_attacking_l and w_l is RangedWeaponData):
			is_ranged_attack = true
		
		# Calcular distancia
		var dist = global_position.distance_to(player_ref.global_position)
		
		# Si es cuerpo a cuerpo y está muy lejos, no esquivar
		if not is_ranged_attack and dist > 4.0: return
		
		# Comprobar si me está mirando a MÍ (Dot product > 0.7 = Me está apuntando directamente a la cara)
		var dir_to_me = (global_position - player_ref.global_position).normalized()
		var player_forward = -player_ref.global_transform.basis.z.normalized()
		if player_forward.dot(dir_to_me) > 0.7:
			_intentar_esquivar(is_ranged_attack)

func _intentar_esquivar(is_ranged: bool):
	evade_cooldown = randf_range(2.0, 4.0) # Evitar spam
	
	var health_percent = 1.0
	if health_component and health_component.max_health > 0:
		health_percent = health_component.current_health / health_component.max_health
	
	# Probabilidad sube hasta un +50% extra si se está muriendo
	var current_chance = dodge_chance_base + ((1.0 - health_percent) * 0.5)
	
	# Si es a distancia, 30% más de probabilidad de asustarse y esquivar
	if is_ranged: current_chance += 0.3
	
	if randf() <= current_chance:
		# ¡Va a esquivar! Entramos en PRE_DODGE (delay humano)
		current_state = State.PRE_DODGE
		_dodge_timer = dodge_reaction_time
		_dodge_is_aggressive = false
		
		# Decidir dirección (-1, 0, 1). Atrás, Izquierda o Derecha. ESTRICTAMENTE DEFENSIVO.
		var options = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)] # (-X, +X, +Y para BlendSpace)
		_dodge_direction = options[randi() % options.size()]

func _procesar_pre_dodge(delta: float):
	_dodge_timer -= delta
	# Frenado sutil antes de saltar
	velocity.x = move_toward(velocity.x, 0, base_speed * 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, base_speed * 10.0 * delta)
	
	if _dodge_timer <= 0:
		_ejecutar_dodging()

func _ejecutar_dodging():
	current_state = State.DODGING
	var playback = anim_tree["parameters/StateMachine/playback"]
	
	# El BlendSpace de un enemigo espera una posición 2D. 
	# X = Izquierda/Derecha, Y = Adelante/Atrás (En Y invertido en Godot 3D, pero asumimos Y+ es atrás temporalmente)
	anim_tree.set("parameters/StateMachine/Dodge/blend_position", _dodge_direction)
	playback.travel("Dodge")
	
	# Transformar 2D Direction a 3D Global Direction basado en el ángulo del enemigo
	# X: 1 es derecha, -1 es izquierda. Y: 1 es adelante, -1 es atrás. 
	# En Godot, adelante local = -Z. Atrás local = +Z.
	var forward_local = -global_transform.basis.z * _dodge_direction.y
	var right_local = global_transform.basis.x * _dodge_direction.x
	var dir_3d = (forward_local + right_local).normalized()
	
	var multiplicador_potencia = 1.0
	if _dodge_is_aggressive: multiplicador_potencia = 1.8 # ¡Que se note violentamente el esquive hacia adelante!
	
	velocity.x = dir_3d.x * (dodge_power * multiplicador_potencia)
	velocity.z = dir_3d.z * (dodge_power * multiplicador_potencia)
	
	var prefijo = "[IA ENEMIGO] DEFENSIVE-DODGE" if not _dodge_is_aggressive else "[IA ENEMIGO] OFFENSIVE-DODGE"
	print(prefijo, " Fired. Dirección 2D (BlendSpace): ", _dodge_direction, " Potencia: ", (dodge_power * multiplicador_potencia))

func _procesar_dodging(delta: float):
	if is_instance_valid(player_ref):
		_mirar_hacia(player_ref.global_position, delta * 12.0) # FIX: Snap-Back, mirar al jugador mientras evade

	velocity.x = move_toward(velocity.x, 0, 40.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 40.0 * delta)
	move_and_slide()
	
	var playback = anim_tree["parameters/StateMachine/playback"]
	var current_node = str(playback.get_current_node())
	
	# El playback tarda 1 frame en actualizar. Usaremos un umbral de velocidad baja
	# para garantizar que no corta la animación a medio hacer.
	if current_node != "Dodge" and velocity.length() < 2.0:
		if _dodge_is_aggressive and is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) <= 4.0:
			# Si esquivó agresivamente hacia adelante y está cerca, ¡ATACA INMEDIATAMENTE!
			_iniciar_ataque_melee()
		else:
			current_state = State.CHASE 
			_entrar_cooldown(0.5) # Pausa cortita post-esquive

func _iniciar_esquive_ofensivo():
	current_state = State.PRE_DODGE
	_dodge_timer = dodge_reaction_time * 0.5 # Reacción más rápida al ser ofensivo
	_dodge_is_aggressive = true
	# OFENSIVO: ESTRICTAMENTE HACIA ADELANTE para acortar distancia y golpear
	_dodge_direction = Vector2(0, 1)

# ------------------------------------------------------------------------------
# LÓGICA DE ESTADOS
# ------------------------------------------------------------------------------
func _comportamiento_patrulla(delta):
	if nav_agent.is_navigation_finished():
		patrol_timer -= delta
		if patrol_timer <= 0:
			_buscar_punto_patrulla()
			patrol_timer = 4.0
	else:
		_mover_hacia(nav_agent.get_next_path_position(), delta, base_speed * 0.5)

func _comportamiento_persecucion(delta: float):
	if not is_instance_valid(player_ref): return
	var dist = global_position.distance_to(player_ref.global_position)
	
	# MEJORA: Entrar en combate un poco ANTES de llegar al límite
	if dist <= preferred_range:
		current_state = State.COMBAT_MANEUVER
		ai_decision_timer = 0.0 # ⚡ CERO espera. ¡Ataca ya!
		return

	var target_pos = player_ref.global_position
	
	# --- LÓGICA DE ZIG-ZAG ANTI-RANGED ---
	var aplicar_zigzag = false
	var speed_to_use = base_speed
	
	if can_sprint: speed_to_use *= sprint_speed_mult
	
	if can_dodge and dist > 4.0:
		var p_combat = player_ref.get_node_or_null("CombatManager")
		if p_combat:
			var w_r = p_combat.slot_1_right
			var w_l = p_combat.slot_1_left
			var is_ranged_equipped = (w_r is RangedWeaponData) or (w_l is RangedWeaponData)
			
			if is_ranged_equipped:
				var dir_to_me = (global_position - player_ref.global_position).normalized()
				var player_forward = -player_ref.global_transform.basis.z.normalized()
				# Si el jugador con alcance tiene la cámara apuntando cerca al enemigo (+0.8 dot)
				if player_forward.dot(dir_to_me) > 0.8:
					aplicar_zigzag = true

	if aplicar_zigzag:
		var dir_to_player = (player_ref.global_position - global_position).normalized()
		var right_vec = dir_to_player.cross(Vector3.UP)
		zigzag_time += delta
		
		# Cambiar impredeciblemente el zigzag
		if randf() < 0.05:
			_zigzag_amp = randf_range(1.5, 4.0)
			_zigzag_freq = randf_range(4.0, 10.0)
			
		var offset = right_vec * sin(zigzag_time * _zigzag_freq) * _zigzag_amp
		target_pos += offset

	_mover_hacia(target_pos, delta, speed_to_use)
	_mirar_hacia(player_ref.global_position, delta * 8.0)
	
	if can_jump and is_on_floor() and velocity.length() < 0.5 and randf() < 0.05:
		velocity.y = jump_force # Lógica simple de salto si está atascado
			
	if _intentar_maniobra_ofensiva(dist, (player_ref.global_position - global_position).normalized(), "Persecución"):
		return

func _comportamiento_combate(delta: float):
	if not is_instance_valid(player_ref): current_state = State.PATROL; return
	_mirar_hacia(player_ref.global_position, delta * aim_speed)
	
	ai_decision_timer -= delta
	if ai_decision_timer > 0: return

	var dist = global_position.distance_to(player_ref.global_position)
	
	# LÓGICA DE DECISIÓN AGRESIVA
	var can_attack = false
	
	if current_archetype == Archetype.MELEE_2H:
		if dist <= 3.2: can_attack = true # Margen generoso
	elif current_archetype == Archetype.MELEE_1H:
		if dist <= 2.5: can_attack = true # Margen generoso
	else:
		# Rango
		if dist < 15.0 and dist > 4.0: can_attack = true
		elif dist <= 4.0:
			_maniobra_alejarse(delta) # Demasiado cerca
			return 

	if can_attack:
		# Lógica de equipar máscara al atacar por primera vez
		_check_mask_condition(MaskEquipCondition.FIRST_ATTACK)
		
		# ¡ATACAR!
		if current_archetype == Archetype.MELEE_2H or current_archetype == Archetype.MELEE_1H:
			_iniciar_ataque_melee()
		elif current_archetype == Archetype.RANGED_BEAM:
			_iniciar_ataque_rayo()
		else:
			_iniciar_ataque_rango_unico()
	else:
		# ESTÁ CERCA PERO NO SUFICIENTE: ACERCARSE SIN CAMBIAR ESTADO
		var dir = (player_ref.global_position - global_position).normalized()
		var speed_to_use = base_speed * sprint_speed_mult if can_sprint else base_speed
		
		# Evaluar Dinámicas Ofensivas mientras intenta acortar distancia en combate
		if _intentar_maniobra_ofensiva(dist, dir, "Combate"):
			return
		
		velocity.x = dir.x * speed_to_use
		velocity.z = dir.z * speed_to_use
		# No cambiamos a STATE.CHASE, nos movemos manualmente en modo combate

func _intentar_maniobra_ofensiva(dist: float, dir: Vector3, estado_origen: String) -> bool:
	if can_jump and is_on_floor() and dist <= 5.5 and dist >= 3.5 and _next_combat_maneuver == "JUMP_ATTACK" and (current_archetype == Archetype.MELEE_1H or current_archetype == Archetype.MELEE_2H):
		print("[IA ENEMIGO] OFFENSIVE-JUMP Ejecutado en ", estado_origen, "! Distancia: ", round(dist))
		velocity.y = jump_force
		velocity.x = dir.x * base_speed * 3.0
		velocity.z = dir.z * base_speed * 3.0
		_next_combat_maneuver = ""
		
		# 🟢 CÁLCULO DINÁMICO DE TIEMPO DE VUELO
		var grav_real = gravity * gravity_multiplier
		# t = 2 * v0 / g (tiempo total de vuelo parabólico hasta el suelo)
		var tiempo_vuelo = (2.0 * jump_force) / grav_real
		
		# Restamos 0.15s para compensar la altura del jugador (el ataque debe chocar antes de tocar el suelo)
		tiempo_vuelo -= 0.15 
		
		# En lugar de _iniciar_ataque_melee() genérico, programamos cada mano:
		current_state = State.ATTACKING
		safety_attack_timer = 0.2
		
		var ataco = false
		if combat_manager.weapon_r:
			var effective_windup_r: float = combat_manager.weapon_r.windup_time
			if combat_manager.has_method("get_effective_windup_time"):
				effective_windup_r = combat_manager.get_effective_windup_time(combat_manager.weapon_r.windup_time, combat_manager.attack_speed_multiplier)
			var delay_r = max(0.0, tiempo_vuelo - effective_windup_r)
			_ataque_retrasado("right", delay_r)
			ataco = true
		if combat_manager.weapon_l:
			var effective_windup_l: float = combat_manager.weapon_l.windup_time
			if combat_manager.has_method("get_effective_windup_time"):
				effective_windup_l = combat_manager.get_effective_windup_time(combat_manager.weapon_l.windup_time, combat_manager.attack_speed_multiplier)
			var delay_l = max(0.0, tiempo_vuelo - effective_windup_l)
			_ataque_retrasado("left", delay_l)
			ataco = true
			
		if not ataco:
			_iniciar_ataque_melee() # Fallback si no hay armas
			
		return true

	if can_dodge and dist <= 3.75 and dist >= 2.0 and _next_combat_maneuver == "DODGE_ATTACK" and (current_archetype == Archetype.MELEE_1H or current_archetype == Archetype.MELEE_2H):
		print("[IA ENEMIGO] ¡Evasión Ofensiva (Dodge-Attack) Iniciada en ", estado_origen, "! Distancia: ", round(dist))
		_next_combat_maneuver = ""
		_iniciar_esquive_ofensivo()
		return true

	return false

# --- API PUNTERÍA (Retraso) ---
func get_aim_position() -> Vector3:
	var pos_to_shoot = global_position # Fallback
	
	if _position_history.size() > 0:
		pos_to_shoot = _position_history[0] # Usar la posición más vieja (retraso)
	elif is_instance_valid(player_ref):
		pos_to_shoot = player_ref.global_position + Vector3(0, 1.2, 0)
		
	if aim_inaccuracy_bloom > 0.0:
		pos_to_shoot += _current_bloom_offset
		
	return pos_to_shoot

func _iniciar_ataque_melee():
	if combat_manager.weapon_r:
		combat_manager.handle_right_click(true)
		combat_manager.handle_right_click(false)
	if combat_manager.weapon_l:
		combat_manager.handle_left_click(true)
		combat_manager.handle_left_click(false)
	
	current_state = State.ATTACKING
	safety_attack_timer = 0.2 

func _ataque_retrasado(mano: String, delay: float):
	if delay > 0:
		await get_tree().create_timer(delay, false).timeout
		# Validar que siga vivo y no paralizado ni esquivando tras la espera
		if not is_inside_tree() or current_state == State.STUNNED or current_state == State.DODGING: return
	
	if mano == "right" and combat_manager.weapon_r:
		combat_manager.handle_right_click(true)
		combat_manager.handle_right_click(false)
	elif mano == "left" and combat_manager.weapon_l:
		combat_manager.handle_left_click(true)
		combat_manager.handle_left_click(false)

func _iniciar_ataque_rango_unico():
	combat_manager.handle_left_click(true)
	combat_manager.handle_left_click(false)
	current_state = State.ATTACKING
	safety_attack_timer = 0.2

func _iniciar_ataque_rayo():
	combat_manager.handle_left_click(true)
	is_holding_attack = true
	hold_attack_timer = 3.0
	current_state = State.ATTACKING
	safety_attack_timer = 0.5

func _procesar_ataque_en_curso(delta):
	# Moverse lentamente hacia el jugador durante el ataque (Solo si estamos en el suelo!)
	if is_on_floor():
		if is_instance_valid(player_ref):
			var dir = (player_ref.global_position - global_position).normalized()
			var speed_to_use = base_speed * attack_movement_mult
			velocity.x = dir.x * speed_to_use
			velocity.z = dir.z * speed_to_use
		else:
			velocity.x = move_toward(velocity.x, 0, base_speed * delta)
			velocity.z = move_toward(velocity.z, 0, base_speed * delta)

	# Si el ataque apenas empezó, obligamos a esperar un poco
	if safety_attack_timer > 0:
		safety_attack_timer -= delta
		return

	if is_holding_attack:
		hold_attack_timer -= delta
		if hold_attack_timer <= 0: _finalizar_ataque_hold()
	else:
		if not combat_manager.is_attacking:
			# Cooldown reducido por agresividad
			var cd = randf_range(1.0, 2.0) / aggression
			_entrar_cooldown(cd)

func _finalizar_ataque_hold():
	combat_manager.handle_left_click(false)
	is_holding_attack = false
	_entrar_cooldown(2.0 / aggression)

func _maniobra_alejarse(delta):
	var dir = (global_position - player_ref.global_position).normalized()
	var retreat_speed = base_speed * sprint_speed_mult if can_sprint else base_speed
	velocity.x = dir.x * retreat_speed; velocity.z = dir.z * retreat_speed
	_mirar_hacia(player_ref.global_position, delta * 8.0)
	
	if global_position.distance_to(player_ref.global_position) > 7.0:
		current_state = State.COMBAT_MANEUVER

func _entrar_cooldown(tiempo):
	current_state = State.COOLDOWN
	ai_cooldown_timer = tiempo
	_decidir_proxima_maniobra()
	
func _decidir_proxima_maniobra():
	_next_combat_maneuver = ""
	if randf() < jump_attack_chance:
		_next_combat_maneuver = "JUMP_ATTACK"
	elif randf() < dodge_attack_chance:
		_next_combat_maneuver = "DODGE_ATTACK"
		
func _comportamiento_cooldown(delta):
	ai_cooldown_timer -= delta
	if is_instance_valid(player_ref): _mirar_hacia(player_ref.global_position, delta * 5.0)
	
	# Strafe lateral rápido
	var side = transform.basis.x * strafe_dir
	var strafe_speed = base_speed
	velocity.x = side.x * strafe_speed; velocity.z = side.z * strafe_speed
	
	if ai_cooldown_timer <= 0:
		strafe_dir *= -1
		current_state = State.COMBAT_MANEUVER
		ai_decision_timer = 0.0 # ¡Atacar inmediatamente al terminar CD!

# ------------------------------------------------------------------------------
# 6. MOVIMIENTO BASE Y UTILIDADES
# ------------------------------------------------------------------------------
func _mover_hacia_destino(delta, velocidad):
	var nav_map = nav_agent.get_navigation_map()
	var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
	var dist_to_nav = global_position.distance_to(closest)

	if dist_to_nav > 3.0: # ajusta este umbral
		velocity.x = 0
		velocity.z = 0
		return true
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
		return true 

	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0
	velocity.x = dir.x * velocidad
	velocity.z = dir.z * velocidad
	_mirar_hacia(next_pos, delta * 8.0)
	return false

# ------------------------------------------------------------------------------
# UTILIDADES Y EVENTOS
# ------------------------------------------------------------------------------
func _mover_hacia(target, delta, vel):
	var dir = (target - global_position).normalized()
	velocity.x = dir.x * vel; velocity.z = dir.z * vel
	_mirar_hacia(target, delta * 8.0)

func _mirar_hacia(target, factor_velocidad):
	var t_flat = Vector3(target.x, global_position.y, target.z)
	
	# Evitamos errores si el enemigo está exactamente sobre el jugador
	if global_position.distance_to(t_flat) < 0.1: return

	# Calculamos hacia dónde debería mirar
	var target_xform = global_transform.looking_at(t_flat, Vector3.UP)
	
	# Interpolamos suavemente (Slerp)
	# IMPORTANTE: Usamos 'factor_velocidad' directamente porque ya incluye el delta
	global_transform.basis = global_transform.basis.slerp(target_xform.basis, factor_velocidad)

func _buscar_punto_patrulla():
	nav_agent.target_position = global_position + Vector3(randf_range(-5,5), 0, randf_range(-5,5))

func _buscar_jugador():
	if not is_instance_valid(player_ref): player_ref = get_tree().get_first_node_in_group("Player") as Node3D
	if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) < vision_range:
		current_state = State.CHASE

func _animar_movimiento(delta):
	if not anim_tree: return
	
	var cur_blend = anim_tree.get(P_MOVIMIENTO)
	var target_blend = Vector2.ZERO
	
	if velocity.length() > 0.1:
		# Convertimos la velocidad global a local (relativa a donde mira el enemigo)
		var local_vel = global_transform.basis.inverse() * velocity
		
		# En Godot 3D, adelante es -Z (Y en el blendspace), derecha es +X (X en el blendspace)
		target_blend = Vector2(local_vel.x, -local_vel.z) / base_speed
		
		# Limitamos visualmente para no romper la animación si va a súper velocidad
		var max_len = sprint_speed_mult if can_sprint else 1.0
		if target_blend.length() > max_len:
			target_blend = target_blend.normalized() * max_len
			
	anim_tree.set(P_MOVIMIENTO, cur_blend.lerp(target_blend, delta * 5.0))

# --- KNOCKBACK Y DAÑO ---
func apply_knockback(direction: Vector3, force: float, vertical_force: float):
	knockback_velocity = direction * force
	if vertical_force > 0 and is_on_floor(): velocity.y += vertical_force
	
	# Interrupción (Stagger)
	if force > 6.0:
		combat_manager.is_attacking_r = false
		combat_manager.is_attacking_l = false
		current_state = State.COOLDOWN
		ai_cooldown_timer = 0.4
		flash_red()

func equipar_mascara_guardada():
	if mask_manager and loadout_mask and mask_handling == MaskHandling.EN_INVENTARIO:
		mask_manager.equip_mask(loadout_mask, false) # false = animate spawn

func _uses_enemy_ultimate_roll_system() -> bool:
	return true

func _initialize_enemy_ultimate_roll():
	_has_ultimate_roll = true
	_can_activate_ultimate = false
	_ultimate_proc_chance = 0.0
	_ultimate_hits_dealt = 0
	_ultimate_hits_received = 0
	_forced_low_health_ultimate_used = false

	if not _uses_enemy_ultimate_roll_system():
		return

	if mask_handling == MaskHandling.SIN_MASCARA:
		return

	if not loadout_mask:
		return

	_can_activate_ultimate = randf() <= (ultimate_instance_chance_with_mask / 100.0)

func _can_try_enemy_ultimate() -> bool:
	if not _uses_enemy_ultimate_roll_system():
		return false
	if not _has_ultimate_roll or not _can_activate_ultimate:
		return false
	if not mask_manager or not mask_manager.current_mask:
		return false
	if mask_manager.is_ultimate_active:
		return false
	return true

func _activate_enemy_ultimate(reason: String):
	if not _can_try_enemy_ultimate():
		return

	mask_manager.current_ult_charge = mask_manager.max_ult_charge
	mask_manager.activate_ultimate()

	if mask_manager.is_ultimate_active:
		_ultimate_proc_chance = 0.0

func _check_enemy_emergency_ultimate():
	if _forced_low_health_ultimate_used:
		return
	if not _can_try_enemy_ultimate():
		return
	if not health_component or health_component.max_health <= 0:
		return

	var hp_ratio := health_component.current_health / health_component.max_health
	if hp_ratio <= 0.33:
		_forced_low_health_ultimate_used = true
		_activate_enemy_ultimate("LOW_HEALTH_33")

func _register_enemy_ultimate_event(event_name: String):
	if not _can_try_enemy_ultimate():
		return

	_check_enemy_emergency_ultimate()
	if mask_manager and mask_manager.is_ultimate_active:
		return

	_ultimate_proc_chance = clampf(_ultimate_proc_chance + 10.0, 0.0, 100.0)
	if randf() * 100.0 <= _ultimate_proc_chance:
		_activate_enemy_ultimate(event_name)

func _on_attack_hit_landed(_target: Node = null):
	_ultimate_hits_dealt += 1
	_register_enemy_ultimate_event("HIT_DEALT")

func _check_mask_condition(trigger: MaskEquipCondition):
	if mask_handling != MaskHandling.EN_INVENTARIO: return
	if mask_manager and mask_manager.current_mask: return # Ya equipada
	if not loadout_mask: return # No tiene nada
	
	if mask_equip_condition == trigger or mask_equip_condition == MaskEquipCondition.ANY:
		equipar_mascara_guardada()

func _on_damage_received(a, c):
	flash_red()
	if current_state == State.PATROL: current_state = State.CHASE
	
	# ON-HIT DODGE REACTIVO (Para armas a distancia)
	if can_dodge and current_state != State.DODGING and current_state != State.PRE_DODGE:
		# Si recibe daño repentino de lejos (más de 3 metros), asume proyectil e intenta esquivar sutilmente si es capaz.
		if is_instance_valid(player_ref) and global_position.distance_to(player_ref.global_position) > 3.0:
			_intentar_esquivar(true)
	
	_check_mask_condition(MaskEquipCondition.FIRST_HIT_RECEIVED)
	
	if health_component:
		if health_component.current_health <= health_component.max_health * 0.5:
			_check_mask_condition(MaskEquipCondition.HALF_HEALTH)
		if health_component.current_health <= health_component.max_health * 0.25:
			_check_mask_condition(MaskEquipCondition.LOW_HEALTH_DESPERATION)

	_ultimate_hits_received += 1
	_register_enemy_ultimate_event("HIT_RECEIVED")
	_check_enemy_emergency_ultimate()

func _morir():
	if is_instance_valid(player_ref) and player_ref.has_node("MaskManager"):
		player_ref.get_node("MaskManager").add_charge(combat_manager.ult_charge_reward)
	set_physics_process(false)
	queue_free()

# --- VISUALES ---
func _setup_unique_materials():
	if not visual_mesh: return
	unique_materials.clear()
	original_colors.clear()
	_buscar_meshes_recursivo(visual_mesh)

func _buscar_meshes_recursivo(n):
	if n is MeshInstance3D:
		for i in range(n.get_surface_override_material_count()):
			var m = n.get_active_material(i)
			if m:
				var u = m.duplicate(); n.set_surface_override_material(i, u)
				unique_materials.append(u); original_colors[u] = u.albedo_color
	for c in n.get_children(): _buscar_meshes_recursivo(c)

func flash_red():
	if flash_tween: flash_tween.kill()
	for m in unique_materials: m.albedo_color = Color(1, 0.2, 0.2)
	flash_tween = create_tween()
	for m in unique_materials:
		if m in original_colors: flash_tween.parallel().tween_property(m, "albedo_color", original_colors[m], 0.2)

func _get_effective_aura_color(mask_data: MaskData) -> Color:
	var aura_c: Color = mask_data.aura_color
	var looks_default_white: bool = (
		is_equal_approx(aura_c.r, 1.0)
		and is_equal_approx(aura_c.g, 1.0)
		and is_equal_approx(aura_c.b, 1.0)
	)

	if looks_default_white:
		aura_c = mask_data.screen_tint

	aura_c.a = clampf(mask_data.aura_alpha, 0.0, 1.0)
	return aura_c

func _activar_aura_mascara(is_ult: bool = false):
	if not mask_manager or not mask_manager.current_mask: return
	if unique_materials.is_empty(): _setup_unique_materials()
	if unique_materials.is_empty(): return

	var mask_data: MaskData = mask_manager.current_mask
	if not mask_data.aura_enabled:
		for m in unique_materials: m.next_pass = null
		return

	var aura_alpha_mult: float = mask_data.ult_aura_alpha_mult if is_ult else 1.0
	var aura_emission_mult: float = mask_data.ult_aura_emission_mult if is_ult else 1.0
	var aura_grow_mult: float = mask_data.ult_aura_grow_mult if is_ult else 1.0

	var c: Color = _get_effective_aura_color(mask_data)
	c.a = clampf(c.a * aura_alpha_mult, 0.0, 1.0)
	var emission_c: Color = c
	emission_c.a = 1.0

	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.albedo_color = c
	mat.emission = emission_c
	mat.emission_enabled = true
	mat.emission_energy = maxf(0.0, mask_data.aura_emission_energy * aura_emission_mult)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = maxf(0.0, mask_data.aura_grow_amount * aura_grow_mult)
	for m in unique_materials: m.next_pass = mat

func _on_mask_changed_event(data: MaskData):
	if data != null:
		var is_ult_active := mask_manager != null and mask_manager.is_ultimate_active
		_activar_aura_mascara(is_ult_active)
	else:
		for m in unique_materials: m.next_pass = null

func _on_ultimate_visuals(is_active: bool):
	if not mask_manager or not mask_manager.current_mask:
		return
	_activar_aura_mascara(is_active)
