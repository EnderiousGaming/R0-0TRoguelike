extends Node

# --- RUN STATE ---
var current_stage = 0
var score = 0
var enemies_defeated_this_room = 0 # NEW: The room progression tracker

var max_health = 5
var current_health = max_health

var laser_damage = 1
var player_speed_multiplier = 1.0

func reset_run():
	print("SYSTEM: Resetting run variables...")
	current_stage = 0 
	score = 0
	enemies_defeated_this_room = 0 # Reset this!
	current_health = max_health
	laser_damage = 1
	player_speed_multiplier = 1.0
