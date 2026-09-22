extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var projectile_scene := load("res://scenes/projectile.tscn") as PackedScene
	assert(projectile_scene != null, "Projectile scene must load")

	var test_world := Node3D.new()
	root.add_child(test_world)

	var environment_body := _make_body(1, Vector3(0.0, 0.0, -2.0))
	test_world.add_child(environment_body)
	var environment_projectile := projectile_scene.instantiate() as Area3D
	test_world.add_child(environment_projectile)
	environment_projectile.global_position = Vector3.ZERO
	environment_projectile.call(&"launch", Vector3.FORWARD)
	await _wait_for_impact(environment_projectile)
	assert(environment_projectile.get_node("ImpactVisual").visible, "Projectile must impact layer-1 environment")

	var enemy_body := _make_body(2, Vector3(2.0, 0.0, -2.0))
	test_world.add_child(enemy_body)
	var enemy_projectile := projectile_scene.instantiate() as Area3D
	test_world.add_child(enemy_projectile)
	enemy_projectile.global_position = Vector3(2.0, 0.0, 0.0)
	enemy_projectile.call(&"launch", Vector3.FORWARD)
	await _wait_for_impact(enemy_projectile)
	assert(enemy_projectile.get_node("ImpactVisual").visible, "Projectile must still impact layer-2 enemies")

	print("RIVER_BOUND_PROJECTILE_ENVIRONMENT_COLLISION_PASSED")
	test_world.queue_free()
	quit()


func _make_body(layer: int, body_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.position = body_position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 0.2)
	collision.shape = shape
	body.add_child(collision)
	return body


func _wait_for_impact(projectile: Area3D) -> void:
	for frame in 20:
		await physics_frame
		if projectile.get_node("ImpactVisual").visible:
			return
	assert(false, "Projectile did not impact within the expected travel time")
