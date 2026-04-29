extends Node

# --- LOADOUT ---
var equipped_weapon = "blaster" # Can be "blaster" or "sword"

# --- MODIFIER FLAGS ---
var has_ice_physics = false
var has_health_drain = false
var has_lifesteal = false
var has_moon_jump = false
var has_close_combat = false
var has_sniper_combat = false
var has_radiation_aura = false

# --- SHOP ECONOMY ---
var heal_cost = 500
var speed_cost = 800
var damage_cost = 1000
var max_health_cost = 1200 # New upgrade!

# --- RUN STATE ---
var current_stage = 0
var score = 0
var enemies_defeated_this_room = 0 # NEW: The room progression tracker

var max_health = 5
var current_health = max_health

var laser_damage = 1
var player_speed_multiplier = 1.0

var fire_rate = 0.25
var fire_rate_cost = 1000

func reset_run():
	print("SYSTEM: Resetting run variables...")
	current_stage = 0 
	score = 0
	enemies_defeated_this_room = 0 # Reset this!
	current_health = max_health
	laser_damage = 1
	player_speed_multiplier = 1.0
	heal_cost = 500
	speed_cost = 800
	damage_cost = 1000
	max_health_cost = 1200
	fire_rate = 0.25
	fire_rate_cost = 1000
	has_ice_physics = false
	has_health_drain = false
	has_lifesteal = false
	has_moon_jump = false
	has_close_combat = false
	has_sniper_combat = false
	has_radiation_aura = false
	equipped_weapon = "blaster"

func apply_upgrade(upgrade_id: int):
	match upgrade_id:
		1: # Damage +, Fire Rate -
			laser_damage += 2
			fire_rate += 0.15 # Higher fire_rate means a longer delay between shots!
		2: # Faster, Ice Physics
			player_speed_multiplier += 0.3
			has_ice_physics = true
		3: # Max HP +, Slower
			max_health += 3
			current_health += 3
			player_speed_multiplier -= 0.15
		4: # Fire Rate +, Damage -
			fire_rate = max(0.05, fire_rate - 0.1) # Faster!
			laser_damage = max(1, laser_damage - 1) # Don't let damage drop below 1
		5: # Max HP ++, Drain
			max_health += 5
			current_health += 5
			has_health_drain = true
		6: # Lifesteal, Drain
			has_lifesteal = true
			has_health_drain = true
		7: # Jump ++, Gravity ++
			has_moon_jump = true
		8: # Close Combat
			has_close_combat = true
		9: # Sniper
			has_sniper_combat = true
		10: # Radiation Aura
			has_radiation_aura = true
