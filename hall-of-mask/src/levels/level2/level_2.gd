extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var zone_boss: Area3D = $zoneBoss
@onready var player: Node = $Player

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
	# Música ligeramente más baja
	audio.volume_db -= 6.0
	
	# Conectar muerte del jugador
	if player and player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)
	
	audio.finished.connect(_on_audio_finished)
	audio.play()
	
	# Conectar señal del zoneBoss si existe
	if zone_boss:
		zone_boss.body_entered.connect(_on_zone_boss_entered)

	_show_entry_dialog()

func _show_entry_dialog() -> void:
	if not GameData.is_first_visit(LEVEL_ID):
		return
	GameData.mark_level_visited(LEVEL_ID)
	var char_id: String = GameData.selected_character
	if char_id.is_empty() or not GameData.DIALOGS.has(char_id):
		return
	ToastNotification.show_toast(char_id, GameData.DIALOGS[char_id][LEVEL_ID]["entry"])

func _show_exit_dialog() -> void:
	var char_id: String = GameData.selected_character
	if char_id.is_empty() or not GameData.DIALOGS.has(char_id):
		return
	ToastNotification.show_toast(char_id, GameData.DIALOGS[char_id][LEVEL_ID]["exit"])

func _process(delta):
	# Atajo para completar nivel con tecla ñ
	if Input.is_action_just_pressed("ui_text_completion_query") or Input.is_key_pressed(KEY_M):
		_complete_level()

func _on_zone_boss_entered(body):
	if body.name == "Player":
		print("¡Jugador llegó al zoneBoss! Teletransportando al lobby...")
		_complete_level()

func _complete_level():
	# Reproducir sonido de victoria
	audio.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()
	_show_exit_dialog()
	
	GameManager.complete_level("level2")
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_player_died():
	# Reproducir sonido de derrota
	audio.stop()
	sfx_player.stream = defeat_sound
	sfx_player.play()
	print("💀 Level 2: Jugador ha muerto")

func _on_audio_finished() -> void:
	audio.play()
