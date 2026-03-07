extends Control
class_name RadialMenu

signal equip_item(hand_side, item_data) # hand_side: "LEFT", "RIGHT"

# --- STATS PANEL ---
var _stats_panel: PanelContainer = null
var _stat_labels: Dictionary = {}
var _player_ref: CharacterBody3D = null

# --- CONFIGURACIÓN DE RUTAS ---
# Ajusta estas rutas si tus carpetas reales son diferentes
var ruta_armas_melee = "res://src/actors/weapons/" 
var ruta_armas_rango = "res://src/actors/weapons/Ranged_Weapons/" # <--- TU CARPETA
var ruta_mascaras = "res://src/actors/masks/"

var num_sectors = 4
var current_sector_index = -1

var current_equipped_mask: MaskData = null

# --- REFERENCIAS VISUALES ---
@onready var wheel_origin = $WheelOrigin
@onready var stats_panel_node = $"../GameUI/StatsPanel"
@onready var sectores_visuales = [
	$WheelOrigin/Sector0, # Máscaras
	$WheelOrigin/Sector1, # Armas Ligeras
	$WheelOrigin/Sector2, # Armas Pesadas
	$WheelOrigin/Sector3, # Armas mana
	#$WheelOrigin/Sector4,
	#$WheelOrigin/Sector5
]
@onready var rombo_centro = $WheelOrigin/RomboCentro
@onready var icon_mask_preview = $WheelOrigin/RomboCentro/Icon_Mask

# --- INVENTARIO ---
# 0: Máscaras, 1: Ligeras, 2: Pesadas
var inventory_data = {
	0: [], 1: [], 2: [], 3: [], 4: [], 5: []
}
# Índices de scroll para cada sector
var sector_scroll_indices = { 0:0, 1:0, 2:0, 3:0, 4:0, 5:0 }

func _ready():
	visible = false
	if wheel_origin:
		wheel_origin.position = get_viewport_rect().size / 2

	# Buscar player y crear panel de stats
	_player_ref = get_tree().root.find_child("Player", true, false)
	#_build_stats_panel()

	# --- CARGA AUTOMÁTICA DE DATOS ---
	_escanear_carpeta(ruta_armas_melee)
	_escanear_carpeta(ruta_armas_rango)
	_escanear_carpeta(ruta_mascaras)
	
	_agregar_opcion_sin_mascara()
	
	# Conectar con GameManager para actualizar máscaras desbloqueadas
	if GameManager:
		GameManager.mask_unlocked.connect(_on_mask_unlocked)
	
	# Actualizar iconos iniciales
	_actualizar_iconos_sectores()

# -----------------------------------------------------------
# 🔍 SISTEMA DE ESCANEO
# -----------------------------------------------------------
func _escanear_carpeta(ruta):
	var dir = DirAccess.open(ruta)
	
	if dir:
		print("🎒 RadialMenu: Escaneando '", ruta, "'...")
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var nombre_limpio = file_name.replace(".remap", "")
				var path_completo = ruta.path_join(nombre_limpio)
				
				var recurso = load(path_completo)
				if recurso:
					_clasificar_item(recurso)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("❌ RadialMenu: No existe la carpeta: ", ruta)

func _clasificar_item(item):
	# CASO 1: MÁSCARA 🎭 (Sector 0)
	if item is MaskData:
		# Solo agregar si está desbloqueada o no hay GameManager (modo debug)
		if not GameManager or _is_mask_unlocked_by_data(item):
			inventory_data[0].append(item)
			print("   -> [SECTOR 0] Máscara: ", item.mask_name)
		else:
			print("   -> [SECTOR 0] Máscara bloqueada (ignorando): ", item.mask_name)
		return

	# CASO 2: ARMAS (Usando la nueva Categoría)
	if item is WeaponData:
		match item.category:
			WeaponData.WeaponCategory.MELEE_LIGHT:
				inventory_data[1].append(item)
				print("   -> [SECTOR 1] Ligera: ", item.name)
				
			WeaponData.WeaponCategory.MELEE_HEAVY:
				inventory_data[2].append(item)
				print("   -> [SECTOR 2] Pesada: ", item.name)
				
			WeaponData.WeaponCategory.MAGIC:
				inventory_data[3].append(item)
				print("   -> [SECTOR 3] Magia: ", item.name)
				
			WeaponData.WeaponCategory.BOW:
				inventory_data[4].append(item)
				print("   -> [SECTOR 4] Arco/Ballesta: ", item.name)
				
			WeaponData.WeaponCategory.GUN:
				inventory_data[5].append(item)
				print("   -> [SECTOR 5] Fuego: ", item.name)

