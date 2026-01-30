extends Resource
class_name WeaponData

@export_category("Identidad")
@export var name: String = "Arma"
@export var weapon_scene: PackedScene 
@export var icon: Texture2D

@export_category("Animación Manual")
@export var anim_attack: String = "Attack"
@export var anim_idle: String = "Idle"

@export_category("Suavizado")
## Tiempo para mezclar la animación antes de empezar el ataque.
## Evita cortes bruscos. (Ej: 0.1 o 0.2 segundos)
@export var blend_time: float = 0.1

@export_category("Tiempos de Ataque")
## Tiempo desde el clic hasta que el golpe conecta (Pre-golpe)
@export var windup_time: float = 0.3    

## Tiempo que el hitbox se queda encendido haciendo daño
## (Esto es independiente del tiempo total)
@export var active_time: float = 0.1    

## DURACIÓN TOTAL de la animación de ataque.
## El jugador no podrá hacer nada hasta que este tiempo termine.
## Debe ser MAYOR que (windup_time + active_time).
@export var total_animation_time: float = 1.0  

## Tiempo de espera EXTRA después de terminar la animación
## antes de poder volver a atacar.
@export var cooldown: float = 0.2

@export_category("Reglas de Movimiento")
## Si es TRUE, el personaje se congela totalmente al atacar.
@export var stop_movement: bool = false 

@export_category("Estadísticas")
## Daño BASE del arma
@export var damage: float = 10.0 
@export var knockback_force: float = 8.0
@export var jump_force: float = 3.0
@export var stamina_cost: float = 15.0

@export_category("Flags")
@export var is_two_handed: bool = false
@export var can_use_prone: bool = false
