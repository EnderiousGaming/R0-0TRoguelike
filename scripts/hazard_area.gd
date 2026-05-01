extends Area3D


# ==========================================
# COLLISION LOGIC
# ==========================================

func _on_body_entered(body):
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
