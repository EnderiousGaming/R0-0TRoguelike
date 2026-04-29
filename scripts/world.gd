extends Node3D

const UPGRADE_SCENE = preload("res://scenes/upgrade_pickup.tscn")

@onready var wave_director_timer = $WaveDirector/Timer
@onready var portal = $Portal
@onready var portal_collision = $Portal/CollisionShape3D

var target_kills = 0
var portal_active = false

func _ready():
	# 1. Wipe the slate clean for the new room
	RunManager.enemies_defeated_this_room = 0
	
	# 2. Calculate kills needed (Room 1 = 10, Room 2 = 20, etc.)
	target_kills = RunManager.current_stage * 10
	print("SYSTEM: Target kills to open portal is ", target_kills)
	
	portal.visible = false
	portal_collision.call_deferred("set_disabled", true)

func _process(_delta):
	# 3. Check progression based on KILLS, not Score
	if not portal_active and RunManager.enemies_defeated_this_room >= target_kills:
		activate_portal()

func activate_portal():
	portal_active = true
	portal.visible = true
	portal_collision.call_deferred("set_disabled", false)
	
	wave_director_timer.stop()
	
	# --- THE CLEANUP PROTOCOL ---
	# Find every remaining enemy in the room and instantly delete them
	var remaining_enemies = get_tree().get_nodes_in_group("enemy")
	for virus in remaining_enemies:
		virus.queue_free()
	
	# 1. SHUT DOWN THE SPAWNER
	wave_director_timer.stop()
	print("Spawners deactivated.")
	
	# 2. BROADCAST THE MESSAGE TO R0-0T
	# We search the tree for the specific node that has the "player" group tag
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("announce"):
		player.announce("AREA SECURED.\nPROCEED TO UPLINK.")
		
	spawn_upgrades()
	
	print("UPLINK AVAILABLE: Area secured!")
	
func spawn_upgrades():
	# 1. Create a deck of 10 cards and shuffle them
	var pool = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	pool.shuffle()
	
	# 2. Define a triangle of positions around the portal
	var offsets = [Vector3(-3, 0, 2), Vector3(3, 0, 2), Vector3(0, 0, -3)]
	
	# 3. Spawn the first 3 upgrades from the shuffled deck
	for i in range(3):
		var upgrade = UPGRADE_SCENE.instantiate()
		add_child(upgrade)
		
		# Place them using the offsets
		upgrade.global_position = $Portal.global_position + offsets[i]
		
		# Tell the box which upgrade it is!
		upgrade.setup(pool[i])
