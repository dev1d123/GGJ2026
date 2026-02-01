extends Area3D
class_name HomingMagicOrb

@export var speed: float = 4.0
@export var damage: float = 15.0
@export var lifetime: float = 5.0
@export var color: Color = Color(1.0, 0.4, 0.9, 1.0)
@export var radius: float = 0.5
@export var update_interval: float = 0.4

var target: Node3D
var direction: Vector3 = Vector3.FORWARD
var _life_timer: float = 0.0
var _update_timer: float = 0.0

func _ready():
	_life_timer = max(lifetime, 0.1)
	_update_timer = 0.0
	_build_visuals()
	collision_layer = 8
	collision_mask = 2
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_update_direction(true)
	# Activar colisiones después de un frame
	await get_tree().process_frame
	monitoring = true
	monitorable = true

func _physics_process(delta):
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()
		return

	_update_timer -= delta
	if _update_timer <= 0.0:
		_update_direction(false)
		_update_timer = update_interval

	global_position += direction * speed * delta

func _update_direction(force: bool):
	if target:
		var desired = (target.global_position - global_position).normalized()
		if desired.length_squared() > 0.0001:
			direction = desired
			return
	if force or direction.length_squared() <= 0.0001:
		direction = -global_transform.basis.z.normalized()

func _build_visuals():
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.layers = 1 << 2
	var sphere = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	add_child(collision)

func _on_body_entered(body):
	if not _is_player(body):
		return
	_apply_damage(body)
	queue_free()

func _on_area_entered(area):
	if area == self:
		return
	if not _is_player(area):
		return
	_apply_damage(area)
	queue_free()

func _is_player(node) -> bool:
	if node == null:
		return false
	if node.name == "Player":
		return true
	if node.is_in_group("player"):
		return true
	var parent = node.get_parent()
	if parent and parent.name == "Player":
		return true
	return false

func _apply_damage(target_node):
	if target_node == null:
		return
	if target_node.has_method("take_damage"):
		target_node.take_damage(damage)
		return
	if target_node.has_method("hit"):
		target_node.hit(damage, direction, 0.0, 0.0)
		return
	var hc = target_node.get_node_or_null("HealthComponent")
	if hc and hc.has_method("take_damage"):
		hc.take_damage(damage)
