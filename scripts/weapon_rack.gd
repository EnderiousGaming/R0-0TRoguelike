extends Area3D

# ==========================================
# CONFIGURATION
# ==========================================

# Defines which weapon this rack provides (e.g., "blaster" or "sword")
@export var weapon_type = "blaster" 

# ==========================================
# INTERACTION LOGIC
# ==========================================

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Update the global loadout state
		RunManager.equipped_weapon = weapon_type
		
		# Force the player to immediately update their 3D model/hitboxes
		if body.has_method("update_weapon_loadout"):
			body.update_weapon_loadout()
			
		print("SYSTEM: Equipped ", weapon_type)
