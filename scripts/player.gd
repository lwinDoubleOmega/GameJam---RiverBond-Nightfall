class_name RiverBoundPlayer
extends CharacterBody3D

signal health_changed(current: int, maximum: int)
signal ammo_changed(current: int)
signal died
signal shot_fired
signal power_boost_applied(power: StringName)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const LASER_PROJECTILE_SCENE := preload("res://scenes/laser_projectile.tscn")
const PLASMA_SHOTGUN_PROJECTILE_SCENE := preload("res://scenes/plasma_shotgun_projectile.tscn")
const LASER_ASSAULT_RIFLE_SCENE := preload("res://scenes/laser_assault_rifle.tscn")
const PLASMA_SHOTGUN_SCENE := preload("res://scenes/plasma_shotgun.tscn")
const SHOTGUN_SPREAD_ANGLES := [-15.0, -7.5, 0.0, 7.5, 15.0]
const RIFLE_IDLE_SOURCE := preload("res://animation_fix/idleWithGun.fbx")
const RIFLE_RUN_SOURCE := preload("res://animation_fix/Rifle Run.fbx")
const RIFLE_WALK_SOURCE := preload("res://animation_fix/Walk Forward.fbx")
const RUN_BACKWARD_SOURCE := preload("res://animation_fix/Run Backwards.fbx")
const RUN_LEFT_SOURCE := preload("res://animation_fix/Run Left.fbx")
const RUN_RIGHT_SOURCE := preload("res://animation_fix/Run Right.fbx")
const FIRING_RIFLE_STANDING_SOURCE := preload("res://animation_fix/firingRifleWhileStanding.fbx")
const FIRING_RIFLE_WALK_FORWARD_SOURCE := preload("res://animation_fix/Firing Rifle While walking front.fbx")
const FIRING_RIFLE_MOVING_SOURCE := preload("res://animation_fix/Firing Rifle-2.fbx")
const FIRING_RIFLE_SHOT_SOURCE := preload("res://animation_fix/Firing Rifle-3.fbx")
const SOURCE_PROFILE_BONES := {
	"Hips": "Hips", "Spine02": "Spine", "Spine01": "Chest", "Spine": "UpperChest",
	"neck": "Neck", "Head": "Head", "head_end": "HeadTop",
	"LeftShoulder": "LeftShoulder", "LeftArm": "LeftUpperArm",
	"LeftForeArm": "LeftLowerArm", "LeftHand": "LeftHand",
	"RightShoulder": "RightShoulder", "RightArm": "RightUpperArm",
	"RightForeArm": "RightLowerArm", "RightHand": "RightHand",
	"LeftUpLeg": "LeftUpperLeg", "LeftLeg": "LeftLowerLeg",
	"LeftFoot": "LeftFoot", "LeftToeBase": "LeftToes",
	"RightUpLeg": "RightUpperLeg", "RightLeg": "RightLowerLeg",
	"RightFoot": "RightFoot", "RightToeBase": "RightToes",
}
const SWAT_PROFILE_BONES := {
	"mixamorig_Hips": "Hips", "mixamorig_Spine": "Spine",
	"mixamorig_Spine1": "Chest", "mixamorig_Spine2": "UpperChest",
	"mixamorig_Neck": "Neck", "mixamorig_Head": "Head",
	"mixamorig_HeadTop_End": "HeadTop",
	"mixamorig_LeftShoulder": "LeftShoulder", "mixamorig_LeftArm": "LeftUpperArm",
	"mixamorig_LeftForeArm": "LeftLowerArm", "mixamorig_LeftHand": "LeftHand",
	"mixamorig_RightShoulder": "RightShoulder", "mixamorig_RightArm": "RightUpperArm",
	"mixamorig_RightForeArm": "RightLowerArm", "mixamorig_RightHand": "RightHand",
	"mixamorig_LeftUpLeg": "LeftUpperLeg", "mixamorig_LeftLeg": "LeftLowerLeg",
	"mixamorig_LeftFoot": "LeftFoot", "mixamorig_LeftToeBase": "LeftToes",
	"mixamorig_RightUpLeg": "RightUpperLeg", "mixamorig_RightLeg": "RightLowerLeg",
	"mixamorig_RightFoot": "RightFoot", "mixamorig_RightToeBase": "RightToes",
}

