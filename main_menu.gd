extends Control

@onready var menu: VBoxContainer = $VBoxContainer
@onready var start_button: Button = $VBoxContainer/Button
@onready var options_button: Button = $VBoxContainer/Button2
@onready var exit_button: Button = $VBoxContainer/Button3
@onready var options_panel: PanelContainer = $OptionsPanel
@onready var volume_slider: HSlider = $OptionsPanel/Margin/Content/VolumeSlider
@onready var fullscreen_toggle: CheckButton = $OptionsPanel/Margin/Content/Fullscreen
@onready var options_back_button: Button = $OptionsPanel/Margin/Content/BackButton
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var click_player: AudioStreamPlayer = $MenuClick

var _starting_game := false


func _ready() -> void:
	start_button.pressed.connect(_on_start_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	options_back_button.pressed.connect(_on_options_back_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	exit_dialog.confirmed.connect(_on_exit_confirmed)
	fullscreen_toggle.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	start_button.grab_focus()


func _on_start_game_pressed() -> void:
	if _starting_game:
		return
	_starting_game = true
	_play_click()
	get_tree().change_scene_to_file("res://video/intro.tscn")


func _on_options_pressed() -> void:
	_play_click()
	menu.visible = false
	options_panel.visible = true
	options_back_button.grab_focus()


func _on_options_back_pressed() -> void:
	_play_click()
	options_panel.visible = false
	menu.visible = true
	options_button.grab_focus()


func _on_exit_pressed() -> void:
	_play_click()
	exit_dialog.popup_centered(Vector2i(430, 190))


func _on_exit_confirmed() -> void:
	_play_click()
	get_tree().quit()


func _on_volume_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, value <= 0.0)
	if value > 0.0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options_panel.visible:
			_on_options_back_pressed()
		elif not exit_dialog.visible:
			_on_exit_pressed()


func _play_click() -> void:
	click_player.play()
