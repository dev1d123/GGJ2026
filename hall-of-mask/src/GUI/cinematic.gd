extends Control

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var background: TextureRect    = $Background
@onready var portrait:   TextureRect    = $DialogueBg/HBox/Portrait
@onready var name_label: Label          = $DialogueBg/HBox/VBox/NameLabel
@onready var text_label: Label          = $DialogueBg/HBox/VBox/TextLabel
@onready var fade:       ColorRect      = $Fade

# ── Constantes ─────────────────────────────────────────────────────────────
const IMAGES_PATH  := "res://assets/historyImages/"
const LOBBY_SCENE  := "res://src/GUI/CharacterSelect.tscn"
const SKIP_HOLD_TIME := 3.0   # segundos manteniendo Espacio para saltar
# ── Parámetros de presentación ─────────────────────────────────────────────
var fade_time     := 0.8
var typing_speed  := 0.03  # segundos por letra

# ── Estado interno ─────────────────────────────────────────────────────────
var current_index         := 0
var is_typing             := false
var can_advance           := false
var typewriter_generation := 0
var skip_held_time        := 0.0   # acumulador para el hold de saltar
var skip_triggered        := false  # evita doble salto
# ══════════════════════════════════════════════════════════════════════════
# DATOS DEL PRÓLOGO  — 7 escenas, 42 beats
# Formato de cada beat:
#   bg     → archivo de fondo en IMAGES_PATH
#   sprite → archivo de retrato del personaje (vacío = narración)
#   name   → nombre del personaje en mayúsculas  (vacío = narración)
#   text   → texto que se mostrará en el cuadro de diálogo
# ══════════════════════════════════════════════════════════════════════════
var dialogue_data: Array[Dictionary] = [
	# ── ESCENA 1 — CASA VAYNE — TARDE ──────────────────────────────────
	{"bg": "p_scene1.png", "sprite": "",          "name": "",       "text": "El sol entra por la ventana. La casa huele a madera y té. Todo parece normal."},
	{"bg": "p_scene1.png", "sprite": "eli.png",   "name": "ELI",   "text": "¿Cuándo volvemos a plantar el jardín, mamá?"},
	{"bg": "p_scene1.png", "sprite": "vera.png",  "name": "VERA",  "text": "Cuando el clima mejore, amor."},
	{"bg": "p_scene1.png", "sprite": "",          "name": "",       "text": "REN observa una fotografía familiar. Sus dedos rozan el borde como si buscara algo que no sabe nombrar. KAEL entra desde el patio con tierra en las manos."},
	{"bg": "p_scene1.png", "sprite": "kael.png",  "name": "KAEL",  "text": "Papá te está buscando, Ren."},
	{"bg": "p_scene1.png", "sprite": "ren.png",   "name": "REN",   "text": "Ahora voy."},
	{"bg": "p_scene1.png", "sprite": "",          "name": "",       "text": "Se cruzan miradas breves. No hay tensión evidente. Solo algo no dicho."},

	# ── ESCENA 2 — JARDÍN — DÍA ────────────────────────────────────────
	{"bg": "p_scene2.png", "sprite": "",            "name": "",        "text": "ALDRIC conversa con DORIAN CAYNE, el vecino. Hablan bajo, cómodos, como viejos conocidos."},
	{"bg": "p_scene2.png", "sprite": "dorian.png",  "name": "DORIAN", "text": "Siempre me gustó esta casa. Tiene historia."},
	{"bg": "p_scene2.png", "sprite": "aldric.png",  "name": "ALDRIC", "text": "Demasiada."},
	{"bg": "p_scene2.png", "sprite": "",            "name": "",        "text": "REN se acerca. DORIAN lo mira y sonríe, pero hay algo en esa sonrisa: demasiado reconocimiento."},
	{"bg": "p_scene2.png", "sprite": "dorian.png",  "name": "DORIAN", "text": "Cada día te pareces más a tu familia, Ren."},
	{"bg": "p_scene2.png", "sprite": "",            "name": "",        "text": "La palabra \"familia\" flota rara en el aire. ELI no nota nada. KAEL sí."},
	{"bg": "p_scene2.png", "sprite": "eli.png",     "name": "ELI",    "text": "¡Sí! Cuando sonríe, ¡igualito que papá!"},
	{"bg": "p_scene2.png", "sprite": "vera.png",    "name": "VERA",   "text": "Ren, ayúdame adentro."},
	{"bg": "p_scene2.png", "sprite": "",            "name": "",        "text": "KAEL se queda mirando a DORIAN. DORIAN le devuelve la mirada un segundo más de lo necesario."},

	# ── ESCENA 3 — NOCHE — CENA FAMILIAR ──────────────────────────────
	{"bg": "p_scene3.png", "sprite": "",          "name": "",       "text": "Hay risas. Hay normalidad. La mesa está llena. Pero KAEL observa cosas pequeñas: las manos de REN, la forma en que inclina la cabeza, una expresión que le recuerda a alguien que no sabe nombrar."},
	{"bg": "p_scene3.png", "sprite": "eli.png",   "name": "ELI",   "text": "Mañana quiero ir al río."},
	{"bg": "p_scene3.png", "sprite": "ren.png",   "name": "REN",   "text": "Yo también."},
	{"bg": "p_scene3.png", "sprite": "kael.png",  "name": "KAEL",  "text": "Vemos cómo amanece."},
	{"bg": "p_scene3.png", "sprite": "",          "name": "",       "text": "VERA los mira a los tres. Sonríe, pero sus ojos guardan algo."},

	# ── ESCENA 4 — EL INCENDIO — MADRUGADA ────────────────────────────
	{"bg": "p_scene4.png", "sprite": "",           "name": "",        "text": "Un ruido. Cortocircuito en la cocina. Chispas. Fuego en las cortinas."},
	{"bg": "p_scene4.png", "sprite": "vera.png",   "name": "VERA",   "text": "¡Aldric!"},
	{"bg": "p_scene4.png", "sprite": "",           "name": "",        "text": "Caos. KAEL busca a REN entre el humo. ELI llora en el pasillo. ALDRIC saca a los niños."},
	{"bg": "p_scene4.png", "sprite": "aldric.png", "name": "ALDRIC", "text": "¡Salgan, salgan todos!"},
	{"bg": "p_scene4.png", "sprite": "kael.png",   "name": "KAEL",   "text": "¿Dónde está Ren?"},
	{"bg": "p_scene4.png", "sprite": "",           "name": "",        "text": "VERA regresa por algo: una caja, documentos, algo que no puede dejar. El fuego se expande."},
	{"bg": "p_scene4.png", "sprite": "",           "name": "",        "text": "Corte abrupto. Oscuro."},

	# ── ESCENA 5 — EL FUNERAL — CIELO GRIS ────────────────────────────
	{"bg": "p_scene5.png", "sprite": "", "name": "", "text": "Silencio absoluto entre los hermanos. Tres jóvenes frente a una tumba."},
	{"bg": "p_scene5.png", "sprite": "", "name": "", "text": "ELI toma la mano de REN. REN no la suelta."},
	{"bg": "p_scene5.png", "sprite": "", "name": "", "text": "KAEL no mira a nadie. Fija los ojos en el suelo como si buscara una respuesta en la tierra."},
	{"bg": "p_scene5.png", "sprite": "", "name": "", "text": "ALDRIC está a un lado. DORIAN CAYNE aparece al fondo, entre los asistentes. Observa a REN."},

	# ── ESCENA 6 — AÑOS DESPUÉS — CASA VAYNE — NOCHE ──────────────────
	{"bg": "p_scene6.png",  "sprite": "",         "name": "",      "text": "Los hermanos son jóvenes adultos. La casa ha sido reparada, pero algo falta en el aire."},
	{"bg": "p_scene6.png",  "sprite": "",         "name": "",      "text": "REN está en su habitación. Encuentra entre los libros de VERA una carta antigua sin firma."},
	{"bg": "p_scene6b.png", "sprite": "ren.png",  "name": "REN",  "text": "¿Qué es esto...?"},
	{"bg": "p_scene6b.png", "sprite": "",         "name": "",      "text": "La carta menciona un apellido: CAYNE. Y una línea que dice que \"la sangre no olvida lo que la mente entierra\"."},
	{"bg": "p_scene6b.png", "sprite": "",         "name": "",      "text": "REN sale. No dice nada a sus hermanos. Esa noche, el Hall lo llama."},

	# ── ESCENA 7 — DESAPARICIÓN ────────────────────────────────────────
	{"bg": "p_scene7.png", "sprite": "",          "name": "",       "text": "A la mañana siguiente, la habitación de REN está vacía. En su lugar: una máscara desconocida sobre la almohada y un símbolo antiguo trazado en polvo."},
	{"bg": "p_scene7.png", "sprite": "eli.png",   "name": "ELI",   "text": "Kael. Kael, no está."},
	{"bg": "p_scene7.png", "sprite": "",          "name": "",       "text": "KAEL reconoce el símbolo. Lo ha visto antes, en los papeles de ALDRIC."},
	{"bg": "p_scene7.png", "sprite": "kael.png",  "name": "KAEL",  "text": "Sé dónde fue."},
	{"bg": "p_scene7.png", "sprite": "",          "name": "",       "text": "ELI y KAEL se miran. Sin palabras. La decisión ya está tomada."},
]

