extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var player: Node3D = $Player

var bosses_alive: int = 0

const END_SCENE     := "res://src/GUI/End.tscn"
const LOBBY_SCENE   := "res://src/levels/lobby/Lobby.tscn"

var _victory_sound: AudioStream = preload("res://assets/sounds/win.wav")
var _defeat_sound: AudioStream  = preload("res://assets/sounds/lose.wav")
var _sfx: AudioStreamPlayer

func _ready() -> void:
	# ── SFX player ──────────────────────────────────────────────
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	_sfx.volume_db = 6.0
	add_child(_sfx)

	# Sonido de inicio de nivel
	_sfx.stream = preload("res://assets/sfx/startLevel.mp3")
	_sfx.play()

	# Música de jefe un poco más baja que el default
	audio.volume_db -= 6.0

	# ── Conectar muerte del jugador ──────────────────────────────
	if player and player.has_node("HealthComponent"):
		player.get_node("HealthComponent").on_death.connect(_on_player_died)

	# ── Conectar señales de muerte de los dos jefes ─────────────
	for boss_name in ["FrostGolem", "OrcBruteBlue"]:
		var boss = get_node_or_null(boss_name)
		if boss and boss.has_signal("boss_died"):
			bosses_alive += 1
			boss.boss_died.connect(_on_boss_died)

# ────────────────────────────────────────────────────────────────
# CALLBACKS
# ────────────────────────────────────────────────────────────────
func _on_boss_died() -> void:
	bosses_alive -= 1
	if bosses_alive <= 0:
		_victoria()

func _victoria() -> void:
	_sfx.stream = _victory_sound
	_sfx.play()

	# Fade out música de jefe
	var t = create_tween()
	t.tween_property(audio, "volume_db", -80.0, 2.0)

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file(END_SCENE)

func _on_player_died() -> void:
	_sfx.stream = _defeat_sound
	_sfx.play()
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()
