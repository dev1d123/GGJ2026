extends Node
class_name HealthComponent

signal on_damage_received(amount, current_health)
signal on_death

@export var max_health: float = 100.0
var current_health: float

func _ready():
	current_health = max_health

func take_damage(amount: float):
	if current_health <= 0: return # Ya está muerto
	
	current_health -= amount
	print("💔 Daño recibido: ", amount, " | Vida restante: ", current_health)
	
	emit_signal("on_damage_received", amount, current_health)
	
	if current_health <= 0:
		die()

func die():
	print("💀 ¡Ha muerto!")
	emit_signal("on_death")
	# Aquí podrías desactivar colisiones o iniciar ragdoll
