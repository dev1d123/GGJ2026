extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"
@onready var boss: BossOrc =$Node/Orc_Brute_Green

func _ready() -> void:
	boss.boss_died.connect(_on_boss_died)
	audio.finished.connect(_on_audio_finished)
	audio.play()

func _on_audio_finished() -> void:
	audio.play()


func _on_boss_died(_boss):
	get_tree().change_scene_to_file(LOBBY_SCENE)
