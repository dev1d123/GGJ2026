extends Control
class_name RadialMenu

# Señales para conectar con el resto del juego
signal equip_item(hand_side, item_data) # hand_side: "LEFT", "RIGHT"

# --- CONFIGURACIÓN ---
var ruta_armas = "res://src/actors/weapons/"
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

# Inventario (0: Máscaras, 1: Ligeras, 2: Pesadas, etc.)
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
	_cargar_armas_desde_carpeta()
	_actualizar_iconos_sectores()

func _cargar_armas_desde_carpeta():
	var dir = DirAccess.open(ruta_armas)
	
	if dir:
		print("🎒 RadialMenu: Escaneando armas en ", ruta_armas)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# Buscamos archivos .tres (y evitamos los .remap de exportación)
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var nombre_limpio = file_name.replace(".remap", "")
				var path_completo = ruta_armas + "/" + nombre_limpio # Ojo con el "/"
				# Si la ruta ya tiene / al final, quita el "/" del medio
				if ruta_armas.ends_with("/"): path_completo = ruta_armas + nombre_limpio
				
				var recurso = load(path_completo)
				
				# Verificamos si es un arma válida
				if recurso and recurso is WeaponData:
					_clasificar_arma(recurso)
			
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("❌ RadialMenu ERROR: No encuentro la carpeta: ", ruta_armas)

func _clasificar_arma(arma: WeaponData):
	# Lógica simple para ordenar:
	# Si es 2 manos -> Sector 2 (Pesadas)
	# Si es 1 mano  -> Sector 1 (Ligeras)
	# Si tienes más criterios (tipo arcos, magia), agrégalos aquí.
	
	if arma.is_two_handed:
		inventory_data[2].append(arma)
		print("   -> ⚔️ Pesada: ", arma.name)
	else:
		inventory_data[1].append(arma)
		print("   -> 🗡️ Ligera: ", arma.name)

func _distribuir_arma_en_inventario(arma: WeaponData):
	# Lógica simple para ordenar por ahora:
	# Sector 1: Ligeras (Dagas, Espadas)
	# Sector 2: Pesadas (2 Manos, Martillos)
	# Puedes mejorar esto si WeaponData tuviera una variable "tipo" o "categoria"
	
	if arma.is_two_handed:
		inventory_data[2].append(arma) # Sector 2 = Pesadas
	else:
		inventory_data[1].append(arma) # Sector 1 = Una mano

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
			
			# AHORA item ES UN OBJETO DE TIPO WeaponData
			var item : WeaponData = lista_items[indice_actual] 
			
			# Usa .icon
			sector_visual.texture = item.icon
			
			if i != current_sector_index:
				# Usamos .Color.WHITE en lugar de .get("color")
				sector_visual.modulate = Color.WHITE * 0.6 
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
			var item : WeaponData = lista[indice]
			
			# AHORA SE USA LAS PROPIEDADES DE LA CLASE WeaponData
			var color_base = Color.WHITE
			
			sector_activo.modulate = color_base * 1.5 # Brillo HDR
			sector_activo.scale = Vector2(1.15, 1.15) # Pop!
			sector_activo.texture = item.icon
			
		else:
			# CASO B: ESTÁ VACÍO
			sector_activo.modulate = Color(0.8, 0.8, 0.8, 0.5)
			sector_activo.scale = Vector2(1.0, 1.0)


func _input(event):
	
	# 1. LÓGICA DE ABRIR/CERRAR (Mantener TAB)
	if event.is_action_pressed("abrir_menu_radial"):
		visible = true
		wheel_origin.position = get_viewport_rect().size / 2
		_actualizar_resaltado()
		
		# --- PAUSAR EL JUEGO ---
		get_tree().paused = true # Congela al Player y enemigos
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE # Soltar el mouse
		
	elif event.is_action_released("abrir_menu_radial"):
		visible = false
		current_sector_index = -1 
		
		# --- REANUDAR EL JUEGO ---
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Capturar mouse de nuevo
		
		return 

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
				print("Scroll ARRIBA: Cambiado a ", item_nuevo.name)
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var lista = inventory_data[current_sector_index]
			if lista.size() > 1:
				# 1. Matemática: Retroceder índice (truco + size para evitar negativos)
				var current = sector_scroll_indices[current_sector_index]
				sector_scroll_indices[current_sector_index] = (current - 1 + lista.size()) % lista.size()
				
				# 2. Visual: Actualizar inmediatamente el icono en pantalla
				_actualizar_iconos_sectores(current_sector_index)
				
				var item_nuevo = lista[sector_scroll_indices[current_sector_index]]
				print("Scroll ABAJO: Cambiado a ", item_nuevo.name)
			
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
