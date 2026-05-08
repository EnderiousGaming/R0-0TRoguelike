extends Node

const SAVE_PATH = "user://save_data.json"

# The master dictionary that holds everything we want to save
var save_data = {
	"stats": {
		"total_daemons_purged": 0,
		"r0_0t_deaths": 0,
		"highest_stage_reached": 0,
		"highest_score": 0,
		"projectiles_fired": 0,
		"damage_dealt": 0,
		"bosses_purged": 0,
		"points_spent": 0
	},
	"options": {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 1.0,
		"mouse_sensitivity": 0.002,
		"difficulty": 1
	},
	"unlocks": {
		"highest_shop_tier": 1
	}
}

func _ready():
	# Automatically load the player's data the moment the game boots up
	load_game()

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# "\t" makes the JSON pretty-printed and readable in a text editor!
		var json_string = JSON.stringify(save_data, "\t") 
		file.store_string(json_string)
		file.close()
		print("SYSTEM: Memory core synced. Save data written to disk.")
	else:
		print("CRITICAL ERROR: Failed to open save file for writing.")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("SYSTEM: No save file found. Initializing new memory core.")
		return # Keep the default values

	RunManager.current_difficulty = save_data["options"]["difficulty"]
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var parsed_data = JSON.parse_string(json_string)
		if parsed_data is Dictionary:
			# Merge loaded data with default data so updates don't break old saves
			_merge_data(save_data, parsed_data)
			print("SYSTEM: Memory core restored. Save data loaded.")
		else:
			print("CRITICAL ERROR: Save file corrupted or invalid format.")
	else:
		print("CRITICAL ERROR: Failed to open save file for reading.")

# Helper function to safely merge dictionaries.
# If you add new variables in v0.13.0, this ensures old save files don't crash the game!
func _merge_data(default_dict: Dictionary, loaded_dict: Dictionary):
	for key in loaded_dict.keys():
		if default_dict.has(key):
			if typeof(default_dict[key]) == TYPE_DICTIONARY and typeof(loaded_dict[key]) == TYPE_DICTIONARY:
				_merge_data(default_dict[key], loaded_dict[key])
			else:
				default_dict[key] = loaded_dict[key]
