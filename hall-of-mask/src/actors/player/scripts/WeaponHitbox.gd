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

func activate(dmg: float, kb: float, jmp: float, attacker: Node):
	hit_history.clear()
	damage = dmg
	knockback = kb
	jump = jmp
	attacker_node = attacker 
	monitoring = true
	
	# Revisión instantánea
	for body in get_overlapping_bodies():
		_on_body_entered(body)

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
