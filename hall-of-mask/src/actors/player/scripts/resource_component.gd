class_name ResourceComponent extends Node

signal on_value_changed(current, max)
signal on_empty

@export var max_value: float = 100.0
@export var regen_rate: float = 10.0
@export var regen_delay: float = 3.0 # Segundos a esperar antes de recargar

var current_value: float
var can_regen: bool = true
var timer_delay: Timer

func _ready():
	current_value = max_value
	
	# Crear el temporizador automáticamente
	timer_delay = Timer.new()
	timer_delay.one_shot = true
	timer_delay.wait_time = regen_delay
	timer_delay.timeout.connect(func(): can_regen = true)
	add_child(timer_delay)

func _process(delta):
	if can_regen and current_value < max_value:
		current_value += regen_rate * delta
		current_value = min(current_value, max_value)
		on_value_changed.emit(current_value, max_value)

# Función para intentar gastar (Stamina/Mana)
func try_consume(amount: float) -> bool:
	if current_value >= amount:
		current_value -= amount
		can_regen = false # Pausar regeneración
		timer_delay.start() # Iniciar cuenta regresiva (3s o 20s)
		on_value_changed.emit(current_value, max_value)
		
		if current_value <= 0:
			on_empty.emit()
			
		return true # Gasto exitoso
	return false # No hay suficiente
