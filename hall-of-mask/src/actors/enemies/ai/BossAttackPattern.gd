extends Resource
class_name BossAttackPattern

## Define un ataque específico del jefe. Se arrastra al array `attack_patterns`
## del Boss.gd. Cada ataque tiene su propia animación, tiempos y daño.

@export_category("Identidad")
@export var attack_name: String = "Attack_1"

@export_category("Animación")
## Nombre EXACTO del estado en el AnimationTree (ej: "Orc_Axe_2H_Attack_1")
@export var anim_name: String = "Attack_1"

@export_category("Tiempos de Sincronización")
## Tiempo antes de que conecte el golpe (preparación)
@export var windup: float = 0.6
## Duración del hitbox activo
@export var active_time: float = 0.2

@export_category("Daño")
## Multiplicador de daño base del arma
@export var damage_multiplier: float = 1.0
## Fuerza de empuje al golpear
@export var knockback_force: float = 6.0

@export_category("Selección IA")
## Peso relativo para la selección aleatoria (mayor = más frecuente)
@export var weight: float = 1.0
## Rango mínimo para usar este ataque (ej: 0 para melee, 5 para ranged)
@export var min_range: float = 0.0
## Rango máximo para usar este ataque
@export var max_range: float = 5.0
