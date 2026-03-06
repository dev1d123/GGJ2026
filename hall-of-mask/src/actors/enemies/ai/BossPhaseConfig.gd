extends Resource
class_name BossPhaseConfig

## Define una fase del jefe. Cuando su HP baja al % indicado, se activa esta fase.
## Arrastrar al array `phases` del Boss.gd. Ordenar de mayor a menor health_percent.

@export_category("Activación")
## Se activa cuando HP <= este porcentaje (1.0 = 100%, 0.5 = 50%)
@export_range(0.0, 1.0) var health_percent_trigger: float = 1.0
@export var phase_name: String = "Fase 1"

@export_category("Modificadores de Velocidad")
## Multiplicador de velocidad de movimiento en esta fase
@export var speed_multiplier: float = 1.0
## Velocidad de las animaciones (0.6 = lento, 1.0 = normal, 1.5 = rápido)
@export var anim_speed_scale: float = 0.6
## Multiplicador de cooldown entre ataques (0.5 = la mitad de espera)
@export var cooldown_multiplier: float = 1.0

@export_category("Acciones de Fase")
## Si true, equipa la máscara al entrar en esta fase
@export var equip_mask: bool = false
## Si true, activa la ultimate al entrar en esta fase
@export var activate_ult: bool = false

@export_category("Sprint")
## Si true, puede hacer sprint/carga en esta fase
@export var sprint_enabled: bool = false
## Intervalo de tiempo entre sprints (si sprint_enabled)
@export var sprint_interval_min: float = 5.0
@export var sprint_interval_max: float = 15.0
## Si true, sprint es constante (no usa timer, siempre corre)
@export var sprint_permanent: bool = false

@export_category("Zigzag")
## Si true, hace zigzag al perseguir (difícil de disparar)
@export var zigzag_enabled: bool = false
@export var zigzag_speed: float = 5.0
