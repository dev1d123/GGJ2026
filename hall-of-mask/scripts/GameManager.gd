extends Node

# Sistema de niveles completados
var levels_completed: Dictionary = {
	"level1": false,
	"level2": false,
	"level3": false,
	"level4": false
}

signal level_completed(level_name: String)
signal all_levels_completed

var all_levels_signal_emitted: bool = false

func _ready() -> void:
	pass

func complete_level(level_name: String):
	if level_name in levels_completed:
		if not levels_completed[level_name]:
			levels_completed[level_name] = true
			print("✅ Nivel completado: ", level_name)
			level_completed.emit(level_name)
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
	print("🔄 Progreso reiniciado")

func _process(delta: float) -> void:
	pass
