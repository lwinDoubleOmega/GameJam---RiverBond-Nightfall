extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var boss_scene := load("res://scenes/enemy_boss.tscn") as PackedScene
	assert(player_scene != null and boss_scene != null, "Boss combat scenes must load")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := player_scene.instantiate() as RiverBoundPlayer
	world.add_child(player)
	player.global_position = Vector3(0.0, 0.1, -25.0)
	player.firing_enabled = false
	var boss := boss_scene.instantiate() as RiverBossMonster
	world.add_child(boss)
	boss.global_position = Vector3(0.0, 0.1, 0.0)
	boss.attack_cooldown = 20.0
	await physics_frame

	assert(boss.is_in_group(&"boss_enemies"), "Enemy3 must register as the boss")
	assert(boss.maximum_health == 9 and boss.current_health() == 9, "Boss health must be three times Enemy1 health")
	assert(boss.get_node("Visual").scale == Vector3(3.54, 3.54, 3.54), "Final boss visual must be exactly three times its previous scale")
	var boss_collision := boss.get_node("Collision") as CollisionShape3D
	var boss_capsule := boss_collision.shape as CapsuleShape3D
	assert(is_equal_approx(boss_capsule.radius, 1.68) and is_equal_approx(boss_capsule.height, 6.54), "Final boss body/hurt capsule must be three times larger")
	assert(is_equal_approx(boss_collision.position.y, 3.27), "Enlarged boss capsule must remain grounded")
	assert(is_equal_approx((boss.get_node("HealthBar") as Node3D).position.y, 7.0), "Boss health bar must remain above the enlarged body")
	var health_fill := boss.get_node("HealthBar/Fill") as MeshInstance3D
	assert(is_equal_approx((health_fill.mesh as QuadMesh).size.x, 1.46), "Boss health bar must be longer than regular enemy bars")
	assert(boss.current_animation_name() == &"Walking", "Boss movement must use its Walking animation")

	player.global_position = Vector3(0.0, 0.1, -10.0)
	boss._cooldown_timer = 0.0
	boss._next_attack_is_radial = true
	boss.call(&"_start_attack")
	assert(boss.current_animation_name() == &"Right_Hand_Sword_Slash", "Boss attacks must use the right-hand sword slash")
	for frame in 55:
		await physics_frame
	var radial_projectiles := get_nodes_in_group(&"enemy_projectiles")
	assert(radial_projectiles.size() == 24, "Boss radial attack must fire three continuous 8-way pulses")
	for projectile_node in radial_projectiles:
		if projectile_node is RiverBossTornadoProjectile:
			continue
		var projectile := projectile_node as RiverRangedProjectile
		assert(projectile.speed < 10.0, "Boss radial projectiles must travel slowly")
		var radial_effect := projectile.get_node("MProjectileBasicVFX03") as Node3D
		assert(radial_effect != null, "Boss radial attack must use MProjectileBasicVFX_03")
		var rounded_end_direction := (radial_effect.global_basis * Vector3.RIGHT).normalized()
		assert(rounded_end_direction.dot(projectile.travel_direction()) > 0.99, "Boss radial projectile's rounded end must lead along its travel direction")
	for projectile_node in radial_projectiles:
		projectile_node.queue_free()
	await process_frame

	boss._state = RiverMonster.State.CHASE
	boss._cooldown_timer = 0.0
	boss._next_attack_is_radial = false
	boss.call(&"_start_attack")
	for frame in 30:
		await physics_frame
	var tornadoes := get_nodes_in_group(&"boss_tornado_projectiles")
	assert(tornadoes.size() == 5, "Boss tornado attack must fire a five-projectile fan")
	var tornado_angles: Array[float] = []
	for tornado_node in tornadoes:
		var tornado := tornado_node as RiverBossTornadoProjectile
		assert(tornado.speed < 10.0, "Boss tornado projectiles must travel slowly")
		assert(tornado.get_node("Visual/TornadoSource/tornado Blue").visible, "Tornado attack must use the supplied blue and white tornado")
		assert(not tornado.get_node("Visual/TornadoSource/tornado poison").visible, "Poison tornado variant must be hidden")
		assert(not tornado.get_node("Visual/TornadoSource/tornado fire").visible, "Fire tornado variant must be hidden")
		var direction := tornado.travel_direction()
		tornado_angles.append(rad_to_deg(atan2(direction.x, -direction.z)))
	tornado_angles.sort()
	var expected_angles := [-30.0, -15.0, 0.0, 15.0, 30.0]
	for index in expected_angles.size():
		assert(is_equal_approx(tornado_angles[index], expected_angles[index]), "Boss tornadoes must form the requested five-angle fan")
	var sample_tornado := tornadoes[2] as RiverBossTornadoProjectile
	var tornado_start := sample_tornado.global_position
	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(8.0, 4.0, 0.5)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	world.add_child(obstacle)
	obstacle.global_position = tornado_start + sample_tornado.travel_direction() * 1.0
	for frame in 30:
		await physics_frame
	assert(is_instance_valid(sample_tornado), "Tornado must pass through world obstacles instead of disappearing")
	assert(sample_tornado.global_position.distance_to(tornado_start) > 1.5, "Tornado must continue travelling through obstacles")

	var animation_before_hit := boss.current_animation_name()
	boss.take_projectile_hit(1, boss.global_position)
	assert(boss.current_health() == 8, "Boss must lose health when shot")
	assert(boss.current_animation_name() == animation_before_hit, "Boss must not play a gunshot hit reaction")
	boss.take_projectile_hit(boss.current_health(), boss.global_position)
	assert(boss.current_animation_name() == &"Shot_and_Fall_Backward", "Boss death must use shot and fall backward")
	assert(not boss.get_node("HealthBar").visible, "Boss health bar must hide on death")

	print("RIVER_BOUND_BOSS_ENEMY_PASSED")
	quit()
