extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://environment/RiverBoundEnvironment.tscn") as PackedScene
	assert(packed != null, "Environment scene must load")
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var player := scene.get_node("Player") as RiverBoundPlayer
	player.firing_enabled = false
	var monster: RiverMonster
	for enemy_node in get_nodes_in_group(&"enemies"):
		if enemy_node.get_meta(&"spawned_in_river", false):
			monster = enemy_node as RiverMonster
			break
	assert(monster != null, "A river-spawned enemy must exist")
	for enemy_node in get_nodes_in_group(&"enemies"):
		if enemy_node != monster:
			enemy_node.queue_free()
	await process_frame

	player.global_position = Vector3(-30.0, 0.1, 33.0)
	var muzzle := player.get_node("GunPivot/Gun/Muzzle") as Marker3D
	monster.global_position = Vector3(-50.0, -0.45, muzzle.global_position.z)
	monster._state = RiverMonster.State.SPAWN
	monster._state_timer = 20.0
	assert(monster._river_hitbox_lifted, "River enemy hitbox must be raised to the rifle firing line")
	var health_before := monster.current_health()
	var projectile_scene := load("res://scenes/projectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate() as RiverBoundProjectile
	scene.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.lifetime = 1.0
	projectile.launch(Vector3.LEFT)
	for frame in 90:
		await physics_frame
		if monster.current_health() < health_before:
			break
	assert(monster.current_health() < health_before, "Player bullet must pass every river boundary and damage the river enemy")

	print("RIVER_BOUND_RIVER_ENEMY_PROJECTILE_HIT_PASSED")
	quit()
