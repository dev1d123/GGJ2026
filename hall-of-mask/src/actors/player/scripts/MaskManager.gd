extends Node
class_name MaskManager

# --- SEÑALES PARA LA UI ---
signal on_mask_changed(mask_data)     # Cuando te pones/quitas máscara
signal on_ult_charge_changed(value)   # Valor actual (0-100)
signal on_ultimate_state(is_active)   # Si está activo el modo berserk

@export_category("Referencias")
@export var player: CharacterBody3D
@export var combat_manager: CombatManager
@export var stamina_component: ResourceComponent 
@export var screen_overlay: ColorRect 

@export_category("Estado")
@export var current_mask: MaskData

@export var ult_reward: float = 20.0 # Este enemigo llena 20% la ulti

# --- SISTEMA DE CARGA (NUEVO) ---
var current_ult_charge: float = 0.0
var max_ult_charge: float = 100.0
var is_ultimate_active: bool = false
var ult_timer: float = 0.0

func _ready():
	if current_mask: 
		equip_mask(current_mask)
	# Emitimos estado inicial
	on_ult_charge_changed.emit(current_ult_charge)

func _process(delta):
	if is_ultimate_active:
		ult_timer -= delta
		# Hacemos que la barra baje visualmente mientras se usa
		var porcentaje_restante = (ult_timer / current_mask.ultimate_duration) * 100.0
		on_ult_charge_changed.emit(porcentaje_restante)
		
		if ult_timer <= 0:
			deactivate_ultimate()

func _input(event):
	if event.is_action_pressed("ultimate_ability"):
		if is_ultimate_active: deactivate_ultimate()
		# Solo activamos si hay máscara Y la carga está al 100%
		elif current_mask and current_ult_charge >= max_ult_charge:
			activate_ultimate()

# --- FUNCIÓN PARA GANAR CARGA (Llamada por enemigos) ---
func add_charge(amount: float):
	if is_ultimate_active: return # No cargar mientras se usa
	if not current_mask: return   # No cargar si no tienes máscara
	
	current_ult_charge += amount
	current_ult_charge = min(current_ult_charge, max_ult_charge)
	on_ult_charge_changed.emit(current_ult_charge)
	print("⚡ Carga Ulti: ", current_ult_charge, "%")

# --- EQUIPAR ---
func equip_mask(mask: MaskData):
	if not mask: return
	current_mask = mask
	apply_stats(false) 
	if screen_overlay: screen_overlay.color = mask.screen_tint
	print("🎭 Máscara equipada: ", mask.mask_name)
	on_mask_changed.emit(mask) # <--- SEÑAL

# --- QUITAR (NUEVO) ---
func remove_mask():
	print("🎭 Máscara removida.")
	current_mask = null
	is_ultimate_active = false
	
	# 1. Limpiar Visuales
	if screen_overlay: screen_overlay.color = Color(0, 0, 0, 0) # Transparente
	
	# 2. Resetear Player
	if player:
		if "mask_speed_mult" in player: player.mask_speed_mult = 1.0
		if "mask_jump_mult" in player: player.mask_jump_mult = 1.0
		if "mask_defense_mult" in player: player.mask_defense_mult = 1.0
	
	# 3. Resetear Combat
	if combat_manager:
		combat_manager.attack_speed_multiplier = 1.0
		combat_manager.crit_chance = 0.0
		combat_manager.crit_damage = 2.0
	
	# 4. Resetear Stamina
	if stamina_component:
		stamina_component.cost_multiplier = 1.0
		stamina_component.regen_multiplier = 1.0
		stamina_component.delay_multiplier = 1.0
	on_mask_changed.emit(null) # <--- SEÑAL

# --- ULTIMATE ---
func activate_ultimate():
	if not current_mask: return
	is_ultimate_active = true
	ult_timer = current_mask.ultimate_duration
	apply_stats(true)
	if screen_overlay: 
		var t = create_tween()
		t.tween_property(screen_overlay, "color", current_mask.ult_screen_tint, 0.3)
	print("🔥 ULTIMATE ACTIVADO!")
	on_ultimate_state.emit(true) # <--- SEÑAL

func deactivate_ultimate():
	if not current_mask: return
	is_ultimate_active = false
	apply_stats(false)
	if screen_overlay: 
		var t = create_tween()
		t.tween_property(screen_overlay, "color", current_mask.screen_tint, 0.5)
	print("❄️ Ultimate finalizado.")
	current_ult_charge = 0.0 # Consumimos la carga
	on_ult_charge_changed.emit(0.0)
	on_ultimate_state.emit(false) # <--- SEÑAL

func apply_stats(is_ult: bool):
	if not current_mask: return
	
	var spd = current_mask.ult_speed_mult if is_ult else current_mask.speed_mult
	var jmp = current_mask.ult_jump_mult if is_ult else current_mask.jump_mult
	var atk = current_mask.ult_attack_speed_mult if is_ult else current_mask.attack_speed_mult
	var def = current_mask.ult_defense_mult if is_ult else current_mask.defense_mult
	
	var cost = current_mask.ult_stamina_cost_mult if is_ult else current_mask.stamina_cost_mult
	var regen = current_mask.ult_stamina_regen_mult if is_ult else current_mask.stamina_regen_mult
	var delay = current_mask.ult_stamina_delay_mult if is_ult else current_mask.stamina_delay_mult
	
	var crit_ch = current_mask.ult_crit_chance if is_ult else current_mask.crit_chance
	var crit_dmg = current_mask.crit_damage 

	if player:
		if "mask_speed_mult" in player: player.mask_speed_mult = spd
		if "mask_jump_mult" in player: player.mask_jump_mult = jmp
		if "mask_defense_mult" in player: player.mask_defense_mult = def 
	
	if combat_manager:
		combat_manager.attack_speed_multiplier = atk
		combat_manager.crit_chance = crit_ch
		combat_manager.crit_damage = crit_dmg
	
	if stamina_component:
		stamina_component.cost_multiplier = cost
		stamina_component.regen_multiplier = regen
		stamina_component.delay_multiplier = delay
