extends Node
class_name HealthComponent

signal on_damage_received(amount, current_health)
signal on_death

@export var max_health: float = 100.0
var current_health: float

# --- MULTIPLICADOR DE DEFENSA ---
# 1.0 = Daño normal
# 2.0 = Mitad de daño recibido (Doble defensa)
var defense_multiplier: float = 1.0

func _ready():
	current_health = max_health

func take_damage(amount: float):
	if current_health <= 0: return 
	
	# FÓRMULA DE DEFENSA SIMPLE
	# Daño Real = Daño Entrante / Multiplicador de Defensa
	var real_damage = amount / defense_multiplier
	
	current_health -= real_damage
	print("🛡️ Defensa: x", defense_multiplier, " | Daño final: ", real_damage)
	
	emit_signal("on_damage_received", real_damage, current_health)
	
	if current_health <= 0:
		die()

func die():
	print("💀 ¡Ha muerto!")
	emit_signal("on_death")
