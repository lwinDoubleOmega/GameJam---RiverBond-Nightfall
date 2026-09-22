extends Node3D

signal wave_spawned(wave_number: int, total_spawned: int)
signal wave_cleared(wave_number: int)

const WAVE_ONE_MELEE_COUNT := 30

const WAVE_TWO_MELEE_COUNT := 30
const WAVE_TWO_RANGED_COUNT := 15
const FINAL_WAVE_MELEE_COUNT := 30
const FINAL_WAVE_RANGED_COUNT := 20
const FINAL_WAVE_BOSS_COUNT := 1
const FINAL_WAVE_MEDIUM_BOSS_ADDED_COUNT := 10
const FINAL_WAVE_FINAL_BOSS_ADDED_COUNT := 2
const FINAL_WAVE_TOTAL_BOSS_COUNT := FINAL_WAVE_BOSS_COUNT + FINAL_WAVE_FINAL_BOSS_ADDED_COUNT
const FINAL_WAVE_BOSS_HEALTH_MULTIPLIER := 5
const FINAL_WAVE_BOSS_SPEED_MULTIPLIER := 2.0
const TOTAL_REGULAR_MONSTER_COUNT := (
	WAVE_ONE_MELEE_COUNT
	+ WAVE_TWO_MELEE_COUNT
	+ WAVE_TWO_RANGED_COUNT
	+ FINAL_WAVE_MELEE_COUNT
	+ FINAL_WAVE_RANGED_COUNT
	+ FINAL_WAVE_MEDIUM_BOSS_ADDED_COUNT
)
const TOTAL_MONSTER_CAP := TOTAL_REGULAR_MONSTER_COUNT + FINAL_WAVE_TOTAL_BOSS_COUNT
const RIVER_MONSTER_RATIO := 0.75
const MINIMUM_SPAWN_SPACING := 1.35
const RIVER_SPAWN_ZONE := Rect2(-58.0, 4.0, 14.0, 88.0)
# WestInnerBoundary blocks the river-side buffer at X=-36.5. River enemies keep
# world collision disabled until they are safely on the playable side of it.
const RIVER_EXIT_X := -34.0
const LAND_SPAWN_ZONES := [
	Rect2(-31.0, 4.0, 10.0, 88.0),
	Rect2(-18.0, 23.0, 77.0, 16.0),
	Rect2(10.0, 50.0, 50.0, 16.0),
]

@export var enemy_scene: PackedScene
@export var ranged_enemy_scene: PackedScene
@export var boss_enemy_scene: PackedScene

@onready var _player: RiverBoundPlayer = $Player
@onready var _hud: CanvasLayer = $CombatHUD

var total_spawned: int = 0
var current_wave: int = 0
var _random := RandomNumberGenerator.new()
var _spawn_points: Array[Vector3] = []
var _next_spawn_point: int = 0
var _living_wave_enemies: int = 0
var _waiting_for_power_choice: bool = false
var _waiting_for_weapon_choice: bool = false
var _ending_run: bool = false


func _ready() -> void:
	_random.randomize()
	_spawn_points = _generate_spawn_points()
	_player.health_changed.connect(_hud.set_health)
	_player.ammo_changed.connect(_hud.set_ammo)
	_player.died.connect(_on_player_died, CONNECT_ONE_SHOT)
	_hud.power_selected.connect(_on_power_selected)
	_hud.weapon_selected.connect(_on_weapon_selected)
	_hud.set_health(_player.current_health(), _player.maximum_health)
	_hud.set_ammo(_player.current_ammo())
	_hud.set_enemy_count(0)
	_spawn_composition(WAVE_ONE_MELEE_COUNT, 0, 1)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"restart"):
		restart_scene()


func restart_scene() -> void:
	get_tree().reload_current_scene()


