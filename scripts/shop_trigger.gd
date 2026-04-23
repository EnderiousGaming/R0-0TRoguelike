extends Area3D

@onready var shop_menu = $"../ShopMenu"

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Freeze the room, free the mouse, show the catalog!
		get_tree().paused = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		shop_menu.visible = true
		
		# Force the UI to refresh its text so the score is accurate
		shop_menu.update_ui()
