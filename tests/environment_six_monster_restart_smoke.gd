extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://environment/RiverBoundEnvironment.tscn") as PackedScene
	assert(packed != null, "Environment scene must load")
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var constants: Dictionary = scene.get_script().get_script_constant_map()
	var wave_one_count := int(constants["WAVE_ONE_MELEE_COUNT"])
	var wave_two_melee_count := int(constants["WAVE_TWO_MELEE_COUNT"])
	var wave_two_ranged_count := int(constants["WAVE_TWO_RANGED_COUNT"])
	var final_melee_count := int(constants["FINAL_WAVE_MELEE_COUNT"])
	var final_ranged_count := int(constants["FINAL_WAVE_RANGED_COUNT"])
	var final_medium_boss_count := int(constants["FINAL_WAVE_MEDIUM_BOSS_ADDED_COUNT"])
	var final_boss_count := int(constants["FINAL_WAVE_TOTAL_BOSS_COUNT"])
	var wave_two_count := wave_two_melee_count + wave_two_ranged_count
	var final_wave_count := final_melee_count + final_ranged_count + final_medium_boss_count + final_boss_count
	var regular_enemy_count := wave_one_count + wave_two_count + final_melee_count + final_ranged_count + final_medium_boss_count
	var complete_count := regular_enemy_count + final_boss_count
	var expected_river_count := roundi(float(regular_enemy_count) * float(constants["RIVER_MONSTER_RATIO"]))

	var player := scene.get_node("Player") as RiverBoundPlayer
	player.global_position = Vector3(250.0, 0.1, 250.0)
	assert(_monster_count(scene) == wave_one_count, "Wave 1 must spawn its configured enemy count")
	assert(_melee_monster_count(scene) == wave_one_count, "Wave 1 must contain only its configured Enemy1 count")
	assert(_ranged_monster_count(scene) == 0, "Enemy2 must not appear during Wave 1")
	assert(scene.total_spawned == wave_one_count, "Initial spawn count must match Wave 1 configuration")
	assert(scene.current_wave == 1, "The encounter must start on Wave 1")
	assert(scene.living_wave_enemy_count() == wave_one_count, "Wave 1 must track all living enemies")
	var hud := scene.get_node("CombatHUD")
	assert((hud.get_node("WaveBanner") as Label).text == "WAVE 1", "Wave 1 must display at game start")
	assert((hud.get_node("HealthPanel/Margin/Content/HealthRow/HealthCount") as Label).text == "05 / 05", "Top-left HUD must show player health count")
	assert((hud.get_node("EnemyPanel/Margin/Content/EnemyCount") as Label).text == "%03d" % wave_one_count, "Top-right skull counter must show living enemies")
	player.take_damage(1)
	assert((hud.get_node("HealthPanel/Margin/Content/HealthRow/HealthCount") as Label).text == "04 / 05", "Health HUD must update immediately when the player is damaged")

	var wave_one_river_count := _river_monster_count(scene)
	for enemy in get_nodes_in_group(&"enemies"):
		scene.call(&"_on_enemy_defeated")
		enemy.queue_free()
	await process_frame
	assert(_monster_count(scene) == 0, "Wave 2 must wait after Wave 1 is cleared")
	assert(scene.waiting_for_power_choice(), "Wave clear must wait for one power choice")
	assert(hud.is_power_choice_visible(), "Wave clear must display three power cards")
	var original_speed := player.movement_speed
	hud.call(&"_choose", &"movement")
	await process_frame
	assert(is_equal_approx(player.movement_speed, original_speed * 1.2), "Movement card must increase speed by 20 percent")
	assert(scene.current_wave == 2, "Power selection must start Wave 2")
	assert(_monster_count(scene) == wave_two_count, "Wave 2 must contain its configured total")
	assert(_melee_monster_count(scene) == wave_two_melee_count, "Wave 2 must contain its configured Enemy1 count")
	assert(_ranged_monster_count(scene) == wave_two_ranged_count, "Wave 2 must contain its configured Enemy2 count")
	assert(scene.total_spawned == wave_one_count + wave_two_count, "The first two waves must match their configured encounter total")
	var wave_two_river_count := _river_monster_count(scene)
	for enemy in get_nodes_in_group(&"enemies"):
		scene.call(&"_on_enemy_defeated")
		enemy.queue_free()
	await process_frame
	assert(scene.waiting_for_weapon_choice(), "Clearing Wave 2 must wait for a weapon-card choice")
	assert(hud.is_weapon_choice_visible(), "Wave 2 clear must display the two weapon cards")
	hud.call(&"_choose_weapon", &"laser_rifle")
	await physics_frame
	assert(player.equipped_weapon_name() == &"laser_rifle", "Weapon card must replace the player's current gun")
	assert(not scene.waiting_for_weapon_choice(), "Only one post-Wave-2 weapon may be selected")
	assert(scene.current_wave == 3, "Weapon selection must start the Final Wave")
	assert(_monster_count(scene) == final_wave_count, "Final Wave must include all configured enemies and the boss")
	assert(_melee_monster_count(scene) == final_melee_count, "Final Wave must contain 30 Enemy1 monsters")
	assert(_ranged_monster_count(scene) == final_ranged_count + final_medium_boss_count, "Final Wave must contain existing Enemy2 monsters plus medium bosses")
	assert(get_nodes_in_group(&"medium_boss_enemies").size() == final_medium_boss_count, "Final Wave must add all medium bosses")
	assert(_boss_monster_count(scene) == final_boss_count, "Final Wave must contain all final bosses")
	assert(scene.total_spawned == complete_count, "All three waves must match the configured encounter total")
	assert(scene.living_wave_enemy_count() == final_wave_count, "Final Wave must track every living enemy and boss")
	assert((hud.get_node("EnemyPanel/Margin/Content/EnemyCount") as Label).text == "%03d" % final_wave_count, "Enemy counter must include the boss")
	assert(wave_one_river_count + wave_two_river_count + _river_monster_count(scene) == expected_river_count, "The configured share of regular enemies must remain river-spawned")
	# The focused final-battle smoke test validates the real outro transition.
	# Keep this broader restart test in its scene so it can continue checking death and restart.
	scene._ending_run = true
	for enemy in get_nodes_in_group(&"enemies"):
		scene.call(&"_on_enemy_defeated")
		enemy.queue_free()
	await process_frame
	assert(scene.living_wave_enemy_count() == 0, "Clearing the Final Wave must reduce the enemy counter to zero")
	assert((hud.get_node("EnemyPanel/Margin/Content/EnemyCount") as Label).text == "000", "Top-right enemy counter must show zero after victory")

	assert(player.is_alive(), "Wave timing test must keep its player alive before lethal damage")
	player.take_damage(player.maximum_health)
	assert(not player.is_alive(), "Lethal damage must kill the player")
	assert((player.get_node("DeathAudio") as AudioStreamPlayer3D).playing, "Player death sound must play")

	var old_scene_id := scene.get_instance_id()
	assert(InputMap.has_action(&"restart"), "Restart action must exist for the R key")
	scene.restart_scene()
	for frame in 30:
		await process_frame
	assert(current_scene != null and current_scene.get_instance_id() != old_scene_id, "R must reload the scene")
	assert(_monster_count(current_scene) == wave_one_count, "Restart must reset the configured Wave 1 count")
	assert((current_scene.get_node("Player") as RiverBoundPlayer).is_alive(), "Restart must restore a living player")

	print("RIVER_BOUND_FINAL_WAVE_POWER_RESTART_PASSED")
	current_scene.free()
	quit()


func _monster_count(scene: Node) -> int:
	var count := 0
	for child: Node in scene.get_children():
		if child is RiverMonster:
			count += 1
	return count


func _river_monster_count(scene: Node) -> int:
	var count := 0
	for child: Node in scene.get_children():
		if child is RiverMonster and child.get_meta(&"spawned_in_river", false):
			count += 1
	return count


func _ranged_monster_count(scene: Node) -> int:
	var count := 0
	for child: Node in scene.get_children():
		if child.is_in_group(&"ranged_enemies"):
			count += 1
	return count


func _melee_monster_count(scene: Node) -> int:
	var count := 0
	for child: Node in scene.get_children():
		if child is RiverMonster and not child.is_in_group(&"ranged_enemies") and not child.is_in_group(&"boss_enemies"):
			count += 1
	return count


func _boss_monster_count(scene: Node) -> int:
	var count := 0
	for child: Node in scene.get_children():
		if child.is_in_group(&"boss_enemies"):
			count += 1
	return count
