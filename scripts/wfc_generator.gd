extends GridMap

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
# Ensure these match your MeshLibrary IDs!
const TILE_FLOOR = 0
const TILE_WALL = 1
const TILE_PILLAR = 3
const TILE_HAZARD = 4
const TILE_CEILING = 5 

# ==========================================
# EXPORT VARIABLES
# ==========================================
@export var is_boss_arena: bool = false

# ==========================================
# PUBLIC VARIABLES
# ==========================================
# --- CONFIGURATION ---
var grid_width = 20
var grid_depth = 20

# SPAWN WEIGHTS (Higher number = Spawns more often)
var tile_weights = {
	TILE_FLOOR: 80, # 80% chance (Keeps the arena open)
	TILE_WALL: 5,   # 5% chance  (Occasional thick block)
	TILE_PILLAR: 10, # 10% chance (Thin, tall obstacles)
	TILE_HAZARD: 5  # 5% chance (Occasional hazard)
}

var wave = {}

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
	"""Initializes the arena by setting spawn weights and starting the WFC generation."""
	# Automatically detect if this is the final encounter
	if RunManager.current_stage == 10:
		is_boss_arena = true
		print("SYSTEM: Final Stage reached. Initializing Boss Arena protocols.")
		
	# 1. Decide the weights right when the node loads!
	if is_boss_arena:
		# THE UNSTABLE CORE: No walls, lots of pillars, 20% hazard floor
		tile_weights = {
			TILE_FLOOR: 60,
			TILE_WALL: 0, 
			TILE_PILLAR: 20,
			TILE_HAZARD: 20
		}
	else:
		# STANDARD ROOM: Your normal weights
		tile_weights = {
			TILE_FLOOR: 80,
			TILE_WALL: 5,
			TILE_PILLAR: 10,
			TILE_HAZARD: 5
		}
		
	# 2. Proceed with generation
	print("SYSTEM: Initializing Wave Function Collapse...")
	generate_wfc()

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func generate_wfc():
	"""Runs the core Wave Function Collapse algorithm to procedurally generate the room."""
	clear() 
	wave.clear()
	
	# --- 1. INITIALIZE THE WAVE & HARDCODE BORDERS ---
	for x in range(grid_width):
		for z in range(grid_depth):
			if x == 0 or x == grid_width - 1 or z == 0 or z == grid_depth - 1:
				wave[Vector2(x, z)] = [TILE_WALL] 
			else:
				wave[Vector2(x, z)] = [TILE_FLOOR, TILE_PILLAR, TILE_HAZARD]
			
	# --- 2. COLLAPSE THE GRID ---
	var uncollapsed_cells = grid_width * grid_depth
	
	while uncollapsed_cells > 0:
		var target_coords = get_lowest_entropy_cell()
		if target_coords == Vector2(-1, -1):
			break 
			
		var options = wave[target_coords]
		if options.is_empty():
			options = [TILE_FLOOR] # Failsafe
			
		# DYNAMIC WEIGHTED SELECTION
		var chosen_tile = options[0]
		if options.size() > 1:
			var total_weight = 0
			for opt in options:
				total_weight += tile_weights[opt]
				
			var roll = randi() % int(total_weight)
			var current_weight = 0
			
			for opt in options:
				current_weight += tile_weights[opt]
				if roll < current_weight:
					chosen_tile = opt
					break
		
		wave[target_coords] = [chosen_tile]
		propagate()
		uncollapsed_cells -= 1
		
	# --- 3. THE BUILDING PASS ---
	for x in range(grid_width):
		for z in range(grid_depth):
			var final_options = wave[Vector2(x, z)]
			var tile_to_build = TILE_FLOOR 
			if final_options.size() > 0:
				tile_to_build = final_options[0]
			set_cell_item(Vector3i(x, 0, z), tile_to_build)
			
	print("SYSTEM: Map Generation Complete!")
	
	# --- 4. CEILING GENERATION PASS ---
	# Boss is tall, so ceiling must be high enough.
	var ceiling_height = 6 
	print("SYSTEM: Enclosing arena architecture...")
	for x in range(grid_width):
		for z in range(grid_depth):
			set_cell_item(Vector3i(x, ceiling_height, z), TILE_CEILING)
	
	_deploy_entities()
	
