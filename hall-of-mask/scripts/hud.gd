extends CanvasLayer

# REFERENCIAS A LA UI

# Rutas hacia nodos nuevos 
@onready var life_container = $GameUI/StatsPanel/BarsContainer/LifeContainer
@onready var mana_bar = $GameUI/StatsPanel/BarsContainer/ManaBar
@onready var ulti_bar = $GameUI/StatsPanel/BarsContainer/UltiBar
@onready var stamina_bar = $GameUI/StatsPanel/BarsContainer/StaminaBar

# Conexión de los nodos visuales al HUD (no del menú radial)
# Ajusta las rutas según el árbol de nodos real
@onready var slot_pocion_1 = $GameUI/ConsumablesPanel/Potions/Slot1
@onready var slot_pocion_2 = $GameUI/ConsumablesPanel/Potions/Slot2
@onready var slot_pocion_3 = $GameUI/ConsumablesPanel/Potions/Slot3

# --- REFERENCIAS A LOS CONTADORES (LABELS) ---
@onready var label_pocion_1 = $GameUI/ConsumablesPanel/Potions/Slot1/CountLabel
@onready var label_pocion_2 = $GameUI/ConsumablesPanel/Potions/Slot2/CountLabel
@onready var label_pocion_3 = $GameUI/ConsumablesPanel/Potions/Slot3/CountLabel
# rutas iconos de flecha/bala
@onready var label_flechas = $GameUI/ConsumablesPanel/Ammo/IconoFlecha/ArrowLabel
@onready var label_balas = $GameUI/ConsumablesPanel/Ammo/IconoBala/BulletLabel

# Referencia al Triángulo/Rombo Central dentro del Menú Radial
# Para actualizar el icono del centro cuando se equipa algo
@onready var icon_hand_l = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_L
@onready var icon_hand_r = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_R

# Textura para las vidas icono de Godot temporalmente
var heart_texture = preload("res://icon.svg")

func _ready():
	# Conectar la señal del Menú Radial
	# Cuando el menú anuncia un equipamiento, este script reacciona
	$RadialMenu.equip_item.connect(_on_item_equipped)
	
	# --- ESTADO INICIAL DE PRUEBA ---
	# Esto simula que el jugador empieza con todo lleno
	actualizar_vida(5)     # 5 Mascaritas
	actualizar_mana(50, 100) # Maná a la mitad
	actualizar_stamina(100, 100) # Estamina llena
	actualizar_ulti(0, 100)      # Ulti vacía
	
	# PRUEBA INICIAL: Poner números falsos para ver si funciona
	actualizar_pocion(1, 5)  # Slot 1 con 5 pociones
	actualizar_pocion(2, 2)  # Slot 2 con 2 pociones
	actualizar_pocion(3, 0)  # Slot 3 vacío
	
	actualizar_municion("FLECHAS", 30)
	actualizar_municion("BALAS", 12)

func _input(event):
	# LÓGICA DE POCIONES (1, 2, 3)
	# Ffunciona siempre, con o sin menú abierto
	if event.is_action_pressed("usar_pocion_1"):
		print("Usando Poción 1")
		_animar_slot(slot_pocion_1)
		
	elif event.is_action_pressed("usar_pocion_2"):
		print("Usando Poción 2")
		_animar_slot(slot_pocion_2)
		
	elif event.is_action_pressed("usar_pocion_3"):
		print("Usando Poción 3")
		_animar_slot(slot_pocion_3)
		
	# --- SIMULACIÓN DE DAÑO (SOLO PARA TEST) ---
	# ENTER para ver cómo bajan las barras
	if event.is_action_pressed("ui_accept"): 
		print("Test: Perdiendo vida y maná")
		actualizar_vida(3) 
		actualizar_mana(20, 100)
		actualizar_ulti(100, 100) # La ulti se carga al golpearte (ejemplo)

func actualizar_vida(cantidad_actual: int):
	# 1. Borrar vidas viejas
	for child in life_container.get_children():
		child.queue_free()
	
	# 2. Crear mascaritas nuevas
	for i in range(cantidad_actual):
		var icon = TextureRect.new()
		icon.texture = heart_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.custom_minimum_size = Vector2(24, 24) # Tamaño de cada corazoncito
		
		# Truco: Pintarlas de rojo si usas el icon.svg
		icon.modulate = Color.RED 
		
		life_container.add_child(icon)

func actualizar_mana(val, max_val):
	mana_bar.max_value = max_val
	mana_bar.value = val

func actualizar_stamina(val, max_val):
	stamina_bar.max_value = max_val
	stamina_bar.value = val

func actualizar_ulti(val, max_val):
	ulti_bar.max_value = max_val
	ulti_bar.value = val
	
	if val >= max_val:
		ulti_bar.modulate = Color(1.5, 1.5, 2) # Brillar cuando está llena
	else:
		ulti_bar.modulate = Color(1, 1, 1)

# --- FUNCIONES NUEVAS ---
func actualizar_pocion(slot_num: int, cantidad: int):
	# Busca cuál etiqueta tocar
	var label_destino = null
	match slot_num:
		1: label_destino = label_pocion_1
		2: label_destino = label_pocion_2
		3: label_destino = label_pocion_3
	
	if label_destino:
		label_destino.text = str(cantidad) # Convertir número a texto
		
		# Detalle Visual: Si es 0, ponerlo rojo. Si no, blanco.
		if cantidad == 0:
			label_destino.modulate = Color(1, 0.3, 0.3) # Rojo suave
		else:
			label_destino.modulate = Color.WHITE

func actualizar_municion(tipo: String, cantidad: int):
	if tipo == "FLECHAS":
		if label_flechas:
			label_flechas.text = str(cantidad)
			label_flechas.modulate = Color.RED if cantidad == 0 else Color.WHITE
			
	elif tipo == "BALAS":
		if label_balas:
			label_balas.text = str(cantidad)
			label_balas.modulate = Color.RED if cantidad == 0 else Color.WHITE


# Esta función se activa cuando se hace click en el Menú Radial
func _on_item_equipped(hand_side, item_data):
	print("HUD: Equipando ", item_data.get("nombre", "Nada"), " en ", hand_side)
	
	# Si el item viene vacío (null), no se hace nada o se borra
	if item_data.is_empty(): return
	
	var texture_to_show = item_data["icon"]
	var color_to_show = item_data.get("color", Color.WHITE) # Recuperamos el color falso
	
	if hand_side == "LEFT":
		if icon_hand_l: 
			icon_hand_l.texture = texture_to_show
			icon_hand_l.modulate = color_to_show # Aplicar el color falso
			
	elif hand_side == "RIGHT":
		if icon_hand_r: 
			icon_hand_r.texture = texture_to_show
			icon_hand_r.modulate = color_to_show

# Un efecto visual simple para saber que se apretó la tecla
func _animar_slot(slot_node):
	if slot_node:
		var tween = create_tween()
		tween.tween_property(slot_node, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(slot_node, "scale", Vector2(1.0, 1.0), 0.1)
