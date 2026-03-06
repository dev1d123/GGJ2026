extends CharacterBody3D
class_name AlliedSkeleton

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────
@export var speed: float = 4.0
@export var attack_range: float = 2.0
@export var damage: float = 18.0
@export var lifetime: float = 30.0          # segundos antes de desaparecer
@export var attack_cooldown: float = 1.6

# ─── REFERENCIAS ──────────────────────────────────────────────────────────────
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_tree: AnimationTree      = $AnimationTree
@onready var hitbox_area: Area3D           = $HitboxArea   # Area3D esfera pequeña

var player_ref: Node3D = null  # se asigna desde fuera
var _target: Node3D    = null
var _cd_timer: float   = 0.0
var _life_timer: float = 0.0
var _gravity: float    = 9.8
var _unique_mats: Array[StandardMaterial3D] = []

const AURA_COLOR := Color(0.45, 0.0, 0.75, 1.0)   # Morado oscuro

# ─── INICIO ───────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Capa de colisión propia: capa 8 (0b10000000 = 128) – no pertenece a la
	# capa del Player (1) ni de los Enemigos (2), así el player la ignora.
	collision_layer = 64   # capa 7 – "aliado"
	collision_mask  = 4    # solo choca con geometría del mundo (capa 3)

	if hitbox_area:
		hitbox_area.collision_layer = 0
		hitbox_area.collision_mask  = 2  # detecta solo enemigos (capa 2)
		hitbox_area.monitoring = false

	call_deferred("_apply_purple_aura")
	call_deferred("_find_first_target")

# ─── FÍSICA / LOOP PRINCIPAL ──────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor(): velocity.y -= _gravity * delta

	_life_timer += delta
	if _life_timer >= lifetime:
		_dissolve_and_free()
		return

	if _cd_timer > 0.0: _cd_timer -= delta

	# Refrescar objetivo periódicamente
	if _target == null or not is_instance_valid(_target):
		_find_first_target()

	if _target and is_instance_valid(_target):
		var dist: float = global_position.distance_to(_target.global_position)
		if dist <= attack_range:
			_try_attack()
		else:
			nav_agent.target_position = _target.global_position
			var next := nav_agent.get_next_path_position()
			var dir := (next - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_look_at_smooth(_target.global_position, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()

# ─── COMBATE ─────────────────────────────────────────────────────────────────
func _try_attack() -> void:
	if _cd_timer > 0.0: return
	_cd_timer = attack_cooldown
	velocity.x = 0.0; velocity.z = 0.0

	# Animación de ataque 1H simple
	if anim_tree and anim_tree.get("parameters/Combat_R/playback") != null:
		anim_tree.set("parameters/Mezcla_R/blend_amount", 1.0)
		anim_tree["parameters/Combat_R/playback"].start("Melee_1H_Attack_Stab")

	# Activar hitbox durante la ventana de golpe
	_activate_hitbox()

func _activate_hitbox() -> void:
	if not hitbox_area: return
	hitbox_area.monitoring = true
	# Infligir daño a todo lo que esté en rango en este momento
	for body in hitbox_area.get_overlapping_bodies():
		_hit_enemy(body)
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self): hitbox_area.monitoring = false

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
	# Busca enemies en el grupo "Enemy" – asegúrate de add_to_group("Enemy") en tus escenas
	for e in get_tree().get_nodes_in_group("Enemy"):
		if not is_instance_valid(e): continue
		var d := global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			_target = e
	# Fallback: cualquier CharacterBody3D que no sea aliado ni player
	if _target == null:
		for body in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(body): continue
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
