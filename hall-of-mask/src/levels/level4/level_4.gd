extends Node3D

# ---------------- AUDIO ----------------
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone: AudioStreamPlayer = $AudioStreamPlayer2
@onready var boss: BossWizard = $Time_Boss
@onready var zone: Area3D = $zoneBoss
@onready var player: Node = $Player

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
	GameManager.complete_level("level4")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)
