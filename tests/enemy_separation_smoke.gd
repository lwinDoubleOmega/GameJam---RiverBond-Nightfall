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
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.1, -100.0)
	player.firing_enabled = false
	var monsters: Array[RiverMonster] = []
	for index in 3:
		var monster := enemy_scene.instantiate() as RiverMonster
		world.add_child(monster)
		monster.global_position = Vector3(0.0, 0.1, 8.0)
		monster.movement_speed = 4.0
		monster.attack_range = 0.1
		monster._state = RiverMonster.State.CHASE
		monsters.append(monster)
	await physics_frame
	for monster in monsters:
		assert(monster.collision_mask == 3, "Enemies must physically collide with the world and each other")
	for frame in 90:
		await physics_frame
	for first_index in monsters.size():
		for second_index in range(first_index + 1, monsters.size()):
			var first := monsters[first_index]
			var second := monsters[second_index]
			var separation := Vector2(
				first.global_position.x - second.global_position.x,
				first.global_position.z - second.global_position.z,
			).length()
			assert(separation >= 0.82, "Following enemies must not physically or visually overlap")

	print("RIVER_BOUND_ENEMY_SEPARATION_PASSED")
	quit()
