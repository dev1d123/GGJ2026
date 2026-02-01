extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var player: CharacterBody3D = $Player

@onready var level_areas: Dictionary[Area3D, String] = {
	$Level1Area3D: "res://src/levels/level1/Level1.tscn",
	$Level2Area3D: "res://src/levels/level2/Level2.tscn",
	$Level3Area3D: "res://src/levels/level3/Level3.tscn",
	$Level4Area3D: "res://src/levels/level4/Level4.tscn"
}

var progress_ui: Label
var victory_ui: Label
var is_going_to_end: bool = false

func _ready() -> void:
	audio.finished.connect(_on_audio_finished)
	audio.play()

	for area in level_areas.keys():
		area.body_entered.connect(
			func(body: Node3D) -> void:
				_on_area_body_entered(body, area)
		)
	
	# Crear UI de progreso
	_create_progress_ui()
	
	# Conectar señal de todos los niveles completados
	if not GameManager.all_levels_completed.is_connected(_on_all_levels_completed):
		GameManager.all_levels_completed.connect(_on_all_levels_completed)
	
	# Verificar si ya están todos completados al entrar
	await get_tree().create_timer(0.5).timeout
	if GameManager.get_completed_count() == 4:
		_on_all_levels_completed()

func _create_progress_ui():
	# Crear CanvasLayer
	var canvas = CanvasLayer.new()
	canvas.name = "ProgressUI"
	add_child(canvas)
	
	# Panel centrado arriba
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-200, 20)
	panel.custom_minimum_size = Vector2(400, 0)
	canvas.add_child(panel)
	
	# VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	# Label de progreso
	progress_ui = Label.new()
	progress_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_ui.add_theme_font_size_override("font_size", 24)
	vbox.add_child(progress_ui)
	
	# Label de victoria (oculto inicialmente)
	victory_ui = Label.new()
	victory_ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_ui.add_theme_font_size_override("font_size", 28)
	victory_ui.add_theme_color_override("font_color", Color.GOLD)
	victory_ui.visible = false
	vbox.add_child(victory_ui)
	
	_update_progress_ui()

func _update_progress_ui():
	if progress_ui:
		var count = GameManager.get_completed_count()
		progress_ui.text = "NIVELES COMPLETADOS: %d/4" % count
		
		# Mostrar detalles
		var details = "\n"
		if GameManager.is_level_completed("level1"):
			details += "✓ Nivel 1 "
		if GameManager.is_level_completed("level2"):
			details += "✓ Nivel 2 "
		if GameManager.is_level_completed("level3"):
			details += "✓ Nivel 3 "
		if GameManager.is_level_completed("level4"):
			details += "✓ Nivel 4"
		
		progress_ui.text += details

func _on_all_levels_completed():
	if is_going_to_end:
		return
	is_going_to_end = true
	print("🎊 Lobby: Iniciando transición a pantalla final...")
	_show_victory_message()
	# Ir a la pantalla de final después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	_go_to_ending()

func _show_victory_message():
	if victory_ui:
		victory_ui.text = "\n🎉 ¡FELICIDADES! ¡HAS COMPLETADO TODOS LOS NIVELES! 🎉"
		victory_ui.visible = true
		print("🎊 Mostrando mensaje de victoria...")

func _go_to_ending():
	print("🎬 Cargando pantalla de final...")
	# Fade out del audio
	var fade_tween = create_tween()
	fade_tween.tween_property(audio, "volume_db", -80.0, 1.5)
	await fade_tween.finished
	
	# Cargar escena de final
	get_tree().change_scene_to_file("res://src/GUI/End.tscn")

func _on_audio_finished() -> void:
	audio.play()

func _on_area_body_entered(body: Node3D, area: Area3D) -> void:
	if body != player:
		return

	# transición visual del player
	player.start_distortion_transition(1.0)

	# fade out de audio
	var audio_tween := create_tween()
	audio_tween.tween_property(
		audio,
		"volume_db",
		-80.0, # silencio real
		1.0
	)

	await get_tree().create_timer(1.0).timeout

	get_tree().change_scene_to_file(level_areas[area])
