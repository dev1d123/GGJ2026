extends PanelContainer

# Señal para notificar al HUD que se equipó una máscara
signal mask_equipped(mask_name: String)

# Referencias a los TextureButton de cada máscara
@onready var fighter_button: TextureButton = $VBoxContainer/FighterSlot
@onready var shooter_button: TextureButton = $VBoxContainer/ShooterSlot
@onready var undead_button: TextureButton = $VBoxContainer/UndeadSlot
@onready var time_button: TextureButton = $VBoxContainer/TimeSlot

# Iconos de las máscaras
var mask_icons: Dictionary = {}

# Estado actual
var currently_equipped: String = ""

func _ready():
	# Cargar iconos
	mask_icons["fighter"] = load("res://assets/imagesGUI/fighter_mask.png")
	mask_icons["shooter"] = load("res://assets/imagesGUI/shooter_mask.png")
	mask_icons["undead"] = load("res://assets/imagesGUI/undead_mask.png")
	mask_icons["time"] = load("res://assets/imagesGUI/time_mask.png")
	
	# Configurar botones
	_setup_buttons()
	
	# Conectar con GameManager
	if GameManager:
		GameManager.mask_unlocked.connect(_on_mask_unlocked)
		# Inicializar estado desde GameManager
		_refresh_all_masks()

func _setup_buttons():
	# Conectar señales pressed de cada botón
	fighter_button.pressed.connect(func(): _on_mask_button_pressed("fighter"))
	shooter_button.pressed.connect(func(): _on_mask_button_pressed("shooter"))
	undead_button.pressed.connect(func(): _on_mask_button_pressed("undead"))
	time_button.pressed.connect(func(): _on_mask_button_pressed("time"))
	
	# Configurar iconos normales
	fighter_button.texture_normal = mask_icons["fighter"]
	shooter_button.texture_normal = mask_icons["shooter"]
	undead_button.texture_normal = mask_icons["undead"]
	time_button.texture_normal = mask_icons["time"]
	
	# Inicialmente todas bloqueadas (gris oscuro)
	fighter_button.modulate = Color(0.3, 0.3, 0.3, 0.5)
	shooter_button.modulate = Color(0.3, 0.3, 0.3, 0.5)
	undead_button.modulate = Color(0.3, 0.3, 0.3, 0.5)
	time_button.modulate = Color(0.3, 0.3, 0.3, 0.5)
	
	# Deshabilitar interacción
	fighter_button.disabled = true
	shooter_button.disabled = true
	undead_button.disabled = true
	time_button.disabled = true

func _refresh_all_masks():
	# Actualizar estado de todas las máscaras desde GameManager
	if GameManager.is_mask_unlocked("fighter"):
		_unlock_mask_visual("fighter")
	if GameManager.is_mask_unlocked("shooter"):
		_unlock_mask_visual("shooter")
	if GameManager.is_mask_unlocked("undead"):
		_unlock_mask_visual("undead")
	if GameManager.is_mask_unlocked("time"):
		_unlock_mask_visual("time")

func _on_mask_unlocked(mask_name: String):
	_unlock_mask_visual(mask_name)
	
	# Efecto visual de desbloqueo (brillo)
	var button = _get_button_for_mask(mask_name)
	if button:
		var tween = create_tween()
		tween.tween_property(button, "modulate", Color(2, 2, 2, 1), 0.3)
		tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.3)

func _unlock_mask_visual(mask_name: String):
	var button = _get_button_for_mask(mask_name)
	if button:
		button.modulate = Color(1, 1, 1, 1)
		button.disabled = false

func _on_mask_button_pressed(mask_name: String):
	# Solo permitir si está desbloqueada
	if not GameManager.is_mask_unlocked(mask_name):
		return
	
	_highlight_mask(mask_name)
	mask_equipped.emit(mask_name)
	print("🎭 Máscara equipada desde UI: ", mask_name)

func _highlight_mask(mask_name: String):
	# Resetear borde de la anterior
	if currently_equipped != "":
		var prev_button = _get_button_for_mask(currently_equipped)
		if prev_button:
			prev_button.modulate = Color(1, 1, 1, 1)
	
	# Resaltar la nueva
	var button = _get_button_for_mask(mask_name)
	if button:
		button.modulate = Color(1.5, 1.5, 0.5, 1) # Dorado
	
	currently_equipped = mask_name

# Método público para sincronizar desde el menú radial
func sync_equipped_mask(mask_name: String):
	# Si mask_name es vacío, quitar resaltado
	if mask_name == "":
		if currently_equipped != "":
			var prev_button = _get_button_for_mask(currently_equipped)
			if prev_button:
				prev_button.modulate = Color(1, 1, 1, 1)
		currently_equipped = ""
	else:
		_highlight_mask(mask_name)

func _get_button_for_mask(mask_name: String) -> TextureButton:
	match mask_name:
		"fighter": return fighter_button
		"shooter": return shooter_button
		"undead": return undead_button
		"time": return time_button
	return null