@export var movement_speed: float = 4.6
@export var maximum_health: int = 5
@export var starting_ammo: int = 60
@export var shot_cooldown: float = 0.1
@export var firing_enabled: bool = true

@onready var _collision: CollisionShape3D = $Collision
@onready var _visual: Node3D = $Visual
@onready var _muzzle: Marker3D = $GunPivot/Gun/Muzzle
@onready var _muzzle_flash: Node3D = $GunPivot/Gun/Muzzle/MuzzleFlash
@onready var _shot_audio: AudioStreamPlayer3D = $GunPivot/Gun/Muzzle/ShotAudio
@onready var _gun_pivot: Node3D = $GunPivot
@onready var _aim_crosshair: CanvasLayer = $AimCrosshair
@onready var _crosshair: Control = $AimCrosshair/Crosshair
@onready var _right_grip: Marker3D = $GunPivot/Gun/Grip
@onready var _left_grip: Marker3D = $GunPivot/Gun/Foregrip
@onready var _damage_flash: OmniLight3D = $DamageFlash
@onready var _damage_audio: AudioStreamPlayer3D = $DamageAudio
@onready var _death_audio: AudioStreamPlayer3D = $DeathAudio

var _right_hand_bone: int = -1
var _left_hand_bone: int = -1
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _animation_driver: Node3D
var _source_skeleton: Skeleton3D
var _aligning_weapon: bool = false
var _health: int
var _ammo: int
var _shot_timer: float = 0.0
var _alive: bool = true
var _shot_pitch_index: int = 0
var _hit_visual_tween: Tween
var _hit_flash_tween: Tween
var attack_power_multiplier: float = 1.0
var weapon_damage_multiplier: float = 1.0
var _attack_bonus_accumulator: float = 0.0
var _base_shot_cooldown: float
var _equipped_weapon: StringName = &"rifle"
var _aim_world_position: Vector3 = Vector3.ZERO
var _has_aim_world_position: bool = false


func _ready() -> void:
	add_to_group("player")
	_base_shot_cooldown = shot_cooldown
	_health = maximum_health
	_ammo = maxi(0, starting_ammo)
	_setup_animation_retargeting()
	_install_rifle_animations()
	_right_hand_bone = _skeleton.find_bone(&"RightHand")
	_left_hand_bone = _skeleton.find_bone(&"LeftHand")
	_apply_rifle_hand_grip()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_update_crosshair_screen_position()
	_skeleton.skeleton_updated.connect(_align_gun_to_trigger_hand)
	health_changed.emit(_health, maximum_health)
	ammo_changed.emit(_ammo)
	_hold_armed_pose()


func _physics_process(delta: float) -> void:
	_shot_timer = maxf(0.0, _shot_timer - delta)
	if not _alive:
		velocity = Vector3.ZERO
		return

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back",
	)
	velocity = Vector3(input_vector.x, 0.0, input_vector.y) * movement_speed
	move_and_slide()
	_face_mouse_cursor()

	var is_moving := input_vector.length_squared() > 0.01
	var is_firing := firing_enabled and Input.is_action_pressed("fire")
	if is_firing:
		_fire_once()
		_play_animation(_firing_animation_name(is_moving))
	elif is_moving:
		_play_animation(_movement_animation_name())
	else:
		_hold_armed_pose()
	# Keep both grips synchronized with the final animated pose. Persistent bone
	# overrides prevent the uncorrected support-hand pose appearing between calls.
	_align_gun_to_trigger_hand()


func take_damage(amount: int) -> void:
	if not _alive:
		return
	_health = maxi(0, _health - amount)
	health_changed.emit(_health, maximum_health)
	if _health == 0:
		_alive = false
		velocity = Vector3.ZERO
		_play_death_reaction()
		died.emit()
	else:
		_damage_audio.play()
		_play_hit_reaction()


func is_alive() -> bool:
	return _alive


func current_health() -> int:
	return _health


func current_ammo() -> int:
	return _ammo


func add_ammo(amount: int) -> void:
	if amount <= 0:
		return
	_ammo += amount
	ammo_changed.emit(_ammo)


func heal(amount: int) -> void:
	if amount <= 0 or not _alive:
		return
	var healed_health := mini(_health + amount, maximum_health)
	if healed_health == _health:
		return
	_health = healed_health
	health_changed.emit(_health, maximum_health)


