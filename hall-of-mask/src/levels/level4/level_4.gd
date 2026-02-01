extends Node3D

# ---------------- AUDIO ----------------
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone: AudioStreamPlayer = $AudioStreamPlayer2
@onready var boss: BossWizard = $Time_Boss
@onready var zone: Area3D = $zoneBoss
@onready var player: Node = $Player

# Sonidos de victoria y derrota
var victory_sound: AudioStream = preload("res://assets/sounds/win.wav")
var defeat_sound: AudioStream = preload("res://assets/sounds/lose.wav")
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

# ---------------- PLATFORMS ----------------
@onready var platforms: Array[Node3D] = [
	$Elements/Node/ClockPlatform,
	$Elements/Node/ClockPlatform2,
	$Elements/Node/ClockPlatform3,
	$Elements/Node/ClockPlatform4,
	$Elements/Node/ClockPlatform5
]

const MOVE_HEIGHT := 15.0
const MOVE_TIME := 2.5
const OFFSET_TIME := 0.4 # desfase entre plataformas

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"

# ---------------- BRASS ----------------
@onready var brass_parts: Array[Node3D] = [
	$Elements/Brass13,
	$Elements/Brass14,
	$Elements/Brass15
]
const BRASS_ROT_SPEED := 1.5 # radianes por segundo

# ---------------- READY ----------------
func _ready() -> void:
	# Agregar AudioStreamPlayer para SFX
	add_child(sfx_player)
	sfx_player.bus = "Master"
	
	# Conectar muerte del jugador
	if player and player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)
	
	# audio normal en loop
	audio.finished.connect(_on_audio_finished)
	audio.play()

	# muerte del boss -> volver al lobby
	if boss:
		boss.boss_died.connect(_on_boss_died)

	# iniciar plataformas con desfase
	for i in platforms.size():
		start_platform_loop(platforms[i], i * OFFSET_TIME)

	# conectar zona del jefe
	zone.body_entered.connect(_on_zone_entered)
	zone.body_exited.connect(_on_zone_exited)

	# audio_zone en loop
	audio_zone.finished.connect(_on_audio_zone_finished)

# ---------------- AUDIO LOOP ----------------
func _on_audio_finished() -> void:
	if not audio.playing:
		audio.play()

func _on_audio_zone_finished() -> void:
	if not audio_zone.playing:
		audio_zone.play()

# ---------------- ZONE AUDIO ----------------
func _on_zone_entered(body: Node) -> void:
	if body != player:
		return
	# cambiar a música de zona
	if audio.playing:
		audio.stop()
	audio_zone.play()

func _on_zone_exited(body: Node) -> void:
	if body != player:
		return
	# volver a música normal
	if audio_zone.playing:
		audio_zone.stop()
	audio.play()

# ---------------- PLATFORM MOVEMENT ----------------
func start_platform_loop(platform: Node3D, offset: float) -> void:
	var start_pos := platform.position
	var up_pos := start_pos + Vector3.UP * MOVE_HEIGHT

	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# desfase inicial
	if offset > 0.0:
		tween.tween_interval(offset)

	# subir
	tween.tween_property(
		platform,
		"position",
		up_pos,
		MOVE_TIME
	)

	# bajar
	tween.tween_property(
		platform,
		"position",
		start_pos,
		MOVE_TIME
	)

# ---------------- BRASS ROTATION (CONSTANTE) ----------------
func _process(delta: float) -> void:
	for brass in brass_parts:
		brass.rotate_y(BRASS_ROT_SPEED * delta)
	
	# Atajo para completar nivel con tecla M
	if Input.is_key_pressed(KEY_M):
		_complete_level()

# ---------------- BOSS DIED ----------------
func _on_boss_died(_boss) -> void:
	_complete_level()

func _complete_level():
	# Reproducir sonido de victoria
	audio.stop()
	audio_zone.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()
	
	GameManager.complete_level("level4")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_player_died():
	# Reproducir sonido de derrota
	audio.stop()
	audio_zone.stop()
	sfx_player.stream = defeat_sound
	sfx_player.play()
	print("💀 Level 4: Jugador ha muerto")
