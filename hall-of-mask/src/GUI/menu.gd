extends Control

@onready var start_button: TextureButton = $startButton
@onready var exit_button: TextureButton = $exitButton

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_exit_pressed() -> void:
	get_tree().quit()
