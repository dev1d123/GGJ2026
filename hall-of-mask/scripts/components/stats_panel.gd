extends HBoxContainer

@onready var life_container = $BarsContainer/LifeContainer
@onready var mana_bar = $BarsContainer/ManaBar
@onready var stamina_bar = $BarsContainer/StaminaBar
@onready var ulti_bar = $BarsContainer/UltiBar
@onready var mask_icon = $MaskIcon

# --- CONFIGURACIÓN DE ICONOS ---
var default_texture: Texture2D = preload("res://UI_assets/Face.png")
var current_texture: Texture2D = null 
var current_color = Color.WHITE # Cambiado a BLANCO para no teñir la cara de rojo
# --- Panel de Stats ---
var _attr_panel: PanelContainer = null
var _stat_labels: Dictionary = {}

func _ready():
	# Cuando el panel arranca, guarda la cara del personaje 
	# que pusiste en el editor como la textura "por defecto".
	default_texture = default_texture
	current_texture = default_texture
	
	mask_icon.modulate = Color(1, 1, 1, 1) 
	mask_icon.self_modulate = Color(1, 1, 1, 1)
	
	_build_attributes_panel()

# --- FUNCIÓN PARA CAMBIAR ICONOS (Llamada desde HUD) ---
func update_life_icons_texture(new_icon: Texture2D):
	print("📊 StatsPanel: update_life_icons_texture llamado, nuevo icono: ", new_icon)
	
	# 1. Decidir qué textura y color usar
	if new_icon == null:
		# Si no hay máscara, volvemos a la cara original del personaje
		current_texture = default_texture
		current_color = Color.WHITE 
		mask_icon.texture = default_texture # Actualizamos también el retrato grande
		print("  -> Usando cara del personaje por defecto")
	else:
		# Si hay máscara, usamos su icono
		current_texture = new_icon
		current_color = Color.WHITE
		mask_icon.texture = current_texture # Actualizamos también el retrato grande
		print("  -> Usando icono de máscara")
	
	# 2. Actualizar INMEDIATAMENTE los iconos de vida que ya están en pantalla
	var updated_count = 0
	for child in life_container.get_children():
		if child is TextureRect:
			child.texture = current_texture
			child.modulate = current_color
			updated_count += 1
	
	print("  -> Iconos actualizados: ", updated_count)

# --- ACTUALIZACIÓN DE SALUD ---
func update_health(cantidad: int):
	# Limpiar
	for child in life_container.get_children():
		child.queue_free()
	
	# Cálculo de corazones
	var corazones_a_dibujar = ceil(cantidad / 10.0) 
	
	# Llenar
	for i in range(corazones_a_dibujar):
		var icon = TextureRect.new()
		# ¡AQUÍ USAMOS LAS VARIABLES DINÁMICAS!
		icon.texture = current_texture 
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = current_color # Rojo si es Godot, Blanco si es Máscara
		life_container.add_child(icon)

func update_mana(val, max_val):
	mana_bar.max_value = max_val
	mana_bar.value = val

func update_stamina(val, max_val):
	stamina_bar.max_value = max_val
	stamina_bar.value = val

func update_ulti(val, max_val):
	ulti_bar.max_value = max_val
	ulti_bar.value = val
	
	# Definimos tus colores aquí para que no se pierdan
	var morado_normal = Color("9b59b6") 
	var morado_brillante = Color(1.5, 1.0, 2.0) # Glow
	
	if val >= max_val:
		# ¡ULTI LISTA! (Brilla)
		ulti_bar.tint_progress = morado_brillante 
	else:
		# CARGANDO... (Color normal)
		ulti_bar.tint_progress = morado_normal

# --- CONSTRUCCIÓN DEL PANEL DE TEXTO ---
func _build_attributes_panel():
	_attr_panel = PanelContainer.new()
	_attr_panel.name = "AttributesTextPanel"
	_attr_panel.visible = false # Nace oculto, solo se ve al abrir el menú radial
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_width_left = 1; style.border_width_right = 1
	style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 12; style.content_margin_bottom = 12
	_attr_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_attr_panel.add_child(vbox)

	var title = Label.new()
	title.text = "— ATTRIBUTES —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	title.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.6, 1.0, 0.5))
	vbox.add_child(sep)

	var rows = [
		["mask",         "Mask"], ["hp",            "HP"],
		["speed",        "Speed"], ["jump",          "Jump"],
		["damage",       "Damage"], ["defense",       "Defense"],
		["atk_speed",    "Atk Speed"], ["crit",          "Crit Chance"],
		["ult",          "Ultimate"]
	]

	for row in rows:
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var lbl_key = Label.new()
		lbl_key.text = row[1]
		lbl_key.custom_minimum_size = Vector2(100, 0)
		lbl_key.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		lbl_key.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
		lbl_key.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl_key)

		var lbl_val = Label.new()
		lbl_val.text = "—"
		lbl_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		lbl_val.add_theme_font_override("font", load("res://assets/imagesGUI/font.TTF"))
		lbl_val.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl_val)
		_stat_labels[row[0]] = lbl_val

	# 🌟 MAGIA DE LA JERARQUÍA: Lo añadimos a BarsContainer (debajo de UltiBar)
	$BarsContainer.add_child(_attr_panel)

# --- FUNCIÓN PARA ACTUALIZAR Y MOSTRAR/OCULTAR ---
func toggle_attributes_panel(show_panel: bool, player_ref: CharacterBody3D = null):
	if not _attr_panel: return
	_attr_panel.visible = show_panel
	
	if not show_panel or not player_ref: return
	
	# Aquí va tu lógica de actualización de stats (Copiada de _refresh_stats)
	var hc  = player_ref.get_node_or_null("HealthComponent")
	var cm  = player_ref.get_node_or_null("CombatManager")
	var mm  = player_ref.get_node_or_null("MaskManager")

	var mask_name = "None"
	if mm and mm.current_mask: mask_name = mm.current_mask.mask_name
	_stat_labels["mask"].text = mask_name

	if hc:
		_stat_labels["hp"].text = "%d / %d" % [int(hc.current_health), int(hc.max_health)]
		_stat_labels["defense"].text = "x%.2f" % hc.defense_multiplier
	else:
		_stat_labels["hp"].text = "—"
		_stat_labels["defense"].text = "—"

	var spd = player_ref.speed_walk if "speed_walk" in player_ref else 0.0
	var spd_mult = player_ref.mask_speed_mult if "mask_speed_mult" in player_ref else 1.0
	_stat_labels["speed"].text = "%.0f" % (spd * spd_mult)

	var jmp = player_ref.jump_force if "jump_force" in player_ref else 0.0
	var jmp_mult = player_ref.mask_jump_mult if "mask_jump_mult" in player_ref else 1.0
	_stat_labels["jump"].text = "%.1f" % (jmp * jmp_mult)

	if cm:
		_stat_labels["damage"].text   = "x%.2f" % cm.damage_multiplier
		_stat_labels["atk_speed"].text = "x%.2f" % cm.attack_speed_multiplier
		_stat_labels["crit"].text      = "%.0f%%" % (cm.crit_chance * 100.0)
	else:
		_stat_labels["damage"].text   = "—"
		_stat_labels["atk_speed"].text = "—"
		_stat_labels["crit"].text      = "—"

	if mm:
		_stat_labels["ult"].text = "%d / %d" % [int(mm.current_ult_charge), int(mm.max_ult_charge)]
	else:
		_stat_labels["ult"].text = "—"

#Averiguar que bajaba el alpha
func _process(delta):
	mask_icon.modulate = Color.WHITE
