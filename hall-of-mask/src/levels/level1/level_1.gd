extends Node3D

@onready var audio_normal: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone:   AudioStreamPlayer = $AudioStreamPlayer2
@onready var zone:         Area3D            = $zoneBoss
@onready var player:       Node              = $Player

# Jefe spawnea dinámicamente al entrar a la zona
const BOSS_SCENE := preload("res://src/actors/enemies/bosses/orc_brute_green.tscn")
const BOSS_SPAWN_POS := Vector3(113.09914, 24.901669, 127.99787)
var _boss: BossOrc = null
var _boss_spawned: bool = false

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
	sfx_player.stream = preload("res://assets/sfx/startLevel.mp3")
	sfx_player.play()
	audio_normal.volume_db -= 6.0
	audio_zone.volume_db   -= 6.0

	# ── Conectar señales ───────────────────────────────────────────────
	if player and player.has_node("HealthComponent"):
		var health: Node = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)

	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)
	audio_normal.finished.connect(_on_audio_normal_finished)
	audio_zone.finished.connect(_on_audio_zone_finished)

	audio_normal.play()


func _process(_delta: float) -> void:
	# Atajo para completar nivel con tecla M
	if Input.is_key_pressed(KEY_M):
		_complete_level()

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
	# Spawn el jefe la primera vez que el jugador entra a la zona
	if not _boss_spawned:
		_boss_spawned = true
		_spawn_boss()

func _spawn_boss() -> void:
	_boss = BOSS_SCENE.instantiate() as BossOrc
	# Capas iguales a las del nodo pre-colocado en la escena (capa 1 = Terrain3D)
	_boss.collision_layer = 255
	_boss.collision_mask  = 255
	get_node("Node").add_child(_boss)
	# Diferir un frame para que el chunk de Terrain3D esté registrado en el servidor de física
	await get_tree().physics_frame
	_boss.global_position = BOSS_SPAWN_POS
	_boss.boss_died.connect(_on_boss_died)

func _on_zone_exited(body: Node) -> void:
	if body != player:
		return
	audio_zone.stop()
	audio_normal.play()

func _on_boss_died(_boss = null):
	_complete_level()

func _complete_level():
	# Reproducir sonido de victoria
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()
	
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
