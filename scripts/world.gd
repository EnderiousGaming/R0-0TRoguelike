extends Node3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
const UPGRADE_SCENE = preload("res://scenes/upgrade_pickup.tscn")

# ==========================================
# EXPORT VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
var target_kills = 0
var portal_active = false

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
@onready var wave_director_timer = $WaveDirector/Timer
@onready var portal = $Portal
@onready var portal_collision = $Portal/CollisionShape3D

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes the stage progression requirements and arena setup."""
	AudioManager.play_arena_music()
	
	# 1. Reset room progression data
	RunManager.enemies_defeated_this_room = 0
	
	# 2. Calculate required kills for this stage (10 kills per stage level)
	target_kills = RunManager.current_stage * 10
	print("SYSTEM: Target kills to open portal is ", target_kills)
	
	# 3. Ensure the exit portal is hidden and disabled on start
	portal.visible = false
	portal_collision.call_deferred("set_disabled", true)

func _process(_delta):
	"""Monitors kill count to trigger the portal sequence once the target is reached."""
	if not portal_active and RunManager.enemies_defeated_this_room >= target_kills:
		activate_portal()

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func activate_portal():
	"""Handles the transition from combat phase to the upgrade/exit phase."""
	portal_active = true
	portal.visible = true
	portal_collision.call_deferred("set_disabled", false)
	
	# 1. Shutdown the enemy spawner
	wave_director_timer.stop()
	print("SYSTEM: Spawners deactivated.")
	
	# 2. Vaporize remaining enemies to clear the arena
	var remaining_enemies = get_tree().get_nodes_in_group("enemy")
	for daemon in remaining_enemies:
		daemon.queue_free()
		
	# 3. Turn off dynamic hazards
	get_tree().call_group("hazards", "set_hazard_active", false)
	
	# 4. Broadcast the secure message to the player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("announce"):
		player.announce("AREA SECURED.\nPROCEED TO UPLINK.")
		
	# 5. Generate random upgrade choices
	spawn_upgrades()
	print("SYSTEM: UPLINK AVAILABLE. Area secured!")
	
func spawn_upgrades():
	"""Generates 3 valid random upgrades based on the player's active loadout."""
	var valid_pool = []
	
	# Add general movement and survival upgrades
	valid_pool.append_array([2, 3, 5, 7, 17])
	
	# Add weapon-specific upgrades based on current loadout
	if RunManager.equipped_weapon == "blaster":
		valid_pool.append_array([1, 4, 11, 12, 18, 19])
	elif RunManager.equipped_weapon == "sword":
		valid_pool.append_array([13, 14, 15, 16, 20])
		
	# Shuffle the valid pool to ensure random selection
	valid_pool.shuffle()
	
	var offsets = [Vector3(-1.5, 0, 1), Vector3(1.5, 0, 1), Vector3(0, 0, -1.5)]
	
	# Spawn the top 3 upgrades from the shuffled deck
	for i in range(3):
		var upgrade = UPGRADE_SCENE.instantiate()
		add_child(upgrade)
		upgrade.global_position = $Portal.global_position + offsets[i]
		upgrade.setup(valid_pool[i])
