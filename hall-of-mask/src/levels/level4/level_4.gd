extends Node3D

# ---------------- AUDIO ----------------
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

# ---------------- PLATFORMS ----------------
@onready var platforms: Array[Node3D] = [
	$Elements/Node/ClockPlatform,
	$Elements/Node/ClockPlatform2,
	$Elements/Node/ClockPlatform3,
	$Elements/Node/ClockPlatform4,
	$Elements/Node/ClockPlatform5
]

const MOVE_HEIGHT := 10.0
const MOVE_TIME := 2.5
const OFFSET_TIME := 0.4 # desfase entre plataformas

# ---------------- BRASS ----------------
@onready var brass_parts: Array[Node3D] = [
	$Elements/Brass13,
	$Elements/Brass14,
	$Elements/Brass15
]

const BRASS_ROT_SPEED := 1.5 # radianes por segundo

# ---------------- READY ----------------
func _ready() -> void:
	# audio en loop
	audio.finished.connect(_on_audio_finished)
	audio.play()

	# iniciar plataformas con desfase
	for i in platforms.size():
		start_platform_loop(platforms[i], i * OFFSET_TIME)

# ---------------- AUDIO LOOP ----------------
func _on_audio_finished() -> void:
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
