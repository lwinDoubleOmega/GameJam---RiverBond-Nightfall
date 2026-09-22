extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/player.tscn") as PackedScene
	assert(packed != null, "Player scene must load")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := packed.instantiate() as RiverBoundPlayer
	world.add_child(player)
	player.firing_enabled = false
	await physics_frame
	_assert_red_crosshair(player)

	var base_cooldown := player.shot_cooldown
	player.equip_weapon(&"laser_rifle")
	for frame in 5:
		await physics_frame
	assert(player.equipped_weapon_name() == &"laser_rifle", "Laser card must equip the laser assault rifle")
	assert(is_equal_approx(player.weapon_damage_multiplier, 1.5), "Laser rifle attack must be 50 percent higher")
	assert(is_equal_approx(player.shot_cooldown, base_cooldown), "Laser rifle must retain the original fire rate")
	assert(player._shot_audio.stream.resource_path.ends_with("laserGunShot.mp3"), "Laser rifle must use laserGunShot.mp3")
	_assert_red_crosshair(player)
	_assert_weapon_grip(player)
	var laser_two_shot_damage := 0
	for shot in 2:
		laser_two_shot_damage += player.call(&"_next_projectile_damage") as int
	assert(laser_two_shot_damage == 3, "Laser rifle must deal exactly 50 percent more damage across two shots")
	player._attack_bonus_accumulator = 0.0
	var crosshair_target := Vector3(7.0, player.global_position.y, -9.0)
	player._aim_world_position = crosshair_target
	player._has_aim_world_position = true
	player.look_at(crosshair_target, Vector3.UP)
	player.call(&"_fire_once")
	await physics_frame
	var laser_projectiles := get_nodes_in_group(&"player_energy_projectiles")
	assert(laser_projectiles.size() == 1, "Laser rifle must fire one projectile per shot")
	assert(laser_projectiles[0].get_node("Effect/MProjectileJavelinVFX_02") != null, "Laser rifle must use MProjectileJavelinVFX_02")
	var laser_projectile := laser_projectiles[0] as PlayerEnergyProjectile
	var laser_muzzle := player.get_node("GunPivot/Gun/Muzzle") as Marker3D
	var muzzle_firing_direction := (-laser_muzzle.global_basis.z).normalized()
	assert(laser_projectile.travel_direction().dot(muzzle_firing_direction) > 0.99, "Laser projectile must travel in the muzzle's firing direction, not backward")
	var crosshair_aim_direction := player.call(&"_current_aim_direction") as Vector3
	assert(laser_projectile.travel_direction().dot(crosshair_aim_direction) > 0.99, "Laser projectile must follow the red crosshair aim direction")
	var expected_crosshair_direction := (crosshair_target - player.global_position).normalized()
	assert(laser_projectile.travel_direction().dot(expected_crosshair_direction) > 0.99, "Off-axis crosshair position must control projectile direction")
	var laser_effect := laser_projectile.get_node("Effect/MProjectileJavelinVFX_02") as Node3D
	# The supplied Javelin VFX has its rounded leading end on local +X.
	var rounded_end_direction := (laser_effect.global_basis * Vector3.RIGHT).normalized()
	assert(rounded_end_direction.dot(laser_projectile.travel_direction()) > 0.99, "Javelin's rounded end must lead along its travel direction")
	assert(player._shot_audio.playing, "Laser rifle shooting sound must play")
	for projectile in laser_projectiles:
		projectile.queue_free()
	await process_frame
	player._has_aim_world_position = false
	player.rotation = Vector3.ZERO

	player.equip_weapon(&"plasma_shotgun")
	for frame in 5:
		await physics_frame
	assert(player.equipped_weapon_name() == &"plasma_shotgun", "Shotgun card must equip the plasma shotgun")
	assert(is_equal_approx(player.weapon_damage_multiplier, 1.7), "Plasma shotgun attack must be 70 percent higher")
	assert(is_equal_approx(player.shot_cooldown, base_cooldown / 0.35), "Plasma shotgun firing frequency must be reduced by 65 percent")
	_assert_red_crosshair(player)
	_assert_weapon_grip(player)
	var shotgun_ten_pellet_damage := 0
	for pellet in 10:
		shotgun_ten_pellet_damage += player.call(&"_next_projectile_damage") as int
	assert(shotgun_ten_pellet_damage == 17, "Plasma pellets must deal exactly 70 percent more damage")
	player._attack_bonus_accumulator = 0.0
	player._shot_timer = 0.0
	player.call(&"_fire_once")
	await physics_frame
	var pellets := get_nodes_in_group(&"player_energy_projectiles")
	assert(pellets.size() == 5, "Plasma shotgun must spawn exactly five individual pellets")
	var actual_angles: Array[float] = []
	for pellet_node in pellets:
		var pellet := pellet_node as PlayerEnergyProjectile
		assert(pellet.get_node("Effect/MProjectileBasicVFX_04") != null, "Every shotgun pellet must use MProjectileBasicVFX_04")
		var direction := pellet.travel_direction()
		actual_angles.append(rad_to_deg(atan2(direction.x, -direction.z)))
	actual_angles.sort()
	var expected_angles := [-15.0, -7.5, 0.0, 7.5, 15.0]
	for index in expected_angles.size():
		assert(is_equal_approx(actual_angles[index], expected_angles[index]), "Shotgun pellets must form the requested five-angle fan")

	print("RIVER_BOUND_PLAYER_WEAPON_CHOICES_PASSED")
	quit()


