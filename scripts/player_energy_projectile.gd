class_name PlayerEnergyProjectile
extends Area3D

signal impacted(hit_position: Vector3)

@export var speed: float = 48.0
@export var damage: int = 1
@export var lifetime: float = 0.9

@onready var _effect: Node3D = $Effect
@onready var _collision: CollisionShape3D = $Collision
@onready var _impact_audio: AudioStreamPlayer3D = $ImpactAudio

var _direction: Vector3 = Vector3.FORWARD
var _remaining_lifetime: float
var _finished: bool = false


func _ready() -> void:
	add_to_group(&"projectiles")
	add_to_group(&"player_energy_projectiles")
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
		queue_free()
		return
	var start := global_position
	var destination := start + _direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(start, destination, collision_mask)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
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
	if body != null and body.has_method(&"take_projectile_hit"):
		body.call(&"take_projectile_hit", damage, global_position)
	_finished = true
	set_deferred(&"monitoring", false)
	_collision.set_deferred(&"disabled", true)
	_effect.visible = false
	impacted.emit(global_position)
	_impact_audio.play()
	await get_tree().create_timer(_impact_audio.stream.get_length()).timeout
	queue_free()
