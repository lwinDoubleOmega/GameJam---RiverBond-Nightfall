class_name RiverBoundOcclusionFade
extends Node

@export var target: Node3D
@export var camera: Camera3D
@export var building_root: Node3D
@export var additional_building_root: Node3D
@export_range(0.1, 1.0, 0.05) var faded_alpha: float = 0.38

var _building_meshes: Dictionary = {}
var _faded_buildings: Dictionary = {}

func _ready() -> void:
	if building_root == null:
		return
	for building in building_root.get_children():
		if building is Node3D:
			_building_meshes[building] = _cache_fade_materials(building)
	if additional_building_root != null:
		for building in additional_building_root.get_children():
			if building is Node3D:
				_building_meshes[building] = _cache_fade_materials(building)

func _process(_delta: float) -> void:
	if target == null or camera == null or not is_instance_valid(target) or not is_instance_valid(camera):
		return
	var blocking_building := _find_blocking_building()
	for building in _building_meshes:
		_set_building_faded(building, building == blocking_building)

func get_faded_building_count() -> int:
	return _faded_buildings.size()

func _find_blocking_building() -> Node3D:
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		target.global_position + Vector3.UP * 0.85,
		1,
		[target.get_rid()]
	)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return _find_registered_building(hit.collider as Node)

func _find_registered_building(node: Node) -> Node3D:
	for building in _building_meshes:
		if building == node or (building as Node).is_ancestor_of(node):
			return building as Node3D
		if node != null and node.name == StringName("%sCollision" % building.name):
			return building as Node3D
	return null

func _cache_fade_materials(building: Node) -> Array[Dictionary]:
	var cached: Array[Dictionary] = []
	for child in building.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh != null:
				for surface in mesh_instance.mesh.get_surface_count():
					var original := mesh_instance.get_active_material(surface)
					if original is BaseMaterial3D:
						var fade_material := (original as BaseMaterial3D).duplicate() as BaseMaterial3D
						fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						var color := fade_material.albedo_color
						color.a *= faded_alpha
						fade_material.albedo_color = color
						cached.append({
							"mesh_instance": mesh_instance,
							"surface": surface,
							"original_override": mesh_instance.get_surface_override_material(surface),
							"fade_material": fade_material,
						})
		cached.append_array(_cache_fade_materials(child))
	return cached

func _set_building_faded(building: Node3D, faded: bool) -> void:
	if _faded_buildings.has(building) == faded:
		return
	for entry in _building_meshes[building] as Array[Dictionary]:
		var mesh_instance := entry.mesh_instance as MeshInstance3D
		var material := entry.fade_material as Material if faded else entry.original_override as Material
		mesh_instance.set_surface_override_material(int(entry.surface), material)
	if faded:
		_faded_buildings[building] = true
	else:
		_faded_buildings.erase(building)
