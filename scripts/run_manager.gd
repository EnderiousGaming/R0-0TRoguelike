extends Node

# ==========================================
# GLOBAL LOADOUT & FLAGS
# ==========================================

var equipped_weapon = "blaster" # Options: "blaster", "sword"

# --- MODIFIER FLAGS ---
var has_ice_physics = false
var has_health_drain = false
var has_lifesteal = false
var has_moon_jump = false
var has_close_combat = false
var has_sniper_combat = false
var has_radiation_aura = false


# ==========================================
# WEAPON STATS
# ==========================================

# --- BLASTER STATS ---
var laser_damage = 1
var fire_rate = 0.25
var max_ammo = 15
var current_ammo = 15
var reload_time = 1.5

# --- SWORD STATS ---
var sword_swing_speed = 1.0
var sword_range_multiplier = 1.0
var has_deflect_boost = false


# ==========================================
# PLAYER & RUN STATE
# ==========================================

# --- HP & MOVEMENT ---
var max_health = 5
var current_health = max_health
var player_speed_multiplier = 1.0

# --- PROGRESSION ---
var current_stage = 0
var score = 0
var enemies_defeated_this_room = 0

# --- DASH ---
var dash_cooldown = 1.5


# ==========================================
# ECONOMY (SHOP COSTS)
# ==========================================

var heal_cost = 500
var speed_cost = 800
var damage_cost = 1000
var fire_rate_cost = 1000
var max_health_cost = 1200


# ==========================================
# RUN LOGIC FUNCTIONS
# ==========================================

func reset_run():
	"""Resets all variables to default state when starting a new run or entering the Hub."""
	print("SYSTEM: Resetting run variables...")
	
	# Stats
	max_health = 5
	current_health = max_health
	player_speed_multiplier = 1.0
	score = 0
	current_stage = 0
	
	# Weapon Defaults
	laser_damage = 1
	fire_rate = 0.25
	max_ammo = 15
	current_ammo = 15
	reload_time = 1.5
	
	# Sword Defaults
	sword_swing_speed = 1.0
	sword_range_multiplier = 1.0
	has_deflect_boost = false
	
	# Movement Defaults
	dash_cooldown = 1.5
	
	# Flags
	has_ice_physics = false
	has_health_drain = false
	has_lifesteal = false
	has_moon_jump = false
	has_close_combat = false
	has_sniper_combat = false
	has_radiation_aura = false

func apply_upgrade(upgrade_id: int):
	"""Applies a specific upgrade modifier to the current run state."""
	match upgrade_id:
		# --- GENERAL UPGRADES ---
		1: # Overclocked Core: Damage +, Fire Rate -
			laser_damage += 2
			fire_rate += 0.15 
		2: # Speed Demon: Faster, Ice Physics
			player_speed_multiplier += 0.3
			has_ice_physics = true
		3: # Tank: Max HP +, Slower
			max_health += 3
			current_health += 3
			player_speed_multiplier -= 0.15
		4: # Rapid Fire: Fire Rate +, Damage -
			fire_rate = max(0.05, fire_rate - 0.1) 
			laser_damage = max(1, laser_damage - 1) 
		5: # Titan Plating: Max HP ++, Drain
			max_health += 5
			current_health += 5
			has_health_drain = true
		6: # Vampire: Lifesteal, Drain
			has_lifesteal = true
			has_health_drain = true
		7: # Zero-G: Jump ++, Gravity ++
			has_moon_jump = true
		8: # CQC: Close Combat Bonus
			has_close_combat = true
		9: # Longshot: Sniper Bonus
			has_sniper_combat = true
		10: # Fallout: Radiation Aura
			has_radiation_aura = true
			
		# --- BLASTER SPECIFIC ---
		11: # Extended Mag
			max_ammo += 10
			current_ammo += 10
		12: # Sleight of Hand
			reload_time = max(0.5, reload_time - 0.5)
		
		# --- SWORD SPECIFIC ---
		13: # Carbon-Fiber Hilt
			sword_swing_speed += 0.5
		14: # Extended Blade
			sword_range_multiplier += 0.5
		15: # Kinetic Deflection
			has_deflect_boost = true
			
		# --- DASH & SURVIVAL ---
		16: # Hydraulic Servos
			dash_cooldown = max(0.5, dash_cooldown - 0.5)
		17: # Kinetic Plating
			max_health += 2
			current_health += 2
