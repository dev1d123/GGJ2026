extends Area3D
class_name Hurtbox
@onready var attack_audio: AudioStreamPlayer3D = get_node_or_null("../DamageAudio")
@onready var health_component: HealthComponent = $"../HealthComponent"

func hit(damage_amount: float, dir: Vector3, knockback: float, jump: float):
	# 1. VIDA
	if health_component:
		health_component.take_damage(damage_amount)
	else:
		print("⚠️ Hurtbox sin HealthComponent")

	# 2. SONIDO DE IMPACTO
	if attack_audio:
		if not attack_audio.playing:
			attack_audio.pitch_scale = randf_range(0.95, 1.05)
			attack_audio.play()

	# 3. KNOCKBACK
	if owner and owner.has_method("apply_knockback"):
		owner.apply_knockback(dir, knockback, jump)
