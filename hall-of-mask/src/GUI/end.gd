extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var fade: ColorRect = $Fade
@onready var end_sprite: Sprite2D = $End
@onready var label: Label = $End/Label1
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var time_elapsed: float = 0.0
var fade_duration: float = 3.0
var text_appear_time: float = 4.0
var exit_time: float = 35.0

func _ready() -> void:
	# Configuración inicial
	fade.modulate.a = 1.0
	end_sprite.modulate.a = 0.0
	label.modulate.a = 0.0
	
	# Reproducir música
	audio.play()
	
	# Iniciar secuencia de animaciones
	_start_cinematic()

func _start_cinematic():
	# Fade in desde negro
	var tween1 = create_tween()
	tween1.tween_property(fade, "modulate:a", 0.0, fade_duration)
	
	await tween1.finished
	
	# Aparecer imagen de fondo con zoom
	end_sprite.scale = Vector2(1.5, 1.5)
	var tween2 = create_tween().set_parallel(true)
	tween2.tween_property(end_sprite, "modulate:a", 1.0, 2.0)
	tween2.tween_property(end_sprite, "scale", Vector2(1.34, 1.34), 2.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(text_appear_time).timeout
	
	# Aparecer texto con efecto fade
	var tween3 = create_tween()
	tween3.tween_property(label, "modulate:a", 1.0, 2.5)
	
	# Efecto de brillo pulsante en el texto
	await tween3.finished
	_pulse_text()
	
	# Esperar y volver al menú principal
	await get_tree().create_timer(exit_time - text_appear_time - fade_duration).timeout
	_return_to_menu()

func _pulse_text():
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(label, "modulate:a", 0.7, 1.5).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(label, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)

func _return_to_menu():
	# Fade out final
	var final_tween = create_tween()
	final_tween.tween_property(fade, "modulate:a", 1.0, 2.0)
	
	await final_tween.finished
	
	# MANTENER EN LA PANTALLA FINAL - NO VOLVER AL LOBBY
	# El juego termina aquí
	print("🎮 FIN DEL JUEGO")

func _process(delta: float) -> void:
	time_elapsed += delta
	
	# Permitir cerrar el juego con ESC
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func _skip_cinematic():
	# NUNCA SALTAR - MANTENER EN LA PANTALLA
	pass
