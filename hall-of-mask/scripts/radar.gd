extends Control

@onready var player_blip = $PlayerBlip
# Radio del radar en pixeles, mitad
var radar_radius = 100.0 

# Lista falsa de enemigos (Posiciones relativas a ti)
var fake_enemies = []

func _ready():
	# Centrar al jugador visualmente
	player_blip.position = size / 2 - (player_blip.size / 2)
	
	# Crear 3 enemigos falsos en posiciones aleatorias
	for i in range(3):
		fake_enemies.append(Vector2(randf_range(-100, 100), randf_range(-100, 100)))

func _process(delta):
	# --- DIBUJAR PUNTOS ROJOS ---
	queue_redraw() # Esto llama a la función _draw()
	
	# --- SIMULACIÓN: MOVER ENEMIGOS ---
	# Hacemos que los puntos giren o se acerquen para ver que funciona
	for i in range(fake_enemies.size()):
		# Rotar un poco la posición para que parezca que se mueven
		fake_enemies[i] = fake_enemies[i].rotated(delta * 0.5)

func _draw():
	# Esta función de Godot dibuja formas geométricas simples
	var center = size / 2
	
	for enemy_pos in fake_enemies:
		# 1. Calcular distancia en el radar
		# Si el enemigo está muy lejos, lo limitamos al borde (clamping)
		var dist = enemy_pos.length()
		var draw_pos = enemy_pos
		
		# Escala: 1 metro en el juego = 1 pixel en el radar (ajustable)
		if dist > radar_radius:
			draw_pos = draw_pos.normalized() * radar_radius
		
		# 2. Dibujar punto rojo
		# draw_circle(posición, radio, color)
		draw_circle(center + draw_pos, 4.0, Color.RED)
