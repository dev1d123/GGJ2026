extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var player: CharacterBody3D = $Player

@onready var level_areas: Dictionary[Area3D, String] = {
	$Level1Area3D: "res://src/levels/level1/Level1.tscn",
	$Level2Area3D: "res://src/levels/level2/Level2.tscn",
	$Level3Area3D: "res://src/levels/level3/Level3.tscn",
	$Level4Area3D: "res://src/levels/level4/Level4.tscn"
}

func _ready() -> void:
	audio.finished.connect(_on_audio_finished)
	audio.play()

	for area in level_areas.keys():
		area.body_entered.connect(
			func(body: Node3D) -> void:
				_on_area_body_entered(body, area)
		)

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
