extends CanvasLayer

# ── Constantes ─────────────────────────────────────────────────────────────
const IMAGES_PATH    := "res://assets/historyImages/"
const FONT_PATH      := "res://assets/imagesGUI/font.TTF"
const FADE_IN_TIME   := 0.3
const VISIBLE_TIME   := 3.5
const FADE_OUT_TIME  := 0.4

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var _panel:    PanelContainer = $PanelContainer
@onready var _portrait: TextureRect    = $PanelContainer/HBox/Portrait
@onready var _label:    Label          = $PanelContainer/HBox/TextLabel

# ── Cola de toasts pendientes ──────────────────────────────────────────────
var _queue:   Array[Dictionary] = []
var _running: bool              = false

# ══════════════════════════════════════════════════════════════════════════
# API PÚBLICA
# ══════════════════════════════════════════════════════════════════════════

## Muestra un toast con el personaje y texto indicados.
## Si hay uno visible, lo encola para mostrarlo a continuación.
func show_toast(character: String, text: String) -> void:
	_queue.append({"character": character, "text": text})
	if not _running:
		_process_queue()


func _process_queue() -> void:
	if _queue.is_empty():
		_running = false
		return

	_running = true
	var entry: Dictionary = _queue.pop_front()
	await _show_entry(entry["character"], entry["text"])
	_process_queue()


func _show_entry(character: String, text: String) -> void:
	# Cargar imagen del personaje (kael.png / eli.png; fallback: invisible)
	var img_path := IMAGES_PATH + character + ".png"
	if ResourceLoader.exists(img_path):
		_portrait.texture = load(img_path)
		_portrait.visible = true
	else:
		_portrait.visible = false

	_label.text      = text
	_panel.modulate  = Color(1, 1, 1, 0)
	_panel.visible   = true

	# Fade in
	var tween_in := create_tween()
	tween_in.tween_property(_panel, "modulate:a", 1.0, FADE_IN_TIME)
	await tween_in.finished

	# Visible
	await get_tree().create_timer(VISIBLE_TIME).timeout

	# Fade out
	var tween_out := create_tween()
	tween_out.tween_property(_panel, "modulate:a", 0.0, FADE_OUT_TIME)
	await tween_out.finished

	_panel.visible = false