func _spawn_composition(
	melee_count: int,
	ranged_count: int,
	wave_number: int,
	boss_count: int = 0,
	medium_boss_count: int = 0,
) -> void:
	if enemy_scene == null:
		push_error("Environment combat controller has no enemy scene")
		return
	if ranged_count > 0 and ranged_enemy_scene == null:
		push_error("Environment combat controller has no ranged enemy scene")
		return
	if boss_count > 0 and boss_enemy_scene == null:
		push_error("Environment combat controller has no boss enemy scene")
		return
	current_wave = wave_number
	_waiting_for_power_choice = false
	_waiting_for_weapon_choice = false
	var composition: Array[int] = []
	for index in melee_count:
		composition.append(0)
	for index in ranged_count:
		composition.append(1)
	for index in medium_boss_count:
		composition.append(2)
	for index in range(composition.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := composition[index]
		composition[index] = composition[swap_index]
		composition[swap_index] = temporary
	_living_wave_enemies = composition.size() + boss_count
	for enemy_kind in composition:
		if total_spawned >= TOTAL_MONSTER_CAP:
			break
		var use_ranged_enemy := enemy_kind > 0
		var active_enemy_scene := ranged_enemy_scene if use_ranged_enemy else enemy_scene
		var monster := active_enemy_scene.instantiate() as RiverMonster
		var spawn_position := _spawn_points[_next_spawn_point]
		var spawned_in_river := spawn_position.x <= -44.0
		var enemy_prefix := "MediumBoss" if enemy_kind == 2 else ("RiverRangedMonster" if use_ranged_enemy else "RiverMonster")
		monster.name = "%s%03d" % [enemy_prefix, total_spawned + 1]
		if enemy_kind == 2:
			monster.add_to_group(&"medium_boss_enemies")
		monster.position = spawn_position
		monster.set_meta(&"spawned_in_river", spawned_in_river)
		if spawned_in_river:
			monster.set_meta(&"river_exit", _river_exit_for_spawn(spawn_position))
		monster.defeated.connect(_on_enemy_defeated, CONNECT_ONE_SHOT)
		add_child(monster)
		_next_spawn_point += 1
		total_spawned += 1
	for boss_index in boss_count:
		if total_spawned >= TOTAL_MONSTER_CAP:
			break
		var boss := boss_enemy_scene.instantiate() as RiverBossMonster
		boss.name = "RiverBossMonster%02d" % (boss_index + 1)
		boss.position = _boss_spawn_position(boss_index)
		boss.set_meta(&"spawned_in_river", false)
		if wave_number == 3:
			boss.maximum_health *= FINAL_WAVE_BOSS_HEALTH_MULTIPLIER
			boss.movement_speed *= FINAL_WAVE_BOSS_SPEED_MULTIPLIER
		boss.defeated.connect(_on_enemy_defeated, CONNECT_ONE_SHOT)
		add_child(boss)
		total_spawned += 1
	_hud.set_enemy_count(_living_wave_enemies)
	_hud.show_wave(wave_number)
	wave_spawned.emit(wave_number, total_spawned)
	print("RIVER_BOUND_WAVE_%d_SPAWNED alive=%d total=%d" % [wave_number, _living_wave_enemies, total_spawned])


func _on_enemy_defeated() -> void:
	if _living_wave_enemies <= 0:
		return
	_living_wave_enemies -= 1
	_hud.set_enemy_count(_living_wave_enemies)
	if _living_wave_enemies > 0:
		return
	wave_cleared.emit(current_wave)
	if current_wave == 1:
		_waiting_for_power_choice = true
		_hud.show_power_choice()
	elif current_wave == 2:
		_waiting_for_weapon_choice = true
		_hud.show_weapon_choice()
	elif current_wave == 3:
		_finish_run_with_outro()


func _finish_run_with_outro() -> void:
	if _ending_run:
		return
	_ending_run = true
	_hud.show_completion()
	get_tree().change_scene_to_file("res://video/outro.tscn")


func _on_player_died() -> void:
	if _ending_run:
		return
	_ending_run = true
	get_tree().change_scene_to_file("res://video/death.tscn")


func _on_power_selected(power: StringName) -> void:
	if not _waiting_for_power_choice or current_wave != 1:
		return
	_waiting_for_power_choice = false
	_player.apply_power_boost(power)
	_spawn_composition(WAVE_TWO_MELEE_COUNT, WAVE_TWO_RANGED_COUNT, 2)


func _on_weapon_selected(weapon: StringName) -> void:
	if not _waiting_for_weapon_choice or current_wave != 2:
		return
	_waiting_for_weapon_choice = false
	_player.equip_weapon(weapon)
	_spawn_composition(
		FINAL_WAVE_MELEE_COUNT,
		FINAL_WAVE_RANGED_COUNT,
		3,
		FINAL_WAVE_TOTAL_BOSS_COUNT,
		FINAL_WAVE_MEDIUM_BOSS_ADDED_COUNT,
	)


func living_wave_enemy_count() -> int:
	return _living_wave_enemies


func waiting_for_power_choice() -> bool:
	return _waiting_for_power_choice


func waiting_for_weapon_choice() -> bool:
	return _waiting_for_weapon_choice


func _generate_spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var river_monster_count := roundi(float(TOTAL_REGULAR_MONSTER_COUNT) * RIVER_MONSTER_RATIO)
	_append_random_points(points, river_monster_count, [RIVER_SPAWN_ZONE], -0.45)
	_append_random_points(
		points,
		TOTAL_REGULAR_MONSTER_COUNT - river_monster_count,
		LAND_SPAWN_ZONES,
		0.1,
	)
	# Shuffle after generating the exact regional counts so both waves contain a
	# natural mixture while the complete encounter remains 75 percent river-born.
	for index in range(points.size() - 1, 0, -1):
		var swap_index := _random.randi_range(0, index)
		var temporary := points[index]
		points[index] = points[swap_index]
		points[swap_index] = temporary
	return points


func _append_random_points(
	points: Array[Vector3],
	count: int,
	zones: Array,
	height: float,
) -> void:
	for point_number in count:
		var candidate := Vector3.ZERO
		var accepted := false
		for attempt in 80:
			var zone := zones[_random.randi_range(0, zones.size() - 1)] as Rect2
			candidate = Vector3(
				_random.randf_range(zone.position.x, zone.end.x),
				height,
				_random.randf_range(zone.position.y, zone.end.y),
			)
			if _has_spawn_clearance(candidate, points):
				accepted = true
				break
		if not accepted:
			# Extremely unlikely fallback: retain the random point rather than
			# reducing the requested enemy count.
			candidate.x += float(point_number % 5) * 0.15
		points.append(candidate)


func _has_spawn_clearance(candidate: Vector3, points: Array[Vector3]) -> bool:
	for existing in points:
		var separation := Vector2(candidate.x - existing.x, candidate.z - existing.z)
		if separation.length_squared() < MINIMUM_SPAWN_SPACING * MINIMUM_SPAWN_SPACING:
			return false
	return true


func _river_exit_for_spawn(spawn_position: Vector3) -> Vector3:
	# Preserve the randomized river Z coordinate so dozens of monsters cross the
	# boundary as a broad front instead of converging on four bottlenecks.
	return Vector3(RIVER_EXIT_X, 0.1, clampf(spawn_position.z, 4.5, 91.5))


func _boss_spawn_position(boss_index: int) -> Vector3:
	# Bosses enter from the southeast road, safely inside the playable boundary.
	return Vector3(52.0 - float(boss_index) * 3.0, 0.1, 82.0)