func equipped_weapon_name() -> StringName:
	return _equipped_weapon


func equip_weapon(weapon: StringName) -> void:
	var weapon_scene: PackedScene
	match weapon:
		&"laser_rifle":
			weapon_scene = LASER_ASSAULT_RIFLE_SCENE
			weapon_damage_multiplier = 1.5
			shot_cooldown = _base_shot_cooldown
		&"plasma_shotgun":
			weapon_scene = PLASMA_SHOTGUN_SCENE
			weapon_damage_multiplier = 1.7
			# A 65% reduction leaves 35% of the base firing frequency.
			shot_cooldown = _base_shot_cooldown / 0.35
		_:
			push_warning("Unknown weapon choice: %s" % weapon)
			return
	var old_gun := _gun_pivot.get_node_or_null("Gun")
	if old_gun != null:
		_gun_pivot.remove_child(old_gun)
		old_gun.queue_free()
	var new_gun := weapon_scene.instantiate() as Node3D
	new_gun.name = "Gun"
	_gun_pivot.add_child(new_gun)
	_muzzle = new_gun.get_node("Muzzle") as Marker3D
	_muzzle_flash = new_gun.get_node("Muzzle/MuzzleFlash") as Node3D
	_shot_audio = new_gun.get_node("Muzzle/ShotAudio") as AudioStreamPlayer3D
	_right_grip = new_gun.get_node("Grip") as Marker3D
	_left_grip = new_gun.get_node("Foregrip") as Marker3D
	_equipped_weapon = weapon
	_attack_bonus_accumulator = 0.0
	_shot_timer = 0.0
	_apply_rifle_hand_grip()
	call_deferred(&"_align_gun_to_trigger_hand")


func apply_power_boost(power: StringName) -> void:
	match power:
		&"attack":
			attack_power_multiplier *= 1.2
		&"health":
			var previous_maximum := maximum_health
			maximum_health = ceili(float(maximum_health) * 1.2)
			_health = mini(maximum_health, _health + maximum_health - previous_maximum)
			health_changed.emit(_health, maximum_health)
		&"movement":
			movement_speed *= 1.2
		_:
			push_warning("Unknown power boost: %s" % power)
			return
	power_boost_applied.emit(power)


func _play_death_reaction() -> void:
	# Freeze the current rifle pose, then drop the complete player-and-gun rig.
	# This is intentionally independent of the game-over overlay.
	_animation.pause()
	_aim_crosshair.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_stop_hit_reaction()
	_muzzle_flash.visible = false
	_damage_audio.stop()
	_death_audio.play()
	_collision.set_deferred(&"disabled", true)
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)

	var fallen_rotation := rotation
	fallen_rotation.z = deg_to_rad(-82.0)
	var fallen_position := position + Vector3(0.0, -0.34, 0.0)
	var death_tween := create_tween().set_parallel(true)
	death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death_tween.tween_property(self, ^"rotation", fallen_rotation, 0.62)
	death_tween.tween_property(self, ^"position", fallen_position, 0.62)


func _play_hit_reaction() -> void:
	_stop_hit_reaction()
	_damage_flash.visible = true
	_damage_flash.light_energy = 3.2
	_visual.rotation.z = 0.0
	_hit_visual_tween = create_tween()
	_hit_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_visual_tween.tween_property(_visual, ^"rotation:z", deg_to_rad(-6.0), 0.06)
	_hit_visual_tween.set_ease(Tween.EASE_IN_OUT)
	_hit_visual_tween.tween_property(_visual, ^"rotation:z", 0.0, 0.12)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_damage_flash, ^"light_energy", 0.0, 0.18)
	_hit_flash_tween.tween_callback(_finish_hit_flash)


func _stop_hit_reaction() -> void:
	if _hit_visual_tween != null and _hit_visual_tween.is_valid():
		_hit_visual_tween.kill()
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_visual.rotation.z = 0.0
	_damage_flash.visible = false


func _finish_hit_flash() -> void:
	_damage_flash.visible = false


