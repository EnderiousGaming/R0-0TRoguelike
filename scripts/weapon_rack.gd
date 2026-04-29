extends Area3D

@export var weapon_type = "blaster" # Change this to "sword" in the Inspector for the Sword Rack!

func _on_body_entered(body):
	if body.is_in_group("player"):
		RunManager.equipped_weapon = weapon_type
		
		# Force the player to immediately update their 3D model
		if body.has_method("update_weapon_loadout"):
			body.update_weapon_loadout()
			
		print("SYSTEM: Equipped ", weapon_type)
