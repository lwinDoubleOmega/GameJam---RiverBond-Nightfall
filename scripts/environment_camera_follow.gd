extends Node3D

@export var target: Node3D
@export var follow_speed: float = 14.0


func _process(delta: float) -> void:
	if target == null:
		return
	position.x = move_toward(position.x, target.global_position.x, follow_speed * delta)
	position.z = move_toward(position.z, target.global_position.z, follow_speed * delta)
