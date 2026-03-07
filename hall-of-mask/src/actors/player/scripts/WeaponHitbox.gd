extends Area3D
class_name WeaponHitbox

var damage: float = 0.0
var knockback: float = 0.0
var jump: float = 0.0
var attacker_node: Node = null 
var hit_history: Array[Node] = [] 

@export_group("Efecto Estela (Trail Automático)")
@export var enable_trail: bool = true
@export var trail_color: Color = Color(1.0, 0.067, 0.067, 1) # Tonos Rojos Oscuros / Sangre (Casi opaco)
@export var trail_lifetime: float = 0.35
@export var trail_thickness: float = 0.15 # Volumen reducido y sutil

# Variables internas para la estela
var _trail_mesh: ImmediateMesh
var _trail_instance: MeshInstance3D
var _trail_material: StandardMaterial3D
var _trail_points: Array[Dictionary] = [] # {top, center, bottom, right, left, front, back, age}
var _weapon_length: float = 1.0
var _is_emitting: bool = false
var _last_top_pos: Vector3 = Vector3.ZERO
var _last_center_pos: Vector3 = Vector3.ZERO
var _last_bot_pos: Vector3 = Vector3.ZERO
var _last_weapon_x: Vector3 = Vector3.ZERO
var _last_weapon_z: Vector3 = Vector3.ZERO

func _ready():
	monitoring = false
	monitorable = false
	# Usamos body_entered para detectar CharacterBody3D (Player/Enemigo)
	body_entered.connect(_on_body_entered)
	# También detectamos areas como Hurtbox
	area_entered.connect(_on_area_entered)
	
	if enable_trail:
		_setup_trail()

func activate(dmg: float, kb: float, jmp: float, attacker: Node):
	hit_history.clear()
	damage = dmg
	knockback = kb
	jump = jmp
	attacker_node = attacker 
	monitoring = true
	
	if enable_trail:
		_is_emitting = true
		_trail_points.clear()
	
	# Revisión instantánea de bodies y areas
	for body in get_overlapping_bodies():
		_on_body_entered(body)
	for area in get_overlapping_areas():
		_on_area_entered(area)

func deactivate():
	monitoring = false
	attacker_node = null
	_is_emitting = false
	_last_top_pos = Vector3.ZERO
	_last_center_pos = Vector3.ZERO
	_last_bot_pos = Vector3.ZERO
	_last_weapon_x = Vector3.ZERO
	_last_weapon_z = Vector3.ZERO

func _process(delta):
	if not enable_trail: return
	
	# Envejecer puntos de la estela
	for i in range(_trail_points.size() - 1, -1, -1):
		_trail_points[i].age -= delta
		if _trail_points[i].age <= 0:
			_trail_points.remove_at(i)
	
	# Añadir nuevo punto si estamos atacando
	if _is_emitting:
		# ¡IMPORTANTE! Al usar top_level=true, los puntos DEBEN estar en globales absolutos
		# Obtenemos el shape3D directamente, ya que su transform ya incluye el offset de la empuñadura
		var shape_transform = global_transform
		for child in get_children():
			if child is CollisionShape3D:
				shape_transform = child.global_transform
				break
				
		var weapon_axis = shape_transform.basis.y.normalized() # Eje longitudinal del filo
		var weapon_x = shape_transform.basis.x.normalized() # Eje transversal 1 (Ancho)
		var weapon_z = shape_transform.basis.z.normalized() # Eje transversal 2 (Profundidad Real)
		var center = shape_transform.origin
		
		# Proyectamos Extremos Longitudinales (Punta y Base) exactamente sobre los límites físicos de la Hitbox
		# _weapon_length contiene la altura total del CollisionShape3D. Dividiéndolo entre 2 tenemos el radio desde el centro.
		var half_len = _weapon_length * 0.5
		var top_pos = center + (weapon_axis * half_len)
		var center_pos = center
		var bot_pos = center - (weapon_axis * half_len)
		
		# Estrella Volumétrica de 4 Puntas: Izquierda, Derecha, Frente, Atrás
		var thick = trail_thickness
		var right_pos = center_pos + (weapon_x * thick)
		var left_pos = center_pos - (weapon_x * thick)
		var front_pos = center_pos + (weapon_z * thick)
		var back_pos = center_pos - (weapon_z * thick)
		
		# --- INTERPOLACIÓN DE ALTA DENSIDAD ---
		if _last_top_pos != Vector3.ZERO and _last_bot_pos != Vector3.ZERO and _last_weapon_x != Vector3.ZERO:
			var dist = _last_top_pos.distance_to(top_pos)
			var steps = max(1, int(dist / 0.10))
			for s in range(1, steps + 1):
				var factor = float(s) / float(steps)
				var time_offset = (1.0 - factor) * delta 
				
				# Interpolamos todos los ejes radiantes
				var interp_center = _last_center_pos.lerp(center_pos, factor)
				var interp_x = _last_weapon_x.lerp(weapon_x, factor).normalized()
				var interp_z = _last_weapon_z.lerp(weapon_z, factor).normalized()
				
				_trail_points.push_front({
					"top": _last_top_pos.lerp(top_pos, factor),
					"center": interp_center,
					"bottom": _last_bot_pos.lerp(bot_pos, factor),
					"right": interp_center + (interp_x * thick),
					"left": interp_center - (interp_x * thick),
					"front": interp_center + (interp_z * thick),
					"back": interp_center - (interp_z * thick),
					"age": trail_lifetime - time_offset
				})
		else:
			_trail_points.push_front({
				"top": top_pos,
				"center": center_pos,
				"bottom": bot_pos,
				"right": right_pos,
				"left": left_pos,
				"front": front_pos,
				"back": back_pos,
				"age": trail_lifetime
			})
			
		_last_top_pos = top_pos
		_last_center_pos = center_pos
		_last_bot_pos = bot_pos
		_last_weapon_x = weapon_x
		_last_weapon_z = weapon_z
		
	# Dibujar malla dinámicamente
	if _trail_instance and _trail_mesh:
		_draw_trail()

