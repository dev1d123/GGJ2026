extends CanvasLayer

# --- REFERENCIAS A NODOS UI (Automáticas si usaste los nombres correctos) ---
@onready var bar_vida = $StatsPanel/BarraVida
@onready var bar_stamina = $StatsPanel/BarraStamina
@onready var bar_mana = $StatsPanel/BarraMana
@onready var bar_ulti = $StatsPanel/BarraUlti
@onready var lbl_estado = $StatsPanel/LabelEstado

@onready var lbl_izq = $WeaponsPanel/LabelManoIzq
@onready var lbl_der = $WeaponsPanel/LabelManoDer
@onready var lbl_inv = $WeaponsPanel/LabelInventario

@onready var lbl_mask = $MaskPanel/LabelMask
@onready var lbl_mask_info = $MaskPanel/LabelMaskInfo

@onready var lbl_damage = $DamageMsg

# --- REFERENCIAS AL JUGADOR (Se asignan en _ready buscando al padre) ---
var player_ref: CharacterBody3D
var combat_manager: CombatManager
var mask_manager: MaskManager
var health_comp: HealthComponent
var stamina_comp: ResourceComponent
var mana_comp: ResourceComponent

func _ready():
	# Buscamos al Player (Padre del HUD)
	player_ref = get_parent()
	
	if not player_ref:
		print("❌ HUD: No encuentro al Player padre.")
		return

	# --- 1. CONECTAR SALUD ---
	health_comp = player_ref.get_node_or_null("HealthComponent")
	if health_comp:
		bar_vida.max_value = health_comp.max_health
		bar_vida.value = health_comp.current_health
		health_comp.on_damage_received.connect(_on_damage)
		health_comp.on_death.connect(_on_death)
	
	# --- 2. CONECTAR STAMINA ---
	stamina_comp = player_ref.get_node_or_null("StaminaComponent")
	if stamina_comp:
		stamina_comp.on_value_changed.connect(func(curr, max_v):
			bar_stamina.max_value = max_v
			bar_stamina.value = curr
		)
		
	mana_comp = player_ref.get_node_or_null("ManaComponent")
	if mana_comp:
		mana_comp.on_value_changed.connect(func(curr, max_v):
			bar_mana.max_value = max_v
			bar_mana.value = curr
		)
	
	# --- 3. CONECTAR COMBATE (ARMAS) ---
	combat_manager = player_ref.get_node_or_null("CombatManager")
	if combat_manager:
		combat_manager.on_weapon_changed.connect(_update_weapon_ui)
		_update_inventory_text() # Mostrar lista inicial
	
	# --- 4. CONECTAR MÁSCARAS Y ULTI ---
	mask_manager = player_ref.get_node_or_null("MaskManager")
	if mask_manager:
		mask_manager.on_mask_changed.connect(_update_mask_ui)
		mask_manager.on_ult_charge_changed.connect(func(val): bar_ulti.value = val)
		
	# --- 5. CONECTAR ESTADO DEL JUGADOR ---
	player_ref.on_state_changed.connect(func(estado): lbl_estado.text = "ESTADO: " + estado)

# --- FUNCIONES DE ACTUALIZACIÓN ---

func _on_damage(amount, current):
	bar_vida.value = current
	
	# Mostrar mensaje de daño flotante simple
	lbl_damage.text = "-" + str(int(amount))
	lbl_damage.modulate = Color.RED
	lbl_damage.visible = true
	
	# Animación simple (Timer)
	var t = create_tween()
	t.tween_property(lbl_damage, "modulate:a", 0.0, 1.0) # Desvanecer
	t.tween_callback(func(): lbl_damage.visible = false; lbl_damage.modulate.a = 1.0)

func _on_death():
	lbl_estado.text = "💀 MUERTO 💀"
	lbl_estado.modulate = Color.RED

func _update_weapon_ui(mano: String, weapon: WeaponData):
	var txt = "Vacío"
	if weapon: txt = weapon.name
	
	if mano == "left":
		lbl_izq.text = "IZQ: " + txt
	elif mano == "right":
		lbl_der.text = "DER: " + txt
		# Si es 2 manos, actualizamos ambas etiquetas para claridad
		if weapon and weapon.is_two_handed:
			lbl_izq.text = "IZQ: (Ocupada por 2H)"

func _update_mask_ui(mask: MaskData):
	if mask:
		lbl_mask.text = "🎭 " + mask.mask_name
		lbl_mask.modulate = mask.screen_tint # Pintar texto del color de la máscara
		lbl_mask.modulate.a = 1.0 # Asegurar que sea legible
		bar_ulti.visible = true
	else:
		lbl_mask.text = "Sin Máscara"
		lbl_mask.modulate = Color.WHITE
		bar_ulti.visible = false # Ocultar barra ulti si no hay máscara

func _update_inventory_text():
	# Esto es manual y feo, justo lo que pediste para prototipo
	var txt = "INVENTARIO (Teclas):\n"
	if combat_manager.slot_1_right: txt += "1: " + combat_manager.slot_1_right.name + "\n"
	if combat_manager.slot_2: txt += "2: " + combat_manager.slot_2.name + "\n"
	if combat_manager.slot_3: txt += "3: " + combat_manager.slot_3.name + "\n"
	if combat_manager.slot_4: txt += "4: " + combat_manager.slot_4.name + "\n"
	lbl_inv.text = txt
