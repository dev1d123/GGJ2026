extends WeaponData
class_name RangedWeaponData

enum FireMode {
	INSTANT,        ## Varita, Pistola (Click = Disparo inmediato)
	AUTO,           ## Ametralladora (Mantener = Disparo continuo)
	CHARGE_RELEASE  ## Arco (Mantener para cargar -> Soltar para disparar)
}

enum ReticleStyle {
	NONE,       # Sin mira
	CIRCLE,     # Pistolas, Magia, Bastones (Muestra el Bloom)
	CROSSHAIR,  # Francotirador, Arcos (Cruz o Rayas)
	DOT         # Punto simple
}

@export_category("Configuración a Distancia")
## Define cómo se comporta el gatillo.
@export var fire_mode: FireMode = FireMode.INSTANT

## La escena (.tscn) de la bala o magia que vas a instanciar.
@export var projectile_scene: PackedScene

## Velocidad de viaje del proyectil (20.0 = Magia lenta, 80.0 = Bala rápida).
@export var launch_speed: float = 20.0

## Imprecisión del disparo en grados (0.0 = Precisión perfecta).
@export var spread_degrees: float = 0.0

## Cantidad de proyectiles por disparo (1 = Normal, 3 = Escopeta/Tridente).
@export var projectile_count: int = 1

## Si es TRUE, el proyectil cae con el tiempo (Flechas). Si es FALSE, va recto (Magia).
@export var use_gravity: bool = false

@export var mana_cost: float = 0.0

@export_category("Modo Rayo Continuo (Beam)")
@export var is_beam_weapon: bool = false ## Actívalo para el Báculo de Rayos
@export var beam_tick_rate: float = 0.1  ## Cada cuánto hace daño (0.1 = 10 veces por seg)
@export var mana_cost_per_second: float = 10.0 ## Costo por segundo mantenido
@export var max_beam_duration: float = 6.0 ## Tiempo máximo disparando (6s)
@export var overheat_cooldown: float = 3.0 ## Tiempo de castigo si se quema
@export var overheat_recovery_start: float = 2.0 ## Con cuánto empieza tras el castigo

@export_category("Efectos")
## Escena opcional para el fogonazo en la punta del arma.
@export var muzzle_flash_scene: PackedScene

## Intensidad del temblor de cámara al disparar (0.0 = Nada, 0.5 = Fuerte)
@export var recoil_shake: float = 0.0 
## ¿Tiene esta arma una animación con sufijo "_Aim" en el AnimationTree?
## Ej: "Cast_Aim" para apuntar, "Cast" para disparar.
@export var has_aim_animation: bool = false

@export_category("Interfaz (UI)")
@export var reticle_style: ReticleStyle = ReticleStyle.CIRCLE
@export var reticle_scale: float = 1.0 # Para hacerla más grande/pequeña manualment
