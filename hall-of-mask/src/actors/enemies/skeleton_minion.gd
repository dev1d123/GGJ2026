extends CharacterBody3D
class_name EnemyAI 

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN Y REFERENCIAS
# ------------------------------------------------------------------------------
@export_group("Configuración Visual")
@export var visual_mesh: Node3D # Asigna aquí el Mesh del Esqueleto, Goblin, etc.

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: RayCast3D = $VisionManager/Eyes

# --- SISTEMAS MODULARES ---
@onready var combat_manager: CombatManager = $CombatManager
@onready var health_component: HealthComponent = $HealthComponent
# Asigna el AnimationTree de tu enemigo aquí. Si cada enemigo tiene uno distinto, 
# asegúrate de que el nombre del nodo hijo coincida o reasígnalo en el editor.
@onready var anim_tree: AnimationTree = $AnimationTree 

const P_MOVIMIENTO = "parameters/StateMachine/Standing/blend_position"

# ------------------------------------------------------------------------------
# 2. VARIABLES DE IA
# ------------------------------------------------------------------------------
@export_category("Atributos Base")
@export var base_speed: float = 2.5
@export var vision_range: float = 15.0

# Variables Dinámicas (Se autoconfiguran según el arma)
var current_speed: float
var attack_range: float = 1.8 
var aggression: float = 1.0 
var archetype: String = "Duelista"

enum State { PATROL, CHASE, ATTACK, COOLDOWN }
var current_state = State.PATROL
var player_ref: Node3D = null
var patrol_timer = 0.0
var ai_cooldown_timer = 0.0 
var _last_vision_blocker = "" 

# Físicas
var gravity = 9.8
var knockback_velocity: Vector3 = Vector3.ZERO
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween

# ------------------------------------------------------------------------------
# 3. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready():
	# Si el AnimationTree está dentro del modelo importado, búscalo dinámicamente si falla el onready
	if not anim_tree:
		var visual = get_node_or_null("Visual") # O como se llame tu nodo modelo
		if visual and visual.has_node("AnimationTree"):
			anim_tree = visual.get_node("AnimationTree")
	
	if anim_tree: anim_tree.active = true
	
	print("\n🤖 --- INICIANDO IA GENÉRICA: ", name, " ---")
	
	# 1. EQUIPAR ARMAS Y ANALIZAR LOADOUT
	if combat_manager:
		if combat_manager.slot_1_right:
			combat_manager.equip_weapon(combat_manager.slot_1_right, "right")
		if combat_manager.slot_1_left:
			combat_manager.equip_weapon(combat_manager.slot_1_left, "left")
		
		_analizar_armamento()
	
	# 2. CONEXIONES
	if health_component:
		health_component.on_death.connect(_morir)
		health_component.on_damage_received.connect(_on_damage_visual)
	
	_setup_unique_materials()
	if eyes: eyes.add_exception(self)
	call_deferred("_buscar_punto_patrulla")

func _analizar_armamento():
	current_speed = base_speed
	var w_r = combat_manager.weapon_r
	var w_l = combat_manager.weapon_l
	
	# LÓGICA DE ARQUETIPOS
	if w_r and w_r.is_two_handed:
		archetype = "Verdugo"
		attack_range = 2.5 
		current_speed = base_speed * 0.8
		print(name, ": Arquetipo VERDUGO")
	elif w_r and w_l:
		archetype = "Berserker"
		attack_range = 1.5 
		current_speed = base_speed * 1.4 
		aggression = 2.0 
		print(name, ": Arquetipo BERSERKER")
	else:
		archetype = "Duelista"
		attack_range = 1.8
		print(name, ": Arquetipo DUELISTA")

