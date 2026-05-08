extends Area3D

@onready var label = $Label3D
var player_in_range = false

func _ready():
	update_terminal_display()

func _process(_delta):
	# Wait for the interact button
	if player_in_range and Input.is_action_just_pressed("interact"):
		
		# Cycle the difficulty up by 1
		RunManager.current_difficulty += 1
		
		# If it goes past 4 (YOU WILL DIE), loop back to 0 (EASY)
		if RunManager.current_difficulty > 4:
			RunManager.current_difficulty = 0
			
		# Save the new preference to the hard drive
		SaveManager.save_data["options"]["difficulty"] = RunManager.current_difficulty
		SaveManager.save_game()
		
		update_terminal_display()
		print("SYSTEM: Difficulty set to ", RunManager.DIFF_NAMES[RunManager.current_difficulty])

func update_terminal_display():
	var diff_name = RunManager.DIFF_NAMES[RunManager.current_difficulty]
	label.text = "THREAT LEVEL:\n" + diff_name + "\n\n[Press E or F to Cycle]"
	
	# Optional: Change text color based on difficulty to make it pop!
	match RunManager.current_difficulty:
		0: label.modulate = Color.GREEN
		1: label.modulate = Color.WHITE
		2: label.modulate = Color.ORANGE
		3: label.modulate = Color.RED
		4: label.modulate = Color.DARK_RED

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
