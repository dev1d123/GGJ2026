class_name AttributeManager extends Node

# Estos son los valores BASE del personaje (sin máscaras)
var base_stats = {
	"max_health": 100.0,
	"move_speed": 15.0,
	"jump_force": 4.5,
	"defense": 0.0,           # 0% reducción
	"melee_damage": 1.0,      # Multiplicador x1
	"ranged_damage": 1.0,
	"attack_speed": 1.0,
	"reload_speed": 1.0,
	"accuracy": 1.0           # Bloom multiplier (1.0 normal, 0.5 muy preciso)
}

# Aquí se suman los efectos de la máscara actual
var modifiers = {}

func _ready():
	reset_modifiers()

func reset_modifiers():
	# Reinicia todo a 0 (para sumas) o 1 (para multiplicaciones)
	for key in base_stats:
		modifiers[key] = 0.0

# Función maestra para pedir un stat final
func get_stat(stat_name: String) -> float:
	var base = base_stats.get(stat_name, 0.0)
	var mod = modifiers.get(stat_name, 0.0)
	
	# Lógica: Algunos stats se suman (Defensa), otros se multiplican (Daño)
	if stat_name in ["defense", "max_health"]:
		return base + mod
	else:
		# Ejemplo: base 5.0 * (1.0 base + 0.2 bono máscara) = 6.0 velocidad
		return base * (1.0 + mod)

# Llamaremos a esto cuando nos pongamos una máscara
func apply_mask_bonuses(bonuses: Dictionary):
	reset_modifiers()
	for key in bonuses:
		if key in modifiers:
			modifiers[key] = bonuses[key]
