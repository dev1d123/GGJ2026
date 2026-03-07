extends CharacterBody3D
class_name AlliedSkeleton

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
@export var speed: float = 4.0
@export var attack_range: float = 2.0
@export var damage: float = 10.0
@export var lifetime: float = 30.0
@export var attack_cooldown: float = 1.6

# ─── REFERENCIAS (resueltas manualmente en _ready para evitar errores @onready) ──
var nav_agent: NavigationAgent3D = null
var anim_tree: AnimationTree     = null

var player_ref: Node3D = null
var _target: Node3D    = null
var _cd_timer: float   = 0.0
var _life_timer: float = 0.0
var _gravity: float    = 9.8
var _unique_mats: Array[StandardMaterial3D] = []
# NavigationAgent3D en Godot 4 tarda al menos un frame en registrarse con
# el servidor de navegación. Hasta entonces get_next_path_position() devuelve
# la posición actual → dir = ZERO → sin movimiento.
var _nav_ready: bool = false

const AURA_COLOR := Color(0.45, 0.0, 0.75, 1.0)

# ─── INICIO ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("allied_skeleton")

	collision_layer = 64   # capa 7 – aliado (no colisiona con player ni enemigos)
	collision_mask  = 4    # solo geometría del mundo

	# Resolución segura de nodos opcionales
	nav_agent = get_node_or_null("NavigationAgent3D")
	anim_tree = _buscar_animation_tree(self)

	call_deferred("_apply_purple_aura")
	# Esperamos 2 frames: 1 para que nav se registre, 1 para que el target esté disponible
	call_deferred("_init_deferred")

func _init_deferred() -> void:
	await get_tree().physics_frame
	_nav_ready = true
	_find_first_target()

func _buscar_animation_tree(nodo: Node) -> AnimationTree:
	if nodo is AnimationTree:
		return nodo as AnimationTree
	for child in nodo.get_children():
		var found := _buscar_animation_tree(child)
		if found:
			return found
	return null

