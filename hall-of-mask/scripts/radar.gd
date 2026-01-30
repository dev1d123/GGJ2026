extends Control

@onready var player_blip = $PlayerBlip
@export var radar_radius_pixels = 100.0 # Radio visual en el UI
@export var detection_range = 20.0 # Metros en el mundo 3D que cubre el radar

func _ready():
	# Centrar al jugador visualmente
	if player_blip:
		player_blip.position = size / 2 - (player_blip.size / 2)

func _process(_delta):
	queue_redraw() # Redibujar cada frame (para seguir enemigos en movimiento)

func _draw():
	var player = get_tree().root.find_child("Player", true, false)
	if not player: return
	
	var center = size / 2
	
	# 1. BUSCAR ENEMIGOS REALES (Usando Grupos)
	# Dile a tu compañero que añada sus enemigos al grupo "Enemies"
	var enemies = get_tree().get_nodes_in_group("Enemies")
	
	for enemy in enemies:
		# 2. Calcular posición relativa (Matemática de vectores)
		# Restamos posición enemigo - posición jugador para saber dónde está respecto a nosotros
		var relative_pos_3d = enemy.global_position - player.global_position
		
		# Convertimos 3D (X, Z) a 2D del radar (X, Y)
		# Nota: En 3D "Adelante" suele ser -Z. En 2D UI "Arriba" es -Y.
		# Rotamos el vector según la rotación del jugador para que el radar gire contigo
		var rotated_pos = Vector2(relative_pos_3d.x, relative_pos_3d.z).rotated(-player.rotation.y)
		
		# 3. Escalar al tamaño del radar UI
		# Si detection_range es 20m y radar_radius es 100px -> 1m = 5px
		var scale_factor = radar_radius_pixels / detection_range
		var draw_pos = rotated_pos * scale_factor
		
		# 4. Limitar al borde (Clamping) si está muy lejos
		if draw_pos.length() > radar_radius_pixels:
			# Opcional: Si quieres que no se vean los lejanos, usa 'continue'
			# draw_pos = draw_pos.normalized() * radar_radius_pixels
			continue 
			
		# 5. Dibujar punto rojo
		draw_circle(center + draw_pos, 3.0, Color.RED)
