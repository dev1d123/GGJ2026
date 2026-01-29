extends CharacterBody3D

# ------------------------------------------------------------------------------
# 1. REFERENCIAS Y CONFIGURACIÓN
# ------------------------------------------------------------------------------
@export_group("Referencias")
@export var skeleton_mesh: Node3D 
@export var hand_attachment: Node3D 
@export var weapon_data: WeaponData 

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: RayCast3D = $VisionManager/Eyes
@onready var health_component = $HealthComponent

# Animación (Ajustado a tu estructura)
@onready var anim_tree = $Skeleton_Minion/AnimationTree 
@onready var sm_base = anim_tree["parameters/StateMachine/playback"]
@onready var sm_combat = anim_tree["parameters/Combat_2H/playback"]

# Rutas de Parámetros
const P_BLEND_2H = "parameters/Mezcla_2H/blend_amount"
const P_MOVIMIENTO = "parameters/StateMachine/Standing/blend_position"

# Variables de Juego
var speed = 2.5
var gravity = 9.8
var attack_range = 1.8 
var vision_range = 15.0

# Variables Internas
enum State { PATROL, CHASE, ATTACK }
var current_state = State.PATROL
var player_ref: Node3D = null
var current_weapon_hitbox: Area3D = null 
var is_attacking = false
var patrol_timer = 0.0
var debug_timer = 0.0 

# Efectos
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween
var _last_vision_blocker = ""

@export var skeleteon_damage = 1

# ------------------------------------------------------------------------------
# 2. INICIALIZACIÓN
# ------------------------------------------------------------------------------
func _ready():
	print("\n💀 --- INICIANDO ESQUELETO ---")
	
	if anim_tree:
		anim_tree.active = true
		# Igual que en tu combat_manager: Todo a 0 al inicio
		anim_tree.set("parameters/Mezcla_R/blend_amount", 0.0)
		anim_tree.set("parameters/Mezcla_L/blend_amount", 0.0)
		anim_tree.set(P_BLEND_2H, 0.0) 
		sm_base.travel("Standing")
		print("✅ Animaciones configuradas (Mezclas en 0).")
	
	_equipar_arma()
	_setup_unique_materials()
	
	if health_component: 
		health_component.on_death.connect(_morir)
	
	eyes.add_exception(self)
	
	call_deferred("_buscar_punto_patrulla")

# ------------------------------------------------------------------------------
# 3. FÍSICA Y LÓGICA PRINCIPAL
# ------------------------------------------------------------------------------
func _physics_process(delta):
	# Debug cada 1 segundo
	debug_timer += delta
	if debug_timer > 1.0:
		# _imprimir_estado_debug() # Descomenta si quieres ver velocidad
		debug_timer = 0.0

	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	match current_state:
		State.PATROL:
			_procesar_patrulla(delta)
			_buscar_jugador()
		
		State.CHASE:
			_procesar_persecucion(delta)
		
		State.ATTACK:
			# ESTILO MINECRAFT: Girar hacia el jugador MIENTRAS ataca
			if player_ref:
				_rotar_hacia(player_ref.global_position, delta * 10.0)
			
			# Frenar casi en seco
			velocity.x = move_toward(velocity.x, 0, 1.0)
			velocity.z = move_toward(velocity.z, 0, 1.0)

	move_and_slide()
	_animar_movimiento(delta)

# ------------------------------------------------------------------------------
# 4. SISTEMA DE MOVIMIENTO (UNIVERSAL)
# ------------------------------------------------------------------------------
func _mover_hacia_destino(delta, velocidad_base):
	if nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, 1.0)
		velocity.z = move_toward(velocity.z, 0, 1.0)
		return true 

	var next_pos = nav_agent.get_next_path_position()
	var vector_direccion = next_pos - global_position
	vector_direccion.y = 0 
	
	if vector_direccion.length() > 0.01:
		var dir = vector_direccion.normalized()
		velocity.x = dir.x * velocidad_base
		velocity.z = dir.z * velocidad_base
		_rotar_hacia(next_pos, delta * 8.0)
	
	return false

