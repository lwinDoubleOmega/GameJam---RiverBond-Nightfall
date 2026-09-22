class_name RiverBoundProjectile
extends Area3D

signal impacted(hit_position: Vector3)

@export var speed: float = 46.0
@export var damage: int = 1
@export var lifetime: float = 0.55

@onready var _flight_visual: Node3D = $FlightVisual
@onready var _impact_visual: Node3D = $ImpactVisual
@onready var _impact_sparks: GPUParticles3D = $ImpactVisual/Sparks
@onready var _collision: CollisionShape3D = $Collision
@onready var _impact_audio: AudioStreamPlayer3D = $ImpactAudio

var _direction: Vector3 = Vector3.FORWARD
var _remaining_lifetime: float
var _finished: bool = false


func _ready() -> void:
	add_to_group(&"projectiles")
	_remaining_lifetime = lifetime
	body_entered.connect(_on_body_entered)


func launch(direction: Vector3) -> void:
	_direction = direction.normalized()
	if _direction.length_squared() > 0.0:
		look_at(global_position + _direction, Vector3.UP)


func travel_direction() -> Vector3:
	return _direction


func _physics_process(delta: float) -> void:
	if _finished:
		return

	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		_finish()
		return

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
	if body != null and body.has_method("take_projectile_hit"):
		body.call("take_projectile_hit", damage, global_position)
	_impact()


func _impact() -> void:
	if _finished:
		return
	_finished = true
	set_deferred(&"monitoring", false)
	_collision.set_deferred(&"disabled", true)
	_flight_visual.visible = false
	_impact_visual.visible = true
	_impact_sparks.emitting = true
	_impact_audio.play()
	impacted.emit(global_position)
	var tween := create_tween()
	tween.tween_property(_impact_visual, ^"scale", Vector3(1.8, 1.8, 1.8), 0.08)
	var remaining_audio_time := maxf(0.0, _impact_audio.stream.get_length() - 0.08)
	tween.tween_interval(remaining_audio_time)
	tween.tween_callback(queue_free)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	queue_free()
