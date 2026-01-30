extends Area3D
class_name WeaponHitbox

var damage: float = 0.0
var knockback: float = 0.0
var jump: float = 0.0
var attacker_node: Node = null # REFERENCIA AL DUEÑO DEL ARMA
var hit_history: Array[Node] = [] 

func _ready():
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

# Ahora recibimos "attacker" para saber a quién NO golpear
func activate(dmg: float, kb: float, jmp: float, attacker: Node):
	hit_history.clear()
	damage = dmg
	knockback = kb
	jump = jmp
	attacker_node = attacker # Guardamos quién está atacando
	monitoring = true
	
	# Revisión instantánea
	for area in get_overlapping_areas():
		_on_area_entered(area)

func deactivate():
	monitoring = false
	attacker_node = null

func _on_area_entered(area):
	if not monitoring: return
	if area in hit_history: return
	
	# --- FIX SUICIDIO ---
	# Si el área golpeada pertenece al mismo nodo que ataca, IGNORAR.
	# Esto evita que el esqueleto se pegue a su propia Hurtbox.
	if attacker_node and area.owner == attacker_node: 
		return 

	if area.has_method("hit"):
		hit_history.append(area)
		
		# Dirección del empuje: Desde el atacante hacia la víctima
		var origin = global_position
		if attacker_node: origin = attacker_node.global_position
		
		var dir = (area.global_position - origin).normalized()
		dir.y = 0.2 
		
		area.hit(damage, dir, knockback, jump)
		print("🩸 Golpe conectado a: ", area.owner.name)
