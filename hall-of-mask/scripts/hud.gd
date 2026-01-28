extends CanvasLayer

# REFERENCIAS A LA UI
# Conexión de los nodos visuales al HUD (no del menú radial)
# Ajusta las rutas según el árbol de nodos real
@onready var slot_pocion_1 = $GameUI/ConsumablesPanel/Potions/Slot1
@onready var slot_pocion_2 = $GameUI/ConsumablesPanel/Potions/Slot2
@onready var slot_pocion_3 = $GameUI/ConsumablesPanel/Potions/Slot3

# Referencia al Triángulo/Rombo Central dentro del Menú Radial
# Para actualizar el icono del centro cuando se equipa algo
@onready var icon_hand_l = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_L
@onready var icon_hand_r = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_R

func _ready():
	# Conectar la señal del Menú Radial
	# Cuando el menú anuncia un equipamiento, este script reacciona
	$RadialMenu.equip_item.connect(_on_item_equipped)

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
