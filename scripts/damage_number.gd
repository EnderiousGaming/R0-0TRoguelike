extends Label3D


# ==========================================
# ANIMATION LOGIC
# ==========================================

func animate():
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
