@tool
extends EditorScript

const ENEMY_DIR = "res://src/actors/enemies/"
const BOSS_DIR = "res://src/actors/enemies/bosses/"

func _run():
	print("Starting AI Configuration Setup...")
	
	setup_skeletons()
	setup_bosses()
	
	print("AI Configuration Setup Complete!")
	EditorInterface.get_resource_filesystem().scan()

func setup_skeletons():
	var skeletons = {
		"Skeleton_Warrior.tscn": {
			"combat_style": 0, # MELEE
			"aggression": 1.0,
			"courage": 0.8,
			"flee_health_percent": 0.0,
			"can_sprint": true,
			"can_dodge": false,
			"dodge_chance_vs_ranged": 0.0,
			"zigzag_when_chasing": false,
			"vision_range": 20.0,
			"lose_aggro_time": 5.0
		},
		"Skeleton_Rogue.tscn": {
			"combat_style": 0, # MELEE
			"aggression": 1.5,
			"courage": 0.6,
			"flee_health_percent": 0.2,
			"can_sprint": true,
			"can_dodge": true,
			"dodge_chance_vs_ranged": 0.6,
			"zigzag_when_chasing": true,
			"vision_range": 25.0,
			"lose_aggro_time": 8.0
		},
		"Skeleton_Minion.tscn": {
			"combat_style": 0, # MELEE
			"aggression": 0.8,
			"courage": 0.5,
			"flee_health_percent": 0.3,
			"can_sprint": false,
			"can_dodge": false,
			"dodge_chance_vs_ranged": 0.0,
			"zigzag_when_chasing": false,
			"vision_range": 15.0,
			"lose_aggro_time": 4.0
		},
		"Skeleton_Mage.tscn": {
			"combat_style": 1, # RANGED
			"aggression": 0.6,
			"courage": 0.3,
			"flee_health_percent": 0.5,
			"can_sprint": false,
			"can_dodge": true,
			"dodge_chance_vs_ranged": 0.8,
			"zigzag_when_chasing": false,
			"vision_range": 30.0,
			"lose_aggro_time": 10.0
		}
	}
	
	for file_name in skeletons:
		var path = ENEMY_DIR + file_name
		var scene = load(path)
		if not scene:
			print("Could not load: ", path)
			continue
			
		var instance = scene.instantiate()
		
		# Create Behavior Config
		var config = AIBehaviorConfig.new()
		var data = skeletons[file_name]
		for key in data:
			config.set(key, data[key])
			
		var res_path = ENEMY_DIR + "ai_configs/"
		DirAccess.make_dir_absolute(ProjectSettings.globalize_path(res_path))
		var config_path = res_path + file_name.replace(".tscn", "_ai_config.tres")
		ResourceSaver.save(config, config_path)
		
		# Assign to instance
		instance.ai_config = load(config_path)
		
		var packed = PackedScene.new()
		packed.pack(instance)
		ResourceSaver.save(packed, path)
		print("Configured ", file_name)
		instance.queue_free()

func setup_bosses():
	# Simple default setup for bosses
	var bosses = [
		"orc_brute_green.tscn",
		"orc_brute_blue.tscn",
		"monstrosity.tscn",
		"skull_knight.tscn",
		"frost_golem.tscn"
	]
	
	var res_path = BOSS_DIR + "ai_configs/"
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(res_path))
	
	for file_name in bosses:
		var path = BOSS_DIR + file_name
		var scene = load(path)
		if not scene:
			print("Could not load: ", path)
			continue
			
		var instance = scene.instantiate()
		
		# Bosses share enemy AI config base properties (aggression etc)
		var base_config = AIBehaviorConfig.new()
		base_config.combat_style = 0 # MELEE
		base_config.aggression = 2.0
		base_config.courage = 1.0 # Never flees
		base_config.can_sprint = true
		base_config.zigzag_when_chasing = false
		base_config.vision_range = 50.0 # Bosses see far
		
		var config_path = res_path + file_name.replace(".tscn", "_base_ai.tres")
		ResourceSaver.save(base_config, config_path)
		instance.ai_config = load(config_path)
		
		# 1. Phase Config
		var phase1 = BossPhaseConfig.new()
		phase1.phase_name = "Phase 1"
		phase1.health_percent_trigger = 1.0
		var phase2 = BossPhaseConfig.new()
		phase2.phase_name = "Phase 2 (Enraged)"
		phase2.health_percent_trigger = 0.5
		phase2.speed_multiplier = 1.3
		phase2.anim_speed_scale = 1.2
		phase2.sprint_enabled = true
		
		var p1_path = res_path + file_name.replace(".tscn", "_phase1.tres")
		var p2_path = res_path + file_name.replace(".tscn", "_phase2.tres")
		ResourceSaver.save(phase1, p1_path)
		ResourceSaver.save(phase2, p2_path)
		
		var p_arr: Array[BossPhaseConfig] = []
		p_arr.append(load(p1_path))
		p_arr.append(load(p2_path))
		instance.phases = p_arr
		
		# 2. Attack Patterns
		var attack1 = BossAttackPattern.new()
		attack1.anim_name = "Orc_Axe_2H_Attack" # A generic default, will need tuning per boss
		if "orc" in file_name:
			attack1.anim_name = "Orc_Axe_2H_Attack_1"
		elif "skull" in file_name:
			attack1.anim_name = "Sword_2H_Attack" # example
			
		attack1.windup = 0.5
		attack1.active_time = 0.3
		attack1.damage_multiplier = 1.0
		attack1.weight = 1.0
		
		var a1_path = res_path + file_name.replace(".tscn", "_attack1.tres")
		ResourceSaver.save(attack1, a1_path)
		var a_arr: Array[BossAttackPattern] = []
		a_arr.append(load(a1_path))
		instance.attack_patterns = a_arr
		
		var packed = PackedScene.new()
		packed.pack(instance)
		ResourceSaver.save(packed, path)
		print("Configured Boss: ", file_name)
		instance.queue_free()
