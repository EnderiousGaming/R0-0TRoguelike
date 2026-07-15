extends Node3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
# (None in this script)

# ==========================================
# EXPORT VARIABLES
# ==========================================
@export var enemy_types: Array[PackedScene]

# ==========================================
# PUBLIC VARIABLES
# ==========================================
var spawn_points = []

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Gathers all valid spawn locations in the level on startup."""
	spawn_points = get_tree().get_nodes_in_group("spawn_point")
	
	if spawn_points.is_empty():
		print("DIRECTOR ERROR: No spawn points found in the level!")
	else:
		print("Wave Director Online. Commencing virus drops...")

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func _on_timer_timeout():
	"""
	Called when the WaveTimer ticks.
	Attempts to safely spawn an enemy if the population cap has not been reached.
	"""
	print("SYSTEM: WaveTimer ticked! Attempting to spawn enemy...")
	
	# --- POPULATION CAP CHECK ---
	var current_enemy_count = get_tree().get_nodes_in_group("enemy").size()
	var max_enemies = RunManager.DIFF_MAX_ENEMIES[RunManager.current_difficulty]
	
	if current_enemy_count >= max_enemies:
		print("SYSTEM: Maximum threat capacity reached. Spawn aborted.")
		return 
	
	# --- SAFETY CHECKS ---
	if spawn_points.is_empty():
		push_error("DIRECTOR ERROR: Spawn points array is empty!")
		return
		
	if enemy_types.is_empty():
		push_error("DIRECTOR ERROR: No enemy scenes loaded! Check the Inspector for WaveDirector!")
		return
		
	var camera = get_viewport().get_camera_3d()
	var hidden_spawns = []
	var valid_spawns = []
	
	# --- GATHER SAFE SPAWN POINTS ---
	if camera:
		for sp in spawn_points:
			if is_instance_valid(sp):
				# Only consider this spawner if no Daemons are standing on it!
				if is_spawn_clear(sp.global_position):
					valid_spawns.append(sp) # Save it to our safe list
					
					# Now check if it is off-camera
					if not camera.is_position_in_frustum(sp.global_position):
						hidden_spawns.append(sp)
					
		# SAFETY ABORT: If no spawners survived (like in the Boss Arena), stop the function!
		if valid_spawns.is_empty():
			return
			
	var chosen_spawn = null
	
	# --- PICK A SPAWN POINT ---
	# Prefer off-camera spawns, fallback to valid on-camera spawns
	if hidden_spawns.size() > 0:
		chosen_spawn = hidden_spawns.pick_random()
	else:
		chosen_spawn = valid_spawns.pick_random()
		
	# --- SPAWN THE ENEMY ---
	var new_enemy = enemy_types.pick_random().instantiate()
	get_parent().add_child(new_enemy)
	new_enemy.global_position = chosen_spawn.global_position
	
	print("SYSTEM: Enemy successfully deployed at ", chosen_spawn.global_position)

func is_spawn_clear(target_pos: Vector3) -> bool:
	"""
	Checks if a specific spawn location is clear of enemies.
	Returns true if no enemies are within 1.5 meters of the point.
	"""
	var active_daemons = get_tree().get_nodes_in_group("enemy")
	
	for daemon in active_daemons:
		if is_instance_valid(daemon):
			if daemon.global_position.distance_to(target_pos) < 1.5:
				return false
				
	return true
