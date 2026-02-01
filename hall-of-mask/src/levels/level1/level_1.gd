extends Node3D

@onready var audio_normal: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone: AudioStreamPlayer = $AudioStreamPlayer2
@onready var zone: Area3D = $zoneBoss
@onready var player: Node = $Player
@onready var boss: BossOrc = $Node/Orc_Brute_Green

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"

func _ready() -> void:
	# Conectamos la muerte del jefe
	boss.boss_died.connect(_on_boss_died)

	# Conectamos la zona
	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)

	# Conectar señales de fin de audio para repetir
	audio_normal.finished.connect(_on_audio_normal_finished)
	audio_zone.finished.connect(_on_audio_zone_finished)

	# Reproducir audio normal
	audio_normal.play()

func _on_audio_normal_finished() -> void:
	audio_normal.play()

func _on_audio_zone_finished() -> void:
	audio_zone.play()

func _on_zone_entered(body: Node) -> void:
	print("enter")
	if body != player:
		return
	audio_normal.stop()
	audio_zone.play()

func _on_zone_exited(body: Node) -> void:
	if body != player:
		return
	audio_zone.stop()
	audio_normal.play()

func _on_boss_died(_boss):
	get_tree().change_scene_to_file(LOBBY_SCENE)
