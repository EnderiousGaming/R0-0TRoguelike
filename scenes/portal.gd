extends Area3D

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Uplink established. Entering the void...")
		
		# DEFERRED: Wait for physics to finish, THEN change the scene!
		get_tree().call_deferred("change_scene_to_file", "res://scenes/world.tscn")
