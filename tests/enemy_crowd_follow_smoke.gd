extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	assert(player_scene != null and enemy_scene != null, "Player and enemy scenes must load")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := player_scene.instantiate() as RiverBoundPlayer
	player.maximum_health = 1000
	player.firing_enabled = false
	world.add_child(player)
	player.global_position = Vector3.ZERO

	var monsters: Array[RiverMonster] = []
	for index in 16:
		var monster := enemy_scene.instantiate() as RiverMonster
		world.add_child(monster)
		monster.global_position = Vector3(
			8.0 + float(index / 4) * 0.16,
			0.1,
			(float(index % 4) - 1.5) * 0.16,
		)
		monster.movement_speed = 4.0
		monster.attack_range = 0.85
		monster.attack_damage = 0
		monster._state = RiverMonster.State.CHASE
		monsters.append(monster)
	await physics_frame

	var initial_average := _average_distance(monsters, player.global_position)
	for frame in 240:
		await physics_frame
	var final_average := _average_distance(monsters, player.global_position)
	var followers_near_player := 0
	for monster in monsters:
		if monster.global_position.distance_to(player.global_position) <= 3.5:
			followers_near_player += 1
	assert(final_average < initial_average * 0.55, "A dense enemy crowd must keep advancing toward the player")
	assert(followers_near_player >= 12, "Clustered enemies must flow around one another and reach attack proximity")
	for first_index in monsters.size():
		for second_index in range(first_index + 1, monsters.size()):
			var separation := Vector2(
				monsters[first_index].global_position.x - monsters[second_index].global_position.x,
				monsters[first_index].global_position.z - monsters[second_index].global_position.z,
			).length()
			assert(separation >= 0.78, "Crowd followers must not visually or physically overlap")

	print("RIVER_BOUND_ENEMY_CROWD_FOLLOW_PASSED near=%d average=%.2f" % [followers_near_player, final_average])
	quit()


func _average_distance(monsters: Array[RiverMonster], target_position: Vector3) -> float:
	var total := 0.0
	for monster in monsters:
		total += monster.global_position.distance_to(target_position)
	return total / float(monsters.size())
