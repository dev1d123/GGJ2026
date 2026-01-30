extends CharacterBody3D
class_name Player

# --- SEÑALES PARA TU UI ---
signal vida_cambiada(nueva_vida)
signal mana_cambiado(nuevo_mana, max_mana)
signal stamina_cambiada(nueva_stamina, max_stamina)
signal pociones_cambiadas(slot_index, cantidad)
signal ulti_cambiada(nueva_carga, max_carga)

# --- REFERENCIAS A LOS HIJOS (Tus nodos nuevos) ---
@onready var health_comp: HealthComponent = $HealthComponent
@onready var stamina_comp: ResourceComponent = $StaminaComponent
@onready var mana_comp: ResourceComponent = $ManaComponent
@onready var attributes: AttributeManager = $AttributeManager
@onready var combat_manager = $CombatManager 

# Inventario de Pociones
var pociones = [3, 1, 0] 
var current_ulti: float = 0.0 
var max_ulti: float = 100.0

func _ready() -> void:
	# CONECTAR COMPONENTES -> SEÑALES UI
	health_comp.on_damage_received.connect(func(_amount, current): emit_signal("vida_cambiada", current))
	stamina_comp.on_value_changed.connect(func(current, max_val): emit_signal("stamina_cambiada", current, max_val))
	mana_comp.on_value_changed.connect(func(current, max_val): emit_signal("mana_cambiado", current, max_val))
	
	await get_tree().process_frame
	actualizar_toda_la_ui()

# --- AQUÍ ESTABA LO QUE FALTABA ---
func _input(event):
	# Detectar teclas 1, 2, 3
	if event.is_action_pressed("usar_pocion_1"):
		usar_pocion(0)
	elif event.is_action_pressed("usar_pocion_2"):
		usar_pocion(1)
	elif event.is_action_pressed("usar_pocion_3"):
		usar_pocion(2)
	elif event.is_action_pressed("usar_habilidad_r"):
		intentar_usar_ulti()

func actualizar_toda_la_ui():
	# Enviamos estado inicial
	emit_signal("vida_cambiada", health_comp.current_health)
	emit_signal("stamina_cambiada", stamina_comp.current_value, stamina_comp.max_value)
	emit_signal("mana_cambiado", mana_comp.current_value, mana_comp.max_value)
	emit_signal("pociones_cambiadas", 1, pociones[0])
	emit_signal("pociones_cambiadas", 2, pociones[1])
	emit_signal("pociones_cambiadas", 3, pociones[2])

# --- CONEXIÓN HUD -> COMBAT MANAGER ---
func equipar_desde_ui(weapon_data, hand_side):
	# Si mañana cambia el nombre a "poner_arma", solo cambias ESTA línea.
	# El resto de tu HUD ni se entera.
	if combat_manager:
		if combat_manager.has_method("equip_weapon"):
			combat_manager.equip_weapon(weapon_data, hand_side.to_lower())
		elif combat_manager.has_method("equipar"): # Por si se arrepiente y vuelve atrás
			combat_manager.equipar(weapon_data, hand_side.to_lower())

func desequipar_desde_ui(hand_side):
	if combat_manager:
		combat_manager.desequipar(hand_side.to_lower())

# --- INPUTS DE PRUEBA (Para que te muevas y gastes cosas) ---
func _physics_process(_delta):
	# Movimiento muy básico para que no sea una estatua
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity.x = input.x * 5.0
	velocity.z = input.y * 5.0
	move_and_slide()
	
	# Test de daño y gasto
	if Input.is_action_just_pressed("ui_accept"): # ESPACIO
		health_comp.take_damage(10)
		stamina_comp.try_consume(20)
		cargar_ulti_test(20.0)

func usar_pocion(index):
	# Validar que índice es válido y hay pociones
	if index >= 0 and index < pociones.size() and pociones[index] > 0:
		
		# 1. Restar poción
		pociones[index] -= 1
		
		# 2. Lógica de Curación (Solo si es la poción 1, index 0)
		if index == 0: # Asumiendo que el slot 1 es Vida
			health_comp.current_health += 20 
			
			# Tope de vida (Clamp)
			if health_comp.current_health > health_comp.max_health:
				health_comp.current_health = health_comp.max_health
			
			# --- ¡LA LÍNEA MÁGICA QUE FALTA! ---
			# Avisamos manualmente al HUD con el nuevo valor
			emit_signal("vida_cambiada", health_comp.current_health)
			print("❤️ Player: Curado. Vida actual: ", health_comp.current_health)

		# 3. Actualizar contador visual de pociones
		emit_signal("pociones_cambiadas", index + 1, pociones[index])

func cargar_ulti_test(cantidad): # ⬅️ AGREGAR FUNCIÓN
	current_ulti += cantidad
	if current_ulti >= max_ulti:
		current_ulti = max_ulti
		print("🟣 ULTI LISTA!")
	
	emit_signal("ulti_cambiada", current_ulti, max_ulti)

func intentar_usar_ulti():
	# Solo se puede usar si está LLENA (>= max_ulti)
	if current_ulti >= max_ulti:
		print("✨⚔️ ¡¡¡ULTIMATE ACTIVADA!!! ⚔️✨")
		
		# 1. Consumir la barra
		current_ulti = 0.0
		
		# 2. Avisar a la UI (Esto vaciará la barra morada y el icono R)
		emit_signal("ulti_cambiada", current_ulti, max_ulti)
		
		# AQUÍ IRÍA LA LÓGICA DE COMBATE REAL (Explosión, Buff, etc.)
		# combat_manager.lanzar_ulti() 
		
	else:
		print("❌ Falta carga para la Ulti: ", current_ulti, "/", max_ulti)
