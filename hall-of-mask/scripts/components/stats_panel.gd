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
	# Llenar
	for i in range(cantidad):
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
	
	if val >= max_val:
		ulti_bar.modulate = Color(1.5, 1.5, 2)
	else:
		ulti_bar.modulate = Color(1, 1, 1)
