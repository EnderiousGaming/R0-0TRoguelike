extends Control

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
# (None in this script)

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
@onready var run_stats_label = $HBoxContainer/ThisRunColumn/StatsText
@onready var lifetime_stats_label = $HBoxContainer/LifetimeColumn/StatsText

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes the game over screen by unlocking the mouse and populating stats."""
	# Unlock the mouse so the player can click "Restart" or "Main Menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	populate_run_stats()
	populate_lifetime_stats()

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func populate_run_stats():
	"""Gathers and displays stats from the current run."""
	var text = "SCORE: %d\n" % RunManager.score
	text += "FLOOR REACHED: %d\n" % RunManager.current_stage
	text += "DAEMONS PURGED: %d\n" % RunManager.daemons_purged
	text += "PROJECTILES FIRED: %d\n" % RunManager.projectiles_fired
	text += "DAMAGE DEALT: %d\n" % RunManager.damage_dealt
	text += "BOSSES PURGED: %d\n" % RunManager.bosses_purged
	text += "POINTS SPENT: %d" % RunManager.points_spent
	
	run_stats_label.text = text

func populate_lifetime_stats():
	"""Gathers and displays lifetime stats from the SaveManager."""
	var stats = SaveManager.save_data["stats"]
	
	# Translate the integer into the difficulty name
	var threat_text = "NONE"
	if stats["highest_threat_cleared"] >= 0:
		threat_text = RunManager.DIFF_NAMES[stats["highest_threat_cleared"]]
	
	var text = "HIGHEST SCORE: %d\n" % stats["highest_score"]
	text += "HIGHEST FLOOR: %d\n" % stats["highest_stage_reached"]
	text += "TOTAL PURGED: %d\n" % stats["total_daemons_purged"]
	text += "TOTAL SHOTS: %d\n" % stats["projectiles_fired"]
	text += "TOTAL DAMAGE: %d\n" % stats["damage_dealt"]
	text += "TOTAL BOSSES: %d\n" % stats["bosses_purged"]
	text += "TOTAL SPENT: %d\n" % stats["points_spent"]
	text += "R0-0T DEATHS: %d\n" % stats["r0_0t_deaths"]
	text += "MAX THREAT PURGED: %s\n" % threat_text
	
	lifetime_stats_label.text = text

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_button_pressed():
	"""Handles the restart button press."""
	# Teleport the player back to the safe zone (Hub) to start a new run
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
