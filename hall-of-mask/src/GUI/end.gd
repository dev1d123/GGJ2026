extends Control

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var background: TextureRect = $Background
@onready var portrait:   TextureRect = $DialogueBg/HBox/Portrait
@onready var name_label: Label       = $DialogueBg/HBox/VBox/NameLabel
@onready var text_label: Label       = $DialogueBg/HBox/VBox/TextLabel
@onready var fade:       ColorRect   = $Fade
@onready var audio:      AudioStreamPlayer = $AudioStreamPlayer

# ── Constantes ─────────────────────────────────────────────────────────────
const IMAGES_PATH := "res://assets/historyImages/"

# ── Parámetros de presentación ─────────────────────────────────────────────
var fade_time    := 0.8
var typing_speed := 0.03  # segundos por letra

# ── Estado interno ─────────────────────────────────────────────────────────
var current_index         := 0
var is_typing             := false
var can_advance           := false
var typewriter_generation := 0

# ══════════════════════════════════════════════════════════════════════════
# DATOS DEL ENDING — 2 escenas finales + post-créditos (20 beats)
#
# Claves de cada beat:
#   bg     → archivo de fondo en IMAGES_PATH
#   sprite → retrato del personaje (vacío = narración o voz sin imagen)
#   name   → nombre en mayúsculas  (vacío = narración pura)
#   text   → texto del cuadro de diálogo
#
# Nota de implementación:
#   • VOZ DESCONOCIDA → sprite vacío, name = "VOZ DESCONOCIDA"
#     (se muestra el nombre sin retrato; fuente en color distinto vía
#      la rama _load_beat que detecta este nombre especial)
#   • Monólogo interno (para sí) → texto entre paréntesis en el campo text
# ══════════════════════════════════════════════════════════════════════════
var dialogue_data: Array[Dictionary] = [

	# ── ESCENA FINAL 1 — CASA VAYNE — ATARDECER ────────────────────────
	{"bg": "f_scene1.png", "sprite": "",          "name": "",      "text": "La casa. Reparada. Foto de VERA en la pared. ELI coloca una planta nueva en el jardín."},
	{"bg": "f_scene1.png", "sprite": "eli.png",   "name": "ELI",  "text": "Mamá decía que las raíces sostienen todo."},
	{"bg": "f_scene1.png", "sprite": "",          "name": "",      "text": "KAEL mira a REN."},
	{"bg": "f_scene1.png", "sprite": "kael.png",  "name": "KAEL", "text": "Encontramos parte del árbol genealógico. Tú y Dorian comparten sangre. Antigua. Lejana. Pero real."},
	{"bg": "f_scene1.png", "sprite": "ren.png",   "name": "REN",  "text": "¿Dorian sabía?"},
	{"bg": "f_scene1.png", "sprite": "kael.png",  "name": "KAEL", "text": "Creo que sí. Pero nunca dijo nada por respeto a mamá."},
	{"bg": "f_scene1.png", "sprite": "",          "name": "",      "text": "REN procesa esto. No hay explosión emocional. Solo entendimiento lento."},
	{"bg": "f_scene1.png", "sprite": "ren.png",   "name": "REN",  "text": "¿Eso cambia algo entre nosotros?"},
	{"bg": "f_scene1.png", "sprite": "eli.png",   "name": "ELI",  "text": "Para mí no."},
	{"bg": "f_scene1.png", "sprite": "kael.png",  "name": "KAEL", "text": "No importa cómo empezó. Somos lo que decidimos ahora."},
	{"bg": "f_scene1.png", "sprite": "",          "name": "",      "text": "REN asiente. ELI le pasa una pala. Los tres plantan el jardín."},

	# ── ESCENA FINAL 2 — CUARTO DE ALDRIC — NOCHE ──────────────────────
	{"bg": "f_scene2.png", "sprite": "",           "name": "",       "text": "ALDRIC solo. Abre un viejo baúl. Saca un árbol genealógico completo, más completo del que KAEL encontró en el Hall. En la parte inferior: un símbolo antiguo junto a los apellidos VAYNE y CAYNE entrelazados."},
	{"bg": "f_scene2.png", "sprite": "aldric.png", "name": "ALDRIC", "text": "(Para sí) Pronto tendré que contarles el resto."},
	{"bg": "f_scene2.png", "sprite": "",           "name": "",       "text": "Cierra el baúl. Apaga la luz."},

	# ── POST-CRÉDITOS — EL HALL — RUINAS ───────────────────────────────
	{"bg": "credits.png", "sprite": "", "name": "",                  "text": "Entre los restos del Hall colapsado. Polvo y máscaras rotas."},
	{"bg": "credits.png", "sprite": "", "name": "",                  "text": "Una puerta sellada con el mismo símbolo antiguo del baúl de ALDRIC."},
	{"bg": "credits.png", "sprite": "", "name": "",                  "text": "La puerta vibra. Una grieta de luz aparece en el borde."},
	{"bg": "credits.png", "sprite": "", "name": "",                  "text": "Del otro lado: una máscara desconocida flota. No es como las otras. Más antigua. Más pesada."},
	{"bg": "credits.png", "sprite": "", "name": "",                  "text": "Una voz. No es VERA. No es nadie que conozcamos."},
	{"bg": "credits.png", "sprite": "", "name": "VOZ DESCONOCIDA",   "text": "Las raíces van más profundo de lo que creen, Vayne."},
]

