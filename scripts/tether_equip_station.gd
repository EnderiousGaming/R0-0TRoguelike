extends Area3D

func _ready():
	# Connect the collision signal via code
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Confirm R0-0T actually interacted with the hitbox
	print("Entity entered: ",body.name)
	
	# Check if the object that walked in is R0-0T
	if body.is_in_group("player"):
		RunManager.equipped_weapon = "tether"
		
		# Tell the player to swap their weapon models immediately
		if body.has_method("update_weapon_loadout"):
			body.update_weapon_loadout()
			
		print("SYSTEM: Siphon Tether equipped.")
		
		# OPTIONAL: You can add an AudioStreamPlayer3D to the station and play an equip sound here!
