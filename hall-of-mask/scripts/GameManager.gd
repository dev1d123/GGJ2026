extends Node

# Sistema de niveles completados
var levels_completed: Dictionary = {
	"level1": false,
	"level2": false,
	"level3": false,
	"level4": false
}

# Sistema de máscaras desbloqueadas
var masks_unlocked: Dictionary = {
	"fighter": false,   # Level 1
	"shooter": false,   # Level 2
	"undead": false,    # Level 3
	"time": false       # Level 4
}

# Mapeo de niveles a máscaras
var level_to_mask: Dictionary = {
	"level1": "fighter",
	"level2": "shooter",
	"level3": "undead",
	"level4": "time"
}

signal level_completed(level_name: String)
signal all_levels_completed
signal mask_unlocked(mask_name: String)

var all_levels_signal_emitted: bool = false

func _ready() -> void:
	pass

func complete_level(level_name: String):
	if level_name in levels_completed:
		var was_completed_before = levels_completed[level_name]
		
		if not was_completed_before:
			levels_completed[level_name] = true
			print("✅ Nivel completado: ", level_name)
			level_completed.emit(level_name)
			
			# Desbloquear máscara asociada al nivel (SOLO LA PRIMERA VEZ)
			if level_name in level_to_mask:
				var mask_name = level_to_mask[level_name]
				unlock_mask(mask_name)
			
			_check_all_levels_completed()
		else:
			print("⚠️ Nivel ya estaba completado: ", level_name)

func _check_all_levels_completed():
	var all_complete = true
	for level in levels_completed.values():
		if not level:
			all_complete = false
			break
	
	if all_complete and not all_levels_signal_emitted:
		all_levels_signal_emitted = true
		print("🎉 ¡TODOS LOS NIVELES COMPLETADOS!")
		all_levels_completed.emit()

func get_completed_count() -> int:
	var count = 0
	for completed in levels_completed.values():
		if completed:
			count += 1
	return count

func is_level_completed(level_name: String) -> bool:
	if level_name in levels_completed:
		return levels_completed[level_name]
	return false

func reset_progress():
	for key in levels_completed.keys():
		levels_completed[key] = false
	for key in masks_unlocked.keys():
		masks_unlocked[key] = false
	print("🔄 Progreso reiniciado")

func unlock_mask(mask_name: String):
	if mask_name in masks_unlocked:
		if not masks_unlocked[mask_name]:
			masks_unlocked[mask_name] = true
			print("🎭 ¡Máscara desbloqueada: ", mask_name.to_upper(), "!")
			mask_unlocked.emit(mask_name)
		else:
			print("⚠️ Máscara ya estaba desbloqueada: ", mask_name)

func is_mask_unlocked(mask_name: String) -> bool:
	if mask_name in masks_unlocked:
		return masks_unlocked[mask_name]
	return false

func get_unlocked_masks() -> Array:
	var unlocked = []
	for mask_name in masks_unlocked.keys():
		if masks_unlocked[mask_name]:
			unlocked.append(mask_name)
	return unlocked

func _process(delta: float) -> void:
	pass