func _face_mouse_cursor() -> void:
	_update_crosshair_screen_position()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var movement_plane := Plane(Vector3.UP, global_position.y)
	var intersection: Variant = movement_plane.intersects_ray(ray_origin, ray_direction)
	if intersection == null:
		return
	var target := intersection as Vector3
	_aim_world_position = Vector3(target.x, global_position.y, target.z)
	_has_aim_world_position = true
	if global_position.distance_squared_to(target) > 0.01:
		look_at(_aim_world_position, Vector3.UP)


func _fire_once() -> void:
	if _shot_timer > 0.0 or _ammo <= 0:
		return
	_shot_timer = shot_cooldown
	_ammo -= 1
	ammo_changed.emit(_ammo)
	var pitch_cycle := [0.97, 1.0, 1.03]
	if _equipped_weapon == &"laser_rifle":
		pitch_cycle = [0.98, 1.0, 1.02]
	elif _equipped_weapon == &"plasma_shotgun":
		pitch_cycle = [0.76, 0.79, 0.82]
	_shot_audio.pitch_scale = pitch_cycle[_shot_pitch_index % pitch_cycle.size()]
	_shot_pitch_index += 1
	_shot_audio.play()
	_muzzle_flash.visible = true
	get_tree().create_timer(0.045).timeout.connect(_hide_muzzle_flash)
	var forward := _current_aim_direction()
	if _equipped_weapon == &"plasma_shotgun":
		for spread_angle: float in SHOTGUN_SPREAD_ANGLES:
			_spawn_player_projectile(
				PLASMA_SHOTGUN_PROJECTILE_SCENE,
				forward.rotated(Vector3.UP, deg_to_rad(spread_angle)),
			)
	elif _equipped_weapon == &"laser_rifle":
		_spawn_player_projectile(LASER_PROJECTILE_SCENE, forward)
	else:
		_spawn_player_projectile(PROJECTILE_SCENE, forward)
	shot_fired.emit()


func _spawn_player_projectile(projectile_scene: PackedScene, direction: Vector3) -> void:
	var projectile := projectile_scene.instantiate() as Node3D
	projectile.set(&"damage", _next_projectile_damage())
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	projectile.call(&"launch", direction)


func _next_projectile_damage() -> int:
	var damage := 1
	var combined_multiplier := attack_power_multiplier * weapon_damage_multiplier
	_attack_bonus_accumulator += maxf(0.0, combined_multiplier - 1.0)
	if _attack_bonus_accumulator >= 0.9999:
		var bonus_damage := floori(_attack_bonus_accumulator + 0.0001)
		damage += bonus_damage
		_attack_bonus_accumulator -= bonus_damage
	return damage


func _hide_muzzle_flash() -> void:
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false


func _update_crosshair_screen_position() -> void:
	if not is_instance_valid(_crosshair):
		return
	_crosshair.position = get_viewport().get_mouse_position() - _crosshair.size * 0.5


func _current_aim_direction() -> Vector3:
	if _has_aim_world_position:
		var direction := _aim_world_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			return direction.normalized()
	return -global_basis.z


func _exit_tree() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _play_animation(animation_name: StringName) -> void:
	if _animation.current_animation == animation_name and _animation.is_playing():
		return
	_animation.speed_scale = 1.0
	_animation.play(animation_name, 0.12)


func _movement_animation_name() -> StringName:
	var local_velocity := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	if absf(local_velocity.x) > absf(local_velocity.z):
		return &"RunRight" if local_velocity.x > 0.0 else &"RunLeft"
	return &"RunBackward" if local_velocity.z > 0.0 else &"RifleRun"


func _firing_animation_name(is_moving: bool) -> StringName:
	if not is_moving:
		return &"FiringRifleStanding"
	var local_velocity := global_basis.inverse() * Vector3(velocity.x, 0.0, velocity.z)
	if absf(local_velocity.z) >= absf(local_velocity.x) and local_velocity.z < 0.0:
		return &"FiringRifleWalkForward"
	return &"FiringRifleMoving"


func _hold_armed_pose() -> void:
	if _animation.current_animation == &"RifleIdle" and _animation.is_playing():
		return
	_animation.speed_scale = 1.0
	_animation.play(&"RifleIdle", 0.12)


