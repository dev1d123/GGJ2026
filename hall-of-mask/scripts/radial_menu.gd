extends Control
class_name RadialMenu

# Señales para conectar con el resto del juego
signal equip_item(hand_side, item_data) # hand_side: "LEFT", "RIGHT"

# --- CONFIGURACIÓN ---
var num_sectors = 6
var current_sector_index = -1

# Referencias a los Nodos Visuales (Asegúrate que los nombres coincidan en tu escena)
@onready var wheel_origin = $WheelOrigin
@onready var sectores_visuales = [
	$WheelOrigin/Sector0,
	$WheelOrigin/Sector1,
	$WheelOrigin/Sector2,
	$WheelOrigin/Sector3,
	$WheelOrigin/Sector4,
	$WheelOrigin/Sector5
]
@onready var rombo_centro = $WheelOrigin/RomboCentro

# Datos simulados (luego con el inventario real)
# Estructura de cada item: { "nombre": String, "icon": Texture }
# CAMBIO 1: El inventario ahora guardará objetos reales (ItemData)
var inventory_data = {
	0: [], # Máscaras (Vacio por ahora)
	1: [], # Ligero
	2: [], # Pesado
	3: [], # Arco
	4: [], # Magia
	5: []  # Fuego
}
# Índices para saber qué arma se está viendo en cada sector al hacer scroll
var sector_scroll_indices = { 0:0, 1:0, 2:0, 3:0, 4:0, 5:0 }

func _ready():
	# empieza oculto
	visible = false
	# Centrar el origen de la rueda en la pantalla
	# (Esto asume que RadialMenu ocupa toda la pantalla con Full Rect)
	if wheel_origin:
		wheel_origin.position = get_viewport_rect().size / 2
		
	# --- GENERAR ITEMS DE PRUEBA ---
	# --- GENERAR DATOS DE PRUEBA (USANDO LA NUEVA CLASE) ---
	_crear_datos_falsos_pro()
	_actualizar_iconos_sectores()

func _crear_datos_falsos_pro():
	var icono_ref = preload("res://icon.svg")
	
	# Creamos items "al vuelo" usando nuestra nueva clase
	var daga = ItemData.new()
	daga.nombre = "Daga Oxidada"
	daga.icono = icono_ref
	daga.color_ui = Color.RED
	inventory_data[1].append(daga)
	
	var espada = ItemData.new()
	espada.nombre = "Espada Real"
	espada.icono = icono_ref
	espada.color_ui = Color.GREEN
	inventory_data[1].append(espada)
	
	var martillo = ItemData.new()
	martillo.nombre = "Aplastador"
	martillo.icono = icono_ref
	martillo.color_ui = Color.BLUE
	inventory_data[2].append(martillo)

# CAMBIO 2: Actualizar lectura de datos en _actualizar_iconos_sectores
func _actualizar_iconos_sectores(sector_especifico: int = -1):
	var inicio = 0
	var fin = num_sectors
	
	if sector_especifico != -1:
		inicio = sector_especifico
		fin = sector_especifico + 1

	for i in range(inicio, fin):
		var lista_items = inventory_data[i]
		var sector_visual = sectores_visuales[i]
		
		if lista_items.size() > 0:
			var indice_actual = sector_scroll_indices[i]
			
			# AHORA item ES UN OBJETO DE TIPO ItemData
			var item : ItemData = lista_items[indice_actual] 
			
			# Usa .icono en lugar de ["icon"]
			sector_visual.texture = item.icono
			
			if i != current_sector_index:
				# Usamos .color_ui en lugar de .get("color")
				sector_visual.modulate = item.color_ui * 0.6 
				sector_visual.scale = Vector2(1, 1)
			else:
				_actualizar_resaltado()
				
		else:
			sector_visual.modulate = Color(0.2, 0.2, 0.2, 0.5)

