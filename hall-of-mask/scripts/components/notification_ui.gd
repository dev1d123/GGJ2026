extends Control

# Nodo para mostrar notificaciones temporales
@onready var label: Label = $PanelContainer/MarginContainer/Label

func _ready():
	visible = false

func show_notification(message: String, duration: float = 3.0):
	label.text = message
	visible = true
	modulate.a = 0.0
	
	# Animación de fade in/out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(duration - 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)
