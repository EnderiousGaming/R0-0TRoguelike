extends Area3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
# (None in this script)

# ==========================================
# EXPORT VARIABLES
# ==========================================
# Defines which weapon this rack provides (e.g., "blaster" or "sword")
@export var weapon_type = "blaster" 

# ==========================================
# PUBLIC VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================
# (None in this script)

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================
# (None in this script)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_body_entered(body):
	"""Handles player collision to equip the weapon."""
	if body.is_in_group("player"):
		# Update the global loadout state
		RunManager.equipped_weapon = weapon_type
		
		# Force the player to immediately update their 3D model/hitboxes
		if body.has_method("update_weapon_loadout"):
			body.update_weapon_loadout()
			
		print("SYSTEM: Equipped ", weapon_type)