# ══════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	var font_res: FontFile = load("res://assets/imagesGUI/font.TTF")
	name_label.add_theme_font_override("font", font_res)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)

	var font_text: FontFile = load("res://assets/imagesGUI/font.TTF")
	text_label.add_theme_font_override("font", font_text)
	text_label.add_theme_font_size_override("font_size", 28)

	audio.play()
	fade.modulate.a = 1.0
	_load_beat(0)
	await _fade_in()
	_start_typewriter()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if is_typing:
			_finish_typewriter()
		elif can_advance:
			_advance()
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

# ══════════════════════════════════════════════════════════════════════════
# LÓGICA DE AVANCE
# ══════════════════════════════════════════════════════════════════════════

func _advance() -> void:
	if current_index >= dialogue_data.size() - 1:
		await _fade_out()
		_end_game()
		return

	can_advance = false
	var next_index := current_index + 1

	if dialogue_data[current_index]["bg"] != dialogue_data[next_index]["bg"]:
		await _fade_out()
		current_index = next_index
		_load_beat(current_index)
		await _fade_in()
	else:
		current_index = next_index
		_load_beat(current_index)

	_start_typewriter()


func _load_beat(index: int) -> void:
	var entry: Dictionary = dialogue_data[index]

	background.texture = load(IMAGES_PATH + entry["bg"])

	var sprite: String = entry["sprite"]
	var name:   String = entry["name"]

	if sprite.is_empty() and name.is_empty():
		# Narración pura
		portrait.visible   = false
		name_label.visible = false
	elif name == "VOZ DESCONOCIDA":
		# Voz sin imagen: nombre con color especial, sin retrato
		portrait.visible   = false
		name_label.text    = name
		name_label.visible = true
		# Color plateado / espectral para distinguirlo de personajes normales
		name_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 1.0))
	else:
		if not sprite.is_empty():
			portrait.texture = load(IMAGES_PATH + sprite)
			portrait.visible = true
		else:
			portrait.visible = false
		name_label.text  = name
		name_label.visible = true
		# Color dorado estándar para personajes conocidos
		name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))

	text_label.text              = entry["text"]
	text_label.visible_characters = 0

# ══════════════════════════════════════════════════════════════════════════
# EFECTO MÁQUINA DE ESCRIBIR
# ══════════════════════════════════════════════════════════════════════════

func _start_typewriter() -> void:
	is_typing   = true
	can_advance = false
	typewriter_generation += 1
	var my_gen := typewriter_generation

	for _i in range(text_label.text.length()):
		await get_tree().create_timer(typing_speed).timeout
		if typewriter_generation != my_gen:
			return
		text_label.visible_characters += 1

	if typewriter_generation == my_gen:
		is_typing   = false
		can_advance = true


func _finish_typewriter() -> void:
	typewriter_generation += 1
	is_typing                     = false
	text_label.visible_characters = text_label.text.length()
	can_advance                   = true

# ══════════════════════════════════════════════════════════════════════════
# TRANSICIONES Y CIERRE
# ══════════════════════════════════════════════════════════════════════════

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, fade_time)
	await tween.finished


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	await tween.finished


func _end_game() -> void:
	# El juego termina aquí — pantalla en negro, ESC para salir
	print("🎮 FIN DEL JUEGO")