# ══════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Estilo del nombre del personaje (más grande y en color dorado)
	var font_res: FontFile = load("res://assets/imagesGUI/font.TTF")
	name_label.add_theme_font_override("font", font_res)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))
	name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	name_label.add_theme_constant_override("shadow_offset_x", 2)
	name_label.add_theme_constant_override("shadow_offset_y", 2)

	var font_text: FontFile = load("res://assets/imagesGUI/font.TTF")
	text_label.add_theme_font_override("font", font_text)
	text_label.add_theme_font_size_override("font_size", 28)

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

func _process(delta: float) -> void:
	if skip_triggered:
		return
	if Input.is_key_pressed(KEY_SPACE):
		skip_held_time += delta
		_update_skip_bar(skip_held_time / SKIP_HOLD_TIME)
		if skip_held_time >= SKIP_HOLD_TIME:
			skip_triggered = true
			_skip_cinematic()
	else:
		if skip_held_time > 0.0:
			skip_held_time = 0.0
			_update_skip_bar(0.0)

func _update_skip_bar(ratio: float) -> void:
	var bar: ProgressBar = get_node_or_null("SkipBar")
	if bar:
		bar.value = ratio * 100.0
		bar.visible = ratio > 0.0

func _skip_cinematic() -> void:
	typewriter_generation += 1
	_update_skip_bar(0.0)
	await _fade_out()
	get_tree().change_scene_to_file(LOBBY_SCENE)

