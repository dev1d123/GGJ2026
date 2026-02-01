extends Area3D
class_name Projectile

@export var speed: float = 40.0
@export var damage: float = 10.0
@export var lifetime: float = 5.0
@export var use_gravity: bool = false
@export var gravity_scale: float = 1.0

# 🔴 NUEVO: Vector de dirección pura. 
# Ignora hacia donde mira la bola, solo le importa hacia donde viaja.
var movement_direction: Vector3 = Vector3.FORWARD 
var velocity_y: float = 0.0 
var shooter_node: Node = null 

func _ready():
	set_as_top_level(true)
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self): queue_free()

func _physics_process(delta):
	# USAMOS EL VECTOR QUE CALCULÓ EL COMBAT MANAGER
	var move_step = movement_direction * speed * delta
	
	if use_gravity:
		velocity_y -= 9.8 * gravity_scale * delta
		move_step.y += velocity_y * delta
		global_position += move_step
		if move_step.length() > 0.01: look_at(global_position + move_step, Vector3.UP)
	else:
		global_position += move_step

func _on_body_entered(body):
	if body == shooter_node: return 
	if body is Area3D: return 
	
	print("🎯 Impacto en: ", body.name)
	
	if body.has_node("HealthComponent"):
		var hp = body.get_node("HealthComponent")
		if hp.has_method("take_damage"):
			hp.take_damage(damage)
	
	queue_free()
