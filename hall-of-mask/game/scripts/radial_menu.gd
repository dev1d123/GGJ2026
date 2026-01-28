extends Control

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
var inventory_data = {
	0: [], # Máscaras
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
			print("Scroll ARRIBA en sector ", current_sector_index)
			# lógica para cambiar índice en inventory_data
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			print("Scroll ABAJO en sector ", current_sector_index)
			
		elif event.button_index == MOUSE_BUTTON_LEFT:
			print("Equipar MANO IZQUIERDA del sector ", current_sector_index)
			# emit_signal("equip_item", "LEFT", item_seleccionado)
			
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			print("Equipar MANO DERECHA del sector ", current_sector_index)
			# emit_signal("equip_item", "RIGHT", item_seleccionado)

# FUNCIONES VISUALES

func _actualizar_resaltado():
	# 1. Resetear todos los sectores a estado "apagado"
	for i in range(sectores_visuales.size()):
		var s = sectores_visuales[i]
		s.modulate = Color(0.6, 0.6, 0.6, 1) # Grisáceo (inactivo)
		s.scale = Vector2(1, 1) # Tamaño normal

	# 2. Resetear el rombo central
	if rombo_centro:
		rombo_centro.modulate = Color(1, 1, 1) 

	# 3. Si hay un sector seleccionado, encenderlo
	if current_sector_index != -1 and current_sector_index < sectores_visuales.size():
		var sector_activo = sectores_visuales[current_sector_index]
		
		# Efecto de resaltado (Brillo Amarillo y Pop)
		sector_activo.modulate = Color(1.2, 1.2, 0, 1) # Amarillo brillante (HDR)
		sector_activo.scale = Vector2(1.15, 1.15) # Crece un 15%
		
		# Opcional: Que el rombo también brille un poco
		if rombo_centro:
			rombo_centro.modulate = Color(1, 1, 0.8)
