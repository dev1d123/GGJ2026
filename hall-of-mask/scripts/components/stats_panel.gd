extends HBoxContainer

@onready var life_container = $BarsContainer/LifeContainer
@onready var mana_bar = $BarsContainer/ManaBar
@onready var stamina_bar = $BarsContainer/StaminaBar
@onready var ulti_bar = $BarsContainer/UltiBar
@onready var mask_icon = $MaskIcon

# --- CONFIGURACIÓN DE ICONOS ---
var default_texture = preload("res://icon.svg") # El Godot original
var current_texture = default_texture           # La textura que usaremos ahora
var current_color = Color.RED                   # El color actual (Rojo para default)

# --- FUNCIÓN NUEVA PARA CAMBIAR ICONOS (Llamada desde HUD) ---
func update_life_icons_texture(new_icon: Texture2D):
	# 1. Decidir qué textura y color usar
	if new_icon == null:
		# Si no hay máscara, volvemos al Godot Rojo
		current_texture = default_texture
		current_color = Color.RED 
	else:
		# Si hay máscara, usamos su icono en color original (Blanco)
		current_texture = new_icon
		current_color = Color.WHITE 
	
	# 2. Actualizar INMEDIATAMENTE los iconos que ya están en pantalla
	for child in life_container.get_children():
		if child is TextureRect:
			child.texture = current_texture
			child.modulate = current_color

# --- ACTUALIZACIÓN DE SALUD ---
func update_health(cantidad: int):
	# Limpiar
	for child in life_container.get_children():
		child.queue_free()
	
	# Cálculo de corazones
	var corazones_a_dibujar = ceil(cantidad / 10.0) 
	
	# Llenar
	for i in range(corazones_a_dibujar):
		var icon = TextureRect.new()
		# ¡AQUÍ USAMOS LAS VARIABLES DINÁMICAS!
		icon.texture = current_texture 
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = current_color # Rojo si es Godot, Blanco si es Máscara
		life_container.add_child(icon)

func update_mana(val, max_val):
	mana_bar.max_value = max_val
	mana_bar.value = val

func update_stamina(val, max_val):
	stamina_bar.max_value = max_val
	stamina_bar.value = val

func update_ulti(val, max_val):
	ulti_bar.max_value = max_val
	ulti_bar.value = val
	
	# Definimos tus colores aquí para que no se pierdan
	var morado_normal = Color("9b59b6") 
	var morado_brillante = Color(1.5, 1.0, 2.0) # Glow
	
	if val >= max_val:
		# ¡ULTI LISTA! (Brilla)
		ulti_bar.tint_progress = morado_brillante 
	else:
		# CARGANDO... (Color normal)
		ulti_bar.tint_progress = morado_normal
