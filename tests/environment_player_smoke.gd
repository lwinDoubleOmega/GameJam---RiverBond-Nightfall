extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://environment/RiverBoundEnvironment.tscn") as PackedScene
	assert(packed != null, "Environment scene must load")
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene

	var player := scene.get_node("Player") as CharacterBody3D
	var camera_rig := scene.get_node("CameraRig") as Node3D
	var camera := scene.get_node("CameraRig/OverviewCamera") as Camera3D
	assert(player != null, "Working prototype player must be present")
	assert(camera_rig != null and camera != null, "Environment camera must be present")
	assert(camera.current, "Environment camera must be current")
	assert(is_equal_approx(player.position.y, 0.1), "Player must start at prototype ground height")

	await physics_frame
	var player_start := player.global_position
	var camera_start := camera_rig.global_position
	Input.action_press(&"move_forward")
	for frame in 30:
		await physics_frame
	Input.action_release(&"move_forward")
	await process_frame

	assert(player.global_position.distance_to(player_start) > 0.5, "Player must move inside environment")
	assert(camera_rig.global_position.distance_to(camera_start) > 0.1, "Camera must follow player")
	print("RIVER_BOUND_ENVIRONMENT_PLAYER_MOVEMENT_PASSED")
	scene.queue_free()
	quit()
