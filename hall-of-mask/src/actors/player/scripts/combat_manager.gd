extends Node3D

# --- REFERENCIAS (Ajusta las rutas si es necesario) ---
@onready var player = $".." # El CharacterBody3D
@onready var anim_tree = $"../AnimationTree"
@onready var skeleton = $"../Ranger/Rig_Medium/Skeleton3D"
@onready var hand_r_node = $"../Ranger/Rig_Medium/Skeleton3D/Right Hand"
@onready var hand_l_node = $"../Ranger/Rig_Medium/Skeleton3D/Left Hand/Marker3D"

# Tus Componentes
@onready var attributes = $"../AttributeManager"
@onready var stamina = $"../StaminaComponent"
@onready var mana = $"../ManaComponent"

# Variables de Estado
var weapon_r: WeaponData
var weapon_l: WeaponData
var is_attacking_r = false
var is_attacking_l = false
var cooldown_time: float = 0.2 # Tiempo extra tras terminar el ataque

# Rutas del AnimationTree
var path_blend_r = "parameters/Mezcla_R/blend_amount"
var path_blend_l = "parameters/Mezcla_L/blend_amount"
var path_blend_2h = "parameters/Mezcla_2H/blend_amount"
var path_playback_r = "parameters/Combat_R/playback"
var path_playback_l = "parameters/Combat_L/playback"
var path_playback_2h = "parameters/Combat_2H/playback"

func _ready():
	# Al inicio, reseteamos las mezclas a 0 (brazos libres al caminar)
	anim_tree.set(path_blend_r, 0.0)
	anim_tree.set(path_blend_l, 0.0)
	anim_tree.set(path_blend_2h, 0.0)

# --- ZONA DE PRUEBAS (BORRAR LUEGO) ---
func _input(event):
	# 1. ATAQUES CON MOUSE
	if event is InputEventMouseButton and event.pressed:
		# Click Derecho -> Atacar con Mano Derecha (Tu pedido)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if weapon_r: # Solo ataca si hay arma
				procesar_input("right")
			else:
				print("⚠️ Mano Derecha vacía")

		# Click Izquierdo -> Atacar con Mano Izquierda
		if event.button_index == MOUSE_BUTTON_LEFT:
			if weapon_l: # Solo ataca si hay arma
				procesar_input("left")
			else:
				print("⚠️ Mano Izquierda vacía")

	# 2. SELECTOR DE ARMAS (TECLADO)
	if event is InputEventKey and event.pressed:
		# Detectar si TAB está presionado
		var holding_tab = Input.is_physical_key_pressed(KEY_TAB)

		# Tecla 1: DESEQUIPAR (Nada)
		if event.keycode == KEY_1:
			if holding_tab:
				print("🧪 TEST: Desequipando Izquierda")
				desequipar("left")
			else:
				print("🧪 TEST: Desequipando Derecha")
				desequipar("right")

		# Tecla 2: EQUIPAR HACHA
		elif event.keycode == KEY_2:
			# Asegúrate de que esta ruta exista, si no, te dará error
			var hacha_res = load("res://src/actors/weapons/Hacha_Mano.tres")
			
			if hacha_res:
				if holding_tab:
					print("🧪 TEST: Equipando Hacha en Izquierda")
					equipar(hacha_res, "left")
				else:
					print("🧪 TEST: Equipando Hacha en Derecha")
					equipar(hacha_res, "right")
			else:
				print("❌ ERROR: No se encontró res://src/actors/weapons/Hacha_Mano.tres")
				
		# Tecla 3: EQUIPAR MARTILLO
		elif event.keycode == KEY_3:
			# Asegúrate de que esta ruta exista, si no, te dará error
			var martillo_res = load("res://src/actors/weapons/Martillo_Mano.tres")
			
			if martillo_res:
				if holding_tab:
					print("🧪 TEST: Equipando Martillo en Izquierda")
					equipar(martillo_res, "left")
				else:
					print("🧪 TEST: Equipando Martillo en Derecha")
					equipar(martillo_res, "right")
			else:
				print("❌ ERROR: No se encontró res://src/actors/weapons/Martillo_Mano.tres")
				
		# Tecla 3: EQUIPAR DAGGA
		elif event.keycode == KEY_4:
			# Asegúrate de que esta ruta exista, si no, te dará error
			var daga_res = load("res://src/actors/weapons/Daga_Mano.tres")
			
			if daga_res:
				if holding_tab:
					print("🧪 TEST: Equipando Daga en Izquierda")
					equipar(daga_res, "left")
				else:
					print("🧪 TEST: Equipando Daga en Derecha")
					equipar(daga_res, "right")
			else:
				print("❌ ERROR: No se encontró res://src/actors/weapons/Daga_Mano.tres")

		# EXTRA: Tecla 4 para probar la Espada 2 Manos en la derecha
		elif event.keycode == KEY_4 and not holding_tab:
			var espada_res = load("res://src/actors/weapons/Espada_2H.tres")
			if espada_res:
				print("🧪 TEST: Equipando Espada 2H (Ocupa todo)")
				equipar(espada_res, "right")
