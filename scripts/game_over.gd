extends Control

# Grab your column references (Adjust the paths to match your actual scene tree!)
@onready var run_stats_label = $HBoxContainer/ThisRunColumn/StatsText
@onready var lifetime_stats_label = $HBoxContainer/LifetimeColumn/StatsText

func _ready():
	# Unlock the mouse so the player can click "Restart" or "Main Menu"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	populate_run_stats()
	populate_lifetime_stats()

func populate_run_stats():
	var text = "SCORE: %d\n" % RunManager.score
	text += "FLOOR REACHED: %d\n" % RunManager.current_stage
	text += "DAEMONS PURGED: %d\n" % RunManager.daemons_purged
	text += "PROJECTILES FIRED: %d\n" % RunManager.projectiles_fired
	text += "DAMAGE DEALT: %d\n" % RunManager.damage_dealt
	text += "BOSSES PURGED: %d\n" % RunManager.bosses_purged
	text += "POINTS SPENT: %d" % RunManager.points_spent
	
	run_stats_label.text = text

func populate_lifetime_stats():
	var stats = SaveManager.save_data["stats"]
	
	var text = "HIGHEST SCORE: %d\n" % stats["highest_score"]
	text += "HIGHEST FLOOR: %d\n" % stats["highest_stage_reached"]
	text += "TOTAL PURGED: %d\n" % stats["total_daemons_purged"]
	text += "TOTAL SHOTS: %d\n" % stats["projectiles_fired"]
	text += "TOTAL DAMAGE: %d\n" % stats["damage_dealt"]
	text += "TOTAL BOSSES: %d\n" % stats["bosses_purged"]
	text += "TOTAL SPENT: %d\n" % stats["points_spent"]
	text += "R0-0T DEATHS: %d" % stats["r0_0t_deaths"]
	
	lifetime_stats_label.text = text


# ==========================================
# UI EVENTS
# ==========================================

func _on_button_pressed():
	# Teleport the player back to the safe zone (Hub) to start a new run
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
