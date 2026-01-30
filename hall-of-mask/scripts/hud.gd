extends CanvasLayer

# --- REFERENCIAS A LOS COMPONENTES ---
@onready var stats_panel = $GameUI/StatsPanel 
@onready var consumables_panel = $GameUI/ConsumablesPanel
@onready var skills_panel = $GameUI/SkillsPanel
@onready var radar = $GameUI/Radar
@onready var radial_menu = $RadialMenu
@onready var mask_icon_grande = $GameUI/StatsPanel/MaskIcon

# Referencias iconos mano
@onready var icon_hand_l = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_L
@onready var icon_hand_r = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_R

func _ready():
	# 1. Conexión Menú Radial
	radial_menu.equip_item.connect(_on_item_equipped)
	
	# 2. BUSCAR AL JUGADOR Y CONECTARSE (EL CABLEADO REAL)
	var player = get_tree().root.find_child("Player", true, false)
	
	if player:
		print("HUD: ✅ Player encontrado. Conectando señales...")
		
		# Conectamos los gritos del Player a las funciones de actualización del HUD
		player.vida_cambiada.connect(_on_player_vida_cambiada)
		player.mana_cambiado.connect(_on_player_mana_cambiado)
		player.stamina_cambiada.connect(_on_player_stamina_cambiada)
		player.pociones_cambiadas.connect(_on_player_pociones_cambiadas)
		
		# CONEXIÓN ULTI (NUEVO)
		player.ulti_cambiada.connect(_on_player_ulti_cambiada)
		
		if player.has_signal("mascara_cambiada"):
			player.mascara_cambiada.connect(_on_mask_changed)
	else:
		print("HUD: ❌ ¡NO encuentro al Player! Asegúrate que el nodo se llame 'Player'")

func _on_mask_changed(mask_data):
	# PROTECCIÓN: Si olvidamos poner el nodo en la escena
	if not mask_icon_grande: return 

	# CASO A: Se quitó la máscara (mask_data es null)
	if mask_data == null:
		mask_icon_grande.modulate = Color(0.3, 0.3, 0.3, 0.5) 
		
		# AVISAR A LOS ICONOS PEQUEÑOS (Vuelta a la normalidad)
		stats_panel.update_life_icons_texture(null) 
		return

	# CASO B: Hay máscara nueva
	if "icon" in mask_data and mask_data.icon:
		# 1. Actualizar el Grande
		mask_icon_grande.texture = mask_data.icon
		mask_icon_grande.modulate = Color(1, 1, 1, 1)
		
		# 2. Actualizar los Pequeños (¡NUEVO!) 🆕
		stats_panel.update_life_icons_texture(mask_data.icon)

func _input(event):
	# --- YA NO MANEJAMOS POCIONES AQUÍ ---
	# El Player.gd se encarga de detectar la tecla 1, 2, 3.
	# El HUD solo reacciona cuando el Player emite la señal.
	
	# Solo dejamos inputs EXCLUSIVOS de UI (como debug o menús)
	
	# 2. Usar Habilidad Q (Visualización)
	# Si la lógica está en el player, esto también debería moverse, 
	# pero por ahora lo dejamos visual.
	if event.is_action_pressed("usar_habilidad_q"): 
		skills_panel.start_q_cooldown(2.0)

# --- RECEPCIÓN DE SEÑALES DEL PLAYER (CALLBACKS) 📡 ---

func _on_player_vida_cambiada(nueva_vida):
	# Convertimos a int por si acaso viene como float
	stats_panel.update_health(int(nueva_vida))

func _on_player_mana_cambiado(nuevo_mana, max_mana):
	stats_panel.update_mana(nuevo_mana, max_mana)

func _on_player_stamina_cambiada(nueva_stamina, max_stamina):
	stats_panel.update_stamina(nueva_stamina, max_stamina)

func _on_player_pociones_cambiadas(slot_index, cantidad):
	# El Player manda slot 1, 2, 3. El panel lo entiende perfecto.
	consumables_panel.update_potion_count(slot_index, cantidad)
	consumables_panel.animar_slot(slot_index)

# --- NUEVA FUNCIÓN DE ULTI ---
func _on_player_ulti_cambiada(nueva_carga, max_carga):
	# 1. Actualizar la barra grande de arriba
	stats_panel.update_ulti(nueva_carga, max_carga)
	# 2. Actualizar el icono pequeño de abajo (R)
	skills_panel.update_ulti_charge(nueva_carga, max_carga)

# --- LÓGICA DE EQUIPAMIENTO (Radial Menu) ---

func _on_item_equipped(hand_side, item_data):
	if item_data == null: return
	
	# ENVIAR ORDEN AL PLAYER PRIMERO (Para que la lógica funcione siempre)
	var player = get_tree().root.find_child("Player", true, false)
	if player and player.has_method("equipar_desde_ui"):
		player.equipar_desde_ui(item_data, hand_side)

	# --- FILTRO DE SEGURIDAD ---
	# Si es una MÁSCARA, no hacemos nada con los iconos de las MANOS y terminamos aquí.
	if item_data is MaskData:
		return 
	
	# ===============================================
	# DE AQUÍ PARA ABAJO ES SOLO PARA ARMAS (WeaponData)
	# ===============================================
	
	var target_icon = null
	var other_icon = null
	
	if hand_side == "LEFT":
		target_icon = icon_hand_l
		other_icon = icon_hand_r
	elif hand_side == "RIGHT":
		target_icon = icon_hand_r
		other_icon = icon_hand_l
	
	if target_icon:
		target_icon.texture = item_data.icon
		target_icon.modulate = Color(1, 1, 1)
		
		# AHORA ES SEGURO PREGUNTAR: Como ya filtramos las máscaras arriba,
		# sabemos que 'item_data' es un WeaponData y tiene 'is_two_handed'.
		if item_data.is_two_handed:
			# print("HUD: Arma 2 manos. Bloqueando la otra.")
			other_icon.texture = null
			other_icon.modulate = Color(0.5, 0.5, 0.5, 0.5)
		else:
			# Limpiar fantasma si estaba bloqueada
			if other_icon.modulate.a < 0.9: 
				other_icon.texture = null 
				other_icon.modulate = Color(1, 1, 1, 1)
