extends Control

func _ready():
	# CRUCIAL: Free the mouse so you can actually click the button!
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_button_pressed():
	# Teleport the player back to the new Hub area
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
