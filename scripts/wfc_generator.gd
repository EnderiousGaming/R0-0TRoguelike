extends GridMap

# --- CONFIGURATION ---
var grid_width = 20
var grid_depth = 20

# Ensure these match your MeshLibrary IDs!
const TILE_FLOOR = 0
const TILE_WALL = 1
const TILE_PILLAR = 3
const TILE_HAZARD = 4

# SPAWN WEIGHTS (Higher number = Spawns more often)
var tile_weights = {
	TILE_FLOOR: 80, # 80% chance (Keeps the arena open)
	TILE_WALL: 5,    # 5% chance  (Occasional thick block)
	TILE_PILLAR: 10,  # 10% chance (Thin, tall obstacles)
	TILE_HAZARD: 5 #5% chance (occasional hazard)
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
				wave[Vector2(x, z)] = [TILE_FLOOR, TILE_PILLAR, TILE_HAZARD]
			
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
	
	# # ==========================================
	# THE PILLAR PLASTER PASS (Filling the holes)
	# ==========================================
	
	# 1. Clean up old patches from the last generation
	for child in get_children():
		if child.name.begins_with("PillarPatch"):
			child.queue_free()
			
	# 2. Find every single Pillar on the map
	var pillar_cells = get_used_cells_by_item(TILE_PILLAR)
	var patch_count = 0
	
	for cell in pillar_cells:
		# 3. Build a local 4x4 floor patch for this specific hole
		var patch = StaticBody3D.new()
		patch.name = "PillarPatch_" + str(patch_count)
		
		# Give it the exact dimensions of your standard floor tile (4x0.2x4)
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(4.0, 0.2, 4.0) 
		collision.shape = box_shape
		patch.add_child(collision)
		
		# Build the visual mesh so it isn't an invisible bridge
		var mesh_instance = MeshInstance3D.new()
		var visual_mesh = BoxMesh.new()
		visual_mesh.size = box_shape.size
		mesh_instance.mesh = visual_mesh
		
		# Optional: Create a quick material to make it match your GridMap floor color!
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.25, 0.25, 0.25) # Tweak this to match your floor
		visual_mesh.material = mat
		
		patch.add_child(mesh_instance)
		
		# 4. Snap it to the exact same cell center as the Pillar
		patch.position = map_to_local(cell)
		
		# 5. Add it to the world
		add_child(patch)
		patch_count += 1
		
	print("SYSTEM: ", patch_count, " Pillar holes plastered perfectly flush.")
	
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
	# CORRUPTED DOMAIN DEPLOYMENT
	# ==========================================
		var hazard_scene = preload("res://scenes/hazard_zone.tscn")
		var hazard_cells = get_used_cells_by_item(TILE_HAZARD)
		var domains_placed = 0
		
		for cell in hazard_cells:
			var zone = hazard_scene.instantiate()
			add_child(zone)
			# Drop the zone exactly on the red tile!
			zone.global_position = to_global(map_to_local(cell)) 
			domains_placed += 1
			
		print("SYSTEM: ", domains_placed, " corrupted domains materialized.")

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
					if wave[n][0] == TILE_WALL:
						locked_wall_neighbors += 1
					
			if locked_wall_neighbors >= 2:
				if current_options.has(TILE_WALL):
					current_options.erase(TILE_WALL)
