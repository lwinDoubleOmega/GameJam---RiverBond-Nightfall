class_name RiverMonster
extends CharacterBody3D

const PICKUP_SCENE := preload("res://scenes/combat_pickup.tscn")
const AMMO_DROP_CHANCE := 0.50
const HEALTH_DROP_CHANCE := 0.10

signal health_changed(current: int, maximum: int)
signal defeated

enum State {
	SPAWN,
	CHASE,
	ATTACK,
	HIT,
	DEAD,
}

@export var maximum_health: int = 3
@export var movement_speed: float = 2.15
@export var attack_range: float = 1.25
@export var attack_damage: int = 1
@export var attack_cooldown: float = 0.8

const ATTACK_DAMAGE_NORMALIZED_TIME := 0.28
const DEATH_REST_TIME := 0.3
const INJURED_SPEED_MULTIPLIER := 0.8
const ATTACK_ANIMATION_SPEED := 1.8
const HEALTH_BAR_FILL_WIDTH := 1.04
const RIVER_HITBOX_LIFT := 0.4
const ENEMY_SEPARATION_RADIUS := 1.7
const ENEMY_SEPARATION_WEIGHT := 1.05
const CROWD_LANE_WEIGHT := 0.8
const MINIMUM_FORWARD_STEERING := 0.35

@onready var _animation: AnimationPlayer = $Visual/AnimationPlayer
@onready var _collision: CollisionShape3D = $Collision
@onready var _attack_audio: AudioStreamPlayer3D = $AttackAudio
@onready var _death_audio: AudioStreamPlayer3D = $DeathAudio
@onready var _health_bar: Node3D = $HealthBar
@onready var _health_bar_fill: MeshInstance3D = $HealthBar/Fill

var _health: int
var _target: RiverBoundPlayer
var _state: State = State.SPAWN
var _state_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _attack_connected: bool = false
var _attack_pitch_index: int = 0
var _next_attack_is_sword: bool = true
var _active_attack_animation: StringName = &"Right_Hand_Sword_Slash"
var _health_bar_material: StandardMaterial3D
var _health_bar_fill_mesh: QuadMesh
var _emerging_from_river: bool = false
var _river_exit: Vector3 = Vector3.ZERO
var _normal_collision_mask: int
var _river_hitbox_lifted: bool = false
var _nearby_enemy_count: int = 0


func _ready() -> void:
	add_to_group("enemies")
	_normal_collision_mask = collision_mask
	_emerging_from_river = bool(get_meta(&"spawned_in_river", false))
	if _emerging_from_river:
		_river_exit = get_meta(&"river_exit", global_position) as Vector3
		# Ignore the riverbank only while taking the authored route out. The
		# enemy's collision layer remains active, so projectiles can still hit it.
		# Ignore the world while crossing the embankment, but continue colliding
		# with other enemies so multiple river spawns cannot stack together.
		collision_mask = 2
		_lift_river_hitbox()
	_health = maximum_health
	_prepare_runtime_animations()
	_prepare_visual_materials()
	_prepare_health_bar()
	health_changed.emit(_health, maximum_health)
	_target = get_tree().get_first_node_in_group("player") as RiverBoundPlayer
	_state_timer = _animation_duration(&"Arise", 1.0)
	_play_animation(&"Arise")


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	if _state == State.SPAWN:
		_update_spawn(delta)
		return
	if not is_instance_valid(_target) or not _target.is_alive():
		velocity = Vector3.ZERO
		return

	match _state:
		State.HIT:
			_update_hit(delta)
		State.ATTACK:
			_update_attack(delta)
		State.CHASE:
			_update_chase()


func take_projectile_hit(amount: int, _hit_position: Vector3) -> void:
	if _state == State.DEAD:
		return
	_health = maxi(0, _health - amount)
	_update_health_bar()
	health_changed.emit(_health, maximum_health)
	if _health == 0:
		_die()
		return
	_state = State.HIT
	_state_timer = _animation_duration(&"Hit_Reaction", 1.5)
	velocity = Vector3.ZERO
	_play_animation("Hit_Reaction", 1.5)


func current_health() -> int:
	return _health


func current_state_name() -> String:
	return State.keys()[_state]


func current_animation_name() -> StringName:
	return _animation.current_animation


func _update_spawn(delta: float) -> void:
	velocity = Vector3.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.CHASE


func _update_chase() -> void:
	if _emerging_from_river:
		_update_river_emergence()
		return
	var offset := _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= attack_range and _cooldown_timer <= 0.0:
		_start_attack()
		return
	if distance > 0.01:
		var active_speed := movement_speed
		if _is_injured():
			active_speed *= INJURED_SPEED_MULTIPLIER
		velocity = _crowd_movement_direction(offset) * active_speed
		look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	if _is_injured():
		_play_animation(&"Unsteady_Walk", 1.35)
	else:
		_play_animation(&"Running", 1.35)


