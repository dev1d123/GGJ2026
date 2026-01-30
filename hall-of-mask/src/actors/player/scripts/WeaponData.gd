extends Resource
class_name WeaponData

@export_category("Identidad")
@export var name: String = "Arma"
@export var weapon_scene: PackedScene 
@export var icon: Texture2D

@export_category("Animación")
@export var anim_attack: String = "Attack"
@export var anim_idle: String = "Idle"

@export_category("Tiempos (Sincronización)")
## Tiempo de mezclado inicial (XFade).
@export var blend_time: float = 0.1

## 1. PRE-GOLPE: Tiempo exacto en la animación donde conecta el golpe.
@export var windup_time: float = 0.3    

## 2. GOLPE: Tiempo que el daño se mantiene activo.
@export var active_time: float = 0.1    

## 3. TOTAL: Duración completa de la animación.
## El ataque termina cuando se cumple este tiempo.
@export var total_animation_time: float = 1.0  

## Tiempo extra antes de poder volver a pulsar el botón.
@export var cooldown: float = 0.2

@export_category("Reglas")
@export var stop_movement: bool = false 
@export var is_two_handed: bool = false
@export var can_use_prone: bool = false

@export_category("Estadísticas")
@export var damage: float = 10.0 
@export var knockback_force: float = 8.0
@export var jump_force: float = 3.0
@export var stamina_cost: float = 15.0
