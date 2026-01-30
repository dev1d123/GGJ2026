extends Control
class_name RadialMenu

signal equip_item(hand_side, item_data) # hand_side: "LEFT", "RIGHT"

# --- CONFIGURACIÓN DE RUTAS ---
# Ajusta estas rutas si tus carpetas reales son diferentes
var ruta_armas = "res://src/actors/weapons/" 
var ruta_mascaras = "res://src/actors/masks/"

var num_sectors = 6
var current_sector_index = -1

var current_equipped_mask: MaskData = null

# --- REFERENCIAS VISUALES ---
@onready var wheel_origin = $WheelOrigin
@onready var sectores_visuales = [
	$WheelOrigin/Sector0, # Máscaras
	$WheelOrigin/Sector1, # Armas Ligeras
	$WheelOrigin/Sector2, # Armas Pesadas
	$WheelOrigin/Sector3,
	$WheelOrigin/Sector4,
	$WheelOrigin/Sector5
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
	
	# --- CARGA AUTOMÁTICA DE DATOS ---
	_escanear_carpeta(ruta_armas)
	_escanear_carpeta(ruta_mascaras)
	
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
		inventory_data[0].append(item)
		print("   -> [SECTOR 0] Máscara: ", item.mask_name)
		
	# CASO 2: ARMA ⚔️ (Sector 1 o 2)
	elif item is WeaponData:
		if item.is_two_handed:
			inventory_data[2].append(item)
			print("   -> [SECTOR 2] Pesada: ", item.name)
		else:
			inventory_data[1].append(item)
			print("   -> [SECTOR 1] Ligera: ", item.name)

# -----------------------------------------------------------
# 🎨 VISUALIZACIÓN E INPUT
# -----------------------------------------------------------

func _input(event):
	# 1. ABRIR / CERRAR
	if event.is_action_pressed("abrir_menu_radial"):
		visible = true
		wheel_origin.position = get_viewport_rect().size / 2
		_actualizar_resaltado()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	elif event.is_action_released("abrir_menu_radial"):
		visible = false
		current_sector_index = -1
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return 

	if not visible: return
	
	# 2. CALCULAR SECTOR
	var center = get_viewport_rect().size / 2
	var mouse_pos = get_global_mouse_position()
	var direction = mouse_pos - center
	
	if direction.length() < 60.0: # Zona muerta
		if current_sector_index != -1:
			current_sector_index = -1
			_actualizar_resaltado()
		return

	var deg = rad_to_deg(direction.angle())
	if deg < 0: deg += 360
	deg = fmod(deg + 90, 360.0) # Rotar 90deg para que 0 esté arriba
	
	var sector_size = 360.0 / num_sectors
	var new_index = int(deg / sector_size)
	
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
			emit_signal("equip_item", "LEFT", item)
			
			# ¡AQUÍ ESTÁ EL CAMBIO! 
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
				
			sector_visual.modulate = Color(1, 1, 1, 0.6) # Dimmed
		else:
			sector_visual.texture = null
			sector_visual.modulate = Color(0.2, 0.2, 0.2, 0.5) # Apagado

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
		
		sector_activo.modulate = Color(1.5, 1.5, 1.5, 1) 
		sector_activo.scale = Vector2(1.15, 1.15)
		
		# Si estamos sobre el sector de máscaras (0), mostramos la PREVIEW
		# Esto sobrescribe momentáneamente a la equipada
		if current_sector_index == 0 and lista.size() > 0:
			var indice = sector_scroll_indices[current_sector_index]
			var item_preview = lista[indice]
			
			if icon_mask_preview:
				icon_mask_preview.texture = item_preview.icon
				icon_mask_preview.modulate = Color(1, 1, 1, 0.7) # Un poco transparente para indicar "preview"
