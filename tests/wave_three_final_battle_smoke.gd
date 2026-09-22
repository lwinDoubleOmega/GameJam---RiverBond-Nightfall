extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://environment/RiverBoundEnvironment.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var constants: Dictionary = scene.get_script().get_script_constant_map()
	assert(_count_group(&"enemies") == int(constants["WAVE_ONE_MELEE_COUNT"]), "Wave 1 count must remain unchanged")

	_clear_tracked_wave(scene)
	scene.get_node("CombatHUD").call(&"_choose", &"movement")
	await process_frame
	assert(_count_group(&"enemies") == int(constants["WAVE_TWO_MELEE_COUNT"]) + int(constants["WAVE_TWO_RANGED_COUNT"]), "Wave 2 count must remain unchanged")

	_clear_tracked_wave(scene)
	scene.get_node("CombatHUD").call(&"_choose_weapon", &"laser_rifle")
	await process_frame
	var expected_wave_three := (
		int(constants["FINAL_WAVE_MELEE_COUNT"])
		+ int(constants["FINAL_WAVE_RANGED_COUNT"])
		+ int(constants["FINAL_WAVE_MEDIUM_BOSS_ADDED_COUNT"])
		+ int(constants["FINAL_WAVE_TOTAL_BOSS_COUNT"])
	)
	assert(_count_group(&"enemies") == expected_wave_three, "Wave 3 must retain existing enemies and add all requested bosses")
	assert(_count_group(&"medium_boss_enemies") == 10, "Wave 3 must add 10 medium bosses")
	assert(_count_group(&"boss_enemies") == 3, "Wave 3 must retain one final boss and add two more")
	for boss_node in get_nodes_in_group(&"boss_enemies"):
		var boss := boss_node as RiverBossMonster
		assert(boss.maximum_health == 45 and boss.current_health() == 45, "Wave 3 final boss health must be five times its scene value")
		assert(is_equal_approx(boss.movement_speed, 2.9), "Wave 3 final boss speed must be twice its scene value")

	scene._living_wave_enemies = 2
	scene.call(&"_on_enemy_defeated")
	await process_frame
	assert(current_scene == scene, "Defeating one tracked final enemy must not start the outro")
	scene.call(&"_on_enemy_defeated")
	await process_frame
	assert(current_scene != scene and current_scene.scene_file_path == "res://video/outro.tscn", "The outro must start once after all Wave 3 enemies are cleared")
	print("RIVER_BOUND_WAVE_THREE_FINAL_BATTLE_PASSED")
	quit()


func _clear_tracked_wave(scene: Node) -> void:
	var enemies := get_nodes_in_group(&"enemies")
	for enemy in enemies:
		scene.call(&"_on_enemy_defeated")
		enemy.queue_free()


func _count_group(group_name: StringName) -> int:
	return get_nodes_in_group(group_name).size()
