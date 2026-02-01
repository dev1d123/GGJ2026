extends Node3D

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var enemy_container = $"."
@onready var player: Node = $Player

var total_enemies: int = 0
var enemies_killed: int = 0
var enemies_list: Array[Node] = []
var ui_label: Label

# Sonidos de victoria y derrota
var victory_sound: AudioStream = preload("res://assets/sounds/win.wav")
var defeat_sound: AudioStream = preload("res://assets/sounds/lose.wav")
@onready var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()

const LOBBY_SCENE := "res://src/levels/lobby/Lobby.tscn"

func _ready() -> void:
	# Agregar AudioStreamPlayer para SFX
	add_child(sfx_player)
	sfx_player.bus = "Master"
	
	# Conectar muerte del jugador
	if player and player.has_node("HealthComponent"):
		var health = player.get_node("HealthComponent")
		if health.has_signal("on_death"):
			health.on_death.connect(_on_player_died)
	
	audio.finished.connect(_on_audio_finished)
	audio.play()
	
	# Contar enemigos Skeleton
	_count_enemies()
	
	# Crear UI
	_create_enemy_counter_ui()
	
	# Conectar señales de muerte de enemigos
	_connect_enemy_signals()

func _process(delta):
	# Atajo para completar nivel con tecla M
	if Input.is_key_pressed(KEY_M):
		_complete_level()

func _count_enemies():
	if not enemy_container:
		return
	
	for child in enemy_container.get_children():
		if "Skeleton" in child.name:
			enemies_list.append(child)
			total_enemies += 1
	
	print("Level 3: Se encontraron ", total_enemies, " enemigos")

func _connect_enemy_signals():
	for enemy in enemies_list:
		if enemy.has_node("HealthComponent"):
			var health_comp = enemy.get_node("HealthComponent")
			if health_comp.has_signal("on_death"):
				# Conectar con lambda para ignorar parámetros extra
				health_comp.on_death.connect(func(): _on_enemy_died())
				print("  ✅ Conectado: ", enemy.name)

func _on_enemy_died():
	enemies_killed += 1
	print("💀 Enemigo eliminado! Total: ", enemies_killed, "/", total_enemies)
	_update_ui()
	
	if enemies_killed >= total_enemies:
		_all_enemies_defeated()

func _all_enemies_defeated():
	print("¡Todos los enemigos derrotados! Teletransportando al lobby...")
	_complete_level()

func _complete_level():
	# Reproducir sonido de victoria
	audio.stop()
	sfx_player.stream = victory_sound
	sfx_player.play()
	
	GameManager.complete_level("level3")
	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file(LOBBY_SCENE)

func _on_player_died():
	# Reproducir sonido de derrota
	audio.stop()
	sfx_player.stream = defeat_sound
	sfx_player.play()
	print("💀 Level 3: Jugador ha muerto")

func _create_enemy_counter_ui():
	# Crear un CanvasLayer para el UI
	var canvas = CanvasLayer.new()
	canvas.name = "EnemyCounterUI"
	add_child(canvas)
	
	# Crear panel de fondo centrado en la parte superior
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-150, 20)
	panel.custom_minimum_size = Vector2(300, 0)
	canvas.add_child(panel)
	
	# Crear VBoxContainer para organizar el texto
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Título
	var title = Label.new()
	title.text = "MATA A TODOS LOS ENEMIGOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	# Contador
	ui_label = Label.new()
	ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(ui_label)
	
	_update_ui()

func _update_ui():
	if ui_label:
		ui_label.text = "Restantes: %d/%d" % [total_enemies - enemies_killed, total_enemies]

func _on_audio_finished() -> void:
	audio.play()