# ══════════════════════════════════════════════════════════════════════════
# LÓGICA DE AVANCE
# ══════════════════════════════════════════════════════════════════════════

func _advance() -> void:
	if current_index >= dialogue_data.size() - 1:
		await _fade_out()
		get_tree().change_scene_to_file(LOBBY_SCENE)
		return

	can_advance = false
	var next_index := current_index + 1

	# Fade sólo al cambiar de fondo
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
	if sprite.is_empty():
		portrait.visible   = false
		name_label.visible = false
	else:
		portrait.texture   = load(IMAGES_PATH + sprite)
		portrait.visible   = true
		name_label.text    = entry["name"]
		name_label.visible = true

	text_label.text             = entry["text"]
	text_label.visible_characters = 0

# ══════════════════════════════════════════════════════════════════════════
# EFECTO MÁQUINA DE ESCRIBIR
# ══════════════════════════════════════════════════════════════════════════

func _start_typewriter() -> void:
	is_typing   = true
	can_advance = false
	typewriter_generation += 1
	var my_gen := typewriter_generation

	var total_chars := text_label.text.length()
	for _i in range(total_chars):
		await get_tree().create_timer(typing_speed).timeout
		if typewriter_generation != my_gen:
			return
		text_label.visible_characters += 1

	if typewriter_generation == my_gen:
		is_typing   = false
		can_advance = true


func _finish_typewriter() -> void:
	typewriter_generation += 1   # cancela la coroutine activa
	is_typing                        = false
	text_label.visible_characters    = text_label.text.length()
	can_advance                      = true

# ══════════════════════════════════════════════════════════════════════════
# TRANSICIONES
# ══════════════════════════════════════════════════════════════════════════

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, fade_time)
	await tween.finished


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, fade_time)
	await tween.finished
