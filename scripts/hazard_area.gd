extends Area3D

func _on_body_entered(body):
	# Did R0-0T fall in?
	if body.is_in_group("player"):
		print("CRITICAL ERROR: R0-0T fell out of bounds.")
		if body.has_method("take_damage"):
			# Deal massive damage to bypass health upgrades and force a game over
			body.take_damage(999) 
			
	# Did a virus get pushed off the edge?
	elif body.is_in_group("enemy"):
		body.queue_free() # Vaporize it so it doesn't fall forever and lag the game