func _install_rifle_animations() -> void:
	var library := _animation.get_animation_library(&"")
	_add_animation_from_scene(library, &"RifleIdle", RIFLE_IDLE_SOURCE)
	_add_animation_from_scene(library, &"RifleRun", RIFLE_RUN_SOURCE)
	_add_animation_from_scene(library, &"RifleWalk", RIFLE_WALK_SOURCE)
	_add_animation_from_scene(library, &"RunBackward", RUN_BACKWARD_SOURCE)
	_add_animation_from_scene(library, &"RunLeft", RUN_LEFT_SOURCE)
	_add_animation_from_scene(library, &"RunRight", RUN_RIGHT_SOURCE)
	_add_animation_from_scene(library, &"FiringRifleStanding", FIRING_RIFLE_STANDING_SOURCE)
	_add_animation_from_scene(library, &"FiringRifleWalkForward", FIRING_RIFLE_WALK_FORWARD_SOURCE)
	_add_animation_from_scene(library, &"FiringRifleMoving", FIRING_RIFLE_MOVING_SOURCE)
	_add_animation_from_scene(library, &"FiringRifleShot", FIRING_RIFLE_SHOT_SOURCE)


func _add_animation_from_scene(
	library: AnimationLibrary,
	animation_name: StringName,
	source_scene: PackedScene,
) -> void:
	var source_root := source_scene.instantiate()
	var source_player := _find_animation_player(source_root)
	var source_skeleton := _find_skeleton(source_root)
	var source_bone_names := _bone_profile_for_skeleton(source_skeleton)
	var source_axis_basis := Basis.IDENTITY
	var source_parent := source_skeleton.get_parent() as Node3D
	if source_parent != null:
		source_axis_basis = source_parent.transform.basis
		_apply_axis_to_root_rest(source_skeleton, source_axis_basis)
	var source_animation := source_player.get_animation(&"mixamo_com")
	var animation := source_animation.duplicate(true) as Animation
	for track_index: int in range(animation.get_track_count() - 1, -1, -1):
		var track_path := animation.track_get_path(track_index)
		if track_path.get_subname_count() == 0:
			animation.remove_track(track_index)
			continue
		var source_bone_name := String(track_path.get_subname(0))
		var profile_bone_name := String(source_bone_names.get(source_bone_name, ""))
		if profile_bone_name.is_empty():
			animation.remove_track(track_index)
			continue
		if animation.track_get_type(track_index) == Animation.TYPE_POSITION_3D:
			animation.remove_track(track_index)
			continue
		if animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
			var source_bone_index := source_skeleton.find_bone(StringName(source_bone_name))
			var target_bone_index := _source_skeleton.find_bone(StringName(profile_bone_name))
			for key_index in animation.track_get_key_count(track_index):
				var source_rotation := animation.track_get_key_value(track_index, key_index) as Quaternion
				var source_pose_basis := Basis(source_rotation)
				if source_skeleton.get_bone_parent(source_bone_index) < 0:
					source_pose_basis = source_axis_basis * source_pose_basis
				animation.track_set_key_value(
					track_index,
					key_index,
					Quaternion(_retarget_pose_basis(
						source_skeleton,
						source_bone_index,
						_source_skeleton,
						target_bone_index,
						source_pose_basis,
					)),
				)
		else:
			animation.remove_track(track_index)
			continue
		animation.track_set_path(track_index, NodePath("Skeleton3D:%s" % profile_bone_name))
	animation.loop_mode = Animation.LOOP_LINEAR
	if library.has_animation(animation_name):
		library.remove_animation(animation_name)
	library.add_animation(animation_name, animation)
	source_root.free()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _setup_animation_retargeting() -> void:
	_skeleton = _find_skeleton(_visual)
	_rename_skeleton_bones(_skeleton, SWAT_PROFILE_BONES)

	_animation_driver = RIFLE_IDLE_SOURCE.instantiate() as Node3D
	_animation_driver.name = "AnimationDriver"
	_visual.add_child(_animation_driver)
	for mesh_node in _animation_driver.find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).visible = false

	var source_skeleton := _find_skeleton(_animation_driver)
	_rename_skeleton_bones(source_skeleton, SWAT_PROFILE_BONES)
	_source_skeleton = source_skeleton
	_animation = _find_animation_player(_animation_driver)

	var retarget_modifier := RetargetModifier3D.new()
	retarget_modifier.name = "SwatRetarget"
	retarget_modifier.profile = SkeletonProfileHumanoid.new()
	retarget_modifier.set_position_enabled(false)
	retarget_modifier.set_scale_enabled(false)
	source_skeleton.add_child(retarget_modifier)
	# The source FBX has a -90-degree Armature node. Preserve the SWAT
	# skeleton's world transform while moving it under the retarget modifier.
	_skeleton.reparent(retarget_modifier, true)


