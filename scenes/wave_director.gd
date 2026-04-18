extends Node3D

@export var enemy_scene: PackedScene
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
	if spawn_points.is_empty() or enemy_scene == null:
		return
		
	var random_spawn = spawn_points.pick_random()
	var new_enemy = enemy_scene.instantiate()
	
	# 1. Add it to the physical game world FIRST
	get_parent().add_child(new_enemy)
	
	# 2. NOW move it to the correct coordinates
	new_enemy.global_position = random_spawn.global_position