# ----------------------------------------

func equipar(data: WeaponData, mano: String):
	# 1. LOGICA 2 MANOS
	if data.is_two_handed:
		# Para 2 manos SÍ queremos override (1.0) porque cambia la postura entera
		crear_tween_mezcla(path_blend_2h, 1.0)
		crear_tween_mezcla(path_blend_r, 0.0)
		crear_tween_mezcla(path_blend_l, 0.0)
	else:
		# Para 1 mano queremos que siga caminando normal (0.0)
		# Solo activaremos el blend al atacar
		crear_tween_mezcla(path_blend_2h, 0.0)
		
		# ¡ESTO ES LO QUE CAUSABA EL T-POSE!
		# Antes decía 1.0, cámbialo a 0.0
		if mano == "right": 
			weapon_r = data
			crear_tween_mezcla(path_blend_r, 0.0) 
		else: 
			weapon_l = data
			crear_tween_mezcla(path_blend_l, 0.0)

	# 2. VISUALES (Mesh)
	if mano == "right": limpiar_nodo(hand_r_node)
	else: limpiar_nodo(hand_l_node)

	# Instanciamos la escena del arma (.tscn)
	if data.weapon_scene:
		var nueva_arma = data.weapon_scene.instantiate()
		
		# IMPORTANTE: Desactivar colisiones físicas si tu arma tiene StaticBody 
		# (para que no choque con el jugador al moverse)
		# Pero dejamos el Area3D (Hitbox) activo.
		
		if mano == "right":
			weapon_r = data
			hand_r_node.add_child(nueva_arma)
			anim_tree[path_playback_r].travel(data.anim_idle)
		else:
			weapon_l = data
			hand_l_node.add_child(nueva_arma)
			# Nota: Si usaste el script de espejo, recuerda usar anim_idle + "_L" si aplica
			anim_tree[path_playback_l].travel(data.anim_idle)

func desequipar(mano: String):
	if mano == "left":
		weapon_l = null
		limpiar_nodo(hand_l_node)
		crear_tween_mezcla(path_blend_l, 0.0) # Bajamos el brazo
	else:
		weapon_r = null
		limpiar_nodo(hand_r_node)
		crear_tween_mezcla(path_blend_r, 0.0)

func procesar_input(mano: String):
	var w = weapon_r if mano == "right" else weapon_l
	if not w: return
	
	# 1. BLOQUEO DE SPAM (Si ya está atacando, ignoramos el click)
	if mano == "right" and is_attacking_r: return
	if mano == "left" and is_attacking_l: return

	# 2. Restricción de Postura
	if player.current_state == 3 and not w.can_use_prone:
		print("¡No puedes usar esto reptando!")
		return

	# 3. Consumo y Ejecución
	var costo = w.stamina_cost # (Logica de mana/stamina igual)
	if stamina.try_consume(costo):
		ejecutar_ataque_seguro(w, mano)