# ─── FÍSICA / LOOP PRINCIPAL ──────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	_life_timer += delta
	if _life_timer >= lifetime:
		_dissolve_and_free()
		return

	if _cd_timer > 0.0:
		_cd_timer -= delta

	# Refrescar objetivo si perdemos el actual
	if _target == null or not is_instance_valid(_target):
		_find_first_target()

	if _target and is_instance_valid(_target):
		var dist: float = global_position.distance_to(_target.global_position)
		if dist <= attack_range:
			_try_attack()
		else:
			var dir := _calcular_direccion()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_look_at_smooth(_target.global_position, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()

# Calcula dirección hacia el objetivo: usa NavigationAgent3D si está listo,
# y cae a movimiento directo si el nav no da un vector útil.
func _calcular_direccion() -> Vector3:
	if nav_agent and _nav_ready:
		nav_agent.target_position = _target.global_position
		var next := nav_agent.get_next_path_position()
		var to_next := (next - global_position)
		to_next.y = 0.0
		if to_next.length() > 0.4:
			return to_next.normalized()

	# Fallback: movimiento directo (siempre funciona)
	var to_target := (_target.global_position - global_position)
	to_target.y = 0.0
	if to_target.length() > 0.01:
		return to_target.normalized()
	return Vector3.ZERO

# ─── COMBATE ─────────────────────────────────────────────────────────────────
func _try_attack() -> void:
	if _cd_timer > 0.0: return
	_cd_timer = attack_cooldown
	velocity.x = 0.0; velocity.z = 0.0

	# Animación (opcional, falla en silencio si el árbol no coincide)
	if anim_tree:
		var pb = anim_tree.get("parameters/Combat_R/playback")
		if pb != null:
			anim_tree.set("parameters/Mezcla_R/blend_amount", 1.0)
			pb.start("Melee_1H_Attack_Stab")

	# Daño directo: no depende de hitbox ni Area3D
	_aplicar_dano_en_rango()

func _aplicar_dano_en_rango() -> void:
	# Pequeño windup visual
	await get_tree().create_timer(0.2).timeout
	if not is_instance_valid(self): return

	# Golpea todo lo que esté dentro del radio de ataque
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = attack_range
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape     = sphere
	params.transform = global_transform
	params.exclude   = [get_rid()]
	var hits := space.intersect_shape(params, 16)
	for hit in hits:
		var body = hit.get("collider")
		_hit_enemy(body)

func _hit_enemy(body: Node) -> void:
	if body == self: return
	if player_ref and body == player_ref: return
	if body.is_in_group("allied_skeleton"): return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.has_node("HealthComponent"):
		body.get_node("HealthComponent").take_damage(damage)
	if body.has_method("apply_knockback"):
		var dir: Vector3 = (body.global_position - global_position).normalized()
		body.apply_knockback(dir, 6.0, 2.0)

# ─── BÚSQUEDA DE OBJETIVO ────────────────────────────────────────────────────
func _find_first_target() -> void:
	_target = null
	var best_dist := INF

	# Paso 1: buscar por grupos estándar de enemigos
	for grupo in ["Enemies", "Enemy", "enemy"]:
		for e in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(e) or e == self: continue
			if e.is_in_group("allied_skeleton"): continue
			if e.is_in_group("Player"): continue
			if player_ref and e == player_ref: continue
			var d := global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				_target = e
		if _target != null:
			return

	# Paso 2: escaneo físico de esfera grande — encuentra cualquier nodo
	# que tenga HealthComponent o take_damage() y no sea aliado/jugador.
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 60.0
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape     = sphere
	params.transform = global_transform
	params.exclude   = [get_rid()]
	var hits := space.intersect_shape(params, 32)
	for hit in hits:
		var body = hit.get("collider")
		if not body or body == self: continue
		if body.is_in_group("allied_skeleton"): continue
		if body.is_in_group("Player"): continue
		if player_ref and body == player_ref: continue
		if not (body.has_method("take_damage") or body.has_node("HealthComponent")): continue
		var d := global_position.distance_to(body.global_position)
		if d < best_dist:
			best_dist = d
			_target = body

# ─── AURA MORADA ─────────────────────────────────────────────────────────────
func _apply_purple_aura() -> void:
	_collect_meshes(self)
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color    = AURA_COLOR
	aura_mat.emission_enabled = true
	aura_mat.emission        = AURA_COLOR
	aura_mat.emission_energy = 2.5
	aura_mat.transparency    = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.cull_mode       = BaseMaterial3D.CULL_FRONT
	aura_mat.grow            = true
	aura_mat.grow_amount     = 0.04

	for m in _unique_mats:
		# Tinte morado sobre el material base
		m.albedo_color = m.albedo_color.lerp(AURA_COLOR, 0.55)
		m.emission_enabled = true
		m.emission = AURA_COLOR
		m.emission_energy = 1.2
		m.next_pass = aura_mat

func _collect_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.get_surface_override_material_count()):
			var m = node.get_active_material(i)
			if m:
				var u: StandardMaterial3D = m.duplicate()
				node.set_surface_override_material(i, u)
				_unique_mats.append(u)
	for child in node.get_children():
		_collect_meshes(child)

# ─── DISOLUCIÓN ──────────────────────────────────────────────────────────────
func _dissolve_and_free() -> void:
	set_physics_process(false)
	var t := create_tween()
	for m in _unique_mats:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		t.parallel().tween_property(m, "albedo_color:a", 0.0, 0.6)
	await t.finished
	queue_free()

# ─── HELPER ───────────────────────────────────────────────────────────────────
func _look_at_smooth(target_pos: Vector3, delta: float) -> void:
	var flat := Vector3(target_pos.x, global_position.y, target_pos.z)
	if flat.is_equal_approx(global_position): return
	var desired := global_transform.looking_at(flat, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired.basis, delta * 8.0)
