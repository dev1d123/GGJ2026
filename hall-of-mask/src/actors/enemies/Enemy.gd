extends CharacterBody3D
class_name Enemy

# ------------------------------------------------------------------------------
# LOADOUT RÁPIDO (Sobrescribe al CombatManager)
# ------------------------------------------------------------------------------
@export_group("Loadout Inicial (Opcional)")
@export var loadout_weapon_r: WeaponData ## Arma Derecha (o 2 Manos)
@export var loadout_weapon_l: WeaponData ## Arma Izquierda (Dual Wield)
@export var loadout_mask: MaskData       ## Máscara Inicial

# --- SISTEMAS MODULARES ---
@onready var combat_manager: CombatManager = $CombatManager
@onready var health_component: HealthComponent = $HealthComponent
@export var anim_tree: AnimationTree
# AGREGAMOS REFERENCIA AL MASK MANAGER (Si no la tenías)
@onready var mask_manager: MaskManager = $MaskManager

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN Y REFERENCIAS
# ------------------------------------------------------------------------------
@export_group("Configuración Visual")
@export var visual_mesh: Node3D # Asigna aquí el Mesh del Esqueleto, Goblin, etc.

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: RayCast3D = $VisionManager/Eyes

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

# --- VARIABLES RECEPTORAS DE MÁSCARA ---
# Estas variables son modificadas por el MaskManager automáticamente
var mask_speed_mult: float = 1.0
var mask_defense_mult: float = 1.0:
	set(value):
		mask_defense_mult = value
		# Si tiene componente de vida, actualizamos su defensa real
		if health_component: health_component.defense_multiplier = value

# Físicas
var gravity = 9.8
var knockback_velocity: Vector3 = Vector3.ZERO
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween

# --- VARIABLES VISUALES EXTRA ---
# Diccionario para recordar el color original de cada parte (Ej: Ojos->Amarillo, Huesos->Blanco)
var original_colors: Dictionary = {}

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
	
	# -----------------------------------------------------------
	# 1. APLICAR LOADOUT RÁPIDO (NUEVO BLOQUE)
	# -----------------------------------------------------------
	# Si definiste armas en el Inspector del Enemigo, úsalas.
	if combat_manager:
		if loadout_weapon_r:
			combat_manager.equip_weapon(loadout_weapon_r, "right")
		if loadout_weapon_l:
			combat_manager.equip_weapon(loadout_weapon_l, "left")
			
		# Si NO hay loadout rápido, intentamos cargar lo que tenga el CombatManager por defecto
		# (Esto es retro-compatibilidad por si ya configuraste algunos a mano dentro del nodo)
		if not loadout_weapon_r and not loadout_weapon_l:
			if combat_manager.slot_1_right:
				combat_manager.equip_weapon(combat_manager.slot_1_right, "right")
			if combat_manager.slot_1_left:
				combat_manager.equip_weapon(combat_manager.slot_1_left, "left")

	# -----------------------------------------------------------
	# 2. APLICAR MÁSCARA (NUEVO BLOQUE)
	# -----------------------------------------------------------
	if mask_manager and loadout_mask:
		mask_manager.equip_mask(loadout_mask)
		# Nota: Como es IA, quizás quieras activar la ulti automáticamente bajo cierta condición,
		# o dejar que los stats pasivos (velocidad/defensa) hagan su trabajo.
		print(name, ": Máscara equipada -> ", loadout_mask.mask_name)

	# -----------------------------------------------------------
	# 3. ANALIZAR ARQUETIPO (Ahora detectará las nuevas armas)
	# -----------------------------------------------------------
	if combat_manager:
		_analizar_armamento()
	
	# 4. CONEXIONES
	if health_component:
		health_component.on_death.connect(_morir)
		health_component.on_damage_received.connect(_on_damage_visual)
	
	if mask_manager:
		mask_manager.on_ultimate_state.connect(_on_ultimate_visuals)
	
	_setup_unique_materials()
	if eyes: eyes.add_exception(self)
	
	# --- ¡LLÁMALO AL FINAL! ---
	# Después de setup_unique_materials para que existan los materiales
	if mask_manager and mask_manager.current_mask:
		_activar_aura_mascara()
	
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
	_mover_hacia_destino(delta, current_speed * mask_speed_mult)
	
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

