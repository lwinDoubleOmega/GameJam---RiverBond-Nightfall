extends Control

var _returning := false


func _ready() -> void:
	$Center/Content/ReturnButton.pressed.connect(_on_return_pressed)
	$Center/Content/ReturnButton.grab_focus()


func _on_return_pressed() -> void:
	if _returning:
		return
	_returning = true
	get_tree().change_scene_to_file("res://main_menu_update_v2.tscn")
