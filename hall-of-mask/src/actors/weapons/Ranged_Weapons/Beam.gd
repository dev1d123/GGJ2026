extends Node3D

@onready var raycast: RayCast3D = $RayCast3D
@onready var visual_mesh: Node3D = $MeshInstance3D
@onready var hit_particles: GPUParticles3D = $HitParticles # (Opcional)

var max_length: float = 50.0
var damage_per_tick: float = 0.0 
var owner_node: Node = null

func _ready():
	# Configurar rayo hacia adelante (-Z)
	raycast.target_position = Vector3(0, 0, -max_length)
	raycast.enabled = true

func _process(delta):
	var cast_point = to_global(Vector3(0, 0, -max_length))
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		cast_point = raycast.get_collision_point()
		
		if hit_particles:
			hit_particles.global_position = cast_point
			hit_particles.emitting = true
			# Orientar partículas a la normal (opcional)
			var n = raycast.get_collision_normal()
			if n.length_squared() > 0.01: hit_particles.look_at(cast_point + n, Vector3.UP)
	else:
		if hit_particles: hit_particles.emitting = false

	# --- MATEMÁTICA VISUAL CORREGIDA ---
	var distance = global_position.distance_to(cast_point)
	
	# 1. Escalar en Y (porque al rotar -90 en X, la Y local es la profundidad)
	visual_mesh.scale.y = distance
	
	# 2. Mover el centro hacia adelante la mitad de la distancia
	# (Porque el cilindro crece desde el centro, no desde la base)
	visual_mesh.position.z = -distance / 2.0

func apply_damage_tick():
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider == owner_node: return
		
		if collider.has_method("take_damage"):
			collider.take_damage(damage_per_tick)
		elif collider.has_node("HealthComponent"):
			collider.get_node("HealthComponent").take_damage(damage_per_tick)