func _rotar_hacia(target, speed_rot):
	var target_flat = Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(target_flat) > 0.1:
		var new_transform = global_transform.looking_at(target_flat, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(new_transform.basis, speed_rot)

# ------------------------------------------------------------------------------
# 5. ESTADOS IA
# ------------------------------------------------------------------------------
func _procesar_patrulla(delta):
	var llego = _mover_hacia_destino(delta, speed * 0.5)
	if llego:
		patrol_timer += delta
		if patrol_timer > 3.0:
			_buscar_punto_patrulla()
			patrol_timer = 0.0

func _buscar_punto_patrulla():
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var destino = global_position + (random_dir * 5.0)
	nav_agent.target_position = destino

func _procesar_persecucion(delta):
	if not player_ref: return
	nav_agent.target_position = player_ref.global_position
	
	_mover_hacia_destino(delta, speed)
	
	var dist = global_position.distance_to(player_ref.global_position)
	
	if dist <= attack_range:
		_iniciar_ataque()
	elif dist > vision_range * 1.5:
		current_state = State.PATROL
		_buscar_punto_patrulla()

# ------------------------------------------------------------------------------
# 6. COMBATE (LÓGICA DEL PLAYER COPIADA)
# ------------------------------------------------------------------------------
func _iniciar_ataque():
	if is_attacking: return 
	is_attacking = true
	current_state = State.ATTACK
	
	print("⚔️ INICIANDO ATAQUE (Lógica Player)")
	
	# 1. FORZAR REINICIO DE LA ANIMACIÓN
	# Esto es vital para evitar el T-Pose. Si la máquina estaba en "End" o "Idle",
	# start() la fuerza a reproducir desde el frame 0.
	# Asegúrate que weapon_data.anim_attack sea EXACTAMENTE el nombre del nodo en el Tree (ej: "Axe_Attack")
	sm_combat.start("Empty") # Reset por seguridad
	sm_combat.start(weapon_data.anim_attack)
	
	# 2. SUBIR LA MEZCLA (TWEEN)
	# Subimos el peso de la animación de brazos a 1.0 suavemente
	var t = create_tween()
	t.tween_property(anim_tree, P_BLEND_2H, 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	
	# 3. ESPERAR EL GOLPE (DELAY)
	# Si tu animación pega en el segundo 0.3, esperamos 0.3
	await get_tree().create_timer(weapon_data.damage_delay).timeout
	
	# 4. ACTIVAR HITBOX (ESTILO MINECRAFT)
	if is_instance_valid(current_weapon_hitbox):
		# Actualizamos stats
		current_weapon_hitbox.damage = skeleteon_damage * weapon_data.damage_mult
		current_weapon_hitbox.knockback_force = weapon_data.knockback_force
		
		# Llamada directa: "Si hay alguien ahí, golpéalo YA"
		if current_weapon_hitbox.has_method("attack_simple"):
			current_weapon_hitbox.attack_simple()
			print("🔥 Hitbox activado (attack_simple)")
		else:
			print("⚠️ ERROR: El hitbox no tiene script WeaponHitbox")
	
	# 5. ESPERAR FIN DE ANIMACIÓN
	# Calculamos cuanto falta para terminar (Duracion total - lo que ya esperamos)
	# Ajusta 0.8 a la duración real de tu animación.
	var tiempo_restante = 0.8 - weapon_data.damage_delay
	if tiempo_restante > 0:
		await get_tree().create_timer(tiempo_restante).timeout
	
	# 6. BAJAR LA MEZCLA (Volver a caminar normal)
	var t2 = create_tween()
	t2.tween_property(anim_tree, P_BLEND_2H, 0.0, 0.2)
	
	await t2.finished
	
	is_attacking = false
	current_state = State.CHASE

# ------------------------------------------------------------------------------
# 7. UTILIDADES
# ------------------------------------------------------------------------------
func _buscar_jugador():
	# Resiliencia: Si no lo encontramos al inicio, lo buscamos ahora
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
			print("👁️ ¡TE VEO!")
			current_state = State.CHASE
			_last_vision_blocker = "" 
		else:
			if col and col.name != _last_vision_blocker:
				_last_vision_blocker = col.name
				# print("❌ Bloqueado por: ", col.name)

func _imprimir_estado_debug():
	var estado_str = State.keys()[current_state]
	print("📊 Estado: %s" % estado_str)

func _animar_movimiento(delta):
	if not anim_tree: return
	var vel_real = Vector2(velocity.x, velocity.z).length()
	var target = Vector2(0, 1) if vel_real > 0.1 else Vector2(0, 0)
	var actual = anim_tree.get(P_MOVIMIENTO)
	if actual == null: actual = Vector2.ZERO
	anim_tree.set(P_MOVIMIENTO, actual.lerp(target, delta * 8.0))

func _equipar_arma():
	if not weapon_data or not hand_attachment: return
	
	var w = weapon_data.weapon_scene.instantiate()
	hand_attachment.add_child(w)
	
	var hb = w.find_child("Hitbox")
	if hb:
		current_weapon_hitbox = hb
		
		# CONFIGURACIÓN CRÍTICA DEL HITBOX
		hb.collision_mask = 2 # Capa del Player
		hb.set_collision_mask_value(3, false) # No golpear enemigos
		hb.monitoring = false # Apagado por defecto
		
		eyes.add_exception(hb)
		if w is CollisionObject3D: eyes.add_exception(w)
		print("✅ Arma equipada.")
	else:
		print("⚠️ Arma sin Hitbox.")

func _setup_unique_materials():
	if not skeleton_mesh: return
	unique_materials.clear()
	for child in skeleton_mesh.get_children():
		if child is MeshInstance3D:
			var mat = child.get_active_material(0)
			if mat is StandardMaterial3D:
				var unique = mat.duplicate()
				child.set_surface_override_material(0, unique)
				unique_materials.append(unique)

func apply_knockback(dir: Vector3, knock: float, jump: float):
	velocity += dir * knock
	if is_on_floor(): velocity.y += jump
	flash_red()

func flash_red():
	if unique_materials.is_empty(): return
	if flash_tween: flash_tween.kill()
	for mat in unique_materials: mat.albedo_color = Color(1, 0.2, 0.2)
	flash_tween = create_tween()
	flash_tween.set_parallel(true)
	for mat in unique_materials: flash_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.2)

func _morir():
	queue_free()
