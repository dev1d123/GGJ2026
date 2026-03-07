extends Node3D

@onready var audio_normal: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone:   AudioStreamPlayer = $AudioStreamPlayer2
@onready var zone_boss:    Area3D            = $zoneBoss
@onready var player:       Node              = $Player
@onready var boss:         BossOrc           = $BlackKnight

# Sonidos de victoria y derrota
var victory_sound: AudioStream = preload("res://assets/sounds/win.wav")
var defeat_sound: AudioStream = preload("res://assets/sounds/lose.wav")
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"
const LEVEL_ID    := "level_2"

func _ready() -> void:
	# Agregar AudioStreamPlayer para SFX
	add_child(sfx_player)
	sfx_player.bus = "Master"
	sfx_player.volume_db = 6.0
	sfx_player.stream = preload("res://assets/sfx/startLevel.mp3")
	sfx_player.play()
	audio_normal.volume_db -= 6.0
	audio_zone.volume_db   -= 6.0

	# Conectar muerte del jugador
	if player and player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)

	boss.boss_died.connect(_on_boss_died)
	zone_boss.body_entered.connect(_on_zone_boss_entered)
	zone_boss.body_exited.connect(_on_zone_boss_exited)
	audio_normal.finished.connect(_on_audio_normal_finished)
	audio_zone.finished.connect(_on_audio_zone_finished)

	audio_normal.play()

func _process(_delta: float) -> void:
	# Atajo para completar nivel con tecla M
	if Input.is_key_pressed(KEY_M):
		_complete_level()

func _on_zone_boss_entered(body: Node) -> void:
	if body != player:
		return
	audio_normal.stop()
	audio_zone.play()

func _on_zone_boss_exited(body: Node) -> void:
	if body != player:
		return
	audio_zone.stop()
	audio_normal.play()

func _on_boss_died(_boss) -> void:
	_complete_level()

func _complete_level() -> void:
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()

	GameManager.complete_level("level2")
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_player_died() -> void:
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = defeat_sound
	sfx_player.play()
	print("💀 Level 2: Jugador ha muerto")

func _on_audio_normal_finished() -> void:
	audio_normal.play()

func _on_audio_zone_finished() -> void:
	audio_zone.play()
