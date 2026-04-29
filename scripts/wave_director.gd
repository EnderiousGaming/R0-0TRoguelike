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
	if spawn_points.is_empty() or enemy_types.is_empty():
		return
		
	var random_spawn = spawn_points.pick_random()
	
	# Pick a random enemy from the list and instantiate it
	var new_enemy = enemy_types.pick_random().instantiate()
	
	get_parent().add_child(new_enemy)
	new_enemy.global_position = random_spawn.global_position
