extends Resource
class_name MaskData

@export_category("Identidad")
@export var mask_name: String = "Máscara Nueva"
@export var icon: Texture2D
## Color del filtro de pantalla (Alpha controla la intensidad)
@export var screen_tint: Color = Color(1, 0, 0, 0.1) 

@export_category("Multiplicadores de Stats")
## 1.0 = Normal, 1.2 = +20%, 0.8 = -20%
@export var speed_mult: float = 1.0
@export var jump_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var defense_mult: float = 1.0 

@export_category("Stamina")
## Multiplicador de consumo (0.75 = consume 25% menos)
@export var stamina_cost_mult: float = 1.0 
## Multiplicador de velocidad de regeneración
@export var stamina_regen_mult: float = 1.0
## Multiplicador de delay de regeneración (0.66 = 33% más rápido)
@export var stamina_delay_mult: float = 1.0

@export_category("Habilidades Pasivas")
## Probabilidad de crítico (0.0 a 1.0)
@export var crit_chance: float = 0.0 
## Multiplicador de daño crítico
@export var crit_damage: float = 2.0 

@export_category("Ultimate (Habilidad Activa)")
## Duración del modo Ultimate en segundos
@export var ultimate_duration: float = 20.0
## Stats durante el Ultimate (Sobrescriben los base de la máscara)
@export var ult_speed_mult: float = 1.5
@export var ult_jump_mult: float = 1.5
@export var ult_attack_speed_mult: float = 2.0
@export var ult_defense_mult: float = 2.0
@export var ult_stamina_cost_mult: float = 0.5
@export var ult_stamina_regen_mult: float = 1.5
@export var ult_stamina_delay_mult: float = 0.5
@export var ult_crit_chance: float = 0.10
@export var ult_screen_tint: Color = Color(1, 0, 0, 0.3)
