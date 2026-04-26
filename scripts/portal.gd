extends Area3D

# THE FIX: A security lock to prevent double-triggering!
var is_active = true 

func _on_body_entered(body):
	if is_active and body.is_in_group("player"):
		is_active = false
		
		RunManager.current_stage += 1
		var stage = RunManager.current_stage
		
		print("Uplink established. Routing to Stage: ", stage)
		
		var next_scene_path = ""
		
		match stage:
			# THE COMBAT ROOMS (Temporarily including Stage 4 so the alpha is playable!)
			1, 2, 4, 5, 7, 8:
				var combat_maps = [
					"res://scenes/world_a.tscn",
					"res://scenes/world_b.tscn",
					"res://scenes/world_c.tscn",
					"res://scenes/world_d.tscn"
				]
				next_scene_path = combat_maps.pick_random()
				
			# THE SHOPS
			3, 6, 9:
				next_scene_path = "res://scenes/shop.tscn"
				
			# THE FINAL BOSS (Placeholder)
			10:
				next_scene_path = "res://scenes/boss.tscn"
				
			# SAFETY NET
			_:
				print("Simulation Complete. Rebooting to Hub.")
				next_scene_path = "res://scenes/hub.tscn"

		get_tree().call_deferred("change_scene_to_file", next_scene_path)