# ------------------------------------------------------------------------------
# 4. FÍSICAS Y ESTADOS
# ------------------------------------------------------------------------------
func _physics_process(delta):
	# Gravedad
	if not is_on_floor(): velocity.y -= gravity * delta

	# Knockback
	if knockback_velocity.length() > 0.5:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 10.0 * delta)
		velocity.x = knockback_velocity.x; velocity.z = knockback_velocity.z
		move_and_slide(); return 

	# Ataque (Movimiento reducido pero existente)
	if combat_manager.is_attacking:
		var attack_move_speed = 0.5
		if archetype == "Berserker": attack_move_speed = 2.0 
		
		if combat_manager.is_movement_locked:
			velocity.x = move_toward(velocity.x, 0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 20.0 * delta)
		else:
			# Avanza un poco hacia donde mira
			var dir = -global_transform.basis.z
			velocity.x = dir.x * attack_move_speed
			velocity.z = dir.z * attack_move_speed
		
		if player_ref: _rotar_hacia(player_ref.global_position, delta * 10.0)
		move_and_slide(); return

	# MÁQUINA DE ESTADOS
	match current_state:
		State.PATROL:
			_procesar_patrulla(delta)
			_buscar_jugador()
		
		State.CHASE:
			_procesar_persecucion(delta)
			
		State.COOLDOWN:
			# --- FIX DEL BUG: AHORA SE MUEVEN EN COOLDOWN ---
			ai_cooldown_timer -= delta
			_procesar_cooldown_tactico(delta) # Nueva función de movimiento
			
			if ai_cooldown_timer <= 0:
				current_state = State.CHASE
	
	move_and_slide()
	_animar_movimiento(delta)

# ------------------------------------------------------------------------------
# 5. COMPORTAMIENTOS TÁCTICOS
# ------------------------------------------------------------------------------
func _procesar_cooldown_tactico(delta):
	if not player_ref: return
	
	# Siempre miramos al jugador (amenazante)
	_rotar_hacia(player_ref.global_position, delta * 4.0)
	
	# Lógica de movimiento según arquetipo
	var dir_to_player = global_position.direction_to(player_ref.global_position)
	var dist = global_position.distance_to(player_ref.global_position)
	
	var move_dir = Vector3.ZERO
	var tactical_speed = current_speed * 0.6 # Se mueven más lento al recuperar
	
	match archetype:
		"Berserker":
			# Se mueve lateralmente (Strafe) para buscar flancos
			move_dir = dir_to_player.rotated(Vector3.UP, deg_to_rad(90))
			if randf() > 0.5: move_dir = -move_dir # Aleatorio izq/der
			
		"Verdugo":
			# No retrocede mucho, es un tanque. Se queda firme o avanza muy lento.
			if dist > 3.0: move_dir = dir_to_player # Recupera terreno lento
			else: move_dir = Vector3.ZERO # Se planta
			
		"Duelista":
			# Retrocede para esquivar contraataques
			if dist < 2.5: move_dir = -dir_to_player # Backstep
			else: move_dir = dir_to_player.rotated(Vector3.UP, deg_to_rad(45)) # Strafe circular
	
	# Aplicar movimiento
	velocity.x = move_toward(velocity.x, move_dir.x * tactical_speed, 2.0)
	velocity.z = move_toward(velocity.z, move_dir.z * tactical_speed, 2.0)

func _procesar_persecucion(delta):
	if not player_ref: return
	nav_agent.target_position = player_ref.global_position
	_mover_hacia_destino(delta, current_speed)
	
	var dist = global_position.distance_to(player_ref.global_position)
	
	if dist <= attack_range:
		_ejecutar_estrategia_combate()
	elif dist > vision_range * 1.5:
		current_state = State.PATROL
		_buscar_punto_patrulla()

func _ejecutar_estrategia_combate():
	if combat_manager.is_attacking: return

	match archetype:
		"Berserker":
			if randf() < 0.7: _ataque_frenesi_dual()
			else: combat_manager.try_attack("right")
		
		"Verdugo":
			combat_manager.try_attack("right")
			_entrar_cooldown(1.5) # Pausa larga

		"Duelista":
			if combat_manager.cd_timer_r <= 0:
				combat_manager.try_attack("right")
			_entrar_cooldown(0.8) # Pausa media

func _ataque_frenesi_dual():
	combat_manager.try_attack("right")
	await get_tree().create_timer(0.15).timeout
	combat_manager.try_attack("left")
	_entrar_cooldown(1.0)

func _entrar_cooldown(tiempo):
	if aggression > 1.5: tiempo *= 0.5 # Berserkers descansan menos
	current_state = State.COOLDOWN
	ai_cooldown_timer = tiempo

# ------------------------------------------------------------------------------
# 6. MOVIMIENTO BASE Y UTILIDADES
# ------------------------------------------------------------------------------
func _mover_hacia_destino(delta, velocidad):
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
		return true 

	var next_pos = nav_agent.get_next_path_position()
	var dir = (next_pos - global_position).normalized()
	dir.y = 0 
	
	velocity.x = dir.x * velocidad
	velocity.z = dir.z * velocidad
	_rotar_hacia(next_pos, delta * 8.0)
	return false