func _apply_rifle_hand_grip() -> void:
	# The animation FBXs leave their finger tracks open. These bones are not part
	# of the humanoid retarget profile, so a persistent local pose safely closes
	# both hands around the trigger grip and foregrip for every locomotion clip.
	for side in [&"Left", &"Right"]:
		var curl_sign := -1.0 if side == &"Left" else 1.0
		for finger in [&"Index", &"Middle", &"Ring", &"Pinky"]:
			_set_finger_curl("mixamorig_%sHand%s1" % [side, finger], curl_sign * 48.0)
			_set_finger_curl("mixamorig_%sHand%s2" % [side, finger], curl_sign * 72.0)
			_set_finger_curl("mixamorig_%sHand%s3" % [side, finger], curl_sign * 58.0)
		_set_finger_curl("mixamorig_%sHandThumb1" % side, curl_sign * 24.0)
		_set_finger_curl("mixamorig_%sHandThumb2" % side, curl_sign * 42.0)
		_set_finger_curl("mixamorig_%sHandThumb3" % side, curl_sign * 34.0)


func _set_finger_curl(bone_name: String, angle_degrees: float) -> void:
	var bone_index := _skeleton.find_bone(StringName(bone_name))
	if bone_index < 0:
		return
	_skeleton.set_bone_pose_rotation(
		bone_index,
		Quaternion(Vector3.FORWARD, deg_to_rad(angle_degrees)),
	)


func _bone_profile_for_skeleton(skeleton: Skeleton3D) -> Dictionary:
	return SWAT_PROFILE_BONES if skeleton.find_bone(&"mixamorig_Hips") >= 0 else SOURCE_PROFILE_BONES


func _apply_axis_to_root_rest(skeleton: Skeleton3D, axis_basis: Basis) -> void:
	if axis_basis.is_equal_approx(Basis.IDENTITY):
		return
	for bone_index in skeleton.get_bone_count():
		if skeleton.get_bone_parent(bone_index) >= 0:
			continue
		var root_rest := skeleton.get_bone_rest(bone_index)
		root_rest = Transform3D(axis_basis * root_rest.basis, axis_basis * root_rest.origin)
		skeleton.set_bone_rest(bone_index, root_rest)


func _retarget_pose_basis(
	source: Skeleton3D,
	source_bone: int,
	target: Skeleton3D,
	target_bone: int,
	source_pose_basis: Basis,
) -> Basis:
	var source_parent_rest := Basis.IDENTITY
	var source_parent := source.get_bone_parent(source_bone)
	if source_parent >= 0:
		source_parent_rest = source.get_bone_global_rest(source_parent).basis
	var target_parent_rest := Basis.IDENTITY
	var target_parent := target.get_bone_parent(target_bone)
	if target_parent >= 0:
		target_parent_rest = target.get_bone_global_rest(target_parent).basis
	return (
		target_parent_rest.inverse()
		* source_parent_rest
		* source_pose_basis
		* source.get_bone_rest(source_bone).basis.inverse()
		* source_parent_rest.inverse()
		* target_parent_rest
		* target.get_bone_rest(target_bone).basis
	)


