extends Resource
class_name MaskData

@export_category("Identidad")
@export var mask_name: String = "Máscara Nueva"
@export var icon: Texture2D
@export_multiline var description: String = ""
## Aquí va la escena .tscn del modelo 3D de la máscara
@export var mask_visual_scene: PackedScene 

@export_category("Visuales de Pantalla")
@export var screen_tint: Color = Color(1, 1, 1, 0.1)     # Tinte suave pasivo
@export var ult_screen_tint: Color = Color(1, 0, 0, 0.3) # Tinte intenso en Ulti

# ----------------------------------------------------------------
# STATS BASE (PASIVOS)
# ----------------------------------------------------------------
@export_category("Stats Base (Pasivos)")
@export var speed_mult: float = 1.0
@export var jump_mult: float = 1.0
@export var defense_mult: float = 1.0
# --- FALTABAN ESTOS ---
@export var damage_mult: float = 1.0
@export var attack_speed_mult: float = 1.0
@export var crit_chance: float = 0.0      # 0.1 = 10%
# ----------------------
@export var stamina_cost_mult: float = 1.0
@export var stamina_regen_mult: float = 1.0
@export var stamina_delay_mult: float = 1.0

# ----------------------------------------------------------------
# STATS ULTIMATE (ACTIVOS)
# ----------------------------------------------------------------
@export_category("Ultimate (Activa)")
@export var ultimate_duration: float = 10.0

@export var ult_speed_mult: float = 1.2
@export var ult_jump_mult: float = 1.2
@export var ult_defense_mult: float = 1.5
# --- FALTABAN ESTOS ---
@export var ult_damage_mult: float = 1.5
@export var ult_attack_speed_mult: float = 1.2
@export var ult_crit_chance: float = 0.2  # 20% Crítico en Ulti
# ----------------------
@export var ult_stamina_cost_mult: float = 0.5
@export var ult_stamina_regen_mult: float = 2.0
@export var ult_stamina_delay_mult: float = 0.5

@export_category("Otros")
## Daño crítico (Generalmente 1.5x o 2.0x)
@export var crit_damage: float = 2.0
