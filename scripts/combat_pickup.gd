class_name RiverCombatPickup
extends Area3D

enum PickupType { HEALTH, AMMO }

@export var pickup_type: PickupType = PickupType.HEALTH
@export var health_amount: int = 20
@export var ammo_amount: int = 15
@export_range(1.0, 120.0, 1.0) var lifetime_seconds: float = 25.0

@onready var _visual_pivot: Node3D = $VisualPivot
@onready var _placeholder_mesh: MeshInstance3D = $VisualPivot/PlaceholderMesh
@onready var _ammo_model: Node3D = $VisualPivot/AmmoModel
@onready var _health_model: Node3D = $VisualPivot/HealthModel
@onready var _light: OmniLight3D = $Light
@onready var _pickup_collision: CollisionShape3D = $Collision

var _collected: bool = false
var _animation_time: float = 0.0
var _visual_base_height: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_pickup_appearance()
	_visual_base_height = _visual_pivot.position.y
	get_tree().create_timer(lifetime_seconds).timeout.connect(_expire)


func _process(delta: float) -> void:
	_animation_time += delta
	_visual_pivot.rotate_y(delta * 0.8)
	_visual_pivot.position.y = _visual_base_height + sin(_animation_time * 2.0) * 0.08


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is RiverBoundPlayer:
		return
	_collected = true
	var player := body as RiverBoundPlayer
	if pickup_type == PickupType.HEALTH:
		player.heal(health_amount)
	else:
		player.add_ammo(ammo_amount)
	queue_free()


func _apply_pickup_appearance() -> void:
	var color := Color(0.2, 1.0, 0.38) if pickup_type == PickupType.HEALTH else Color(1.0, 0.7, 0.12)
	_ammo_model.visible = pickup_type == PickupType.AMMO
	_health_model.visible = pickup_type == PickupType.HEALTH
	_placeholder_mesh.visible = false
	_light.light_color = color
	if pickup_type == PickupType.HEALTH:
		var health_shape := _pickup_collision.shape.duplicate(true) as SphereShape3D
		health_shape.radius = 1.25
		_pickup_collision.shape = health_shape


func _expire() -> void:
	if is_inside_tree() and not _collected:
		queue_free()
