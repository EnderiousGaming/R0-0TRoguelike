extends Node3D

func _ready():
	# 1. Reset the stats
	RunManager.reset_run()
	
	# 2. NEW: Force the player to update their visuals to match the reset!
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_weapon_loadout"):
		player.update_weapon_loadout()
