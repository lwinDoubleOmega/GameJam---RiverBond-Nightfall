extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as RiverBoundPlayer
	player.starting_ammo = 2
	world.add_child(player)
	await process_frame
	assert(player.current_ammo() == 2, "Configured starting ammo must initialize the player")

	player.call(&"_fire_once")
	assert(player.current_ammo() == 1, "One successful trigger pull must consume exactly one ammo")
	player._shot_timer = 0.0
	player.call(&"_fire_once")
	assert(player.current_ammo() == 0, "Second successful trigger pull must consume the final ammo")
	var projectile_count_at_zero := get_nodes_in_group(&"player_projectiles").size()
	player._shot_timer = 0.0
	player.call(&"_fire_once")
	assert(player.current_ammo() == 0, "Ammo must never become negative")
	assert(get_nodes_in_group(&"player_projectiles").size() == projectile_count_at_zero, "Zero ammo must not create a projectile")

	var pickup_scene := load("res://scenes/combat_pickup.tscn") as PackedScene
	var ammo_pickup := pickup_scene.instantiate() as RiverCombatPickup
	ammo_pickup.pickup_type = RiverCombatPickup.PickupType.AMMO
	world.add_child(ammo_pickup)
	assert(ammo_pickup.get_node("VisualPivot/AmmoModel").visible, "Ammo pickup must show the imported ammo model")
	assert(not ammo_pickup.get_node("VisualPivot/HealthModel").visible, "Ammo pickup must hide the health model")
	assert(ammo_pickup.get_node("VisualPivot/AmmoModel").scale == Vector3(8, 8, 8), "Ammo pickup visual size must remain unchanged")
	assert(is_equal_approx(((ammo_pickup.get_node("Collision") as CollisionShape3D).shape as SphereShape3D).radius, 0.55), "Ammo pickup collision must remain unchanged")
	ammo_pickup.call(&"_on_body_entered", player)
	assert(player.current_ammo() == 15, "Ammo pickup must add its configured 15 ammo")

	player.take_damage(2)
	var health_pickup := pickup_scene.instantiate() as RiverCombatPickup
	health_pickup.pickup_type = RiverCombatPickup.PickupType.HEALTH
	world.add_child(health_pickup)
	assert(health_pickup.get_node("VisualPivot/HealthModel").visible, "Health pickup must show the imported health model")
	assert(not health_pickup.get_node("VisualPivot/AmmoModel").visible, "Health pickup must hide the ammo model")
	assert(health_pickup.get_node("VisualPivot/HealthModel").scale == Vector3(0.54, 0.54, 0.54), "Health pickup visual must be exactly three times larger")
	assert(is_equal_approx(((health_pickup.get_node("Collision") as CollisionShape3D).shape as SphereShape3D).radius, 1.25), "Health pickup collision must match the larger visual")
	var collision_position := (health_pickup.get_node("Collision") as CollisionShape3D).position
	var visual_pivot := health_pickup.get_node("VisualPivot") as Node3D
	var starting_visual_height := visual_pivot.position.y
	health_pickup.call(&"_process", 0.25)
	assert(visual_pivot.position.y != starting_visual_height, "Pickup visual must float gently")
	assert((health_pickup.get_node("Collision") as CollisionShape3D).position == collision_position, "Visual animation must not move collision")
	health_pickup.call(&"_on_body_entered", player)
	assert(player.current_health() == player.maximum_health, "Health pickup must heal without exceeding maximum health")
	player.heal(20)
	assert(player.current_health() == player.maximum_health, "Healing at full health must remain capped")

	var enemy_constants := (load("res://scripts/enemy.gd") as Script).get_script_constant_map()
	assert(is_equal_approx(float(enemy_constants["AMMO_DROP_CHANCE"]), 0.50), "Ammo drop chance must be 50 percent")
	assert(is_equal_approx(float(enemy_constants["HEALTH_DROP_CHANCE"]), 0.10), "Health drop chance must be 10 percent")
	assert(is_equal_approx(1.0 - float(enemy_constants["AMMO_DROP_CHANCE"]) - float(enemy_constants["HEALTH_DROP_CHANCE"]), 0.40), "No-drop chance must be 40 percent")
	print("RIVER_BOUND_AMMO_PICKUP_PASSED")
	quit()
