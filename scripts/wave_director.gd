extends Node3D

@export var enemy_types: Array[PackedScene]
var spawn_points = []

func _ready():
	# Search the level for every node we tagged as a spawn_point
	spawn_points = get_tree().get_nodes_in_group("spawn_point")
	
	if spawn_points.is_empty():
		print("DIRECTOR ERROR: No spawn points found in the level!")
	else:
		print("Wave Director Online. Commencing virus drops...")

# This function will trigger every time the Timer hits 0
func _on_timer_timeout():
	# Make sure we have spawns and enemies (using the array we set up earlier!)
	if spawn_points.is_empty() or enemy_types.is_empty():
		return
		
	# Grab the active 3D camera from the player
	var camera = get_viewport().get_camera_3d()
	var hidden_spawns = []
	
	# Check every single spawn point in the room
	if camera:
		for sp in spawn_points:
			# If the camera CANNOT see this exact coordinate, add it to our valid list
			if not camera.is_position_in_frustum(sp.global_position):
				hidden_spawns.append(sp)
				
	var chosen_spawn = null
	
	# Try to pick a spawn point that the player can't see
	if hidden_spawns.size() > 0:
		chosen_spawn = hidden_spawns.pick_random()
	else:
		# FALLBACK: If R0-0T is standing in a spot where they can see EVERY spawn point 
		# at the exact same time, just pick a random one so the wave doesn't break.
		chosen_spawn = spawn_points.pick_random()
		
	# Pick a random enemy from the list and instantiate it
	var new_enemy = enemy_types.pick_random().instantiate()
	
	get_parent().add_child(new_enemy)
	new_enemy.global_position = chosen_spawn.global_position
