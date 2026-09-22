extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/player.tscn") as PackedScene
	assert(packed != null, "Player scene must load")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var attack_player := packed.instantiate() as RiverBoundPlayer
	world.add_child(attack_player)
	attack_player.apply_power_boost(&"attack")
	assert(is_equal_approx(attack_player.attack_power_multiplier, 1.2), "Attack Boost must increase attack power by 20 percent")
	var five_shot_damage := 0
	for shot in 5:
		five_shot_damage += attack_player.call(&"_next_projectile_damage") as int
	assert(five_shot_damage == 6, "Attack boost must produce exactly 20 percent more damage across five shots")

	var health_player := packed.instantiate() as RiverBoundPlayer
	world.add_child(health_player)
	health_player.apply_power_boost(&"health")
	assert(health_player.maximum_health == 6, "Health card must increase five maximum health by 20 percent")
	assert(health_player.current_health() == 6, "Health card must grant the added health point")

	var movement_player := packed.instantiate() as RiverBoundPlayer
	world.add_child(movement_player)
	var original_speed := movement_player.movement_speed
	movement_player.apply_power_boost(&"movement")
	assert(is_equal_approx(movement_player.movement_speed, original_speed * 1.2), "Movement card must increase speed by 20 percent")

	print("RIVER_BOUND_PLAYER_POWER_BOOSTS_PASSED")
	quit()
