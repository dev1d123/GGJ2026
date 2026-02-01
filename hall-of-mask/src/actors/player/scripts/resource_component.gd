extends Node
class_name ResourceComponent

# Señales para la UI
signal on_value_changed(current, max_val)
signal on_depleted
signal on_full

@export_category("Configuración de Recurso")
@export var max_value: float = 100.0
@export var current_value: float = 100.0

@export_group("Regeneración")
@export var auto_regenerate: bool = true
@export var regen_rate: float = 5.0       # Puntos por segundo
@export var regen_delay: float = 1.5      # Segundos de espera tras gastar

# Variables internas
var _regen_timer: float = 0.0

func _ready():
	# Aseguramos que empiece lleno (o con el valor que pongas en el inspector)
	current_value = clamp(current_value, 0, max_value)
	emit_signal("on_value_changed", current_value, max_value)

func _process(delta):
	if not auto_regenerate: return
	
	# Si estamos llenos, no hacemos nada
	if current_value >= max_value: return

	# Gestión del Delay (Si gastaste hace poco, espera)
	if _regen_timer > 0:
		_regen_timer -= delta
		return

	# Lógica de Regeneración
	var old_value = current_value
	current_value = move_toward(current_value, max_value, regen_rate * delta)
	
	if current_value != old_value:
		emit_signal("on_value_changed", current_value, max_value)
		if current_value == max_value:
			emit_signal("on_full")

# Función para intentar gastar recurso
# Retorna TRUE si se pudo gastar, FALSE si no alcanzaba
func try_consume(amount: float) -> bool:
	if current_value >= amount:
		current_value -= amount
		_regen_timer = regen_delay # Reiniciamos el tiempo de espera
		
		emit_signal("on_value_changed", current_value, max_value)
		
		if current_value <= 0:
			emit_signal("on_depleted")
			
		return true
	
	return false

# Función para añadir recurso externamente (ej: Pociones)
func add_value(amount: float):
	current_value = min(current_value + amount, max_value)
	emit_signal("on_value_changed", current_value, max_value)
