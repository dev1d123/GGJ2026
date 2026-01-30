extends Area3D
class_name WeaponHitbox

var damage: float = 10.0 
var knockback_force: float = 8.0
var jump_force: float = 4.0
var hit_objects = [] 

func _ready():
	monitoring = false 
	monitorable = false
	area_entered.connect(_on_area_entered)

# --- ESTA ES LA MAGIA SIMPLE ---
func attack_simple():
	# 1. Configuración rápida
	hit_objects.clear()
	monitoring = true 
	
	# 2. Revisión instantánea (para que no falle el primer frame)
	for area in get_overlapping_areas():
		_on_area_entered(area)
	
	# 3. EL TEMPORIZADOR (La vieja confiable)
	# Esperamos 0.1 segundos (o lo que dure tu golpe fuerte) y apagamos.
	# No dependemos de la animación.
	await get_tree().create_timer(0.2).timeout 
	
	monitoring = false

func _on_area_entered(area):
	if not monitoring: return # Doble seguridad
	
	if area in hit_objects: return 

	if area.has_method("hit"):
		hit_objects.append(area) 
		
		# Calculamos dirección
		var dir = (area.global_position - global_position).normalized()
		dir.y = 0 
		
		# Golpeamos
		area.hit(damage, dir.normalized(), knockback_force, jump_force)
		print("🩸 PUM! Golpe conectado")