func _rename_skeleton_bones(skeleton: Skeleton3D, bone_names: Dictionary) -> void:
	var renamed_bones: Dictionary[int, StringName] = {}
	for bone_index in skeleton.get_bone_count():
		var original_name := String(skeleton.get_bone_name(bone_index))
		if bone_names.has(original_name):
			renamed_bones[bone_index] = StringName(bone_names[original_name])

	# Imported skins use named binds, so keep those names synchronized with the
	# runtime profile names before the retarget modifier starts deforming them.
	for mesh_node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.skin == null:
			continue
		var local_skin := mesh_instance.skin.duplicate(true) as Skin
		for bind_index in local_skin.get_bind_count():
			var original_bind_name := String(local_skin.get_bind_name(bind_index))
			if bone_names.has(original_bind_name):
				local_skin.set_bind_name(bind_index, StringName(bone_names[original_bind_name]))
		mesh_instance.skin = local_skin

	# Use temporary unique names so swaps such as Spine -> UpperChest and
	# Spine02 -> Spine cannot collide during the rename operation.
	for bone_index in renamed_bones:
		skeleton.set_bone_name(bone_index, &"__retarget_%d" % bone_index)
	for bone_index in renamed_bones:
		skeleton.set_bone_name(bone_index, renamed_bones[bone_index])


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child: Node in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func _align_gun_to_trigger_hand() -> void:
	if not _alive or _aligning_weapon:
		return
	if _right_hand_bone < 0 or _left_hand_bone < 0:
		return
	_aligning_weapon = true
	_align_gun_pivot_to_trigger_hand()
	_apply_support_hand_pose(_left_grip.global_position)
	_aligning_weapon = false


func _align_gun_pivot_to_trigger_hand() -> void:
	if not _alive or _right_hand_bone < 0:
		return
	var right_hand := (_skeleton.global_transform * _skeleton.get_bone_global_pose(_right_hand_bone)).origin
	# Keep the gun anchored to the trigger hand without touching the support-arm
	# overrides; those are applied once after retargeting to avoid visual flicker.
	var aim_direction := -global_basis.z
	var weapon_basis := Basis.looking_at(aim_direction, Vector3.UP)
	var pivot_origin := right_hand - weapon_basis * _right_grip.position
	_gun_pivot.global_transform = Transform3D(weapon_basis, pivot_origin)


func _apply_support_hand_pose(target_world_position: Vector3) -> void:
	var upper_index := _skeleton.find_bone(&"LeftUpperArm")
	var lower_index := _skeleton.find_bone(&"LeftLowerArm")
	if upper_index < 0 or lower_index < 0 or _left_hand_bone < 0:
		return
	var upper_pose := _skeleton.get_bone_global_pose_no_override(upper_index)
	var lower_pose := _skeleton.get_bone_global_pose_no_override(lower_index)
	var hand_pose := _skeleton.get_bone_global_pose_no_override(_left_hand_bone)
	var shoulder := upper_pose.origin
	var elbow := lower_pose.origin
	var hand := hand_pose.origin
	var target := _skeleton.to_local(target_world_position)
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(hand)
	var target_offset := target - shoulder
	var target_distance := clampf(
		target_offset.length(),
		absf(upper_length - lower_length) + 0.001,
		upper_length + lower_length - 0.001,
	)
	if target_distance <= 0.001:
		return
	var reach_direction := target_offset.normalized()
	var current_bend := elbow - shoulder
	current_bend -= reach_direction * current_bend.dot(reach_direction)
	if current_bend.length_squared() <= 0.0001:
		current_bend = Vector3.LEFT
	var bend_direction := current_bend.normalized()
	var shoulder_cosine := clampf(
		(upper_length * upper_length + target_distance * target_distance - lower_length * lower_length)
		/ (2.0 * upper_length * target_distance),
		-1.0,
		1.0,
	)
	var shoulder_sine := sqrt(maxf(0.0, 1.0 - shoulder_cosine * shoulder_cosine))
	var desired_elbow := shoulder
	desired_elbow += reach_direction * shoulder_cosine * upper_length
	desired_elbow += bend_direction * shoulder_sine * upper_length
	var upper_delta := Quaternion((elbow - shoulder).normalized(), (desired_elbow - shoulder).normalized())
	upper_pose.basis = Basis(upper_delta) * upper_pose.basis
	var lower_delta := Quaternion((hand - elbow).normalized(), (target - desired_elbow).normalized())
	lower_pose.origin = desired_elbow
	lower_pose.basis = Basis(lower_delta) * lower_pose.basis
	hand_pose.origin = target
	# Keep the final support-arm pose active until the next post-retarget update.
	# A non-persistent override briefly exposed the animation pose between updates,
	# which made the left hand visibly flicker on and off the foregrip.
	_skeleton.set_bone_global_pose_override(upper_index, upper_pose, 1.0, true)
	_skeleton.set_bone_global_pose_override(lower_index, lower_pose, 1.0, true)
	_skeleton.set_bone_global_pose_override(_left_hand_bone, hand_pose, 1.0, true)
