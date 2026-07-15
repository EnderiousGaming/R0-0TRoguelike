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
# (None in this script)

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
	"""Handles out-of-bounds collision for players and enemies."""
	# 1. Did the player fall out of bounds?
	if body.is_in_group("player"):
		print("CRITICAL ERROR: R0-0T fell out of bounds.")
		if body.has_method("take_damage"):
			# Deal massive damage to bypass health upgrades and force a game over
			body.take_damage(999) 
			
	# 2. Did an enemy get pushed off the edge?
	elif body.is_in_group("enemy"):
		# Vaporize the enemy so it doesn't fall forever and lag the physics engine
		body.queue_free()
