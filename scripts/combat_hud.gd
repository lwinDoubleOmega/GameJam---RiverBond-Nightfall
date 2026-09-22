class_name RiverBoundCombatHUD
extends CanvasLayer

signal power_selected(power: StringName)
signal weapon_selected(weapon: StringName)

@onready var _wave_banner: Label = $WaveBanner
@onready var _health_count: Label = $HealthPanel/Margin/Content/HealthRow/HealthCount
@onready var _health_bar: ProgressBar = $HealthPanel/Margin/Content/HealthBar
@onready var _ammo_count: Label = $HealthPanel/Margin/Content/AmmoRow/AmmoCount
@onready var _enemy_count: Label = $EnemyPanel/Margin/Content/EnemyCount
@onready var _power_overlay: Control = $PowerOverlay
@onready var _attack_card: Button = $PowerOverlay/Center/ChoiceContent/Cards/AttackCard
@onready var _weapon_overlay: Control = $WeaponOverlay
@onready var _laser_card: Button = $WeaponOverlay/Center/ChoiceContent/Cards/LaserCard

var _wave_tween: Tween


func _ready() -> void:
	$PowerOverlay/Center/ChoiceContent/Cards/AttackCard.pressed.connect(_choose.bind(&"attack"))
	$PowerOverlay/Center/ChoiceContent/Cards/HealthCard.pressed.connect(_choose.bind(&"health"))
	$PowerOverlay/Center/ChoiceContent/Cards/SpeedCard.pressed.connect(_choose.bind(&"movement"))
	$WeaponOverlay/Center/ChoiceContent/Cards/LaserCard.pressed.connect(_choose_weapon.bind(&"laser_rifle"))
	$WeaponOverlay/Center/ChoiceContent/Cards/ShotgunCard.pressed.connect(_choose_weapon.bind(&"plasma_shotgun"))


func set_health(current: int, maximum: int) -> void:
	_health_count.text = "%02d / %02d" % [current, maximum]
	_health_bar.max_value = maximum
	_health_bar.value = current


func set_ammo(current: int) -> void:
	_ammo_count.text = "%02d" % maxi(0, current)


func set_enemy_count(count: int) -> void:
	_enemy_count.text = "%03d" % maxi(0, count)


func show_wave(wave_number: int) -> void:
	_show_banner("WAVE %d" % wave_number)


func show_completion() -> void:
	_show_banner("AREA SECURED")


func show_power_choice() -> void:
	_power_overlay.visible = true
	_attack_card.grab_focus()


func is_power_choice_visible() -> bool:
	return _power_overlay.visible


func show_weapon_choice() -> void:
	_weapon_overlay.visible = true
	_laser_card.grab_focus()


func is_weapon_choice_visible() -> bool:
	return _weapon_overlay.visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	if event is InputEventKey:
		if _weapon_overlay.visible:
			match event.keycode:
				KEY_1:
					_choose_weapon(&"laser_rifle")
				KEY_2:
					_choose_weapon(&"plasma_shotgun")
		elif _power_overlay.visible:
			match event.keycode:
				KEY_1:
					_choose(&"attack")
				KEY_2:
					_choose(&"health")
				KEY_3:
					_choose(&"movement")


func _choose(power: StringName) -> void:
	if not _power_overlay.visible:
		return
	_power_overlay.visible = false
	power_selected.emit(power)


func _choose_weapon(weapon: StringName) -> void:
	if not _weapon_overlay.visible:
		return
	_weapon_overlay.visible = false
	weapon_selected.emit(weapon)


func _show_banner(message: String) -> void:
	if _wave_tween != null and _wave_tween.is_valid():
		_wave_tween.kill()
	_wave_banner.text = message
	_wave_banner.visible = true
	_wave_banner.modulate.a = 1.0
	_wave_tween = create_tween()
	_wave_tween.tween_interval(1.7)
	_wave_tween.tween_property(_wave_banner, ^"modulate:a", 0.0, 0.55)
	_wave_tween.tween_callback(_wave_banner.hide)