func _input(event):
	# 1. ABRIR / CERRAR
	if event.is_action_pressed("abrir_menu_radial"):
		visible = true
		wheel_origin.position = get_viewport_rect().size / 2
		_actualizar_resaltado()
		
		#_refresh_starts()
		
		# --- MOSTRAR STATS PANEL ---
		var player = get_tree().root.find_child("Player", true, false)
		
		if stats_panel_node and stats_panel_node.has_method("toggle_attributes_panel"):
			stats_panel_node.toggle_attributes_panel(true, player)
		# ---------------------------
		
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	elif event.is_action_released("abrir_menu_radial"):
		visible = false
		current_sector_index = -1
		
		# --- OCULTAR STATS PANEL ---
		if stats_panel_node and stats_panel_node.has_method("toggle_attributes_panel"):
			stats_panel_node.toggle_attributes_panel(false)
		# ---------------------------
		
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if not visible: return
	
	# 2. CALCULAR SECTOR
	var center = get_viewport_rect().size / 2
	var mouse_pos = get_global_mouse_position()
	var direction = mouse_pos - center
	
	if direction.length() < 60.0: # Zona muerta central
		if current_sector_index != -1:
			current_sector_index = -1
			_actualizar_resaltado()
		return

	# --- MATEMÁTICAS ESTRICTAS EN CRUZ (CON ZONAS MUERTAS) ---
	var deg = rad_to_deg(direction.angle())
	if deg < 0: deg += 360 # Convertimos el ángulo a un formato de 0 a 360 grados
	
	var new_index = -1
	
	# 'tolerancia' es qué tan "ancho" es el rayo de detección para cada arma.
	# 35 grados significa que tienes que apuntar bastante directo al arma.
	# (Si lo bajas a 20, tendrás que apuntar de forma MUY precisa).
	var tolerancia = 35.0 
	
	# Derecha (Sector 1) -> Alrededor de 0° (y 360°)
	if deg <= tolerancia or deg >= (360 - tolerancia):
		new_index = 1
	# Abajo (Sector 2) -> Alrededor de 90°
	elif deg >= (90 - tolerancia) and deg <= (90 + tolerancia):
		new_index = 2
	# Izquierda (Sector 3) -> Alrededor de 180°
	elif deg >= (180 - tolerancia) and deg <= (180 + tolerancia):
		new_index = 3
	# Arriba (Sector 0) -> Alrededor de 270°
	elif deg >= (270 - tolerancia) and deg <= (270 + tolerancia):
		new_index = 0
	# Si el ángulo no cae en ninguno de estos rangos (ej. está en una esquina), new_index se queda en -1
	# ---------------------------------------------------------
	
	if new_index != current_sector_index:
		current_sector_index = new_index
		_actualizar_resaltado()

	# 3. CLICKS Y SCROLL
	if event is InputEventMouseButton and event.pressed:
		if current_sector_index == -1: return
		var lista = inventory_data[current_sector_index]
		if lista.size() == 0: return# Nada que hacer en sector vacío

		# SCROLL
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if lista.size() > 1:
				sector_scroll_indices[current_sector_index] = (sector_scroll_indices[current_sector_index] + 1) % lista.size()
				_actualizar_iconos_sectores(current_sector_index)
				_actualizar_resaltado() # Para actualizar icono grande
				
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if lista.size() > 1:
				var current = sector_scroll_indices[current_sector_index]
				sector_scroll_indices[current_sector_index] = (current - 1 + lista.size()) % lista.size()
				_actualizar_iconos_sectores(current_sector_index)
				_actualizar_resaltado()

		# EQUIPAR (Izquierdo)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var item = lista[sector_scroll_indices[current_sector_index]]
			
			# Si el item es la máscara "None", enviamos null para quitar
			if item is MaskData and (item.mask_name == "None" or item.mask_name == "Ninguna"):
				emit_signal("equip_item", "LEFT", null)
				current_equipped_mask = null
				_actualizar_resaltado()
			else:
				emit_signal("equip_item", "LEFT", item)
				
				# Si equipamos una máscara, la guardamos como la "actual"
				if item is MaskData:
					current_equipped_mask = item
					_actualizar_resaltado() # Refrescamos para fijar el icono
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var item = lista[sector_scroll_indices[current_sector_index]]
			# Solo enviamos señal derecha si NO es máscara (las máscaras no tienen "mano derecha")
			if not (item is MaskData):
				emit_signal("equip_item", "RIGHT", item)

