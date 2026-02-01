extends CanvasLayer

# --- REFERENCIAS A LOS COMPONENTES ---
@onready var stats_panel = $GameUI/StatsPanel 
@onready var consumables_panel = $GameUI/ConsumablesPanel
@onready var skills_panel = $GameUI/SkillsPanel
@onready var radar = $GameUI/Radar
@onready var radial_menu = $RadialMenu
@onready var mask_icon_grande = $GameUI/StatsPanel/MaskIcon

@export var mask_overlay: ColorRect
# Referencias iconos mano
@onready var icon_hand_l = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_L
@onready var icon_hand_r = $RadialMenu/WheelOrigin/RomboCentro/Icon_Hand_R

# 1. MODO NORMAL (Más suave/sutil)
# Bajamos la distorsión y el tinte para que no moleste al jugar normal.
const BASE_DISTORTION = 0.015  # Antes 0.03 (Casi imperceptible, solo un toque en bordes)
const BASE_ABERRATION = 0.2    # Antes 0.5 (Muy poco borroso)
const BASE_TINT_AMOUNT = 0.15  # Antes 0.15 (Solo un ligero color, no tapa la visión)

# 2. MODO ULTI (¡MUCHO MÁS FUERTE!)
# Subimos todo para que se sienta poderoso y caótico.
const ULTI_DISTORTION = 0.15   # Antes 0.08 (Efecto ojo de pez muy marcado)
const ULTI_ABERRATION = 6.0    # Antes 3.0 (Los colores se separan muchísimo en los bordes)
const ULTI_TINT_AMOUNT = 0.6   # Antes 0.4 (El color de la máscara inunda la pantalla)

var tween_filtro: Tween

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
			
		if player.has_signal("mascara_cambiada"):
			player.mascara_cambiada.connect(_on_mask_changed)
	else:
		print("HUD: ❌ ¡NO encuentro al Player! Asegúrate que el nodo se llame 'Player'")
		
	if mask_overlay:
		mask_overlay.visible = false
		if mask_overlay.material:
			mask_overlay.material = mask_overlay.material.duplicate()

func _on_mask_changed(mask_data):
	# PROTECCIÓN: Si olvidamos poner el nodo en la escena
	if not mask_icon_grande: return 

	# CASO A: Se quitó la máscara (mask_data es null)
	if mask_data == null:
		mask_icon_grande.modulate = Color(0.3, 0.3, 0.3, 0.5) 
		
		# AVISAR A LOS ICONOS PEQUEÑOS (Vuelta a la normalidad)
		stats_panel.update_life_icons_texture(null) 
		
		if mask_overlay: mask_overlay.visible = false
		return

	# CASO B: Hay máscara nueva
	if "icon" in mask_data and mask_data.icon:
		# 1. Actualizar el Grande
		mask_icon_grande.texture = mask_data.icon
		mask_icon_grande.modulate = Color(1, 1, 1, 1)
		
		# 2. Actualizar los Pequeños (¡NUEVO!) 🆕
		stats_panel.update_life_icons_texture(mask_data.icon)
		
		# ENCENDER Y CONFIGURAR FILTRO
		if mask_overlay and mask_overlay.material:
			mask_overlay.visible = true
			var mat = mask_overlay.material as ShaderMaterial
			
			# 1. Configurar Color
			var color_final = Color(0, 1, 0) # Verde por defecto
			if "screen_tint" in mask_data:
				color_final = mask_data.screen_tint
			
			mat.set_shader_parameter("tint_color", color_final)
			
			# 2. Resetear valores a BASE (Suavemente)
			_animar_filtro(BASE_DISTORTION, BASE_ABERRATION, BASE_TINT_AMOUNT, false)
			
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

# ------------------------------------------------------------------
# EFECTO ULTI (Aquí está lo espectacular)
# ------------------------------------------------------------------

func _on_player_ulti_estado_cambiado(esta_activa: bool):
	# CORRECCIÓN: Si activamos ulti, aseguramos que el overlay exista
	if not mask_overlay: return
	
	var mat = mask_overlay.material as ShaderMaterial
	if not mat: return
	
	# Si activamos la ulti y tenemos máscara, forzamos visibilidad
	if esta_activa and mask_icon_grande.texture != null:
		mask_overlay.visible = true

	# Debug para confirmar que la señal llega
	print("🔥 HUD: Cambio estado Ulti -> ", esta_activa) 
	
	if esta_activa:
		# Valores EXTREMOS para probar si funciona
		_animar_filtro(0.2, 8.0, 0.8, true) 
	else:
		_animar_filtro(BASE_DISTORTION, BASE_ABERRATION, BASE_TINT_AMOUNT, false)

# Función auxiliar para animar todo junto con un solo Tween
func _animar_filtro(dist: float, aberr: float, tint: float, pulsing: bool):
	var mat = mask_overlay.material as ShaderMaterial
	if tween_filtro: tween_filtro.kill()
	tween_filtro = create_tween().set_parallel(true)
	
	var dur = 0.5 # Medio segundo de transición
	
	# Animar Distorsión
	tween_filtro.tween_method(func(v): mat.set_shader_parameter("lens_distortion", v), 
		mat.get_shader_parameter("lens_distortion"), dist, dur)
		
	# Animar Aberración Cromática
	tween_filtro.tween_method(func(v): mat.set_shader_parameter("aberration_amount", v), 
		mat.get_shader_parameter("aberration_amount"), aberr, dur)
		
	# Animar Cantidad de Tinte
	tween_filtro.tween_method(func(v): mat.set_shader_parameter("tint_amount", v), 
		mat.get_shader_parameter("tint_amount"), tint, dur)
		
	# Activar/Desactivar Pulsación (Inmediato)
	mat.set_shader_parameter("is_pulsing", pulsing)
