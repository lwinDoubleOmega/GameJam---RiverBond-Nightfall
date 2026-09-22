class_name RiverRangedProjectile
extends Area3D

signal impacted(hit_position: Vector3)

@export var speed: float = 13.0
@export var damage: int = 1
@export var lifetime: float = 3.0

var _direction: Vector3 = Vector3.FORWARD
var _target_snapshot: Vector3 = Vector3.ZERO
var _remaining_lifetime: float
var _finished: bool = false


func _ready() -> void:
	add_to_group(&"enemy_projectiles")
	_remaining_lifetime = lifetime
	body_entered.connect(_on_body_entered)


func launch_toward(target_position: Vector3) -> void:
	_target_snapshot = target_position
	_direction = (target_position - global_position).normalized()
	if _direction.length_squared() > 0.0:
		look_at(global_position + _direction, Vector3.UP)


func travel_direction() -> Vector3:
	return _direction


func target_snapshot() -> Vector3:
	return _target_snapshot


func _physics_process(delta: float) -> void:
	if _finished:
		return
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		_finish()
		return

	# Direction is calculated exactly once in launch_toward(). Player movement
	# after firing cannot steer this projectile like a homing missile.
	var start := global_position
	var destination := start + _direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(start, destination, collision_mask)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_hit(hit["collider"])
		return
	global_position = destination


func _on_body_entered(body: Node3D) -> void:
	_hit(body)


func _hit(body: Object) -> void:
	if _finished:
		return
	if body != null and body.has_method(&"take_damage"):
		body.call(&"take_damage", damage)
	impacted.emit(global_position)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_deferred(&"monitoring", false)
	queue_free()
