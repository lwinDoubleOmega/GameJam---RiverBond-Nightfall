class_name RiverRangedMonster
extends RiverMonster

const RANGED_PROJECTILE_SCENE := preload("res://scenes/enemy_ranged_projectile.tscn")
const BURST_SIZE := 3
const BURST_INTERVAL := 0.16
const RANGED_ATTACK_ANIMATION_SPEED := 1.4
const DEATH_FADE_DELAY := 0.8
const DEATH_FADE_DURATION := 2.4

@onready var _projectile_origin: Marker3D = $ProjectileOrigin

var _burst_shots_remaining: int = 0
var _burst_timer: float = 0.0
var _burst_target_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"ranged_enemies")
	_normal_collision_mask = collision_mask
	_emerging_from_river = bool(get_meta(&"spawned_in_river", false))
	if _emerging_from_river:
		_river_exit = get_meta(&"river_exit", global_position) as Vector3
		collision_mask = 2
		_lift_river_hitbox()
	_health = maximum_health
	_prepare_runtime_animations()
	_prepare_visual_materials()
	_prepare_health_bar()
	health_changed.emit(_health, maximum_health)
	_target = get_tree().get_first_node_in_group(&"player") as RiverBoundPlayer
	_state = State.CHASE
	_play_animation(&"Unsteady_Walk", 1.2)


func _update_chase() -> void:
	if _emerging_from_river:
		_update_river_emergence()
		return
	var offset := _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= attack_range:
		velocity = Vector3.ZERO
		if distance > 0.01:
			look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
		if _cooldown_timer <= 0.0:
			_start_attack()
		else:
			_play_animation(&"Unsteady_Walk", 1.2)
		return
	velocity = _crowd_movement_direction(offset) * movement_speed
	if distance > 0.01:
		look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
	move_and_slide()
	_play_animation(&"Unsteady_Walk", 1.2)


func _update_river_emergence() -> void:
	var offset := _river_exit - global_position
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
	_play_animation(&"Unsteady_Walk", 1.2)


func _start_attack() -> void:
	_state = State.ATTACK
	_active_attack_animation = &"Right_Hand_Sword_Slash"
	_state_timer = _animation_duration(_active_attack_animation, RANGED_ATTACK_ANIMATION_SPEED)
	velocity = Vector3.ZERO
	_burst_target_position = _target.global_position + Vector3(0.0, 0.82, 0.0)
	_burst_shots_remaining = BURST_SIZE
	_burst_timer = minf(0.22, _state_timer * 0.25)
	_attack_audio.pitch_scale = 1.04
	_attack_audio.play()
	_play_animation(_active_attack_animation, RANGED_ATTACK_ANIMATION_SPEED)


func _update_attack(delta: float) -> void:
	_state_timer -= delta
	_burst_timer -= delta
	if _burst_shots_remaining > 0 and _burst_timer <= 0.0:
		_spawn_ranged_projectile()
		_burst_shots_remaining -= 1
		_burst_timer = BURST_INTERVAL
	if _state_timer <= 0.0 and _burst_shots_remaining <= 0:
		_state = State.CHASE
		_cooldown_timer = attack_cooldown


func _spawn_ranged_projectile() -> void:
	var projectile := RANGED_PROJECTILE_SCENE.instantiate() as RiverRangedProjectile
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	projectile_parent.add_child(projectile)
	projectile.global_position = _projectile_origin.global_position
	projectile.launch_toward(_burst_target_position)


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
	_state_timer = _animation_duration(&"Hit_Reaction_with_Bow", 1.35)
	velocity = Vector3.ZERO
	_play_animation(&"Hit_Reaction_with_Bow", 1.35)


func _die() -> void:
	_state = State.DEAD
	velocity = Vector3.ZERO
	_collision.set_deferred(&"disabled", true)
	collision_layer = 0
	collision_mask = 0
	_attack_audio.stop()
	_death_audio.play()
	_health_bar.visible = false
	_play_animation(&"Shot_and_Slow_Fall_Backward", 1.0)
	var fade_tween := create_tween()
	fade_tween.tween_interval(DEATH_FADE_DELAY)
	fade_tween.set_parallel(true)
	for mesh_node in $Visual.find_children("*", "MeshInstance3D", true, false):
		fade_tween.tween_property(mesh_node, ^"transparency", 1.0, DEATH_FADE_DURATION)
	_try_drop_pickup()
	defeated.emit()
	await fade_tween.finished
	queue_free()


func _prepare_runtime_animations() -> void:
	var library := _animation.get_animation_library(&"")
	for animation_name: StringName in [
		&"Unsteady_Walk",
		&"Right_Hand_Sword_Slash",
		&"Hit_Reaction_with_Bow",
		&"Shot_and_Slow_Fall_Backward",
	]:
		if not library.has_animation(animation_name):
			continue
		var source := library.get_animation(animation_name)
		var animation := source.duplicate(true) as Animation
		_lock_horizontal_hips(animation)
		if animation_name == &"Unsteady_Walk":
			animation.loop_mode = Animation.LOOP_LINEAR
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)
