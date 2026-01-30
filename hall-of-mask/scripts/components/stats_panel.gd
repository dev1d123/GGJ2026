extends HBoxContainer

@onready var life_container = $BarsContainer/LifeContainer
@onready var mana_bar = $BarsContainer/ManaBar
@onready var stamina_bar = $BarsContainer/StaminaBar
@onready var ulti_bar = $BarsContainer/UltiBar
@onready var mask_icon = $MaskIcon

var heart_texture = preload("res://icon.svg") 

func update_health(cantidad: int):
	# Limpiar
	for child in life_container.get_children():
		child.queue_free()
	
	# --- CORRECCIÓN MATEMÁTICA ---
	# Dividimos entre 10 para que 100 de vida sean 10 corazones.
	# Usamos ceil() para que si tienes 1 de vida, al menos muestre 1 corazón.
	var corazones_a_dibujar = ceil(cantidad / 10.0) 
	
	# Llenar
	for i in range(corazones_a_dibujar):
		var icon = TextureRect.new()
		icon.texture = heart_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(24, 24)
		icon.modulate = Color.RED 
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
	var morado_normal = Color("9b59b6") # O el código hex de tu fuxia preferido
	var morado_brillante = Color(1.5, 1.0, 2.0) # Un tono muy brillante (Glow)
	
	if val >= max_val:
		# ¡ULTI LISTA! (Brilla)
		ulti_bar.tint_progress = morado_brillante 
	else:
		# CARGANDO... (Color normal)
		# AQUÍ ESTABA EL ERROR: Antes decía Color(1, 1, 1)
		ulti_bar.tint_progress = morado_normal
