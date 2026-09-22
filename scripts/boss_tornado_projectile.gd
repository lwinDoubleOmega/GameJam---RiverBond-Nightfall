class_name RiverBossTornadoProjectile
extends Area3D

@export var speed: float = 4.8
@export var damage: int = 1
@export var lifetime: float = 18.0

@onready var _source: Node3D = $Visual/TornadoSource

var _direction: Vector3 = Vector3.FORWARD
var _remaining_lifetime: float
var _has_been_visible: bool = false
var _damaged_player: bool = false


func _ready() -> void:
	add_to_group(&"enemy_projectiles")
	add_to_group(&"boss_tornado_projectiles")
	_remaining_lifetime = lifetime
	body_entered.connect(_on_body_entered)
	_prepare_blue_tornado()


func launch(direction: Vector3) -> void:
	_direction = direction.normalized()
	if _direction.length_squared() > 0.0:
		look_at(global_position + _direction, Vector3.UP)


func travel_direction() -> Vector3:
	return _direction


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()
		return
	# Tornadoes intentionally use no raycast or collision response, allowing them
	# to pass through props, buildings, regular enemies, and the player.
	global_position += _direction * speed * delta
	_update_screen_lifetime()


func _on_body_entered(body: Node3D) -> void:
	if _damaged_player or not body is RiverBoundPlayer:
		return
	_damaged_player = true
	(body as RiverBoundPlayer).take_damage(damage)


func _update_screen_lifetime() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_position_behind(global_position):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var screen_position := camera.unproject_position(global_position)
	var screen_bounds := Rect2(Vector2(-120.0, -120.0), viewport_size + Vector2(240.0, 240.0))
	if screen_bounds.has_point(screen_position):
		_has_been_visible = true
	elif _has_been_visible:
		queue_free()


func _prepare_blue_tornado() -> void:
	var poison := _source.get_node_or_null("tornado poison") as Node3D
	var fire := _source.get_node_or_null("tornado fire") as Node3D
	if poison != null:
		poison.visible = false
	if fire != null:
		fire.visible = false
	var demo_environment := _source.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if demo_environment != null:
		demo_environment.environment = null
	var demo_camera := _source.get_node_or_null("Camera3D") as Camera3D
	if demo_camera != null:
		demo_camera.current = false
