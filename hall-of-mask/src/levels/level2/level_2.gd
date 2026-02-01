extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var zone_boss: Area3D = $zoneBoss

func _ready() -> void:
	audio.finished.connect(_on_audio_finished)
	audio.play()
	
	# Conectar señal del zoneBoss si existe
	if zone_boss:
		zone_boss.body_entered.connect(_on_zone_boss_entered)

func _process(delta):
	# Atajo para completar nivel con tecla ñ
	if Input.is_action_just_pressed("ui_text_completion_query") or Input.is_key_pressed(KEY_M):
		_complete_level()

func _on_zone_boss_entered(body):
	if body.name == "Player":
		print("¡Jugador llegó al zoneBoss! Teletransportando al lobby...")
		_complete_level()

func _complete_level():
	GameManager.complete_level("level2")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://src/levels/lobby/Lobby.tscn")

func _on_audio_finished() -> void:
	audio.play()
