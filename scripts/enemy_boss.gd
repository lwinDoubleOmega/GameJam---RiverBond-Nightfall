class_name RiverBossMonster
extends RiverMonster

const RADIAL_PROJECTILE_SCENE := preload("res://scenes/boss_radial_projectile.tscn")
const TORNADO_PROJECTILE_SCENE := preload("res://scenes/boss_tornado_projectile.tscn")
const RADIAL_DIRECTIONS := 8
const RADIAL_PULSE_COUNT := 3
const RADIAL_PULSE_INTERVAL := 0.24
const TORNADO_SPREAD_ANGLES := [-30.0, -15.0, 0.0, 15.0, 30.0]
const BOSS_ATTACK_ANIMATION_SPEED := 1.15
const BOSS_HEALTH_BAR_FILL_WIDTH := 1.46
const BOSS_DEATH_REST_TIME := 0.65

@onready var _projectile_origin: Marker3D = $ProjectileOrigin
@onready var _tornado_origin: Marker3D = $TornadoOrigin

var _next_attack_is_radial: bool = true
var _radial_pulses_remaining: int = 0
var _attack_spawn_timer: float = 0.0
var _tornado_volley_pending: bool = false
var _attack_target_snapshot: Vector3 = Vector3.ZERO
func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"boss_enemies")
	_normal_collision_mask = collision_mask
	_health = maximum_health
	_prepare_runtime_animations()
	_prepare_visual_materials()
	_prepare_health_bar()
	health_changed.emit(_health, maximum_health)
	_target = get_tree().get_first_node_in_group(&"player") as RiverBoundPlayer
	_state = State.CHASE
	_play_animation(&"Walking", 1.05)


func _update_chase() -> void:
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
			_play_animation(&"Walking", 0.72)
		return
	velocity = _crowd_movement_direction(offset) * movement_speed
	if distance > 0.01:
		look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
	move_and_slide()
	_play_animation(&"Walking", 1.05)


func _start_attack() -> void:
	_state = State.ATTACK
	_active_attack_animation = &"Right_Hand_Sword_Slash"
	_state_timer = maxf(_animation_duration(_active_attack_animation, BOSS_ATTACK_ANIMATION_SPEED), 1.15)
	velocity = Vector3.ZERO
	_attack_target_snapshot = _target.global_position
	_attack_audio.pitch_scale = 0.82 if _next_attack_is_radial else 0.72
	_attack_audio.play()
	_play_animation(_active_attack_animation, BOSS_ATTACK_ANIMATION_SPEED)
	if _next_attack_is_radial:
		_radial_pulses_remaining = RADIAL_PULSE_COUNT
		_attack_spawn_timer = 0.24
		_tornado_volley_pending = false
	else:
		_radial_pulses_remaining = 0
		_attack_spawn_timer = 0.32
		_tornado_volley_pending = true
	_next_attack_is_radial = not _next_attack_is_radial


func _update_attack(delta: float) -> void:
	_state_timer -= delta
	_attack_spawn_timer -= delta
	if _radial_pulses_remaining > 0 and _attack_spawn_timer <= 0.0:
		_spawn_radial_pulse()
		_radial_pulses_remaining -= 1
		_attack_spawn_timer = RADIAL_PULSE_INTERVAL
	elif _tornado_volley_pending and _attack_spawn_timer <= 0.0:
		_spawn_tornado_fan()
		_tornado_volley_pending = false
	if _state_timer <= 0.0 and _radial_pulses_remaining <= 0 and not _tornado_volley_pending:
		_state = State.CHASE
		_cooldown_timer = randf_range(2.0, 3.0)


func _spawn_radial_pulse() -> void:
	for direction_index in RADIAL_DIRECTIONS:
		var angle := TAU * float(direction_index) / float(RADIAL_DIRECTIONS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var projectile := RADIAL_PROJECTILE_SCENE.instantiate() as RiverRangedProjectile
		_projectile_parent().add_child(projectile)
		projectile.global_position = _projectile_origin.global_position
		projectile.launch_toward(projectile.global_position + direction * 100.0)


func _spawn_tornado_fan() -> void:
	var direction := _attack_target_snapshot - _tornado_origin.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = -global_basis.z
	direction = direction.normalized()
	for spread_angle: float in TORNADO_SPREAD_ANGLES:
		var tornado := TORNADO_PROJECTILE_SCENE.instantiate() as RiverBossTornadoProjectile
		_projectile_parent().add_child(tornado)
		tornado.global_position = _tornado_origin.global_position
		tornado.launch(direction.rotated(Vector3.UP, deg_to_rad(spread_angle)))


func _projectile_parent() -> Node:
	var parent := get_tree().current_scene
	return parent if parent != null else get_parent()


func take_projectile_hit(amount: int, _hit_position: Vector3) -> void:
	if _state == State.DEAD:
		return
	# The boss deliberately ignores hit-stun and continues its current action.
	_health = maxi(0, _health - amount)
	_update_health_bar()
	health_changed.emit(_health, maximum_health)
	if _health == 0:
		_die()


func _die() -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	print("FINAL BOSS DIED")
	velocity = Vector3.ZERO
	_collision.set_deferred(&"disabled", true)
	collision_layer = 0
	collision_mask = 0
	_attack_audio.stop()
	_death_audio.play()
	_health_bar.visible = false
	_play_animation(&"Shot_and_Fall_Backward", 0.82)
	await get_tree().create_timer(
		_animation_duration(&"Shot_and_Fall_Backward", 0.82) + BOSS_DEATH_REST_TIME
	).timeout
	defeated.emit()
	queue_free()


func _prepare_runtime_animations() -> void:
	var library := _animation.get_animation_library(&"")
	for animation_name: StringName in [
		&"Walking",
		&"Right_Hand_Sword_Slash",
		&"Shot_and_Fall_Backward",
	]:
		var source := _animation.get_animation(animation_name)
		if source == null:
			continue
		var animation := source.duplicate(true) as Animation
		_lock_horizontal_hips(animation)
		if animation_name == &"Walking":
			animation.loop_mode = Animation.LOOP_LINEAR
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)


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
		var visible_width := BOSS_HEALTH_BAR_FILL_WIDTH * maxf(0.001, ratio)
		_health_bar_fill_mesh.size.x = visible_width
		_health_bar_fill_mesh.center_offset.x = -(BOSS_HEALTH_BAR_FILL_WIDTH - visible_width) * 0.5
	if _health_bar_material != null:
		_health_bar_material.albedo_color = (
			Color(0.95, 0.16, 0.08) if ratio < 0.5 else Color(0.22, 0.7, 1.0)
		)