func _draw_trail():
	_trail_mesh.clear_surfaces()
	if _trail_points.size() < 2: return
	
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(_trail_points.size() - 1):
		var p1 = _trail_points[i]
		var p2 = _trail_points[i+1]
		
		var ratio1 = max(0.0, p1.age / trail_lifetime)
		var ratio2 = max(0.0, p2.age / trail_lifetime)
		
		var w1 = pow(ratio1, 0.5)
		var w2 = pow(ratio2, 0.5)
		
		# Vértices Actuales (i)
		var t1 = p1.center + (p1.top - p1.center) * w1
		var b1 = p1.center + (p1.bottom - p1.center) * w1
		var r1 = p1.center + (p1.right - p1.center) * w1
		var l1 = p1.center + (p1.left - p1.center) * w1
		var f1 = p1.center + (p1.front - p1.center) * w1
		var bk1= p1.center + (p1.back - p1.center) * w1
		var c1 = p1.center
		
		# Vértices Siguientes (i+1)
		var t2 = p2.center + (p2.top - p2.center) * w2
		var b2 = p2.center + (p2.bottom - p2.center) * w2
		var r2 = p2.center + (p2.right - p2.center) * w2
		var l2 = p2.center + (p2.left - p2.center) * w2
		var f2 = p2.center + (p2.front - p2.center) * w2
		var bk2= p2.center + (p2.back - p2.center) * w2
		var c2 = p2.center
		
		var col_c1 = trail_color; col_c1.a *= ratio1
		var col_c2 = trail_color; col_c2.a *= ratio2
		var col_e1 = col_c1; col_e1.a = 0.0
		var col_e2 = col_c2; col_e2.a = 0.0
		
		# Color Oscuro para el rastro principal de la hoja (Eje Y)
		var dark_core_c1 = trail_color.darkened(0.8) # Muy oscuro
		dark_core_c1.a = col_c1.a
		var dark_core_c2 = trail_color.darkened(0.8)
		dark_core_c2.a = col_c2.a
		
		# Combinamos las 6 cintas (Arriba, Abajo, Derecha, Izquierda, Frente, Atrás) conectadas al centro
		# MÍRELAS POR DONDE LAS MIRES (Arriba, lado, frente) SIEMPRE TENDRÁ VOLUMEN 3D FÍSICO.
		var edges1 = [t1, b1, r1, l1, f1, bk1]
		var edges2 = [t2, b2, r2, l2, f2, bk2]
		
		for j in range(6):
			var e1 = edges1[j]
			var e2 = edges2[j]
			
			# Seleccionamos el color: Oscuro para el movimiento del filo (Top/Bottom, índices 0 y 1)
			# y color brillante transparente para el volumen 3D (Right/Left/Front/Back, índices 2 al 5)
			var active_c1 = dark_core_c1 if j < 2 else col_c1
			var active_c2 = dark_core_c2 if j < 2 else col_c2
			var active_e1 = active_c1; active_e1.a = 0.0
			var active_e2 = active_c2; active_e2.a = 0.0
			
			# Triángulo 1 (Centro1, Borde1, Centro2)
			_trail_mesh.surface_set_color(active_c1)
			_trail_mesh.surface_add_vertex(c1)
			
			_trail_mesh.surface_set_color(active_e1)
			_trail_mesh.surface_add_vertex(e1)
			
			_trail_mesh.surface_set_color(active_c2)
			_trail_mesh.surface_add_vertex(c2)
			
			# Triángulo 2 (Borde1, Borde2, Centro2)
			_trail_mesh.surface_set_color(active_e1)
			_trail_mesh.surface_add_vertex(e1)
			
			_trail_mesh.surface_set_color(active_e2)
			_trail_mesh.surface_add_vertex(e2)
			
			_trail_mesh.surface_set_color(active_c2)
			_trail_mesh.surface_add_vertex(c2)
			
	_trail_mesh.surface_end()

