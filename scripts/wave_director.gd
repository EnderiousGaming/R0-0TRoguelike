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
	print("SYSTEM: WaveTimer ticked! Attempting to spawn enemy...")
	
	if spawn_points.is_empty():
		push_error("DIRECTOR ERROR: Spawn points array is empty!")
		return
		
	if enemy_types.is_empty():
		push_error("DIRECTOR ERROR: No enemy scenes loaded! Check the Inspector for WaveDirector!")
		return
		
	var camera = get_viewport().get_camera_3d()
	var hidden_spawns = []
	var valid_spawns = []
	
	if camera:
		
		for sp in spawn_points:
			if is_instance_valid(sp):
				# NEW: Only consider this spawner if no Daemons are standing on it!
				if is_spawn_clear(sp.global_position):
					valid_spawns.append(sp) # Save it to our safe list
					
					# Now check if it is off-camera
					if camera and not camera.is_position_in_frustum(sp.global_position):
						hidden_spawns.append(sp)
					
		# 2. SAFETY ABORT: If no spawners survived (like in the Boss Arena), stop the function!
		if valid_spawns.is_empty():
			return
			
	var chosen_spawn = null
	
	# 3. Pick a spawn point safely
	if hidden_spawns.size() > 0:
		chosen_spawn = hidden_spawns.pick_random()
	else:
		# Fallback to our new safe list instead of the original broken array
		chosen_spawn = valid_spawns.pick_random()
		
	var new_enemy = enemy_types.pick_random().instantiate()
	get_parent().add_child(new_enemy)
	new_enemy.global_position = chosen_spawn.global_position
	
	print("SYSTEM: Enemy successfully deployed at ", chosen_spawn.global_position)

func is_spawn_clear(target_pos: Vector3) -> bool:
	# Grab all currently active Daemons
	var active_daemons = get_tree().get_nodes_in_group("enemy")
	
	for daemon in active_daemons:
		if is_instance_valid(daemon):
			# If a Daemon is standing within 1.5 meters of this point, it's blocked!
			if daemon.global_position.distance_to(target_pos) < 1.5:
				return false
				
	# If the loop finishes without finding anyone too close, the spot is safe
	return true
