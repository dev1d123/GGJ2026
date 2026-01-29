@tool
extends Node

# --- CONFIGURACIÓN ---
@export var source_animation: Animation
@export var base_output_name: String = "Axe_Attack_L"
@export var hand_bone_name: String = "hand.l" # Nombre del hueso de la mano izquierda

# --- BOTÓN PARA GENERAR ---
@export var GENERAR_6_VERSIONES: bool = false:
	set(value):
		if value:
			run_generator()
			GENERAR_6_VERSIONES = false

func run_generator():
	if not source_animation:
		print("❌ ERROR: Falta animación de origen.")
		return
	
	print("--- Iniciando Generación Masiva ---")
	
	# Lista de variantes a probar (Nombre, Rotación Extra en Grados X,Y,Z)
	var variantes = [
		["_V1_Espejo_Simple", Vector3(0, 0, 0)],      # Espejo matemático puro
		["_V2_Correc_Z_90",   Vector3(0, 0, 90)],     # Giro horario
		["_V3_Correc_Z_neg90",Vector3(0, 0, -90)],    # Giro anti-horario (Probable para hachas)
		["_V4_Correc_Y_180",  Vector3(0, 180, 0)],    # Vuelta completa
		["_V5_Correc_X_90",   Vector3(90, 0, 0)],     # Apuntar arriba/abajo
		["_V6_Correc_X_neg90",Vector3(-90, 0, 0)]
	]

	for v in variantes:
		create_variant(v[0], v[1])
		
	print("✅ ¡Listo! 6 versiones generadas en 'res://animaciones_espejo/'")

func create_variant(suffix: String, offset_deg: Vector3):
	var new_anim = source_animation.duplicate(true)
	new_anim.resource_name = base_output_name + suffix
	
	var right_suffix = ".r"
	var left_suffix = ".l"
	
	# 1. LIMPIEZA: Borrar cualquier track izquierdo original para evitar conflictos
	for i in range(new_anim.get_track_count() - 1, -1, -1):
		var path = str(new_anim.track_get_path(i))
		if left_suffix in path:
			new_anim.remove_track(i)

	# Preparar corrección de mano
	var correction = Quaternion.from_euler(Vector3(
		deg_to_rad(offset_deg.x),
		deg_to_rad(offset_deg.y),
		deg_to_rad(offset_deg.z)
	))

	# 2. CONVERSIÓN: Derecha -> Izquierda (Espejo)
	for i in range(new_anim.get_track_count()):
		var path = str(new_anim.track_get_path(i))
		
		# Detectamos tracks derechos
		if right_suffix in path:
			# Cambiamos nombre a izquierdo
			var new_path = path.replace(right_suffix, left_suffix)
			new_anim.track_set_path(i, new_path)
			
			var es_mano = hand_bone_name in new_path
			
			# Modificar Claves
			var type = new_anim.track_get_type(i)
			var key_count = new_anim.track_get_key_count(i)
			
			for k in range(key_count):
				var val = new_anim.track_get_key_value(i, k)
				
				if type == Animation.TYPE_POSITION_3D:
					val.x = -val.x # Invertir X (Espejo lateral estándar)
					new_anim.track_set_key_value(i, k, val)
					
				elif type == Animation.TYPE_ROTATION_3D:
					# Esta combinación (x, -y, -z, w) es la más común para Godot/Blender rigs
					# Si el cuerpo se deforma raro, prueba cambiar esto a (-x, y, z, w) manualmente
					val.y = -val.y
					val.z = -val.z
					
					# Aplicar corrección SOLO a la mano
					if es_mano:
						val = val * correction
					
					new_anim.track_set_key_value(i, k, val)
		
		# 3. TRACKS CENTRALES (Spine, Head, Hips)
		# Si quieres que el cuerpo también se "espeje" (incline al otro lado)
		elif not ".l" in path and not ".r" in path:
			var type = new_anim.track_get_type(i)
			for k in range(new_anim.track_get_key_count(i)):
				var val = new_anim.track_get_key_value(i, k)
				if type == Animation.TYPE_POSITION_3D:
					val.x = -val.x
					new_anim.track_set_key_value(i, k, val)
				elif type == Animation.TYPE_ROTATION_3D:
					val.y = -val.y
					val.z = -val.z
					new_anim.track_set_key_value(i, k, val)

	# GUARDAR
	var dir = "res://animaciones_espejo/"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_absolute(dir)
	
	ResourceSaver.save(new_anim, dir + base_output_name + suffix + ".res")
