extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://environment/RiverBoundEnvironment.tscn") as PackedScene
	assert(packed != null, "Environment scene must load")
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame

	var player := scene.get_node("Player") as RiverBoundPlayer
	var monster := get_first_node_in_group("enemies") as RiverMonster
	var listener := player.get_node("AudioListener") as AudioListener3D
	assert(AudioServer.get_bus_index(&"SFX") >= 0, "SFX bus must exist")
	assert(listener != null and listener.is_current(), "Player audio listener must be current")

	var shot := player.get_node("GunPivot/Gun/Muzzle/ShotAudio") as AudioStreamPlayer3D
	var automatic_shot_count := [0]
	player.shot_fired.connect(func() -> void: automatic_shot_count[0] += 1)
	Input.action_press(&"fire")
	# Wave startup can briefly reduce headless physics throughput while 50 enemies initialize.
	await create_timer(0.75).timeout
	Input.action_release(&"fire")
	assert(automatic_shot_count[0] >= 3, "Holding fire must repeatedly create projectiles")
	assert(shot.playing, "Rifle shot audio must play throughout automatic fire")
	var count_after_release: int = automatic_shot_count[0]
	await create_timer(player.shot_cooldown * 2.0).timeout
	assert(automatic_shot_count[0] == count_after_release, "Releasing fire must stop new shots")
	player.take_damage(1)
	assert((player.get_node("DamageAudio") as AudioStreamPlayer3D).playing, "Player damage sound must play")
	monster.call(&"_start_attack")
	assert((monster.get_node("AttackAudio") as AudioStreamPlayer3D).playing, "Monster attack sound must play")

	print("RIVER_BOUND_AUTOMATIC_FIRE_AND_AUDIO_PASSED shots=%d" % count_after_release)
	await create_timer(0.1).timeout
	scene.free()
	quit()
