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
# This allows us to assign the RespawnPoint directly in the Inspector
@export var respawn_node: Marker3D

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
	"""Handles the player falling into the void and teleports them back."""
	if body.is_in_group("player"):
		# 1. Teleport R0-0T back to the marker
		body.global_position = respawn_node.global_position
		
		# 2. CANCEL THE MOMENTUM! 
		# This prevents R0-0T from clipping through the floor upon landing.
		body.velocity = Vector3.ZERO
		
		print("SYSTEM: Void breach detected. R0-0T recovered to shop floor.")
