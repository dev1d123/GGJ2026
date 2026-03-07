extends Resource
class_name AIBehaviorConfig

## Recurso que define la "personalidad" y capacidades de un enemigo.
## Se arrastra al export `ai_config` de Enemy.gd para configurar sin código.

# ------------------------------------------------------------------------------
# ESTILO DE COMBATE
# ------------------------------------------------------------------------------
enum CombatStyle {
	AGGRESSIVE,  ## Corre hacia ti y ataca sin parar
	DEFENSIVE,   ## Espera, bloquea, contraataca
	KITER,       ## Mantiene distancia, huye si te acercas
	FLANKER,     ## Intenta rodearte, ataca por los lados
	TANK         ## Lento, se planta, no retrocede
}

@export_category("Estilo de Combate")
@export var combat_style: CombatStyle = CombatStyle.AGGRESSIVE

## 0.5 = pasivo (ataca poco), 1.0 = normal, 2.0 = frenético
@export_range(0.1, 3.0) var aggression: float = 1.0

## 0.0 = cobarde (huye fácil), 1.0 = normal, 2.0 = nunca retrocede
@export_range(0.0, 2.0) var courage: float = 1.0

# ------------------------------------------------------------------------------
# DETECCIÓN Y AGGRO
# ------------------------------------------------------------------------------
@export_category("Detección y Aggro")

## Distancia máxima para detectar al jugador
@export var vision_range: float = 20.0

## Distancia a la que pierde interés y regresa a patrullar
@export var lose_aggro_range: float = 30.0

## Segundos sin ver al jugador para perder aggro (-1 = nunca pierde)
@export var lose_aggro_time: float = 5.0

## Si true, usa el RayCast Eyes para verificar línea de visión
@export var require_line_of_sight: bool = true

# ------------------------------------------------------------------------------
# RANGOS
# ------------------------------------------------------------------------------
@export_category("Rangos de Combate")

## -1.0 = auto-detectar del arma equipada. Cualquier otro valor lo sobreescribe.
@export var preferred_range_override: float = -1.0

## Distancia mínima aceptable (para ranged: no quiere estar más cerca que esto)
@export var min_comfort_range: float = 0.0

# ------------------------------------------------------------------------------
# CAPACIDADES
# ------------------------------------------------------------------------------
@export_category("Capacidades")

## Puede saltar para esquivar o alcanzar plataformas
@export var can_jump: bool = false
@export var jump_force: float = 10.0

## Puede hacer dodge lateral al recibir daño ranged
@export var can_dodge: bool = false

## Puede correr (velocidad aumentada)
@export var can_sprint: bool = true
@export var sprint_speed_mult: float = 1.8

# ------------------------------------------------------------------------------
# REACCIONES INTELIGENTES
# ------------------------------------------------------------------------------
@export_category("Reacciones")

## Probabilidad (0-1) de esquivar al recibir un disparo
@export_range(0.0, 1.0) var dodge_chance_vs_ranged: float = 0.0

## Si true, se mueve en zigzag al perseguir (anti-sniper)
@export var zigzag_when_chasing: bool = false
@export var zigzag_frequency: float = 5.0
@export var zigzag_amplitude: float = 2.0

## % de vida al que intenta huir temporalmente (0 = nunca huye)
@export_range(0.0, 1.0) var flee_health_percent: float = 0.0

## Si true y está bajo de vida, busca aliados cercanos para refugiarse
@export var seek_allies_when_low: bool = false

# ------------------------------------------------------------------------------
# MÁSCARA (Sorpresa)
# ------------------------------------------------------------------------------
@export_category("Máscara Táctica")

## % de vida al que se equipa la máscara (0 = no tiene/no equipa)
@export_range(0.0, 1.0) var mask_equip_health_percent: float = 0.0

## Si true, intenta equipar la máscara sorpresivamente al acercarse al jugador
@export var mask_equip_is_surprise: bool = false

# ------------------------------------------------------------------------------
# COOLDOWNS
# ------------------------------------------------------------------------------
@export_category("Tiempos")

## Rango de cooldown entre ataques (se escala con aggression)
@export var attack_cooldown_min: float = 0.5
@export var attack_cooldown_max: float = 1.5

## Cada cuánto re-evalúa qué hacer
@export var decision_interval: float = 0.3

## Duración de la patrulla en un punto antes de buscar otro
@export var patrol_wait_time: float = 4.0

## Radio de patrulla alrededor del punto de spawn
@export var patrol_radius: float = 5.0
