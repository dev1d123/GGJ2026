extends Area3D
class_name LaserRainProjectile

@export var speed: float = 14.0
@export var damage: float = 8.0
@export var lifetime: float = 2.5
@export var color: Color = Color(0.8, 0.2, 1.0, 1.0)
@export var thickness: float = 0.08
@export var length: float = 2.5

var direction: Vector3 = Vector3.DOWN
var _life_timer: float = 0.0

func _ready():
	_life_timer = lifetime
	if direction.length_squared() <= 0.0001:
		direction = Vector3.DOWN
	else:
		direction = direction.normalized()
	_build_visuals()
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	global_position += direction * speed * delta
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()

func _build_visuals():
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.layers = 1 << 2
	var cylinder = CylinderMesh.new()
	cylinder.height = length
	cylinder.top_radius = thickness
	cylinder.bottom_radius = thickness
	mesh_instance.mesh = cylinder
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.height = length
	shape.radius = thickness * 1.2
	collision.shape = shape
	add_child(collision)

func _on_body_entered(body):
	_apply_damage(body)
	queue_free()

func _on_area_entered(area):
	if area == self:
		return
	_apply_damage(area)
	queue_free()

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
