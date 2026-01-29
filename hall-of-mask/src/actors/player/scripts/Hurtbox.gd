extends Area3D
class_name Hurtbox

@export var health_component: HealthComponent

# Actualizamos la función hit para recibir TODOS los datos del arma
func hit(damage_amount: float, dir: Vector3, knockback: float, jump: float):
	# 1. Gestionar la VIDA (Salud)
	if health_component:
		health_component.take_damage(damage_amount)
	else:
		print("⚠️ Error: Este Hurtbox no tiene HealthComponent asignado")
		
	# 2. Gestionar el MOVIMIENTO (Física y Color)
	# 'owner' suele ser el nodo raíz de la escena (el CharacterBody3D del esqueleto)
	if owner.has_method("apply_knockback"):
		owner.apply_knockback(dir, knockback, jump)