func _actualizar_iconos_sectores(sector_especifico: int = -1):
	var inicio = 0
	var fin = num_sectors
	if sector_especifico != -1:
		inicio = sector_especifico; fin = sector_especifico + 1

	for i in range(inicio, fin):
		var lista_items = inventory_data[i]
		var sector_visual = sectores_visuales[i]
		
		if lista_items.size() > 0:
			var indice = sector_scroll_indices[i]
			var item = lista_items[indice]
			
			if item.icon:
				sector_visual.texture = item.icon
			else:
				sector_visual.texture = null # O un icono default
				
			sector_visual.self_modulate = Color(1, 1, 1, 0.6) # Dimmed
		else:
			sector_visual.texture = null
			sector_visual.self_modulate = Color(0.2, 0.2, 0.2, 0.5) # Apagado

func _actualizar_resaltado():
	# 1. Resetear sectores
	for i in range(sectores_visuales.size()):
		_actualizar_iconos_sectores(i) 
		sectores_visuales[i].scale = Vector2(1, 1)
	
	# 2. GESTIÓN DEL ICONO CENTRAL (MÁSCARA)
	# Por defecto, mostramos la que está equipada (si hay una)
	if icon_mask_preview:
		if current_equipped_mask:
			icon_mask_preview.texture = current_equipped_mask.icon
			icon_mask_preview.modulate = Color(1, 1, 1, 1) # Normal
		else:
			icon_mask_preview.texture = null

	# 3. INTERACCIÓN HOVER (PREVISUALIZACIÓN)
	if current_sector_index != -1 and current_sector_index < sectores_visuales.size():
		var sector_activo = sectores_visuales[current_sector_index]
		var lista = inventory_data[current_sector_index]
		
		sector_activo.self_modulate = Color(1.5, 1.5, 1.5, 1) 
		sector_activo.scale = Vector2(1.15, 1.15)
		
		# Si estamos sobre el sector de máscaras (0), mostramos la PREVIEW
		# Esto sobrescribe momentáneamente a la equipada
		if current_sector_index == 0 and lista.size() > 0:
			var indice = sector_scroll_indices[current_sector_index]
			var item_preview = lista[indice]
			
			if icon_mask_preview:
				icon_mask_preview.texture = item_preview.icon
				icon_mask_preview.modulate = Color(1, 1, 1, 1) # Un poco transparente para indicar "preview"

# -----------------------------------------------------------
# 🎭 SISTEMA DE MÁSCARAS DESBLOQUEABLES
# -----------------------------------------------------------
func _is_mask_unlocked_by_data(mask_data: MaskData) -> bool:
	if not GameManager:
		return true # Si no hay GameManager, desbloqueamos todo (modo debug)
	
	# Si es la opción de quitar máscara, siempre está disponible
	if mask_data.mask_name == "None" or mask_data.mask_name == "Ninguna":
		return true
	
	# Mapeo de nombres de máscaras en MaskData a nombres en GameManager
	var mask_name_map = {
		"Fighter": "fighter",
		"Luchador": "fighter",
		"Shooter": "shooter",
		"Tirador": "shooter",
		"Undead": "undead",
		"No Muerto": "undead",
		"NoMuerto": "undead",
		"Time": "time",
		"Tiempo": "time"
	}
	
	var mask_key = mask_name_map.get(mask_data.mask_name, mask_data.mask_name.to_lower())
	return GameManager.is_mask_unlocked(mask_key)

func _on_mask_unlocked(mask_name: String):
	# Reescanear carpeta de máscaras para actualizar inventario
	print("🎭 RadialMenu: Máscara desbloqueada, actualizando inventario...")
	inventory_data[0].clear()
	_escanear_carpeta(ruta_mascaras)
	
	_agregar_opcion_sin_mascara()
	
	_actualizar_iconos_sectores(0)
	sector_scroll_indices[0] = 0 # Reset scroll

# -----------------------------------------------------------
# 👤 OPCIÓN POR DEFECTO: SIN MÁSCARA
# -----------------------------------------------------------
func _agregar_opcion_sin_mascara():
	var no_mask = MaskData.new()
	no_mask.mask_name = "None"
	# Usa LA MISMA RUTA en StatsPanel para la cara del personaje
	no_mask.icon = preload("res://UI_assets/Face.png") 
	
	# Usamos push_front para meterlo al PRINCIPIO de la lista del Sector 0
	inventory_data[0].push_front(no_mask)

