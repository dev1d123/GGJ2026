extends Area3D
class_name WeaponHitbox

var damage: float = 0.0
var knockback: float = 0.0
var jump: float = 0.0
var attacker_node: Node = null 
var hit_history: Array[Node] = [] 

func _ready():
	monitoring = false
	monitorable = false
	# Usamos body_entered para detectar CharacterBody3D (Player/Enemigo)
	body_entered.connect(_on_body_entered)
	# También detectamos areas como Hurtbox
	area_entered.connect(_on_area_entered)

func activate(dmg: float, kb: float, jmp: float, attacker: Node):
	hit_history.clear()
	damage = dmg
	knockback = kb
	jump = jmp
	attacker_node = attacker 
	monitoring = true
	
	# Revisión instantánea de bodies y areas
	for body in get_overlapping_bodies():
		_on_body_entered(body)
	for area in get_overlapping_areas():
		_on_area_entered(area)

func deactivate():
	monitoring = false
	attacker_node = null

func _on_body_entered(body):
	if not monitoring: return
	if body in hit_history: return
	if body == attacker_node: return 
	
	# Evitar fuego amigo entre enemigos (opcional)
	# if attacker_node and attacker_node.is_in_group("Enemy") and body.is_in_group("Enemy"): return

	print("⚔️ HITBOX impactó a: ", body.name)

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
	
	# Si es un Hurtbox, usar su método hit()
	if area is Hurtbox or area.has_method("hit"):
		print("⚔️ HITBOX impactó Hurtbox de: ", area.owner.name if area.owner else area.name)
		
		var origin = global_position
		if attacker_node: origin = attacker_node.global_position
		
		var target_pos = area.global_position
		if area.owner: target_pos = area.owner.global_position
		
		var dir = (target_pos - origin).normalized()
		dir.y = 0.2
		
		area.hit(damage, dir, knockback, jump)
		hit_history.append(area)
