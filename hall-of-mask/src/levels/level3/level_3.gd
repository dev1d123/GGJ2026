extends Node3D

@onready var audio_normal: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_zone:   AudioStreamPlayer = $AudioStreamPlayer2
@onready var player: Node = $Player
@onready var boss: BossOrc = $Monstrosity

var total_enemies: int = 0
var enemies_killed: int = 0
var enemies_list: Array[Node] = []
var ui_label: Label

# Sonidos de victoria y derrota
var victory_sound: AudioStream = preload("res://assets/sounds/win.wav")
var defeat_sound: AudioStream = preload("res://assets/sounds/lose.wav")
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"
const LEVEL_ID    := "level_3"

func _ready() -> void:
	# Agregar AudioStreamPlayer para SFX
	add_child(sfx_player)
	sfx_player.bus = "Master"
	sfx_player.volume_db = 6.0
	sfx_player.stream = preload("res://assets/sfx/startLevel.mp3")
	sfx_player.play()
	audio_normal.volume_db -= 6.0
	audio_zone.volume_db   -= 6.0

	# El boss empieza oculto e inactivo (ya configurado en la escena)
	# (visible = false, process_mode = DISABLED)

	# Conectar muerte del jugador
	if player and player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)

	boss.boss_died.connect(_on_boss_died)
	audio_normal.finished.connect(_on_audio_normal_finished)
	audio_zone.finished.connect(_on_audio_zone_finished)

	audio_normal.play()

	# Contar y conectar enemigos regulares
	_count_enemies()
	_create_enemy_counter_ui()
	_connect_enemy_signals()


func _process(_delta: float) -> void:
	# Atajo para completar nivel con tecla M
	if Input.is_key_pressed(KEY_M):
		_complete_level()

func _count_enemies() -> void:
	for child in get_children():
		if "Skeleton" in child.name:
			enemies_list.append(child)
			total_enemies += 1
	print("Level 3: Se encontraron ", total_enemies, " enemigos")

func _connect_enemy_signals() -> void:
	for enemy in enemies_list:
		if enemy.has_node("HealthComponent"):
			var health_comp = enemy.get_node("HealthComponent")
			if health_comp.has_signal("on_death"):
				health_comp.on_death.connect(func(): _on_enemy_died())
				print("  ✅ Conectado: ", enemy.name)

func _on_enemy_died() -> void:
	enemies_killed += 1
	print("💀 Enemigo eliminado! Total: ", enemies_killed, "/", total_enemies)
	_update_ui()
	if enemies_killed >= total_enemies:
		_all_enemies_defeated()

func _all_enemies_defeated() -> void:
	print("¡Todos los enemigos derrotados! ¡Aparece el jefe!")
	# Cambiar a música de boss
	audio_normal.stop()
	audio_zone.play()
	# Activar y mostrar al boss
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss.visible = true

func _on_boss_died(_b) -> void:
	_complete_level()

func _complete_level() -> void:
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()

	GameManager.complete_level("level3")
	await get_tree().create_timer(4.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_player_died() -> void:
	audio_normal.stop()
	audio_zone.stop()
	sfx_player.stream = defeat_sound
	sfx_player.play()
	print("💀 Level 3: Jugador ha muerto")

func _create_enemy_counter_ui() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "EnemyCounterUI"
	add_child(canvas)

	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-150, 20)
	panel.custom_minimum_size = Vector2(300, 0)
	canvas.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "MATA A TODOS LOS ENEMIGOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	ui_label = Label.new()
	ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_label.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
	ui_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(ui_label)

	_update_ui()

func _update_ui() -> void:
	if ui_label:
		ui_label.text = "Restantes: %d/%d" % [total_enemies - enemies_killed, total_enemies]

func _on_audio_normal_finished() -> void:
	audio_normal.play()

func _on_audio_zone_finished() -> void:
	audio_zone.play()