func ejecutar_ataque_seguro(w: WeaponData, mano: String):
	# 1. Definir Rutas (Igual que antes)
	var playback_path = ""
	var blend_path = ""
	var anim_name = w.anim_attack
	
	if w.is_two_handed:
		playback_path = path_playback_2h
		blend_path = path_blend_2h
		is_attacking_r = true
		is_attacking_l = true
	elif mano == "right":
		playback_path = path_playback_r
		blend_path = path_blend_r
		is_attacking_r = true
	else:
		playback_path = path_playback_l
		blend_path = path_blend_l
		anim_name = w.anim_attack + "_L"
		is_attacking_l = true
	
	# 2. CONFIGURAR HITBOX (CORREGIDO)
	# --- BORRÉ TODO EL BLOQUE QUE PRENDÍA EL MONITORING AQUÍ ---
	# Solo actualizamos el daño base, pero NO lo prendemos todavía.
	
	var weapon_node = null
	if mano == "right": weapon_node = hand_r_node.get_child(0)
	else: weapon_node = hand_l_node.get_child(0)
	
	if weapon_node:
		var hitbox = weapon_node.find_child("Hitbox")
		if hitbox:
			var base_dmg = attributes.get_stat("melee_damage")
			hitbox.damage = base_dmg * w.damage_mult
			# ¡OJO! NO ponemos monitoring = true aquí. Esperamos al delay.
			
	# 3. ARRANCAR ANIMACIÓN
	anim_tree[playback_path].start("Empty") 
	anim_tree[playback_path].start(anim_name)
	
	# CALCULAR VELOCIDAD
	var atk_speed = 1.0
	if attributes.has_method("get_stat"):
		atk_speed = attributes.get_stat("attack_speed")
	
	# ---------------------------------------------------------
	# ESTA ES LA ÚNICA LLAMADA QUE DEBE ACTIVAR EL DAÑO
	# ---------------------------------------------------------
	var delay_real = w.damage_delay / atk_speed
	var duracion_real = w.hitbox_duration / atk_speed
	
	gestionar_hitbox_con_delay(mano, delay_real, duracion_real, w)
	# ---------------------------------------------------------
	
	# 4. SUBIR EL VOLUMEN (Mezcla de animación)
	var t = create_tween()
	t.tween_property(anim_tree, blend_path, 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	
	# 5. ESPERAR QUE TERMINE LA ANIMACIÓN
	var anim_len = 0.5
	var anim_player = player.get_node("AnimationPlayer")
	if anim_player.has_animation(anim_name):
		anim_len = anim_player.get_animation(anim_name).length
	
	await get_tree().create_timer(anim_len).timeout
	
	# 6. BAJAR EL VOLUMEN
	var t_out = create_tween()
	t_out.tween_property(anim_tree, blend_path, 0.0, 0.2) 
	
	await t_out.finished 
	
	# Liberar banderas
	if w.is_two_handed:
		is_attacking_r = false
		is_attacking_l = false
	elif mano == "right":
		is_attacking_r = false
	else:
		is_attacking_l = false

# --- UTILIDADES ---
func crear_tween_mezcla(path, valor_final):
	var t = create_tween()
	t.tween_property(anim_tree, path, valor_final, 0.2)

func limpiar_nodo(nodo):
	for c in nodo.get_children():
		c.queue_free()
		
func gestionar_hitbox_con_delay(mano: String, delay: float, duracion: float, w: WeaponData):
	# 1. Esperar el "Windup" (El tiempo que tarda en levantar el arma antes de pegar)
	await get_tree().create_timer(delay).timeout
	
	# --- VERIFICACIONES DE SEGURIDAD ---
	var weapon_node = hand_r_node.get_child(0) if mano == "right" else hand_l_node.get_child(0)
	if not weapon_node: return
	
	# Si nos cancelaron el ataque en medio del delay, no hacemos daño
	if mano == "right" and not is_attacking_r: return
	if mano == "left" and not is_attacking_l: return
	
	# 2. BUSCAR EL HITBOX Y ACTIVARLO
	var hitbox = weapon_node.find_child("Hitbox")
	if hitbox and hitbox.has_method("attack_simple"):
		# Actualizamos stats antes de pegar
		hitbox.damage = attributes.get_stat("melee_damage") * w.damage_mult
		hitbox.knockback_force = w.knockback_force # Asumiendo que agregaste esto al WeaponData
		
		# ¡AQUÍ ESTÁ LA MAGIA!
		# Le decimos al hitbox: "Haz tu trabajo". Él se prenderá, chequeará colisiones y se apagará solo.
		hitbox.attack_simple() 
	else:
		print("⚠️ Error: No encontré nodo Hitbox o no tiene el script WeaponHitbox")
