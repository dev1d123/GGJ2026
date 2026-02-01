extends Area3D
class_name MagicProjectile

@export var speed: float = 10.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0
@export var color: Color = Color(0.4, 0.7, 1.0, 1.0)

var direction: Vector3 = Vector3.FORWARD
var _life_timer: float = 0.0

func _ready():
	_life_timer = lifetime
	direction = direction.normalized()
	if direction.length_squared() <= 0.0001:
		direction = -global_transform.basis.z.normalized()
	# Visibilidad y colisión
	collision_layer = 8
	collision_mask = 2
	_build_visuals()
	monitoring = false
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# Activar colisiones después de un frame
	await get_tree().process_frame
	monitoring = true
	monitorable = true

func _physics_process(delta):
	global_position += direction * speed * delta
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()

func _build_visuals():
	var mesh_instance = MeshInstance3D.new()
	# Asegura que el proyectil se renderice con el cull_mask de la cámara
	mesh_instance.layers = 1 << 2
	var sphere = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	mesh_instance.mesh = sphere
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.2
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

func _apply_damage(target):
	if target == null:
		return
	if target.has_method("take_damage"):
		target.take_damage(damage)
		return
	if target.has_method("hit"):
		target.hit(damage, direction, 0.0, 0.0)
		return
	var hc = target.get_node_or_null("HealthComponent")
	if hc and hc.has_method("take_damage"):
		hc.take_damage(damage)
