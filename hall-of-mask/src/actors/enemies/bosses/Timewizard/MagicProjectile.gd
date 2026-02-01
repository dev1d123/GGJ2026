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
	_build_visuals()
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
