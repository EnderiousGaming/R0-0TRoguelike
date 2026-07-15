extends Label3D

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

func animate():
	"""
	Animates the damage number floating upwards and fading out before deleting it.
	Called externally right after this node is instantiated and positioned.
	"""
	var tween = create_tween()
	
	# 1. Float Upwards:
	# We use global_position so the text floats up from the exact spot the 
	# enemy was hit, instead of following the enemy if they get knocked back!
	tween.tween_property(self, "global_position", global_position + Vector3(0, 2.0, 0), 0.5)
	
	# 2. Fade Out:
	# The parallel() command ensures the text turns invisible AT THE SAME TIME it floats up.
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	
	# 3. Cleanup:
	# Automatically delete the text node from the game once the fade is complete.
	tween.tween_callback(queue_free)
