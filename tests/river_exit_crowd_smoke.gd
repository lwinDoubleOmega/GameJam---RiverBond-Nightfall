extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := player_scene.instantiate() as RiverBoundPlayer
	player.maximum_health = 1000
	player.firing_enabled = false
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.0, 43.0)

	var monsters: Array[RiverMonster] = []
	for index in 24:
		var monster := enemy_scene.instantiate() as RiverMonster
		monster.set_meta(&"spawned_in_river", true)
		monster.set_meta(&"river_exit", Vector3(-34.0, 0.1, 43.0))
		world.add_child(monster)
		monster.global_position = Vector3(
			-42.5 - float(index % 4) * 0.4,
			-0.45,
			39.0 + float(index / 4) * 1.6,
		)
		monster.movement_speed = 4.0
		monster.attack_damage = 0
		monster._state = RiverMonster.State.CHASE
		monsters.append(monster)
	await physics_frame
	for frame in 420:
		await physics_frame
	var exited := 0
	var following := 0
	for monster in monsters:
		if not monster._emerging_from_river:
			exited += 1
		if monster.global_position.x > -20.0:
			following += 1
	assert(exited >= 22, "River enemies must not jam while crossing onto land")
	assert(following >= 18, "River enemies must continue following the player after crossing")

	print("RIVER_BOUND_RIVER_EXIT_CROWD_PASSED exited=%d following=%d" % [exited, following])
	quit()