# -----------------------------------------------------------
# 📊 PANEL DE ESTADÍSTICAS (desde feature/ulti)
# -----------------------------------------------------------
func _build_stats_panel():
	# PanelContainer raíz
	_stats_panel = PanelContainer.new()
	_stats_panel.name = "StatsPanel"
	_stats_panel.visible = false
	# Posición: lado derecho, ligeramente arriba del centro
	_stats_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_stats_panel.position = Vector2(-320, -100)
	_stats_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_stats_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_width_left = 1; style.border_width_right = 1
	style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.content_margin_left = 14; style.content_margin_right = 14
	style.content_margin_top = 12; style.content_margin_bottom = 12
	_stats_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_stats_panel.add_child(vbox)

	# Título
	var title = Label.new()
	title.text = "— ATTRIBUTES —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var sep = HSeparator.new()
	sep.add_theme_color_override("color", Color(0.4, 0.6, 1.0, 0.5))
	vbox.add_child(sep)

	# Definición de filas: [clave_interna, etiqueta_display]
	var rows = [
		["mask",         "Mask"],
		["hp",           "HP"],
		["speed",        "Speed"],
		["jump",         "Jump"],
		["damage",       "Damage"],
		["defense",      "Defense"],
		["atk_speed",    "Atk Speed"],
		["crit",         "Crit Chance"],
		["ult",          "Ultimate"],
	]

	for row in rows:
		var hbox = HBoxContainer.new()
		vbox.add_child(hbox)

		var lbl_key = Label.new()
		lbl_key.text = row[1]
		lbl_key.custom_minimum_size = Vector2(140, 0)
		lbl_key.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		lbl_key.add_theme_font_size_override("font_size", 16)
		hbox.add_child(lbl_key)

		var lbl_val = Label.new()
		lbl_val.text = "—"
		lbl_val.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		lbl_val.add_theme_font_size_override("font_size", 16)
		hbox.add_child(lbl_val)
		_stat_labels[row[0]] = lbl_val

func _refresh_stats():
	if not _stats_panel or not _player_ref:
		return
	_stats_panel.visible = true

	var hc  = _player_ref.get_node_or_null("HealthComponent")
	var cm  = _player_ref.get_node_or_null("CombatManager")
	var mm  = _player_ref.get_node_or_null("MaskManager")

	# Mask
	var mask_name = "None"
	if mm and mm.current_mask:
		mask_name = mm.current_mask.mask_name
	_stat_labels["mask"].text = mask_name

	# HP
	if hc:
		_stat_labels["hp"].text = "%d / %d" % [int(hc.current_health), int(hc.max_health)]
	else:
		_stat_labels["hp"].text = "��"

	# Speed (respeta el multiplicador de máscara si existe)
	var spd = _player_ref.speed_walk if "speed_walk" in _player_ref else 0.0
	var spd_mult = _player_ref.mask_speed_mult if "mask_speed_mult" in _player_ref else 1.0
	_stat_labels["speed"].text = "%.0f" % (spd * spd_mult)

	# Jump
	var jmp = _player_ref.jump_force if "jump_force" in _player_ref else 0.0
	var jmp_mult = _player_ref.mask_jump_mult if "mask_jump_mult" in _player_ref else 1.0
	_stat_labels["jump"].text = "%.1f" % (jmp * jmp_mult)

	# Damage, Defense, Atk Speed, Crit
	if cm:
		_stat_labels["damage"].text   = "x%.2f" % cm.damage_multiplier
		_stat_labels["atk_speed"].text = "x%.2f" % cm.attack_speed_multiplier
		_stat_labels["crit"].text      = "%.0f%%" % (cm.crit_chance * 100.0)
	else:
		_stat_labels["damage"].text   = "—"
		_stat_labels["atk_speed"].text = "—"
		_stat_labels["crit"].text      = "—"

	if hc:
		_stat_labels["defense"].text = "x%.2f" % hc.defense_multiplier
	else:
		_stat_labels["defense"].text = "—"

	# Ultimate
	if mm:
		_stat_labels["ult"].text = "%d / %d" % [int(mm.current_ult_charge), int(mm.max_ult_charge)]
	else:
		_stat_labels["ult"].text = "—"