func _setup_trail():
	# Buscar el tamaño del CollisionShape para adaptar la estela al tamaño del arma
	for child in get_children():
		if child is CollisionShape3D and child.shape:
			if child.shape is BoxShape3D: 
				_weapon_length = child.shape.size.y # Altura de la espada
				# Reducimos drásticamente la invasión volumétrica (de 1.5x a 0.5x)
				if child.shape.size.x > trail_thickness: trail_thickness = max(0.15, child.shape.size.x * 0.5)
			elif child.shape is CapsuleShape3D: _weapon_length = child.shape.height
			elif child.shape is CylinderShape3D: _weapon_length = child.shape.height
			
	_trail_mesh = ImmediateMesh.new()
	_trail_instance = MeshInstance3D.new()
	_trail_instance.mesh = _trail_mesh
	
	# Fundamental: separarla del parent para que la estela no rote mágicamente con la mano después del tajo
	_trail_instance.top_level = true 
	
	_trail_material = StandardMaterial3D.new()
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX # Mezcla Estándar: Hace que el rastro tape lo que hay atrás (Sólido)
	_trail_material.albedo_color = trail_color
	
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED 
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED # Emite su propia luz
	# Flag esencial para que Godot pinte cada polígono basándose en los colores individuales de sus vértices
	_trail_material.vertex_color_use_as_albedo = true
	
	_trail_instance.material_override = _trail_material
	
	# Añadimos al árbol directamente
	add_child(_trail_instance)

func _on_body_entered(body):
	if not monitoring: return
	if body in hit_history: return
	if body == attacker_node: return 
	# Evitar fuego amigo entre enemigos (NPCs con grupo "Enemy")
	if attacker_node and attacker_node.is_in_group("Enemy") and body.is_in_group("Enemy"): return
	
	# Evitar fuego amigo extra (Jugador golpeándose a sí mismo o a aliados)
	if attacker_node and attacker_node.is_in_group("Player") and body.is_in_group("Player"): return

	var hit_connected = false

	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_connected = true
	elif body.has_node("HealthComponent"):
		body.get_node("HealthComponent").take_damage(damage)
		hit_connected = true
	
	if hit_connected:
		hit_history.append(body)
		
		if body.has_method("apply_knockback"):
			# --- AQUÍ ESTÁ LA MAGIA DEL CÓDIGO ANTIGUO ---
			var origin = global_position
			if attacker_node: origin = attacker_node.global_position
			
			var dir = (body.global_position - origin).normalized()
			
			# ⚡ RESTAURADO: El ángulo hacia arriba que da la sensación de impacto
			dir.y = 0.2 
			
			# Nota: No normalizamos de nuevo para conservar ese extra de fuerza vectorial
			body.apply_knockback(dir, knockback, jump)

func _on_area_entered(area):
	if not monitoring: return
	if area in hit_history: return
	if area == attacker_node: return
	
	# Buscar recursivamente al dueño real (CharacterBody3D, Enemy, Player)
	var entity = area
	while entity != null and entity != get_tree().root:
		if entity.is_in_group("Enemy") or entity.is_in_group("Player"):
			break
		entity = entity.get_parent()
		
	if entity == attacker_node: return # No golpearse a sí mismo
	
	# Evitar fuego amigo entre enemigos/jugadores usando la entidad real
	if attacker_node and entity:
		if attacker_node.is_in_group("Enemy") and entity.is_in_group("Enemy"): return
		if attacker_node.is_in_group("Player") and entity.is_in_group("Player"): return

	# Si es un Hurtbox, usar su método hit()
	if area is Hurtbox or area.has_method("hit"):
		print("⚔️ HITBOX impactó Hurtbox de: ", entity.name if entity else area.name)
		
		var origin = global_position
		if attacker_node: origin = attacker_node.global_position
		
		var target_pos = area.global_position
		if area.owner: target_pos = area.owner.global_position
		
		var dir = (target_pos - origin).normalized()
		dir.y = 0.2
		
		area.hit(damage, dir, knockback, jump)
		hit_history.append(area)
