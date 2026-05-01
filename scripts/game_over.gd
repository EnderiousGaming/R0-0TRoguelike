extends Control


# ==========================================
# CORE LOGIC
# ==========================================

func _ready():
	# Free the mouse cursor so the player can actually click the UI buttons
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# ==========================================
# UI EVENTS
# ==========================================

func _on_button_pressed():
	# Teleport the player back to the safe zone (Hub) to start a new run
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
