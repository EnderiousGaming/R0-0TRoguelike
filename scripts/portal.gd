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
			1, 2, 4, 5, 7, 8:
				next_scene_path = "res://scenes/world.tscn" 
			3, 6, 9:
				next_scene_path = "res://scenes/shop.tscn"
			10:
				next_scene_path = "res://scenes/boss.tscn"
			_:
				print("Simulation Complete. Rebooting to Hub.")
				next_scene_path = "res://scenes/hub.tscn"

		get_tree().call_deferred("change_scene_to_file", next_scene_path)
