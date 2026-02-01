extends Control
class_name ReticleUI

# Variables que recibirán datos del CombatManager
var current_spread_angle: float = 0.0
var current_style: int = 0
var line_color: Color = Color.WHITE
var dot_color: Color = Color.RED

# Referencia a la cámara para calcular la proyección exacta
@onready var camera: Camera3D = get_viewport().get_camera_3d()

func _process(_delta):
	# Redibujamos cada frame para que la animación sea fluida (60 FPS)
	queue_redraw()

func update_reticle_state(spread_deg: float, style: int):
	current_spread_angle = spread_deg
	current_style = style
	
	# Si cambia la cámara (ej: al morir y respawnear), la buscamos de nuevo
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()

func _draw():
	if current_style == 0: return # NONE
	
	var center = Vector2.ZERO # Como el nodo está centrado, dibujamos en 0,0
	
	# 1. CÁLCULO MATEMÁTICO PRECISO 📐
	# Convertimos el ángulo de dispersión (grados) a píxeles en pantalla.
	# Radio = tan(angulo) * (altura_pantalla / 2) / tan(fov / 2)
	var radius = 2.0 # Mínimo visible
	
	if is_instance_valid(camera):
		var viewport_height = get_viewport_rect().size.y
		var fov = camera.fov
		
		# Usamos deg_to_rad porque tan() usa radianes
		var spread_rad = deg_to_rad(current_spread_angle)
		var fov_rad = deg_to_rad(fov)
		
		# Fórmula mágica de proyección
		radius = tan(spread_rad) * (viewport_height / 2.0) / tan(fov_rad / 2.0)
		
		# Asegurar un tamaño mínimo para que no desaparezca
		radius = max(radius, 4.0)

	# 2. DIBUJAR SEGÚN ESTILO 🎨
	match current_style:
		1: # CIRCLE (Magia, Escopeta)
			# draw_arc(centro, radio, angulo_inicio, angulo_fin, segmentos, color, grosor)
			draw_arc(center, radius, 0, TAU, 32, line_color, 2.0)
			# Un puntito en el centro siempre ayuda
			draw_circle(center, 1.0, dot_color)
			
		2: # CROSSHAIR (Arco / Franco)
			# Dibujamos 4 líneas con separación (gap) basada en el spread
			var gap = radius # Las líneas se alejan si el bloom crece
			var length = 10.0
			
			# Izquierda
			draw_line(center + Vector2(-gap - length, 0), center + Vector2(-gap, 0), line_color, 2.0)
			# Derecha
			draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), line_color, 2.0)
			# Arriba
			draw_line(center + Vector2(0, -gap - length), center + Vector2(0, -gap), line_color, 2.0)
			# Abajo
			draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), line_color, 2.0)
			
		3: # DOT (Simple)
			draw_circle(center, 3.0, dot_color)
