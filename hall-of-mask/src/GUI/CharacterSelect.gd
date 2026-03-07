extends Control

# ── Constantes ─────────────────────────────────────────────────────────────
const IMAGES_PATH    := "res://assets/historyImages/"
const FONT_PATH      := "res://assets/imagesGUI/font.TTF"
const LEVEL1_SCENE   := "res://src/levels/lobby/Lobby.tscn"
const FADE_DURATION  := 0.6

# ── Nodos ──────────────────────────────────────────────────────────────────
@onready var card_kael:   PanelContainer = $CardsContainer/CardKael
@onready var card_eli:    PanelContainer = $CardsContainer/CardEli
@onready var btn_confirm: Button         = $ConfirmButton
@onready var fade:        ColorRect      = $Fade

var _selected: String = ""

# ══════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	btn_confirm.disabled = true
	fade.modulate.a = 1.0
	_fade_in()

	card_kael.gui_input.connect(_on_card_input.bind("kael"))
	card_eli.gui_input.connect(_on_card_input.bind("eli"))
	btn_confirm.pressed.connect(_on_confirm_pressed)


func _on_card_input(event: InputEvent, char_name: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(char_name)


func _select(char_name: String) -> void:
	_selected = char_name
	_update_card_visuals()
	btn_confirm.disabled = false


func _update_card_visuals() -> void:
	var kael_selected := _selected == "kael"
	card_kael.modulate = Color(1.0, 1.0, 1.0, 1.0) if kael_selected else Color(0.55, 0.55, 0.55, 1.0)
	card_eli.modulate  = Color(1.0, 1.0, 1.0, 1.0) if _selected == "eli" else Color(0.55, 0.55, 0.55, 1.0)


func _on_confirm_pressed() -> void:
	if _selected.is_empty():
		return
	GameData.select_character(_selected)
	btn_confirm.disabled = true
	_fade_out_and_load()


func _fade_out_and_load() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished
	get_tree().change_scene_to_file(LEVEL1_SCENE)


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, FADE_DURATION)
