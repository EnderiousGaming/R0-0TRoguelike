extends GridMap

# --- CONFIGURATION ---
var grid_width = 10
var grid_depth = 10

# Ensure these match your MeshLibrary IDs!
const TILE_FLOOR = 0
const TILE_WALL = 1
const TILE_COVER = 2
const TILE_PILLAR = 3

# SPAWN WEIGHTS (Higher number = Spawns more often)
var tile_weights = {
	TILE_FLOOR: 75,  # 75% chance (Keeps the arena open)
	TILE_WALL: 5,    # 5% chance  (Occasional thick block)
	TILE_COVER: 10,  # 10% chance (Tactical chest-high cover)
	TILE_PILLAR: 10  # 10% chance (Thin, tall obstacles)
}

var wave = {}

# ==========================================
# INITIALIZATION
# ==========================================

func _ready():
	print("SYSTEM: Initializing Wave Function Collapse...")
	generate_wfc()

func generate_wfc():
	clear() 
	wave.clear()
	
	# 1. INITIALIZE THE WAVE & HARDCODE BORDERS
	for x in range(grid_width):
		for z in range(grid_depth):
			if x == 0 or x == grid_width - 1 or z == 0 or z == grid_depth - 1:
				wave[Vector2(x, z)] = [TILE_WALL] 
			else:
				# --- REMOVED TILE_WALL FROM INTERIOR OPTIONS ---
				wave[Vector2(x, z)] = [TILE_FLOOR, TILE_PILLAR]
			
	# 2. COLLAPSE THE GRID
	var uncollapsed_cells = grid_width * grid_depth
	
	while uncollapsed_cells > 0:
		var target_coords = get_lowest_entropy_cell()
		if target_coords == Vector2(-1, -1):
			break 
			
		var options = wave[target_coords]
		if options.is_empty():
			options = [TILE_FLOOR] # Failsafe
			
		# --- DYNAMIC WEIGHTED SELECTION ---
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
		
	# 3. THE BUILDING PASS
	for x in range(grid_width):
		for z in range(grid_depth):
			var final_options = wave[Vector2(x, z)]
			var tile_to_build = TILE_FLOOR 
			if final_options.size() > 0:
				tile_to_build = final_options[0]
			set_cell_item(Vector3i(x, 0, z), tile_to_build)
			
	print("SYSTEM: Map Generation Complete!")
	
	# ==========================================
	# THE FOUNDATION PASS (PLUGGING THE HOLES)
	# ==========================================
	
	# 1. Clean up any old slabs safely
	var old_foundation = get_node_or_null("FoundationSlab")
	if old_foundation:
		old_foundation.name = "DeletedSlab"
		old_foundation.queue_free()

	# 2. Build a STANDARD Godot physics body (No more CSG nodes!)
	var foundation = StaticBody3D.new()
	foundation.name = "FoundationSlab"
	
	# 3. Create the exact Collision Box the NavMesh scanner is looking for
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(grid_width * 4.0, 2.0, grid_depth * 4.0)
	collision.shape = box_shape
	foundation.add_child(collision)
	
	# 4. Create the Visual Mesh so you can actually see the floor
	var mesh_instance = MeshInstance3D.new()
	var visual_mesh = BoxMesh.new()
	visual_mesh.size = box_shape.size
	mesh_instance.mesh = visual_mesh
	foundation.add_child(mesh_instance)

	# 5. Dynamically calculate the center
	var first_cell = map_to_local(Vector3i(0, 0, 0))
	var last_cell = map_to_local(Vector3i(grid_width - 1, 0, grid_depth - 1))
	var exact_center = (first_cell + last_cell) / 2.0
	
	# Positioned perfectly at your -0.9 sweet spot
	foundation.position = Vector3(exact_center.x, exact_center.y - 0.9, exact_center.z)

	# 6. Add it to the world
	add_child(foundation)
	
	# ==========================================
	# ENTITY SPAWN LOGIC & LIGHTING
	# ==========================================
	var floor_cells = get_used_cells_by_item(TILE_FLOOR)
	
	if floor_cells.size() > 0:
		# Player
		var player = get_tree().get_first_node_in_group("player")
		if player:
			# Wrap coordinates in to_global() to guarantee perfect placement regardless of parent nodes
			player.global_position = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 2.0, 0)
			
		# Portal - Safely search from the absolute root of the level, ignoring hierarchy!
		var portal = get_tree().current_scene.get_node_or_null("Portal")
		if portal:
			portal.global_position = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 1.5, 0)
			
		# Enemies
		for sp in get_tree().get_nodes_in_group("spawn_point"):
			sp.global_position = to_global(map_to_local(floor_cells.pick_random())) + Vector3(0, 1.0, 0)

		# PROCEDURAL LIGHTING PASS
		var lights_placed = 0
		for cell in floor_cells:
			if randf() < 0.08: 
				var new_light = OmniLight3D.new()
				new_light.light_color = Color.CYAN
				new_light.light_energy = 3.0 
				new_light.omni_range = 15.0
				new_light.shadow_enabled = true 
				add_child(new_light)
				new_light.global_position = to_global(map_to_local(cell)) + Vector3(0, 4.0, 0)
				lights_placed += 1
				
		print("SYSTEM: ", lights_placed, " cyan light fixtures deployed.")

	# ==========================================
	# NAVMESH BAKING
	# ==========================================
	
	# 1. Wait one single frame so Godot's physics engine registers the concrete foundation
	await get_tree().process_frame
	
	# 2. Find the NavigationRegion3D safely
	var nav_region = get_parent()
	if nav_region is NavigationRegion3D:
		# PASS FALSE TO BAKE SYNCHRONOUSLY! 
		# This freezes the loading screen until the NavMesh is 100% finished so enemies don't crash.
		nav_region.bake_navigation_mesh(false)
		print("SYSTEM: NavMesh dynamically baked! Enemies are online.")

# ==========================================
# WFC MATHEMATICS
# ==========================================

func get_lowest_entropy_cell() -> Vector2:
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
	for x in range(grid_width):
		for z in range(grid_depth):
			var current_options = wave[Vector2(x, z)]
			if current_options.size() == 1:
				continue
					
			# ANTI-CLUMPING PROTOCOL
			var locked_wall_neighbors = 0
			var neighbors = [Vector2(x+1, z), Vector2(x-1, z), Vector2(x, z+1), Vector2(x, z-1)]
			
			for n in neighbors:
				# Treat both solid walls and cover blocks as geometry to avoid clumping!
				if wave.has(n) and wave[n].size() == 1:
					if wave[n][0] == TILE_WALL or wave[n][0] == TILE_COVER:
						locked_wall_neighbors += 1
					
			if locked_wall_neighbors >= 2:
				if current_options.has(TILE_WALL):
					current_options.erase(TILE_WALL)
				if current_options.has(TILE_COVER):
					current_options.erase(TILE_COVER)
