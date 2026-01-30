extends Node 
# Lo cambiamos a Node a secas, porque el Dummy no necesita posición 3D para esto

# --- REFERENCIAS (SOLO LAS QUE TIENE EL DUMMY) ---
# Estas SÍ existen en tu Player Dummy, así que las dejamos
@onready var attributes = $"../AttributeManager"
@onready var stamina = $"../StaminaComponent"
@onready var mana = $"../ManaComponent"
@onready var player = $".." # Referencia al script del Player padre

# --- REFERENCIAS VISUALES (COMENTADAS) ---
# No las necesitamos para probar la UI
# @onready var anim_tree = ...
# @onready var skeleton = ...
# @onready var hand_r_node = ...

# --- VARIABLES DE ESTADO ---
var weapon_r: WeaponData
var weapon_l: WeaponData
var is_attacking_r = false
var is_attacking_l = false

# --- _READY (LIMPIO) ---
func _ready():
	# No configuramos animaciones porque no hay AnimationTree
	pass

# --- INPUT DE PRUEBA (SIMPLIFICADO) ---
func _input(event):
	# Solo dejamos el ataque para probar el gasto de estamina
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if weapon_r: procesar_input("right")
		if event.button_index == MOUSE_BUTTON_LEFT:
			if weapon_l: procesar_input("left")

# ----------------------------------------
# LÓGICA DE EQUIPAMIENTO (SOLO DATOS)
# ----------------------------------------
func equipar(data: WeaponData, mano: String):
	print("⚔️ CombatManager (Dummy): Solicitud de equipar '", data.name, "' en ", mano)
	
	# 1. LOGICA DE ASIGNACIÓN
	if data.is_two_handed:
		print("   -> Es de dos manos. Ocupando ambos slots lógicos.")
		weapon_r = data
		weapon_l = data
	else:
		if mano == "right": 
			weapon_r = data
			print("   -> Asignado a variable weapon_r")
		else: 
			weapon_l = data
			print("   -> Asignado a variable weapon_l")

	# AQUÍ BORRAMOS TODA LA PARTE VISUAL (Instanciar mesh, animaciones, etc.)
	# Para la UI, basta con saber que la variable ya no es null.

func desequipar(mano: String):
	print("⚔️ CombatManager (Dummy): Desequipando ", mano)
	if mano == "left":
		weapon_l = null
	else:
		weapon_r = null
	# Eliminamos la limpieza visual de nodos

# ----------------------------------------
# LÓGICA DE ATAQUE (SOLO GASTO)
# ----------------------------------------
func procesar_input(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	# Bloqueo simple
	if is_attacking_r or is_attacking_l: return

	# Consumo de Estamina (Esto SÍ lo probamos porque afecta al HUD)
	var costo = w.stamina_cost
	if stamina and stamina.try_consume(costo):
		print("💪 CombatManager: Atacando con ", w.name, " (Gasto estamina: ", costo, ")")
		ejecutar_ataque_simulado(w, mano)
	else:
		print("⚠️ CombatManager: No hay estamina suficiente")

func ejecutar_ataque_simulado(w: WeaponData, mano: String):
	# Simulamos que el ataque dura un tiempo (Cooldown)
	if mano == "right" or w.is_two_handed: is_attacking_r = true
	if mano == "left" or w.is_two_handed: is_attacking_l = true
	
	# Esperamos un tiempo falso (simulando la animación)
	await get_tree().create_timer(w.cooldown).timeout
	
	# Liberamos banderas
	is_attacking_r = false
	is_attacking_l = false
	print("✅ CombatManager: Ataque terminado (Cooldown listo)")

# --- UTILIDADES ELIMINADAS ---
# Las funciones de tween y limpieza de nodos ya no son necesarias aquí.
