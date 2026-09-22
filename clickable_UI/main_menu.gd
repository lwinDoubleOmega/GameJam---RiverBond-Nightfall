extends Control

## Set this in the Inspector after copying your other project's gameplay scene
## into this project. Example: res://game/main.tscn
@export_file("*.tscn") var gameplay_scene_path := ""

@onready var menu := $VBoxContainer
@onready var start_button: Button = $VBoxContainer/Button
@onready var options_button: Button = $VBoxContainer/Button2
@onready var exit_button: Button = $VBoxContainer/Button3

var options_panel: PanelContainer
var placeholder_panel: PanelContainer
var exit_dialog: ConfirmationDialog
var click_player: AudioStreamPlayer


func _ready() -> void:
	# Make the imported menu responsive and keep the actions visibly separated.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_theme_constant_override("separation", 24)
	for button in [start_button, options_button, exit_button]:
		button.custom_minimum_size = Vector2(390, 62)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("normal", _clear_button_style())
		button.add_theme_stylebox_override("hover", _clear_button_style())
		button.add_theme_stylebox_override("pressed", _clear_button_style())
		button.add_theme_stylebox_override("focus", _clear_button_style())
	start_button.pressed.connect(start_game)
	options_button.pressed.connect(show_options)
	exit_button.pressed.connect(request_exit)
	_build_options()
	_build_placeholder()
	_build_exit_dialog()
	click_player = AudioStreamPlayer.new()
	click_player.stream = load("res://menu_click.ogg")
	click_player.volume_db = -4.0
	add_child(click_player)
	start_button.grab_focus()


func start_game() -> void:
	_play_click()
	if gameplay_scene_path.is_empty():
		placeholder_panel.get_parent().get_parent().visible = true
		placeholder_panel.get_node("Margin/Content/EndButton").grab_focus()
		return
	if not ResourceLoader.exists(gameplay_scene_path, "PackedScene"):
		push_error("Gameplay scene not found: " + gameplay_scene_path)
		placeholder_panel.get_node("Margin/Content/Message").text = "GAME SCENE NOT FOUND:\n" + gameplay_scene_path
		placeholder_panel.get_parent().get_parent().visible = true
		return
	await get_tree().create_timer(0.08).timeout
	get_tree().change_scene_to_file(gameplay_scene_path)


## Gameplay can call this when the run ends:
## get_tree().change_scene_to_file("res://main_menu.tscn")
func end_game() -> void:
	_play_click()
	placeholder_panel.get_parent().get_parent().visible = false
	menu.visible = true
	start_button.grab_focus()


func show_options() -> void:
	_play_click()
	options_panel.get_parent().get_parent().visible = true
	options_panel.get_node("Margin/Content/BackButton").grab_focus()


func hide_options() -> void:
	_play_click()
	options_panel.get_parent().get_parent().visible = false
	options_button.grab_focus()


func request_exit() -> void:
	_play_click()
	exit_dialog.popup_centered(Vector2i(430, 190))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options_panel.get_parent().get_parent().visible:
			hide_options()
		elif placeholder_panel.get_parent().get_parent().visible:
			end_game()
		elif not exit_dialog.visible:
			request_exit()


func _build_options() -> void:
	options_panel = _make_panel(Vector2(520, 350))
	var content: VBoxContainer = options_panel.get_node("Margin/Content")
	content.add_child(_title("OPTIONS"))
	var volume_label := _text("MASTER VOLUME: 80%")
	content.add_child(volume_label)
	var slider := HSlider.new()
	slider.max_value = 100
	slider.value = 80
	slider.custom_minimum_size.y = 30
	slider.value_changed.connect(func(value: float):
		volume_label.text = "MASTER VOLUME: %d%%" % int(value)
		var bus := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_mute(bus, value <= 0)
		if value > 0: AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))
	)
	content.add_child(slider)
	var fullscreen := CheckButton.new()
	fullscreen.text = "FULLSCREEN"
	fullscreen.add_theme_font_override("font", load("res://Bitten.ttf"))
	fullscreen.add_theme_font_size_override("font_size", 20)
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(on: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	content.add_child(fullscreen)
	var back := _action_button("SAVE & RETURN")
	back.name = "BackButton"
	back.pressed.connect(hide_options)
	content.add_child(back)


func _build_placeholder() -> void:
	placeholder_panel = _make_panel(Vector2(650, 320))
	var content: VBoxContainer = placeholder_panel.get_node("Margin/Content")
	content.add_child(_title("READY TO ATTACH"))
	var message := _text("START is working. Attach your gameplay scene later\nby setting Gameplay Scene Path on MainMenu.")
	message.name = "Message"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)
	var end := _action_button("END & RETURN TO MENU")
	end.name = "EndButton"
	end.pressed.connect(end_game)
	content.add_child(end)


func _build_exit_dialog() -> void:
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Exit River Bound?"
	exit_dialog.dialog_text = "Are you sure you want to leave?"
	exit_dialog.ok_button_text = "EXIT"
	exit_dialog.cancel_button_text = "STAY"
	exit_dialog.confirmed.connect(_confirm_exit)
	add_child(exit_dialog)


func _confirm_exit() -> void:
	_play_click()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()


func _play_click() -> void:
	if click_player:
		click_player.play()


func _make_panel(minimum: Vector2) -> PanelContainer:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.78)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum
	panel.add_theme_stylebox_override("panel", _button_style(Color(0.025, 0.012, 0.02, 0.98), Color(0.7, 0.04, 0.02), 2))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 36)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)
	shade.visible = false
	return panel


func _title(value: String) -> Label:
	var label := _text(value)
	label.add_theme_font_override("font", load("res://Dark Distance.otf"))
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color("#f01908"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", load("res://Bitten.ttf"))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("#ded5cf"))
	return label


func _action_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(330, 58)
	button.add_theme_font_override("font", load("res://Bitten.ttf"))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_hover_color", Color("#f21908"))
	button.add_theme_color_override("font_focus_color", Color("#f21908"))
	button.add_theme_stylebox_override("normal", _clear_button_style())
	button.add_theme_stylebox_override("hover", _clear_button_style())
	button.add_theme_stylebox_override("pressed", _clear_button_style())
	button.add_theme_stylebox_override("focus", _clear_button_style())
	return button


func _clear_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.content_margin_left = 12
	return style


func _button_style(fill: Color, border: Color, left: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = left
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 22
	return style
