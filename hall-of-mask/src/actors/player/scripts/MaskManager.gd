extends Node
class_name MaskManager

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN
# ------------------------------------------------------------------------------
signal on_mask_changed(mask_data)
signal on_ultimate_state(is_active)
signal on_ult_charge_changed(current, max)

@export_group("Referencias")
## Arrastra aquí al dueño (Enemy_Goblin, BossOrc, Player). NO al jugador si es un enemigo.
@export var player: CharacterBody3D 
@export var combat_manager: CombatManager
@export var stamina_component: Node 
@export var screen_overlay: ColorRect # Solo para el Player (HUD)

@export_group("Visuales")
## Arrastra aquí el nodo 'MaskMount' que creaste en la cabeza
@export var mask_attachment_point: Node3D 

@export_group("Configuración Ulti")
@export var max_ult_charge: float = 100.0
@export var charge_decay_rate: float = 0.0 # Si quieres que baje sola con el tiempo

# ------------------------------------------------------------------------------
# 2. VARIABLES INTERNAS
# ------------------------------------------------------------------------------
var current_mask: MaskData = null
var current_ult_charge: float = 0.0
var is_ultimate_active: bool = false
var ult_timer: float = 0.0

# Referencia al modelo 3D instanciado de la máscara
var current_mask_visual_node: Node3D = null

# ------------------------------------------------------------------------------
# 3. CICLO DE VIDA
# ------------------------------------------------------------------------------
func _ready():
	# Inicializar carga en 0
	current_ult_charge = 0.0

func _process(delta):
	# Lógica de duración de la Ulti
	if is_ultimate_active:
		ult_timer -= delta
		
		# Feedback visual en HUD (Solo Player)
		if screen_overlay and current_mask:
			var alpha = (ult_timer / current_mask.ultimate_duration) * 0.3
			screen_overlay.color = current_mask.ult_screen_tint
			screen_overlay.color.a = alpha
			
		if ult_timer <= 0:
			deactivate_ultimate()
	
	# Lógica de decaimiento de carga (Opcional)
	elif current_ult_charge > 0 and charge_decay_rate > 0:
		current_ult_charge = max(0, current_ult_charge - (charge_decay_rate * delta))
		emit_signal("on_ult_charge_changed", current_ult_charge, max_ult_charge)

# ------------------------------------------------------------------------------
# 4. GESTIÓN DE MÁSCARA (EQUIPAR / QUITAR)
# ------------------------------------------------------------------------------
func equip_mask(data: MaskData):
	if not data: return
	
	# Si ya teníamos una, la quitamos primero visualmente
	if current_mask_visual_node: _remove_visual_model()
	
	current_mask = data
	emit_signal("on_mask_changed", data)
	print("🎭 Manager: Equipando ", data.mask_name)
	
	# 1. Aplicar Stats Base
	apply_stats(false)
	
	# 2. Tintar pantalla (Solo Player)
	if screen_overlay:
		screen_overlay.visible = true
		screen_overlay.color = data.screen_tint
	
	# 3. GENERAR MODELO VISUAL (NUEVO)
	_spawn_mask_visual(data)

func remove_mask():
	print("🎭 Manager: Removiendo máscara")
	
	# Desactivar ulti si estaba activa
	if is_ultimate_active: deactivate_ultimate()
	
	current_mask = null
	emit_signal("on_mask_changed", null)
	
	# 1. Resetear Stats a 1.0 (Valores por defecto)
	_reset_stats_to_default()
	
	# 2. Quitar tinte de pantalla
	if screen_overlay: screen_overlay.visible = false
	
	# 3. BORRAR MODELO VISUAL (NUEVO)
	_remove_visual_model()

