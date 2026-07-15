extends Area3D

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
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
# --- STATE VARIABLES ---
# Security lock to prevent the player from triggering the portal multiple times in one frame
var is_active = true 

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
# (None in this script)

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================
# (None in this script)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_body_entered(body):
	"""Handles player collision to transition between levels."""
	if is_active and body.is_in_group("player"):
		is_active = false
		
		# Increment the global stage tracker
		RunManager.current_stage += 1
		var stage = RunManager.current_stage
		
		print("Uplink established. Routing to Stage: ", stage)
		
		var next_scene_path = ""
		
		# --- LEVEL PROGRESSION ROUTER ---
		match stage:
			# THE COMBAT ROOMS
			1, 2, 4, 5, 7, 8:
				var combat_maps = [
					"res://scenes/world.tscn",
					"res://scenes/world_a.tscn",
					"res://scenes/world_b.tscn",
					"res://scenes/world_c.tscn",
					"res://scenes/world_d.tscn"
				]
				# Pick a random combat arena to keep runs fresh
				next_scene_path = combat_maps.pick_random()
				
			# THE SHOPS (Every 3rd stage)
			3, 6, 9:
				next_scene_path = "res://scenes/shop.tscn"
				
			# THE FINAL BOSS
			10:
				next_scene_path = "res://scenes/world.tscn"
				
			# SAFETY NET (If the stage goes over 10 or bugs out, return to the Hub)
			_:
				print("Simulation Complete. Rebooting to Hub.")
				next_scene_path = "res://scenes/hub.tscn"

		# Defers the scene change until the current physics frame is completely finished
		get_tree().call_deferred("change_scene_to_file", next_scene_path)
