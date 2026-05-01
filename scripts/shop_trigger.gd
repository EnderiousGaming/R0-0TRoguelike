extends Area3D

# --- REFERENCES ---
@onready var shop_menu = $"../ShopMenu"


# ==========================================
# INTERACTION LOGIC
# ==========================================

func _on_body_entered(body):
	# Check if the entity entering the trigger is the player
	if body.is_in_group("player"):
		
		# 1. Hide the standard gameplay HUD to clear the screen for the menu
		if body.has_node("HUD"):
			body.get_node("HUD").visible = false
		
		# 2. Freeze the game world logic while shopping
		get_tree().paused = true
		
		# 3. Release the mouse cursor so the player can interact with buttons
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# 4. Display the shop interface and refresh its data
		shop_menu.visible = true
		shop_menu.update_ui()
		
		print("SYSTEM: Shop interface initialized.")
