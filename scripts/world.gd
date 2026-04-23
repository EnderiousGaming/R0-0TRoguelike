extends Node3D

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
	
	print("UPLINK AVAILABLE: Area secured!")
