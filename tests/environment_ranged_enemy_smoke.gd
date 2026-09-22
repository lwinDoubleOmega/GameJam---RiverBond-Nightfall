extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var ranged_scene := load("res://scenes/enemy_ranged.tscn") as PackedScene
	assert(player_scene != null and ranged_scene != null, "Ranged combat scenes must load")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := player_scene.instantiate() as RiverBoundPlayer
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.1, 0.0)
	player.firing_enabled = false
	var monster := ranged_scene.instantiate() as RiverRangedMonster
	world.add_child(monster)
	monster.global_position = Vector3(0.0, 0.1, 8.0)
	monster.attack_range = 12.0
	monster.attack_cooldown = 20.0
	await physics_frame

	assert(monster.is_in_group(&"ranged_enemies"), "Enemy2 must register as a ranged enemy")
	monster._cooldown_timer = 0.0
	monster.call(&"_start_attack")
	assert(monster.current_animation_name() == &"Right_Hand_Sword_Slash", "Ranged attack must use sword slash")
	var captured_target := monster._burst_target_position
	player.global_position = Vector3(5.0, 0.1, 0.0)
	for frame in 45:
		await physics_frame
	var projectiles := get_nodes_in_group(&"enemy_projectiles")
	assert(projectiles.size() == 3, "Ranged enemy must release exactly three continuous projectiles")
	for projectile_node in projectiles:
		var projectile := projectile_node as RiverRangedProjectile
		assert(projectile.get_node("MProjectileBasicVFX03") != null, "Projectile must use mprojectile_basic_vfx_03")
		assert(projectile.target_snapshot().is_equal_approx(captured_target), "Every burst shot must use the captured player location")
		var expected_direction := (captured_target - projectile.global_position).normalized()
		assert(projectile.travel_direction().dot(expected_direction) > 0.995, "Projectile direction must remain fixed after player movement")

	monster.take_projectile_hit(1, monster.global_position)
	assert(monster.current_animation_name() == &"Hit_Reaction_with_Bow", "Ranged hit must use bow reaction")
	monster._state = RiverMonster.State.CHASE
	monster._cooldown_timer = 20.0
	monster.global_position = Vector3(0.0, 0.1, 20.0)
	for frame in 3:
		await physics_frame
	assert(monster.current_animation_name() == &"Unsteady_Walk", "Ranged movement must use unsteady walk")
	monster.take_projectile_hit(monster.current_health(), monster.global_position)
	assert(monster.current_animation_name() == &"Shot_and_Slow_Fall_Backward", "Ranged death must use slow fall backward")
	assert(not monster.get_node("HealthBar").visible, "Ranged health bar must hide on death")
	var death_meshes := monster.get_node("Visual").find_children("*", "MeshInstance3D", true, false)
	var death_mesh := death_meshes[0] as MeshInstance3D if not death_meshes.is_empty() else null
	assert(death_mesh != null, "Enemy2 must contain a visible mesh")
	for frame in 75:
		await physics_frame
	assert(death_mesh.transparency > 0.0 and death_mesh.transparency < 1.0, "Enemy2 must fade gradually during its death animation")

	print("RIVER_BOUND_RANGED_ENEMY_PASSED")
	quit()
