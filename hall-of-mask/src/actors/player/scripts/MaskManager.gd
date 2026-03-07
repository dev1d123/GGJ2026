extends Node
class_name MaskManager

# Referencias a los iconos de progreso de la ultimate en el HUD
# (Se resuelven diferidos porque HUD2 es una escena instanciada externa)
var _ult_label = null
var _ulti1 = null
var _ulti2 = null
var _ulti3 = null
var _ulti4 = null
var _ulti5 = null
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

@export_group("Animaciones y Tiempos")
@export var mask_equip_delay: float = 0.3

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
	# HUD2 es una escena instanciada externa: sus hijos no están listos aún.
	# Diferimos la búsqueda de nodos para el siguiente frame.
	call_deferred("_init_hud_refs")

func _init_hud_refs():
	# Estrategia 1: usar el export 'player' si apunta al Player real (tiene HUD2 como hijo)
	# Estrategia 2: buscar HUD2 como hermano de este MaskManager (../HUD2)
	# Estrategia 3: no hay HUD -> enemigo, saltar silenciosamente
	var hud_root: Node = null

	if player and player.has_node("HUD2"):
		hud_root = player.get_node("HUD2")
		print("[MaskManager] _init_hud_refs | HUD2 encontrado via 'player' export (", player.name, ")")
	elif has_node("../HUD2"):
		hud_root = get_node("../HUD2")
		print("[MaskManager] _init_hud_refs | HUD2 encontrado via path relativo ../HUD2")
	else:
		print("[MaskManager] _init_hud_refs | Sin HUD2 (soy enemigo: ", get_parent().name, ") -> skip")
		return

	_ult_label = hud_root.get_node_or_null("GameUI/SkillsPanel/UltiProgess/Label")
	_ulti1     = hud_root.get_node_or_null("GameUI/SkillsPanel/UltiProgess/ulti1")
	_ulti2     = hud_root.get_node_or_null("GameUI/SkillsPanel/UltiProgess/ulti2")
	_ulti3     = hud_root.get_node_or_null("GameUI/SkillsPanel/UltiProgess/ulti3")
	_ulti4     = hud_root.get_node_or_null("GameUI/SkillsPanel/UltiProgess/ulti4")
	_ulti5     = hud_root.get_node_or_null("GameUI/SkillsPanel/UltiProgess/ulti5")
	print("[MaskManager] _init_hud_refs | ulti1=", _ulti1, " ulti2=", _ulti2, " ulti3=", _ulti3, " ulti4=", _ulti4, " ulti5=", _ulti5, " label=", _ult_label)
	_update_ult_icons()

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
func equip_mask(data: MaskData, instant_spawn: bool = false):
	if not data: return
	
	# Si ya teníamos una, la quitamos primero visualmente
	if current_mask_visual_node: _remove_visual_model()
	
	current_mask = data
	print("🎭 Manager: Equipando ", data.mask_name)
	
	# 1. GENERAR MODELO VISUAL INMEDIATAMENTE PARA ANIMARLO
	_spawn_mask_visual(data)
	
	# Si es instantáneo (ej. al spawnear) o no hay delay configurado
	if instant_spawn or mask_equip_delay <= 0.01:
		_finalize_equip_mask(data)
	else:
		# ANIMACIÓN DE APARICIÓN (Scala de 0 a 1 tipo pop-in)
		if current_mask_visual_node:
			current_mask_visual_node.scale = Vector3.ZERO
			var tween = create_tween()
			tween.tween_property(current_mask_visual_node, "scale", Vector3.ONE, mask_equip_delay)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				
		await get_tree().create_timer(mask_equip_delay).timeout
		
		# Validar que no se haya quitado la máscara mientras esperábamos
		if current_mask == data:
			_finalize_equip_mask(data)

func _finalize_equip_mask(data: MaskData):
	emit_signal("on_mask_changed", data)
	
	# 2. Aplicar Stats Base
	apply_stats(false)
	
	# 3. Tintar pantalla (Solo Player)
	if screen_overlay:
		screen_overlay.visible = true
		screen_overlay.color = data.screen_tint

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
	if is_ultimate_active or not current_mask:
		return
	current_ult_charge = min(current_ult_charge + amount, max_ult_charge)
	print("[MaskManager] Carga actualizada: ", current_ult_charge, "/", max_ult_charge)
	emit_signal("on_ult_charge_changed", current_ult_charge, max_ult_charge)
	_update_ult_icons()

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
	_update_ult_icons()
	
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
func _resolve_mask_attachment_point() -> Node3D:
	if is_instance_valid(mask_attachment_point):
		return mask_attachment_point

	var search_roots: Array[Node] = []
	if get_parent():
		search_roots.append(get_parent())
	if is_instance_valid(player):
		search_roots.append(player)
	search_roots.append(self)

	for root in search_roots:
		if not is_instance_valid(root):
			continue
		var found := root.find_child("MaskMount", true, false)
		if found is Node3D:
			mask_attachment_point = found
			return found

	return null

func _spawn_mask_visual(data: MaskData):
	# Limpieza previa
	_remove_visual_model()

	# Validaciones
	var mount := _resolve_mask_attachment_point()
	if not mount:
		push_warning("[MaskManager] No se encontró MaskMount para %s" % [str(data.mask_name)])
		return

	if not data.mask_visual_scene:
		return

	# Instanciar
	var scene_instance: Node = data.mask_visual_scene.instantiate()
	if not scene_instance:
		return

	var visual_instance: Node3D
	if scene_instance is Node3D:
		visual_instance = scene_instance as Node3D
	else:
		visual_instance = Node3D.new()
		visual_instance.name = "MaskVisualRoot"
		visual_instance.add_child(scene_instance)

	# Añadir al MaskMount
	mount.add_child(visual_instance)
	current_mask_visual_node = visual_instance

	# Resetear pos/rot local (La escala NO se toca para respetar el MaskMount)
	visual_instance.position = Vector3.ZERO
	visual_instance.rotation = Vector3.ZERO

func _remove_visual_model():
	if current_mask_visual_node:
		current_mask_visual_node.queue_free()
		current_mask_visual_node = null

# ------------------------------------------------------------------------------
# 8. PROGRESO DE ULTIMATE EN HUD
# ------------------------------------------------------------------------------
func _update_ult_icons():
	# ulti1 = siempre visible (0+)
	# ulti2 = >= 25
	# ulti3 = >= 50
	# ulti4 = >= 75
	# ulti5 + label = 100 (carga completa)
	if _ulti1: _ulti1.visible = true
	if _ulti2: _ulti2.visible = current_ult_charge >= 25.0
	if _ulti3: _ulti3.visible = current_ult_charge >= 50.0
	if _ulti4: _ulti4.visible = current_ult_charge >= 75.0
	if _ulti5: _ulti5.visible = current_ult_charge >= 100.0
	if _ult_label: _ult_label.visible = current_ult_charge >= max_ult_charge
