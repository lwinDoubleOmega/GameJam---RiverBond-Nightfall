extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://environment/RiverBoundEnvironment.tscn") as PackedScene
	assert(packed != null, "Environment scene must load")
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene

	var player := scene.get_node("Player") as RiverBoundPlayer
	var monster: RiverMonster
	var nearest_river_distance := INF
	for enemy_node in get_nodes_in_group("enemies"):
		if enemy_node.get_meta(&"spawned_in_river", false) and not enemy_node.is_in_group(&"ranged_enemies"):
			var candidate := enemy_node as RiverMonster
			var candidate_distance := absf(candidate.global_position.z - 33.0)
			if candidate_distance < nearest_river_distance:
				nearest_river_distance = candidate_distance
				monster = candidate
	assert(player != null and monster != null, "Working player and monster must be present")
	for other_enemy in get_nodes_in_group("enemies"):
		if other_enemy != monster:
			(other_enemy as RiverMonster).queue_free()
	await process_frame
	player.firing_enabled = false
	assert(monster.current_animation_name() == &"Arise", "Monster must arise when it spawns")
	var health_bar := monster.get_node("HealthBar") as Node3D
	var health_fill := monster.get_node("HealthBar/Fill") as MeshInstance3D
	assert(health_bar != null and health_fill != null and health_bar.visible, "Monster health bar must be visible")
	assert(is_equal_approx((health_fill.mesh as QuadMesh).size.x, 1.04), "Full-health bar must start full")

	var original_player_position := player.global_position
	var original_movement_speed := monster.movement_speed
	player.global_position = Vector3(-25.0, 0.1, 33.0)
	monster.movement_speed = 40.0
	monster._state = RiverMonster.State.CHASE
	for frame in 120:
		await physics_frame
		if not monster._emerging_from_river:
			break
	assert(not monster._emerging_from_river, "River monster must reach its distributed river exit")
	assert(monster.global_position.x > -35.0, "River monster must cross the inner west boundary")
	assert(is_equal_approx(monster.global_position.y, 0.1), "River monster must finish at ground height")
	assert(monster.collision_mask == monster._normal_collision_mask, "Normal world collision must return after emerging")
	assert(not monster._river_hitbox_lifted, "River hitbox must return to its normal height after emerging")
	monster.movement_speed = 10.0
	var river_route_player_health := player.current_health()
	for frame in 240:
		await physics_frame
		if player.current_health() < river_route_player_health:
			break
	assert(player.current_health() < river_route_player_health, "River monster must cross onto the road and attack the player")
	for frame in 90:
		await physics_frame
		if monster.current_state_name() == "CHASE":
			break
	monster.movement_speed = original_movement_speed
	player.global_position = original_player_position
	monster.global_position = player.global_position + Vector3(0.0, 0.0, 10.0)
	var starting_distance := monster.global_position.distance_to(player.global_position)
	for frame in 30:
		await physics_frame
	assert(monster.current_animation_name() == &"Running", "Healthy monster must run while chasing")
	assert(monster.global_position.distance_to(player.global_position) < starting_distance, "Monster must chase the player")

	monster.global_position = player.global_position + Vector3(0.0, 0.0, 1.0)
	var player_health_before := player.current_health()
	monster._next_attack_is_sword = true
	monster.call(&"_start_attack")
	assert(monster.current_animation_name() == &"Right_Hand_Sword_Slash", "First attack must use sword slash")
	monster.call(&"_start_attack")
	assert(monster.current_animation_name() == &"Shield_Push_Left", "Second attack must use shield push")
	for frame in 90:
		await physics_frame
		if player.current_health() < player_health_before:
			break
	assert(player.current_health() == player_health_before - 1, "Monster attack must damage player once")
	assert((player.get_node("DamageAudio") as AudioStreamPlayer3D).playing, "Player damage sound must play")

	monster.take_projectile_hit(1, monster.global_position)
	assert(monster.current_animation_name() == &"Hit_Reaction", "Monster hit animation must play")
	assert(is_equal_approx((health_fill.mesh as QuadMesh).size.x, 1.04 * 2.0 / 3.0), "Health bar must lose one third after one hit")
	monster.take_projectile_hit(1, monster.global_position)
	assert(monster.current_health() == 1, "Two hits must put a three-health monster below 50 percent")
	assert(is_equal_approx((health_fill.mesh as QuadMesh).size.x, 1.04 / 3.0), "Health bar must show injured health")
	assert((health_fill.mesh as QuadMesh).center_offset.x < 0.0, "Health bar must drain from right to left")
	monster.global_position = player.global_position + Vector3(0.0, 0.0, 10.0)
	for frame in 75:
		await physics_frame
	assert(monster.current_animation_name() == &"Unsteady_Walk", "Injured monster must use unsteady walk")
	assert(monster.velocity.length() <= monster.movement_speed * 0.81, "Injured monster must move 20 percent slower")
	monster.take_projectile_hit(monster.current_health(), monster.global_position)
	assert((monster.get_node("DeathAudio") as AudioStreamPlayer3D).playing, "Monster death sound must play")
	assert(monster.current_animation_name() == &"Shot_and_Slow_Fall_Backward", "Monster death animation must play")
	assert(not health_bar.visible, "Health bar must hide when monster dies")

	print("RIVER_BOUND_ENVIRONMENT_MONSTER_COMBAT_PASSED")
	quit()
