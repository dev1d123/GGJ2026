extends Control

# Referencias internas (Hijos del SkillsPanel)
@onready var skill_q_bar = $SkillQ
@onready var skill_r_bar = $SkillR

func _ready():
	# Configuración inicial de rangos
	skill_q_bar.max_value = 100
	skill_q_bar.value = 100 # Q empieza lista
	
	skill_r_bar.max_value = 100
	skill_r_bar.value = 0 # R empieza vacía

# --- HABILIDAD Q (Cooldown) ---

func start_q_cooldown(tiempo_segundos: float = 2.0):
	# Si ya está en cooldown (valor bajo), tal vez no se quiera reiniciar, 
	# pero por ahora se fuerza el reinicio para probar.
	skill_q_bar.value = 0
	skill_q_bar.modulate = Color(0.5, 0.5, 0.5) # Un poco oscuro mientras carga
	
	var tween = create_tween()
	# Llenar la barra desde 0 hasta el máximo en X segundos
	tween.tween_property(skill_q_bar, "value", skill_q_bar.max_value, tiempo_segundos)
	
	# Cuando termine, ponerla brillante otra vez
	tween.finished.connect(func(): skill_q_bar.modulate = Color(1, 1, 1))

# --- HABILIDAD R (Ultimate) ---

func update_ulti_charge(val, max_val):
	skill_r_bar.max_value = max_val
	skill_r_bar.value = val
	
	# Feedback visual: Si está llena, brillar intensamente
	if val >= max_val:
		skill_r_bar.modulate = Color(2, 1, 2) # Verde/Morado neón brillante
	else:
		skill_r_bar.modulate = Color(1, 1, 1) # Color normal
