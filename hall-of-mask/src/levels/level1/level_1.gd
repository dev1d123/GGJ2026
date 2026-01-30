extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	audio.finished.connect(_on_audio_finished)
	audio.play()

func _on_audio_finished() -> void:
	audio.play()