# ------------------------------------------------------------------------------
# 5. LÓGICA DE STATS
# ------------------------------------------------------------------------------
func apply_stats(is_ult: bool):
	if not current_mask: return
	
	# A. Seleccionar valores (Normal vs Ulti)
	var spd = current_mask.ult_speed_mult if is_ult else current_mask.speed_mult
	var jmp = current_mask.ult_jump_mult if is_ult else current_mask.jump_mult
	var atk_spd = current_mask.ult_attack_speed_mult if is_ult else current_mask.attack_speed_mult
	var def = current_mask.ult_defense_mult if is_ult else current_mask.defense_mult
	var dmg = current_mask.ult_damage_mult if is_ult else current_mask.damage_mult # DAÑO
	
	var cost = current_mask.ult_stamina_cost_mult if is_ult else current_mask.stamina_cost_mult
	var regen = current_mask.ult_stamina_regen_mult if is_ult else current_mask.stamina_regen_mult
	var delay = current_mask.ult_stamina_delay_mult if is_ult else current_mask.stamina_delay_mult
	
	var crit_ch = current_mask.ult_crit_chance if is_ult else current_mask.crit_chance
	var crit_dmg = current_mask.crit_damage 

	# B. Aplicar al Personaje (Player/Enemy)
	if player:
		if "mask_speed_mult" in player: player.mask_speed_mult = spd
		if "mask_jump_mult" in player: player.mask_jump_mult = jmp
		if "mask_defense_mult" in player: player.mask_defense_mult = def 
	
	# C. Aplicar al Combate
	if combat_manager:
		combat_manager.attack_speed_multiplier = atk_spd
		combat_manager.damage_multiplier = dmg  # AQUI SE APLICA EL DAÑO
		combat_manager.crit_chance = crit_ch
		combat_manager.crit_damage = crit_dmg
	
	# D. Aplicar a Stamina
	if stamina_component:
		stamina_component.cost_multiplier = cost
		stamina_component.regen_multiplier = regen
		stamina_component.delay_multiplier = delay

func _reset_stats_to_default():
	if player:
		if "mask_speed_mult" in player: player.mask_speed_mult = 1.0
		if "mask_jump_mult" in player: player.mask_jump_mult = 1.0
		if "mask_defense_mult" in player: player.mask_defense_mult = 1.0
	
	if combat_manager:
		combat_manager.attack_speed_multiplier = 1.0
		combat_manager.damage_multiplier = 1.0
		combat_manager.crit_chance = 0.0
		# crit_damage base suele ser 1.5 o 2.0, dejémoslo en 2.0 por defecto
		combat_manager.crit_damage = 2.0 
		
	if stamina_component:
		stamina_component.cost_multiplier = 1.0
		stamina_component.regen_multiplier = 1.0
		stamina_component.delay_multiplier = 1.0

# ------------------------------------------------------------------------------
# 6. SISTEMA DE ULTIMATE
# ------------------------------------------------------------------------------
func add_charge(amount: float):
	if is_ultimate_active or not current_mask: return
	current_ult_charge = min(current_ult_charge + amount, max_ult_charge)
	emit_signal("on_ult_charge_changed", current_ult_charge, max_ult_charge)

func activate_ultimate():
	if not current_mask or current_ult_charge < max_ult_charge: 
		# Debug rápido para desarrollador (puedes borrarlo)
		# print("❌ No se puede activar ulti. Carga: ", current_ult_charge)
		return
	
	print("🔥 ULTIMATE ACTIVADO!")
	is_ultimate_active = true
	ult_timer = current_mask.ultimate_duration
	current_ult_charge = 0.0 # Consumir carga
	emit_signal("on_ult_charge_changed", 0.0, max_ult_charge)
	emit_signal("on_ultimate_state", true)
	
	apply_stats(true) # Aplicar stats OP

func deactivate_ultimate():
	print("❄️ Ultimate finalizado.")
	is_ultimate_active = false
	emit_signal("on_ultimate_state", false)
	
	if current_mask:
		apply_stats(false) # Volver a stats normales de máscara
		if screen_overlay:
			screen_overlay.color = current_mask.screen_tint
	else:
		_reset_stats_to_default() # Si se quitó la máscara en medio, reset total

# ------------------------------------------------------------------------------
# 7. LÓGICA VISUAL (SPAWN DE MÁSCARA 3D)
# ------------------------------------------------------------------------------
func _spawn_mask_visual(data: MaskData):
	# Limpieza previa
	_remove_visual_model()
	
	# Validaciones
	if not mask_attachment_point:
		# Si no hay punto asignado, no hacemos nada (falla silenciosamente)
		return
		
	# ¡OJO! Asegúrate de haber agregado 'mask_visual_scene' a tu MaskData.gd
	if not "mask_visual_scene" in data or not data.mask_visual_scene:
		# print("⚠️ La máscara no tiene escena visual asignada (.tscn)")
		return
	
	# Instanciar
	var visual_instance = data.mask_visual_scene.instantiate()
	
	# Añadir al MaskMount
	# Al ser hijo, hereda la escala que le diste al MaskMount en el editor del enemigo
	mask_attachment_point.add_child(visual_instance)
	current_mask_visual_node = visual_instance
	
	# Resetear pos/rot local (La escala NO se toca para respetar el MaskMount)
	visual_instance.position = Vector3.ZERO
	visual_instance.rotation = Vector3.ZERO

func _remove_visual_model():
	if current_mask_visual_node:
		current_mask_visual_node.queue_free()
		current_mask_visual_node = null