func _actualizar_resaltado():
	# 1. Resetear todos a gris oscuro (inactivos)
	for i in range(sectores_visuales.size()):
		var s = sectores_visuales[i]
		s.modulate = Color(0.6, 0.6, 0.6, 1)
		s.scale = Vector2(1, 1)

	# 2. Resetear el rombo
	if rombo_centro: rombo_centro.modulate = Color(1, 1, 1)

	# 3. Iluminar SOLO si el mouse está encima
	if current_sector_index != -1 and current_sector_index < sectores_visuales.size():
		var sector_activo = sectores_visuales[current_sector_index]
		var lista = inventory_data[current_sector_index]
		
		if lista.size() > 0:
			var indice = sector_scroll_indices[current_sector_index]
			var item : ItemData = lista[indice]
			
			# AHORA SE USA LAS PROPIEDADES DE LA CLASE ItemData
			var color_base = item.color_ui
			
			sector_activo.modulate = color_base * 1.5 # Brillo HDR
			sector_activo.scale = Vector2(1.15, 1.15) # Pop!
			sector_activo.texture = item.icono
			
		else:
			# CASO B: ESTÁ VACÍO
			sector_activo.modulate = Color(0.8, 0.8, 0.8, 0.5)
			sector_activo.scale = Vector2(1.0, 1.0)


func _input(event):
	
	# 1. LÓGICA DE ABRIR/CERRAR (Mantener TAB)
	
	if event.is_action_pressed("abrir_menu_radial"):
		visible = true
		wheel_origin.position = get_viewport_rect().size / 2 # Recentrar por si acaso
		_actualizar_resaltado() # Limpiar visuales al abrir
		
	elif event.is_action_released("abrir_menu_radial"):
		visible = false
		current_sector_index = -1 
		return # Sale para no procesar clics mientras se cierra

	# Si el menú no está visible no se procesa nada más
	if not visible: return

	
	# 2. CÁLCULO MATEMÁTICO DEL SECTOR

	var center = get_viewport_rect().size / 2
	var mouse_pos = get_global_mouse_position()
	var direction = mouse_pos - center
	
	# A. Zona muerta (centro)
	# Si el mouse está muy cerca del centro, no seleccionamos nada
	if direction.length() < 60.0: # Ajusta 60.0 según el tamaño del rombo
		if current_sector_index != -1:
			current_sector_index = -1
			_actualizar_resaltado() # Apagar luces si volvemos al centro
		return

	# B. Cálculo del Ángulo
	var deg = rad_to_deg(direction.angle())
	if deg < 0: deg += 360
	
	# Ajustar rotación: Godot empieza 0 a la derecha. 
	# Si tu Sector 0 está arriba (12 en punto), sumamos 90 grados.
	deg = fmod(deg + 90, 360.0)
	
	var sector_size = 360.0 / num_sectors
	var new_index = int(deg / sector_size)
	
	# C. Detectar cambio de sector
	if new_index != current_sector_index:
		current_sector_index = new_index
		_actualizar_resaltado() #AQUÍ SE ILUMINAN LOS ICONOS
		# print("Sector: ", current_sector_index) 

	# 3. INTERACCIÓN (CLICKS Y SCROLL)

	if event is InputEventMouseButton and event.pressed:
		
		# Feedback en consola para probar
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var lista = inventory_data[current_sector_index]
			if lista.size() > 1:
				sector_scroll_indices[current_sector_index] = (sector_scroll_indices[current_sector_index] + 1) % lista.size()
				
				# AHORA: Solo se actualiza ESTE sector
				_actualizar_iconos_sectores(current_sector_index) 
				
				# Feedback
				var item_nuevo = lista[sector_scroll_indices[current_sector_index]]
				print("Scroll ARRIBA: Cambiado a ", item_nuevo.nombre)
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var lista = inventory_data[current_sector_index]
			if lista.size() > 1:
				# 1. Matemática: Retroceder índice (truco + size para evitar negativos)
				var current = sector_scroll_indices[current_sector_index]
				sector_scroll_indices[current_sector_index] = (current - 1 + lista.size()) % lista.size()
				
				# 2. Visual: Actualizar inmediatamente el icono en pantalla
				_actualizar_iconos_sectores(current_sector_index)
				
				var item_nuevo = lista[sector_scroll_indices[current_sector_index]]
				print("Scroll ABAJO: Cambiado a ", item_nuevo.nombre)
			
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var lista = inventory_data[current_sector_index]
			if lista.size() > 0:
				var item = lista[sector_scroll_indices[current_sector_index]]
				emit_signal("equip_item", "LEFT", item) # <--- SE ENVIA EL ITEM REAL
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var lista = inventory_data[current_sector_index]
			if lista.size() > 0:
				var item = lista[sector_scroll_indices[current_sector_index]]
				emit_signal("equip_item", "RIGHT", item) # <--- SE ENVIA EL ITEM REAL
