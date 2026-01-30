extends VBoxContainer 

# Referencias a los LABELS
@onready var label_pocion_1 = $Potions/Slot1/CountLabel
@onready var label_pocion_2 = $Potions/Slot2/CountLabel
@onready var label_pocion_3 = $Potions/Slot3/CountLabel

@onready var slot_visual_1 = $Potions/Slot1
@onready var slot_visual_2 = $Potions/Slot2
@onready var slot_visual_3 = $Potions/Slot3

@onready var label_flechas = $Ammo/IconoFlecha/ArrowLabel
@onready var label_balas = $Ammo/IconoBala/BulletLabel

func update_potion_count(slot_num: int, cantidad: int):
	var label = null
	var slot = null
	
	match slot_num:
		1: 
			label = label_pocion_1
			slot = slot_visual_1
		2: 
			label = label_pocion_2
			slot = slot_visual_2
		3: 
			label = label_pocion_3
			slot = slot_visual_3
			
	if label:
		label.text = str(cantidad)
		label.modulate = Color(1, 0.3, 0.3) if cantidad == 0 else Color.WHITE
		if slot: 
			slot.modulate.a = 0.5 if cantidad == 0 else 1.0

func update_ammo(tipo: String, cantidad: int):
	if tipo == "FLECHAS" and label_flechas:
		label_flechas.text = str(cantidad)
		label_flechas.modulate = Color.RED if cantidad == 0 else Color.WHITE
	elif tipo == "BALAS" and label_balas:
		label_balas.text = str(cantidad)
		label_balas.modulate = Color.RED if cantidad == 0 else Color.WHITE

func animar_slot(slot_num: int):
	var slot = null
	match slot_num:
		1: slot = slot_visual_1
		2: slot = slot_visual_2
		3: slot = slot_visual_3
	
	if slot:
		var tween = create_tween()
		tween.tween_property(slot, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1)
