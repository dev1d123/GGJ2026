extends Node3D

@onready var audio_normal: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone:   AudioStreamPlayer = $AudioStreamPlayer2
@onready var zone:         Area3D            = $zoneBoss
@onready var player:       Node              = $Player
@onready var boss:         BossOrc           = $Node/Orc_Brute_Green

# Sonidos de victoria y derrota
var victory_sound: AudioStream = preload("res://assets/sounds/win.wav")
var defeat_sound:  AudioStream = preload("res://assets/sounds/lose.wav")
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

const LOBBY_SCENE  := "res://src/levels/lobby/Lobby.tscn"
const LEVEL_ID     := "level_1"

func _ready() -> void:
	# ── Audio SFX ──────────────────────────────────────────────────────
	add_child(sfx_player)
	sfx_player.bus = "Master"
	sfx_player.volume_db = 6.0
	audio_normal.volume_db -= 6.0
	audio_zone.volume_db   -= 6.0

	# ── Conectar señales ───────────────────────────────────────────────
	if player and player.has_node("HealthComponent"):
		var health: Node = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)

	boss.boss_died.connect(_on_boss_died)
	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)
	audio_normal.finished.connect(_on_audio_normal_finished)
	audio_zone.finished.connect(_on_audio_zone_finished)

	audio_normal.play()

	# ── Diálogo de entrada (primera visita) ────────────────────────────
	_show_entry_dialog()

func _process(_delta: float) -> void:
	# Atajo para completar nivel con tecla M
	if Input.is_key_pressed(KEY_M):
		_complete_level()

func _show_entry_dialog() -> void:
	if not GameData.is_first_visit(LEVEL_ID):
		return
	GameData.mark_level_visited(LEVEL_ID)
	var char_id: String = GameData.selected_character
	if char_id.is_empty() or not GameData.DIALOGS.has(char_id):
		return
	var text: String = GameData.DIALOGS[char_id][LEVEL_ID]["entry"]
	ToastNotification.show_toast(char_id, text)

func _show_exit_dialog() -> void:
	var char_id: String = GameData.selected_character
	if char_id.is_empty() or not GameData.DIALOGS.has(char_id):
		return
	var text: String = GameData.DIALOGS[char_id][LEVEL_ID]["exit"]
	ToastNotification.show_toast(char_id, text)

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
	_complete_level()

func _complete_level():
	# Reproducir sonido de victoria
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()
	_show_exit_dialog()
	
	GameManager.complete_level("level1")
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_player_died():
	# Reproducir sonido de derrota
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = defeat_sound
	sfx_player.play()
	print("💀 Level 1: Jugador ha muerto")