func _rotar_hacia(target, speed_rot):
	var target_flat = Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(target_flat) > 0.1:
		var new_transform = global_transform.looking_at(target_flat, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(new_transform.basis, speed_rot)

func _animar_movimiento(delta):
	if not anim_tree: return
	var vel_real = Vector2(velocity.x, velocity.z).length()
	var blend_val = clamp(vel_real / base_speed, 0.0, 1.0) 
	var target = Vector2(0, blend_val)
	
	var actual = anim_tree.get(P_MOVIMIENTO)
	if actual == null: actual = Vector2.ZERO
	anim_tree.set(P_MOVIMIENTO, actual.lerp(target, delta * 8.0))

func _buscar_punto_patrulla():
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var destino = global_position + (random_dir * 5.0)
	nav_agent.target_position = destino

func _procesar_patrulla(delta):
	var llego = _mover_hacia_destino(delta, current_speed * 0.5)
	if llego:
		patrol_timer += delta
		if patrol_timer > 3.0:
			_buscar_punto_patrulla()
			patrol_timer = 0.0

func _buscar_jugador():
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("Player")
		if not player_ref: return
	
	var dist = global_position.distance_to(player_ref.global_position)
	if dist > vision_range: return 
	
	eyes.look_at(player_ref.global_position + Vector3(0, 1.0, 0))
	eyes.force_raycast_update()
	
	if eyes.is_colliding():
		var col = eyes.get_collider()
		if col and (col == player_ref or col.is_in_group("Player")):
			current_state = State.CHASE
			_last_vision_blocker = "" 

# ------------------------------------------------------------------------------
# 7. EVENTOS
# ------------------------------------------------------------------------------
func apply_knockback(dir: Vector3, knock: float, jump: float):
	knockback_velocity = dir * knock
	if is_on_floor(): velocity.y += jump

func _on_damage_visual(amount, current):
	flash_red()
	if current_state == State.PATROL:
		current_state = State.CHASE
		_buscar_jugador()

func _morir():
	print("💀 Enemigo destruido.")
	var reward_amount = 0.0
	if combat_manager: reward_amount = combat_manager.ult_charge_reward
	
	var target_player = player_ref
	if not target_player: target_player = get_tree().get_first_node_in_group("Player")
	if target_player and target_player.has_node("MaskManager"):
		target_player.get_node("MaskManager").add_charge(reward_amount)
	
	set_physics_process(false)
	queue_free()

func _setup_unique_materials():
	# 1. Validación de seguridad
	if not visual_mesh:
		print("⚠️ ERROR VISUAL: No has asignado el 'Visual Mesh' en el Inspector de ", name)
		return
		
	unique_materials.clear()
	# Iniciamos la búsqueda profunda
	_buscar_meshes_recursivo(visual_mesh)
	
	print("✨ Materiales únicos creados: ", unique_materials.size())
	
# Función auxiliar que busca mallas dentro de mallas dentro de huesos...
func _buscar_meshes_recursivo(nodo: Node):
	# Si encontramos una malla visual...
	if nodo is MeshInstance3D:
		# Recorremos TODAS sus superficies (por si tiene varias texturas)
		for i in range(nodo.get_surface_override_material_count()):
			var mat = nodo.get_active_material(i)
			
			# Verificamos que sea un material válido para cambiar color
			# (Aceptamos StandardMaterial3D y ORMMaterial3D que es el estándar de Godot 4)
			if mat and (mat is StandardMaterial3D or mat is ORMMaterial3D):
				var unique = mat.duplicate()
				nodo.set_surface_override_material(i, unique)
				unique_materials.append(unique)
	
	# Seguimos buscando en los hijos de este nodo
	for child in nodo.get_children():
		_buscar_meshes_recursivo(child)

func flash_red():
	if unique_materials.is_empty(): 
		# Si falla, intentamos configurarlos de nuevo por si acaso
		_setup_unique_materials()
		if unique_materials.is_empty(): return

	if flash_tween: flash_tween.kill()
	
	# Pintamos ROJO
	for mat in unique_materials: 
		mat.albedo_color = Color(1, 0.2, 0.2) # Rojo brillante
		# Si el material tiene emisión, la activamos para que brille en la oscuridad
		if mat.emission_enabled:
			mat.emission = Color(1, 0, 0) 
	
	# Animamos de vuelta a BLANCO
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	for mat in unique_materials: 
		flash_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.2)
		if mat.emission_enabled:
			flash_tween.tween_property(mat, "emission", Color.BLACK, 0.2)
