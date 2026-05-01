extends Node3D

# ==========================================
# VARIABLES & CONFIG
# ==========================================

@export var enemy_types: Array[PackedScene]
var spawn_points = []

# ==========================================
# CORE LOGIC
# ==========================================

func _ready():
	# Gather all valid spawn locations in the level
	spawn_points = get_tree().get_nodes_in_group("spawn_point")
	
	if spawn_points.is_empty():
		print("DIRECTOR ERROR: No spawn points found in the level!")
	else:
		print("Wave Director Online. Commencing virus drops...")

func _on_timer_timeout():
	"""Main spawn cycle: Triggers based on the WaveTimer node."""
	if spawn_points.is_empty() or enemy_types.is_empty():
		return
		
	var camera = get_viewport().get_camera_3d()
	var hidden_spawns = []
	
	# Identify spawn points outside the player's current field of view (frustum)
	if camera:
		for sp in spawn_points:
			if not camera.is_position_in_frustum(sp.global_position):
				hidden_spawns.append(sp)
				
	var chosen_spawn = null
	
	# Prioritize hidden spawn points to avoid spawning enemies in plain sight
	if hidden_spawns.size() > 0:
		chosen_spawn = hidden_spawns.pick_random()
	else:
		# Fallback: Pick any point if the player has full visibility
		chosen_spawn = spawn_points.pick_random()
		
	# Instantiate and deploy the selected enemy
	var new_enemy = enemy_types.pick_random().instantiate()
	get_parent().add_child(new_enemy)
	new_enemy.global_position = chosen_spawn.global_position
