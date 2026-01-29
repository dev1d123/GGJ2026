extends Resource
class_name ItemData

# Esto define qué tiene CUALQUIER objeto del juego
@export var id: String = ""
@export var nombre: String = "Item Nuevo"
@export_multiline var descripcion: String = "Descripción aquí"
@export var icono: Texture2D
@export var color_ui: Color = Color.WHITE # Para UI tintada

# Aquí  cosas específicas en el futuro:
# @export var daño: int = 10
# @export var costo_mana: int = 5