func _update_river_emergence() -> void:
	var offset := _river_exit - global_position
	# The river route ends at a plane, not one exact point. Keeping each enemy's
	# lateral position prevents a whole crowd from being snapped into one stack.
	if global_position.x >= _river_exit.x - 0.25:
		global_position = Vector3(maxf(global_position.x, _river_exit.x), _river_exit.y, global_position.z)
		_emerging_from_river = false
		collision_mask = _normal_collision_mask
		_restore_river_hitbox()
		velocity = Vector3.ZERO
		return
	velocity = _crowd_movement_direction(offset) * movement_speed
	var horizontal_offset := Vector2(offset.x, offset.z)
	if horizontal_offset.length_squared() > 0.001:
		look_at(Vector3(_river_exit.x, global_position.y, _river_exit.z), Vector3.UP)
	move_and_slide()
	_play_animation(&"Running", 1.35)


func _lift_river_hitbox() -> void:
	if _river_hitbox_lifted:
		return
	_collision.position.y += RIVER_HITBOX_LIFT
	_river_hitbox_lifted = true


func _restore_river_hitbox() -> void:
	if not _river_hitbox_lifted:
		return
	_collision.position.y -= RIVER_HITBOX_LIFT
	_river_hitbox_lifted = false


func _enemy_separation_direction() -> Vector3:
	var separation := Vector3.ZERO
	_nearby_enemy_count = 0
	for enemy_node in get_tree().get_nodes_in_group(&"enemies"):
		if enemy_node == self or not enemy_node is CharacterBody3D:
			continue
		if enemy_node is RiverMonster and (enemy_node as RiverMonster)._state == State.DEAD:
			continue
		var away := global_position - (enemy_node as CharacterBody3D).global_position
		away.y = 0.0
		var distance_squared := away.length_squared()
		if distance_squared >= ENEMY_SEPARATION_RADIUS * ENEMY_SEPARATION_RADIUS:
			continue
		_nearby_enemy_count += 1
		if distance_squared <= 0.0001:
			# Deterministic fallback separates bodies that begin at the exact same
			# transform instead of leaving their steering vector undefined.
			var angle := deg_to_rad(float(get_instance_id() % 360))
			away = Vector3(cos(angle), 0.0, sin(angle))
			separation += away
			continue
		var distance := sqrt(distance_squared)
		separation += away / distance * (1.0 - distance / ENEMY_SEPARATION_RADIUS)
	return separation.limit_length(1.0)


func _crowd_movement_direction(target_offset: Vector3) -> Vector3:
	var desired := target_offset.normalized()
	if desired.length_squared() <= 0.001:
		return Vector3.ZERO
	var separation := _enemy_separation_direction()
	var crowd_ratio := clampf(float(_nearby_enemy_count) / 5.0, 0.0, 1.0)
	# Split a blocked crowd into stable left/right flow lanes. Without this
	# tangent, symmetric separation can cancel out and every body waits forever.
	var lane_side := -1.0 if get_instance_id() % 2 == 0 else 1.0
	var tangent := Vector3(-desired.z, 0.0, desired.x) * lane_side
	var steering := desired + separation * ENEMY_SEPARATION_WEIGHT
	steering += tangent * crowd_ratio * CROWD_LANE_WEIGHT
	# Separation may slow pursuit, but it must never reverse it. Enemies continue
	# advancing while sliding sideways around bodies in front of them.
	var forward_amount := steering.dot(desired)
	if forward_amount < MINIMUM_FORWARD_STEERING:
		steering += desired * (MINIMUM_FORWARD_STEERING - forward_amount)
	return steering.normalized()


func _start_attack() -> void:
	_state = State.ATTACK
	_active_attack_animation = (
		&"Right_Hand_Sword_Slash" if _next_attack_is_sword else &"Shield_Push_Left"
	)
	_next_attack_is_sword = not _next_attack_is_sword
	_state_timer = _animation_duration(_active_attack_animation, ATTACK_ANIMATION_SPEED)
	_attack_connected = false
	velocity = Vector3.ZERO
	var pitch_cycle := [0.95, 1.02]
	_attack_audio.pitch_scale = pitch_cycle[_attack_pitch_index % pitch_cycle.size()]
	_attack_pitch_index += 1
	_attack_audio.play()
	_play_animation(_active_attack_animation, ATTACK_ANIMATION_SPEED)


func _update_attack(delta: float) -> void:
	_state_timer -= delta
	var duration := _animation_duration(_active_attack_animation, ATTACK_ANIMATION_SPEED)
	var damage_time_remaining := duration * (1.0 - ATTACK_DAMAGE_NORMALIZED_TIME)
	if not _attack_connected and _state_timer <= damage_time_remaining:
		_attack_connected = true
		if global_position.distance_to(_target.global_position) <= attack_range + 0.25:
			_target.take_damage(attack_damage)
	if _state_timer <= 0.0:
		_state = State.CHASE
		_cooldown_timer = attack_cooldown