func _deploy_entities():
	"""Handles spawning the player, portal, enemies, lights, and hazards after map generation."""
	var floor_cells = get_used_cells_by_item(TILE_FLOOR)
	
	if floor_cells.size() > 0:
		# Player Spawn
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 2.0, 0)
			
		# Portal Spawn
		var portal = get_tree().current_scene.get_node_or_null("Portal")
		if portal:
			portal.global_position = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 1.5, 0)
			
		# Daemon Spawn Logic
		var spawn_points = get_tree().get_nodes_in_group("spawn_point")
		
		if is_boss_arena:
			for sp in spawn_points:
				sp.queue_free()
			print("SYSTEM: Standard Daemon spawners neutralized.")
		else:
			for sp in spawn_points:
				sp.global_position = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 1.0, 0)

		# Procedural Lighting Pass
		var lights_placed = 0
		for cell in floor_cells:
			if randf() < 0.08: 
				var new_light = OmniLight3D.new()
				new_light.light_color = Color.CYAN
				new_light.light_energy = 3.0 
				new_light.omni_range = 15.0
				new_light.shadow_enabled = false 
				add_child(new_light)
				new_light.global_position = to_global(map_to_local(cell)) + Vector3(0, 4.0, 0)
				lights_placed += 1
				
		print("SYSTEM: ", lights_placed, " cyan light fixtures deployed.")
		
		# Boss Spawn Logic
		if is_boss_arena:
			var aureus_scene = preload("res://scenes/boss.tscn")
			var boss_instance = aureus_scene.instantiate()
			
			get_parent().call_deferred("add_child", boss_instance)
			var spawn_pos = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 3.0, 0)
			boss_instance.set_deferred("global_position", spawn_pos)
			print("SYSTEM: AUREUS has materialized.")
		
		# Corrupted Domain (Hazards) Deployment
		var hazard_scene = preload("res://scenes/hazard_zone.tscn")
		var hazard_cells = get_used_cells_by_item(TILE_HAZARD)
		var domains_placed = 0
		
		for cell in hazard_cells:
			var zone = hazard_scene.instantiate()
			add_child(zone)
			zone.global_position = to_global(map_to_local(cell)) 
			domains_placed += 1
			
		print("SYSTEM: ", domains_placed, " corrupted domains materialized.")

	_bake_navmesh()

func _bake_navmesh():
	"""Bakes the navigation mesh dynamically after generation."""
	# Wait one frame so Godot's physics engine registers the concrete foundation
	await get_tree().process_frame
	
	# Find the NavigationRegion3D safely
	var nav_region = get_parent()
	if nav_region is NavigationRegion3D:
		# PASS FALSE TO BAKE SYNCHRONOUSLY! 
		nav_region.bake_navigation_mesh(false)
		print("SYSTEM: NavMesh dynamically baked! Enemies are online.")

# ==========================================
# WFC MATHEMATICS
# ==========================================

func get_lowest_entropy_cell() -> Vector2:
	"""Finds the uncollapsed cell with the fewest remaining tile options."""
	var best_cell = Vector2(-1, -1)
	var lowest_entropy = 999
	for x in range(grid_width):
		for z in range(grid_depth):
			var options = wave[Vector2(x, z)]
			var entropy = options.size()
			if entropy > 1 and entropy < lowest_entropy:
				lowest_entropy = entropy
				best_cell = Vector2(x, z)
	return best_cell

func propagate():
	"""Updates the possible tiles for neighboring cells based on recent collapses."""
	for x in range(grid_width):
		for z in range(grid_depth):
			var current_options = wave[Vector2(x, z)]
			if current_options.size() == 1:
				continue
					
			# ANTI-CLUMPING PROTOCOL
			var locked_wall_neighbors = 0
			var neighbors = [Vector2(x+1, z), Vector2(x-1, z), Vector2(x, z+1), Vector2(x, z-1)]
			
			for n in neighbors:
				if wave.has(n) and wave[n].size() == 1:
					if wave[n][0] == TILE_WALL:
						locked_wall_neighbors += 1
					
			if locked_wall_neighbors >= 2:
				if current_options.has(TILE_WALL):
					current_options.erase(TILE_WALL)

# ==========================================
# DYNAMIC ARENA HAZARDS
# ==========================================

func _on_hazard_shift_timer_timeout():
	"""Dynamically re-routes corrupted domains during the Boss battle."""
	if not is_boss_arena:
		return # Only shift the room if we are fighting AUREUS
		
	print("SYSTEM: Arena Core unstable! Re-routing Corrupted Domains...")
	
	# 1. Destroy old invisible damage hitboxes safely
	for child in get_children():
		if child.name.begins_with("DynamicHazard"):
			child.queue_free()
			
	# 2. Gather every single walkable cell in the arena
	var floor_cells = get_used_cells_by_item(TILE_FLOOR)
	var hazard_cells = get_used_cells_by_item(TILE_HAZARD)
	var all_walkable = floor_cells + hazard_cells
	
	# 3. Visually reset the entire floor to safe, standard concrete
	for cell in all_walkable:
		set_cell_item(cell, TILE_FLOOR)
		
	# 4. Shuffle the deck and pick new spots for the hazards
	all_walkable.shuffle()
	
	# Make exactly 25% of the room a deadly hazard
	var new_hazard_count = int(all_walkable.size() * 0.25) 
	var hazard_scene = preload("res://scenes/hazard_zone.tscn")
	
	for i in range(new_hazard_count):
		var cell = all_walkable[i]
		
		# Change the visual GridMap tile to the purple Hazard material
		set_cell_item(cell, TILE_HAZARD)
		
		# Spawn the physical damage hitbox and lift it 1 meter up
		var zone = hazard_scene.instantiate()
		zone.name = "DynamicHazard_" + str(i)
		add_child(zone)
		zone.global_position = to_global(map_to_local(cell)) + Vector3(0, 1.0, 0)