# --- EFECTOS VISUALES ---

func _setup_unique_materials():
	if not visual_mesh:
		print("⚠️ ERROR VISUAL: No has asignado el 'Visual Mesh' en el Inspector de ", name)
		return
		
	unique_materials.clear()
	original_colors.clear() # Limpiamos la memoria de colores
	
	_buscar_meshes_recursivo(visual_mesh)
	
	print("✨ Materiales configurados. Colores guardados: ", original_colors.size())

func _buscar_meshes_recursivo(nodo: Node):
	if nodo is MeshInstance3D:
		for i in range(nodo.get_surface_override_material_count()):
			var mat = nodo.get_active_material(i)
			if mat and (mat is StandardMaterial3D or mat is ORMMaterial3D):
				var unique = mat.duplicate()
				nodo.set_surface_override_material(i, unique)
				unique_materials.append(unique)
				
				# GUARDAMOS EL COLOR ORIGINAL AQUÍ
				original_colors[unique] = unique.albedo_color
	
	for child in nodo.get_children():
		_buscar_meshes_recursivo(child)

func flash_red():
	if unique_materials.is_empty(): 
		_setup_unique_materials()
		if unique_materials.is_empty(): return

	if flash_tween: flash_tween.kill()
	
	# 1. GOLPE ROJO (Solo afecta al cuerpo, el aura sigue ahí)
	for mat in unique_materials: 
		mat.albedo_color = Color(1, 0.2, 0.2) 
	
	# 2. RECUPERACIÓN (Volver al color de piel original)
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	
	for mat in unique_materials:
		var target_albedo = Color.WHITE
		if mat in original_colors:
			target_albedo = original_colors[mat]
			
		flash_tween.tween_property(mat, "albedo_color", target_albedo, 0.2)

func _activar_aura_mascara():
	if not mask_manager or not mask_manager.current_mask: 
		return
	if unique_materials.is_empty():
		_setup_unique_materials()
	
	# 1. Configurar el Color
	var color_aura = mask_manager.current_mask.screen_tint
	color_aura.a = 0.2 # Transparencia (0.1 leve, 0.5 fuerte)
	
	# 2. Crear el Material del Aura (Cáscara)
	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = color_aura
	aura_mat.emission_enabled = true
	aura_mat.emission = color_aura
	aura_mat.emission_energy = 3.0 # Qué tanto brilla
	
	# TRUCO DEL OUTLINE/AURA:
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD # Modo aditivo (tipo luz/energía)
	aura_mat.cull_mode = BaseMaterial3D.CULL_FRONT     # Renderizar caras internas
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # No le afectan sombras
	aura_mat.grow = true        # Expandir la malla
	aura_mat.grow_amount = 0.03 # Grosor del aura (0.02 a 0.05 es ideal)
	
	# 3. Aplicar como "Siguiente Pase" a los materiales existentes
	for mat in unique_materials:
		mat.next_pass = aura_mat
	
	print(name, ": ✨ Aura externa activada color ", color_aura)
	
func _on_ultimate_visuals(is_active: bool):
	if unique_materials.is_empty(): return
	
	print(name, ": 🔥 CAMBIO VISUAL ULTI -> ", is_active)
	
	var target_energy = 2.0 # Energía normal
	var target_grow = 0.03  # Grosor normal
	
	if is_active:
		target_energy = 8.0 # ¡MUCHO MÁS BRILLO!
		target_grow = 0.08  # Aura más gruesa (Super Saiyan)
	
	# Aplicamos los cambios al material "Next Pass" (el aura)
	for mat in unique_materials:
		if mat.next_pass:
			var aura = mat.next_pass
			# Usamos un tween para que la transición sea épica
			var t = create_tween()
			t.set_parallel(true)
			t.tween_property(aura, "emission_energy", target_energy, 0.5)
			t.tween_property(aura, "grow_amount", target_grow, 0.5)
