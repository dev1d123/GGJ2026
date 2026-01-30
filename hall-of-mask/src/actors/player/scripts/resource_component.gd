class_name ResourceComponent extends Node

signal on_value_changed(current, max)
signal on_empty

@export var max_value: float = 100.0
@export var regen_rate: float = 10.0
@export var regen_delay: float = 3.0 

# --- MULTIPLICADORES (Modificados por Máscaras/Buffs) ---
var cost_multiplier: float = 1.0    # 0.5 = Mitad de costo
var regen_multiplier: float = 1.0   # 2.0 = Doble de velocidad de recarga
var delay_multiplier: float = 1.0   # 0.5 = Espera la mitad de tiempo

var current_value: float
var can_regen: bool = true
var timer_delay: Timer

func _ready():
	current_value = max_value
	
	timer_delay = Timer.new()
	timer_delay.one_shot = true
	# El tiempo se setea dinámicamente al usarse
	timer_delay.timeout.connect(func(): can_regen = true)
	add_child(timer_delay)

func _process(delta):
	if can_regen and current_value < max_value:
		# Aplicamos multiplicador de regeneración
		var real_regen = regen_rate * regen_multiplier
		current_value += real_regen * delta
		current_value = min(current_value, max_value)
		on_value_changed.emit(current_value, max_value)

func try_consume(amount: float) -> bool:
	# Aplicamos multiplicador de costo (Ej: Máscara reduce costo)
	var real_cost = amount * cost_multiplier
	
	if current_value >= real_cost:
		current_value -= real_cost
		can_regen = false
		
		# Aplicamos multiplicador de delay (Ej: Máscara reduce espera)
		var real_delay = regen_delay * delay_multiplier
		timer_delay.start(real_delay) 
		
		on_value_changed.emit(current_value, max_value)
		
		if current_value <= 0:
			on_empty.emit()
		return true 
	return false
