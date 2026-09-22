extends Control

## Set this in the Inspector after copying your other project's gameplay scene
## into this project. Example: res://game/main.tscn
@export_file("*.tscn") var gameplay_scene_path := ""

@onready var menu := $VBoxContainer
@onready var title_label: Label = $Label
@onready var start_button: Button = $VBoxContainer/Button
@onready var options_button: Button = $VBoxContainer/Button2
@onready var exit_button: Button = $VBoxContainer/Button3
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var transition_rect: ColorRect = $TransitionLayer/Black
@onready var transition_player: AnimationPlayer = $TransitionLayer/AnimationPlayer
@onready var loading_screen: Control = $TransitionLayer/LoadingScreen
@onready var loading_label: Label = $TransitionLayer/LoadingScreen/LoadingLabel

const MAIN_TEXT := Color("#EAF2F3")
const HIGHLIGHT := Color("#18D9D2")
const DANGER := Color("#F0445A")
const PANEL_NAVY := Color("#101E2E")
const CHAKRA := preload("res://UI_update_v2/ChakraPetch-Regular.ttf")
const CHAKRA_SEMIBOLD := preload("res://UI_update_v2/ChakraPetch-SemiBold.ttf")
const TITLE_FONT := preload("res://UI_update_v2/Dark Distance.otf")

var is_transitioning := false
var loading_pulse_tween: Tween

var options_panel: PanelContainer
var placeholder_panel: PanelContainer
var exit_dialog: ConfirmationDialog
var click_player: AudioStreamPlayer


func _ready() -> void:
	# Make the imported menu responsive and keep the actions visibly separated.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_transition_animations()
	title_label.add_theme_font_override("font", TITLE_FONT)
	title_label.add_theme_color_override("font_color", Color("#BDF7F3"))
	title_label.add_theme_color_override("font_shadow_color", Color("#0B1624CC"))
	title_label.add_theme_constant_override("shadow_offset_x", 4)
	title_label.add_theme_constant_override("shadow_offset_y", 5)
	title_label.add_theme_constant_override("shadow_outline_size", 3)
	menu.add_theme_constant_override("separation", 24)
	for button in [start_button, options_button, exit_button]:
		button.custom_minimum_size = Vector2(390, 62)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_stylebox_override("normal", _clear_button_style())
		button.add_theme_stylebox_override("hover", _clear_button_style())
		button.add_theme_stylebox_override("pressed", _clear_button_style())
		button.add_theme_stylebox_override("focus", _clear_button_style())
		button.add_theme_font_override("font", CHAKRA_SEMIBOLD)
		button.add_theme_color_override("font_color", MAIN_TEXT)
		button.add_theme_color_override("font_hover_color", DANGER)
		button.add_theme_color_override("font_hover_pressed_color", DANGER)
		button.add_theme_color_override("font_focus_color", MAIN_TEXT)
		button.add_theme_color_override("font_pressed_color", DANGER.lightened(0.12))
		button.mouse_entered.connect(_animate_button_hover.bind(button, true))
		button.mouse_exited.connect(_animate_button_hover.bind(button, false))
	start_button.pressed.connect(start_game)
	options_button.pressed.connect(show_options)
	exit_button.pressed.connect(request_exit)
	_build_options()
	_build_placeholder()
	_build_exit_dialog()
	click_player = AudioStreamPlayer.new()
	click_player.stream = load("res://UI_update_v2/menu_click.ogg")
	click_player.volume_db = -4.0
	add_child(click_player)
	start_button.grab_focus()


func _animate_button_hover(button: Button, hovered: bool) -> void:
	if is_transitioning:
		return
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position:x", 10.0 if hovered else 0.0, 0.14)
	tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0 if hovered else 0.92), 0.14)


