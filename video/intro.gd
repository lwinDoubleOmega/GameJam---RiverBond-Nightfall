extends Control

const NEXT_SCENE := "res://scenes/river_bound_main.tscn"
const VIDEO_PATH := "res://video/intro.ogv"

@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
var _transitioning := false


func _ready() -> void:
	get_tree().paused = false
	video_player.finished.connect(_continue)
	if ResourceLoader.exists(VIDEO_PATH, "VideoStream"):
		video_player.stream = load(VIDEO_PATH) as VideoStream
		video_player.play()
	else:
		push_warning("Intro video is missing: " + VIDEO_PATH)
		call_deferred("_continue")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_continue()


func _continue() -> void:
	if _transitioning:
		return
	_transitioning = true
	video_player.stop()
	get_tree().change_scene_to_file(NEXT_SCENE)