func _assert_red_crosshair(player: RiverBoundPlayer) -> void:
	assert(player.get_node_or_null("AimIndicator") == null, "Old cyan trajectory indicator must be removed")
	var crosshair := player.get_node("AimCrosshair/Crosshair") as Control
	assert(crosshair != null and crosshair.visible, "Standard crosshair must remain visible while the player is alive")
	var expected_position := player.get_viewport().get_mouse_position() - crosshair.size * 0.5
	assert(crosshair.position.is_equal_approx(expected_position), "Red crosshair must remain centered on the mouse cursor")
	assert(crosshair.get_child_count() == 5, "Crosshair must contain four arms and a center point")
	var center := crosshair.get_node("Center") as ColorRect
	assert(center.color.r > 0.9 and center.color.g < 0.25 and center.color.b < 0.25, "Crosshair must be red")


func _assert_weapon_grip(player: RiverBoundPlayer) -> void:
	var gun := player.get_node("GunPivot/Gun") as Node3D
	assert(gun.get_node_or_null("Grip") is Marker3D, "Selected weapon must expose the trigger-hand grip")
	assert(gun.get_node_or_null("Foregrip") is Marker3D, "Selected weapon must expose the support-hand foregrip")
	assert(gun.get_node_or_null("Muzzle") is Marker3D, "Selected weapon must expose the firing muzzle")
	var right_hand := (player._skeleton.global_transform * player._skeleton.get_bone_global_pose(player._right_hand_bone)).origin
	var left_hand := (player._skeleton.global_transform * player._skeleton.get_bone_global_pose(player._left_hand_bone)).origin
	var grip := gun.get_node("Grip") as Marker3D
	var foregrip := gun.get_node("Foregrip") as Marker3D
	assert(grip.global_position.distance_to(right_hand) < 0.08, "Selected weapon trigger grip must remain anchored to the player's right hand")
	assert(foregrip.global_position.distance_to(left_hand) < 0.08, "Selected weapon foregrip must remain in the player's left hand")
	var muzzle := gun.get_node("Muzzle") as Marker3D
	var functional_barrel_direction := (-muzzle.basis.z).normalized()
	var muzzle_offset_from_grip := (muzzle.position - grip.position).normalized()
	assert(muzzle_offset_from_grip.dot(functional_barrel_direction) > 0.99, "Selected weapon's muzzle must sit at its forward firing end")
