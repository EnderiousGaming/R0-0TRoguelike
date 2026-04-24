extends Area3D

# THE FIX: A security lock to prevent double-triggering!
var is_active = true 

func _on_body_entered(body):
	# Only allow entry if the portal hasn't been used yet
	if is_active and body.is_in_group("player"):
		is_active = false # Instantly lock the portal!
		
		RunManager.current_stage += 1
		var stage = RunManager.current_stage
		
		print("Uplink established. Routing to Stage: ", stage)
		
		var next_scene_path = ""
		
		match stage:
			# THE COMBAT ROOMS
			1, 2, 5, 7, 8:
				# The array of our 4 new level designs
				var combat_maps = [
					"res://scenes/world_a.tscn",
					"res://scenes/world_b.tscn",
					"res://scenes/world_c.tscn",
					"res://scenes/world_d.tscn"
				]
				# Randomly pick one of the strings from the array!
				next_scene_path = combat_maps.pick_random() 
			3, 6, 9:
				next_scene_path = "res://scenes/shop.tscn"
			10:
				next_scene_path = "res://scenes/boss.tscn"
			_:
				print("Simulation Complete. Rebooting to Hub.")
				next_scene_path = "res://scenes/hub.tscn"

		get_tree().call_deferred("change_scene_to_file", next_scene_path)