func _update_hit(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.CHASE


func _die() -> void:
	_state = State.DEAD
	velocity = Vector3.ZERO
	_collision.set_deferred("disabled", true)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	_attack_audio.stop()
	_death_audio.play()
	_health_bar.visible = false
	_play_animation(&"Shot_and_Slow_Fall_Backward", 1.35)
	_try_drop_pickup()
	defeated.emit()
	await get_tree().create_timer(_animation_duration(&"Shot_and_Slow_Fall_Backward", 1.35) + DEATH_REST_TIME).timeout
	queue_free()


func _try_drop_pickup() -> void:
	var drop_roll := randf()
	var pickup_type := RiverCombatPickup.PickupType.AMMO
	if drop_roll < AMMO_DROP_CHANCE:
		pickup_type = RiverCombatPickup.PickupType.AMMO
	elif drop_roll < AMMO_DROP_CHANCE + HEALTH_DROP_CHANCE:
		pickup_type = RiverCombatPickup.PickupType.HEALTH
	else:
		return
	var pickup := PICKUP_SCENE.instantiate() as RiverCombatPickup
	pickup.pickup_type = pickup_type
	var pickup_parent := get_tree().current_scene
	if pickup_parent == null:
		pickup_parent = get_parent()
	pickup_parent.add_child(pickup)
	pickup.global_position = global_position + Vector3(0.0, 0.45, 0.0)


func _play_animation(animation_name: StringName, speed: float = 1.0) -> void:
	if _animation.current_animation == animation_name and _animation.is_playing():
		return
	_animation.speed_scale = speed
	_animation.play(animation_name, 0.12)


func _animation_duration(animation_name: StringName, speed: float) -> float:
	var animation := _animation.get_animation(animation_name)
	if animation == null or speed <= 0.0:
		return 0.0
	return animation.length / speed


func _prepare_runtime_animations() -> void:
	var library := _animation.get_animation_library(&"")
	for animation_name: StringName in [
		&"Arise",
		&"Unsteady_Walk",
		&"Running",
		&"Walking",
		&"Right_Hand_Sword_Slash",
		&"Shield_Push_Left",
		&"Hit_Reaction",
		&"Shot_and_Slow_Fall_Backward",
	]:
		var source := _animation.get_animation(animation_name)
		if source == null:
			continue
		var animation := source.duplicate(true) as Animation
		_lock_horizontal_hips(animation)
		if animation_name in [&"Unsteady_Walk", &"Running", &"Walking"]:
			animation.loop_mode = Animation.LOOP_LINEAR
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)


func _prepare_visual_materials() -> void:
	# The imported alpha-depth material samples black transparent atlas pixels at
	# UV borders, creating dark streaks on the animated skin. Give each enemy a
	# local hard-cutout material so transparent texels cannot bleed onto the mesh.
	for mesh_node in $Visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.get_active_material(surface_index)
			if not source_material is BaseMaterial3D:
				continue
			var material := source_material.duplicate(true) as BaseMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.45
			mesh_instance.set_surface_override_material(surface_index, material)


func _is_injured() -> bool:
	return _health * 2 < maximum_health


func _prepare_health_bar() -> void:
	_health_bar_fill_mesh = _health_bar_fill.mesh.duplicate(true) as QuadMesh
	_health_bar_fill.mesh = _health_bar_fill_mesh
	var source_material := _health_bar_fill.get_active_material(0) as StandardMaterial3D
	_health_bar_material = source_material.duplicate(true) as StandardMaterial3D
	_health_bar_fill.material_override = _health_bar_material
	_update_health_bar()


func _update_health_bar() -> void:
	if _health_bar_fill == null:
		return
	var ratio := clampf(float(_health) / float(maxi(1, maximum_health)), 0.0, 1.0)
	if _health_bar_fill_mesh != null:
		var visible_width := HEALTH_BAR_FILL_WIDTH * maxf(0.001, ratio)
		_health_bar_fill_mesh.size.x = visible_width
		# Keep the left edge fixed so lost health drains from right to left.
		_health_bar_fill_mesh.center_offset.x = -(HEALTH_BAR_FILL_WIDTH - visible_width) * 0.5
	if _health_bar_material != null:
		_health_bar_material.albedo_color = (
			Color(0.95, 0.16, 0.08) if ratio < 0.5 else Color(0.18, 0.92, 0.22)
		)


func _lock_horizontal_hips(animation: Animation) -> void:
	for track_index: int in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track_index)).ends_with(":Hips"):
			continue
		var initial := animation.position_track_interpolate(track_index, 0.0)
		for key_index: int in animation.track_get_key_count(track_index):
			var value := animation.track_get_key_value(track_index, key_index) as Vector3
			value.x = initial.x
			value.z = initial.z
			animation.track_set_key_value(track_index, key_index, value)
