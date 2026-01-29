extends CanvasLayer

# --- REFERENCIAS A LOS COMPONENTES (SUB-MANAGERS) ---
@onready var stats_panel = $GameUI/StatsPanel
@onready var consumables_panel = $GameUI/ConsumablesPanel
@onready var skills_panel = $GameUI/SkillsPanel    # <--- NUEVO
@onready var radar = $GameUI/Radar
@onready var radial_menu = $RadialMenu

# Referencias directas para el centro de la rueda (Esto se queda aquí o en RadialMenu)
@onready var icon_hand_l = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_L
@onready var icon_hand_r = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_R

# Variables de prueba (Temporales)
var cant_pocion_1 = 5
var cant_pocion_2 = 3
var cant_pocion_3 = 1

func _ready():
	# Conexión menú radial
	radial_menu.equip_item.connect(_on_item_equipped)
	
	# INICIALIZACIÓN (Delegamos a los componentes)
	# Nota: skills_panel se auto-inicializa en su propio _ready
	
	stats_panel.update_health(5)
	stats_panel.update_mana(50, 100)
	stats_panel.update_stamina(100, 100)
	stats_panel.update_ulti(0, 100)
	
	consumables_panel.update_potion_count(1, cant_pocion_1)
	consumables_panel.update_potion_count(2, cant_pocion_2) 
	consumables_panel.update_potion_count(3, cant_pocion_3)
	
	consumables_panel.update_ammo("FLECHAS", 30)

func _input(event):
	# --- INPUTS DE PRUEBA ---
	
	# --- POCIÓN 1 ---
	if event.is_action_pressed("usar_pocion_1"):
		if cant_pocion_1 > 0:
			cant_pocion_1 -= 1
			consumables_panel.update_potion_count(1, cant_pocion_1)
			consumables_panel.animar_slot(1)
	
	# --- POCIÓN 2  ---
	if event.is_action_pressed("usar_pocion_2"):
		if cant_pocion_2 > 0:
			cant_pocion_2 -= 1
			consumables_panel.update_potion_count(2, cant_pocion_2)
			consumables_panel.animar_slot(2)

	# --- POCIÓN 3  ---
	if event.is_action_pressed("usar_pocion_3"):
		if cant_pocion_3 > 0:
			cant_pocion_3 -= 1
			consumables_panel.update_potion_count(3, cant_pocion_3)
			consumables_panel.animar_slot(3)

	# 2. Usar Habilidad Q (Cooldown)
	if event.is_action_pressed("usar_habilidad_q"): # Asegúrate de tener esta tecla en el Mapa de Entrada (o usa "ui_page_up" para test)
		print("Test: Usando Skill Q")
		skills_panel.start_q_cooldown(2.0) # 2 segundos de cooldown
			
	# 3. Simular Daño y Carga de Ulti (ENTER)
	if event.is_action_pressed("ui_accept"): 
		print("Test: Daño recibido + Carga Ulti")
		stats_panel.update_health(3)
		stats_panel.update_mana(10, 100)
		
		# Actualizamos ambas barras de Ulti (la de arriba y la de abajo)
		var carga_ulti = 100 
		stats_panel.update_ulti(carga_ulti, 100)
		skills_panel.update_ulti_charge(carga_ulti, 100)

# --- RESPUESTA AL MENÚ RADIAL ---
func _on_item_equipped(hand_side, item_data):
	if item_data == null: return
	
	print("HUD: Equipando ", item_data.nombre)
	
	var target_icon = icon_hand_l if hand_side == "LEFT" else icon_hand_r
	if target_icon:
		target_icon.texture = item_data.icono
		target_icon.modulate = item_data.color_ui
