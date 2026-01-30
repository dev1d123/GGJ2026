extends Control

@onready var images = [
	$Image1,
	$Image2,
	$Image3,
	$Image4,
	$Image5
]

@onready var labels = [
	$Image1/Label1,
	$Image2/Label2,
	$Image3/Label3,
	$Image4/Label4,
	$Image5/Label5
]

@onready var fade: ColorRect = $Fade

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"

var current_index := 0
var can_advance := false
var is_typing := false

var fade_time := 1.0
var typing_speed := 0.03 # segundos por letra

func _ready() -> void:
	_hide_all()
	current_index = 0

	images[0].visible = true
	_prepare_label(labels[0])

	fade.modulate.a = 1.0
	await _fade_in()
	_start_typewriter(labels[0])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if is_typing:
			_finish_typewriter(labels[current_index])
		elif can_advance:
			advance_scene()

func advance_scene() -> void:
	# ÚLTIMA IMAGEN → SALIR AL LOBBY
	if current_index >= images.size() - 1:
		await _fade_out()
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return

	can_advance = false

	await _fade_out()

	images[current_index].visible = false
	current_index += 1

	images[current_index].visible = true
	_prepare_label(labels[current_index])

	await _fade_in()
	_start_typewriter(labels[current_index])

func _prepare_label(label: Label) -> void:
	label.visible_characters = 0

func _start_typewriter(label: Label) -> void:
	is_typing = true
	can_advance = false
	label.visible_characters = 0

	var total_chars := label.text.length()

	for i in range(total_chars):
		if not is_typing:
			return
		label.visible_characters += 1
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	can_advance = true

func _finish_typewriter(label: Label) -> void:
	is_typing = false
	label.visible_characters = label.text.length()
	can_advance = true

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, fade_time)
	await tween.finished

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	await tween.finished

func _hide_all() -> void:
	for img in images:
		img.visible = false
