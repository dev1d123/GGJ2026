class_name VisualEffectManager extends Node

# Arrastraremos aquí TODAS las partes del cuerpo que quieras que cambien de color
# (Body, Head, Arms, Legs...)
@export var partes_del_cuerpo: Array[MeshInstance3D]

# Colores de estado
const COLOR_POISON = Color(0.2, 1.0, 0.2) # Verde brillante
const COLOR_FREEZE = Color(0.3, 0.3, 1.0) # Azul
const COLOR_BERSERK = Color(1.0, 0.2, 0.2) # Rojo
const COLOR_DAMAGE = Color(1.0, 0.0, 0.0) # Rojo instantáneo (golpe)

func aplicar_efecto(tipo: String):
	# Recorremos cada parte del cuerpo (Cabeza, torso, piernas...)
	for mesh in partes_del_cuerpo:
		if not mesh: continue
		
		# 1. Limpieza: Si es "normal", quitamos el override y volvemos al .tres original
		if tipo == "normal":
			mesh.set_surface_override_material(0, null)
			continue
			
		# 2. Obtenemos el material base actual (el .tres compartido)
		var material_base = mesh.get_active_material(0)
		if not material_base: continue
		
		# 3. ¡EL TRUCO! Duplicamos el material en memoria.
		# Ahora 'nuevo_mat' es una copia única solo para ESTE objeto.
		var nuevo_mat = material_base.duplicate()
		
		# 4. Pintamos la copia
		match tipo:
			"veneno":
				nuevo_mat.albedo_color = COLOR_POISON
			"congelado":
				nuevo_mat.albedo_color = COLOR_FREEZE
			"berserk":
				nuevo_mat.albedo_color = COLOR_BERSERK
				nuevo_mat.emission_enabled = true
				nuevo_mat.emission = COLOR_BERSERK
				nuevo_mat.emission_energy_multiplier = 1.0
			"golpe":
				nuevo_mat.albedo_color = COLOR_DAMAGE
				
		# 5. Aplicamos la copia COMO OVERRIDE (Sobreescritura)
		# Esto no toca el archivo .tres original, solo cambia cómo se ve este mesh.
		mesh.set_surface_override_material(0, nuevo_mat)

func limpiar_efectos():
	aplicar_efecto("normal")

# Función extra para parpadeo de daño (Hit Flash)
func play_hit_flash():
	aplicar_efecto("golpe")
	await get_tree().create_timer(0.1).timeout # Espera 0.1 seg
	limpiar_efectos() # Vuelve a la normalidad
