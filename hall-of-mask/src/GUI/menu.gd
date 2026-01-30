extends Control

@onready var start_button: TextureButton = $startButton
@onready var exit_button: TextureButton = $exitButton
@onready var music: AudioStreamPlayer = $AudioStreamPlayer

const CINEMATIC_SCENE := "res://src/GUI/Cinematic.tscn"
const FADE_TIME := 1.0

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	music.play()

func _on_start_pressed() -> void:
	start_button.disabled = true
	exit_button.disabled = true

	var tween := create_tween()
	tween.tween_property(
		music,
		"volume_db",
		-80.0,
		FADE_TIME
	)
	tween.tween_callback(_change_to_cinematic)

func _change_to_cinematic() -> void:
	music.stop()
	get_tree().change_scene_to_file(CINEMATIC_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()
