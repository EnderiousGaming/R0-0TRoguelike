extends Node3D


# ==========================================
# CORE LOOP
# ==========================================

func _ready():
	# 1. Reset the player's run stats upon entering the safe zone
	RunManager.reset_run()
	
	# 2. Force the player to update their visual loadout to match the reset
	# This prevents the race condition where R0-0T respawns holding a sword,
	# but the internal stats have already been reset to the starting blaster!
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("update_weapon_loadout"):
		player.update_weapon_loadout()