func start_game() -> void:
	if is_transitioning:
		return
	_play_click()
	var gameplay_is_ready := not gameplay_scene_path.is_empty() and ResourceLoader.exists(gameplay_scene_path, "PackedScene")
	if not gameplay_scene_path.is_empty() and not gameplay_is_ready:
		push_error("Gameplay scene not found: " + gameplay_scene_path)
	is_transitioning = true
	_set_menu_buttons_disabled(true)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var menu_fade := create_tween().set_parallel(true)
	menu_fade.tween_property(title_label, "modulate:a", 0.0, 0.25)
	menu_fade.tween_property(menu, "modulate:a", 0.0, 0.25)
	await menu_fade.finished
	transition_player.play("fade_to_black")
	await transition_player.animation_finished
	loading_screen.visible = true
	_start_loading_pulse()
	transition_player.play("fade_from_black")
	await transition_player.animation_finished
	await get_tree().create_timer(1.1).timeout
	transition_player.play("fade_to_black")
	await transition_player.animation_finished
	loading_screen.visible = false
	_stop_loading_pulse()
	if not gameplay_is_ready:
		title_label.modulate.a = 1.0
		menu.modulate.a = 1.0
		transition_player.play("fade_from_black")
		await transition_player.animation_finished
		transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_menu_buttons_disabled(false)
		is_transitioning = false
		placeholder_panel.get_node("Margin/Content/Message").text = "LOADING COMPLETE\nAttach your gameplay scene by setting Gameplay Scene Path on MainMenu." if gameplay_scene_path.is_empty() else "GAME SCENE NOT FOUND:\n" + gameplay_scene_path
		placeholder_panel.get_parent().get_parent().visible = true
		placeholder_panel.get_node("Margin/Content/EndButton").grab_focus()
		return
	# Keep the black transition owned by the menu. Reparenting it to the SceneTree
	# root can leave an opaque CanvasLayer covering the video and gameplay after
	# this menu node is freed by the scene change.
	var error := get_tree().change_scene_to_file(gameplay_scene_path)
	if error != OK:
		push_error("Could not change to gameplay scene: %s" % error_string(error))
		is_transitioning = false
		return


func _start_loading_pulse() -> void:
	loading_label.add_theme_font_override("font", CHAKRA_SEMIBOLD)
	loading_label.modulate.a = 1.0
	loading_pulse_tween = create_tween().set_loops()
	loading_pulse_tween.tween_property(loading_label, "modulate:a", 0.4, 0.45)
	loading_pulse_tween.tween_property(loading_label, "modulate:a", 1.0, 0.45)


func _stop_loading_pulse() -> void:
	if loading_pulse_tween:
		loading_pulse_tween.kill()
		loading_pulse_tween = null


func _set_menu_buttons_disabled(disabled: bool) -> void:
	for button in [start_button, options_button, exit_button]:
		button.disabled = disabled


func _build_transition_animations() -> void:
	var library := AnimationLibrary.new()
	var fade_to_black := Animation.new()
	fade_to_black.length = 0.35
	var to_track := fade_to_black.add_track(Animation.TYPE_VALUE)
	fade_to_black.track_set_path(to_track, NodePath("Black:color:a"))
	fade_to_black.track_insert_key(to_track, 0.0, 0.0)
	fade_to_black.track_insert_key(to_track, 0.35, 1.0)
	library.add_animation("fade_to_black", fade_to_black)
	var fade_from_black := Animation.new()
	fade_from_black.length = 0.6
	var from_track := fade_from_black.add_track(Animation.TYPE_VALUE)
	fade_from_black.track_set_path(from_track, NodePath("Black:color:a"))
	fade_from_black.track_insert_key(from_track, 0.0, 1.0)
	fade_from_black.track_insert_key(from_track, 0.6, 0.0)
	library.add_animation("fade_from_black", fade_from_black)
	transition_player.add_animation_library("", library)


## Gameplay can call this when the run ends:
## get_tree().change_scene_to_file("res://main_menu_update_v2.tscn")
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
	fullscreen.add_theme_font_override("font", load("res://UI_update_v2/Bitten.ttf"))
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
	panel.add_theme_stylebox_override("panel", _button_style(PANEL_NAVY, HIGHLIGHT, 2))
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
	label.add_theme_font_override("font", CHAKRA_SEMIBOLD)
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", HIGHLIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", CHAKRA)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", MAIN_TEXT)
	return label


func _action_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(330, 58)
	button.add_theme_font_override("font", CHAKRA_SEMIBOLD)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", MAIN_TEXT)
	button.add_theme_color_override("font_hover_color", HIGHLIGHT)
	button.add_theme_color_override("font_focus_color", HIGHLIGHT)
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
