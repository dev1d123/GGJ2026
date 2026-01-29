extends CharacterBody3D

# --- REFERENCIAS ---
@export var skeleton_mesh: Node3D 
@onready var health_component = $HealthComponent

# --- CONFIGURACIÓN FÍSICA ---
var speed = 2.0
var gravity = 9.8
var knockback_velocity = Vector3.ZERO
var knockback_friction = 12.0

# --- VARIABLES VISUALES ---
var unique_materials: Array[StandardMaterial3D] = []
var flash_tween: Tween

func _ready():
	if health_component: 
		health_component.on_death.connect(_morir)
	
	# IMPORTANTE: Configurar los materiales al nacer
	_setup_unique_materials()

func _physics_process(delta):
	# Gravedad
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Físicas de Empuje
	if knockback_velocity.length() > 0.1:
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
	else:
		velocity.x = 0 
		velocity.z = 0
		_perseguir_jugador(delta)

	move_and_slide()

# --- CONFIGURACIÓN DE MATERIALES ---
func _setup_unique_materials():
	if skeleton_mesh == null:
		print("❌ ERROR: Asigna el 'Skeleton Mesh' en el Inspector del enemigo.")
		return

	unique_materials.clear()
	
	# Buscamos recursivamente MeshInstance3D
	for child in skeleton_mesh.get_children():
		if child is MeshInstance3D:
			# Obtenemos el material
			var shared_mat = child.get_active_material(0)
			
			if shared_mat is StandardMaterial3D:
				# Duplicamos para que sea único de este esqueleto
				var unique_mat = shared_mat.duplicate()
				child.set_surface_override_material(0, unique_mat)
				unique_materials.append(unique_mat)
	
	print("✅ Materiales configurados: ", unique_materials.size())

# --- DAÑO Y FEEDBACK VISUAL ---
func apply_knockback(direction: Vector3, knock_force: float, jump_force: float):
	knockback_velocity = direction * knock_force
	if is_on_floor(): velocity.y = jump_force
	
	flash_red()

func flash_red():
	# 1. Si la lista está vacía, no hacemos nada (Evita errores)
	if unique_materials.is_empty():
		return

	# 2. Matamos el Tween anterior si existe (Reset inmediato)
	if flash_tween:
		flash_tween.kill()
	
	# 3. CAMBIO MANUAL INSTANTÁNEO (Sin Tween)
	# Esto garantiza que se ponga rojo SIEMPRE, sin importar animaciones previas.
	var flash_color = Color(1, 0.2, 0.2) # Rojo Intenso
	
	for mat in unique_materials:
		mat.albedo_color = flash_color
	
	# 4. CREAR TWEEN SOLO PARA VOLVER A BLANCO
	flash_tween = create_tween()
	flash_tween.set_parallel(true) # Para que todos los materiales cambien a la vez
	
	for mat in unique_materials:
		# Volver a blanco en 0.2 segundos
		flash_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.2)

func _perseguir_jugador(_delta):
	# (Tu lógica de IA)
	pass

func _morir():
	queue_free()
