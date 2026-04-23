extends Control

@onready var bank_display = $VBoxContainer/BankDisplay
@onready var health_display = $VBoxContainer/HealthDisplay # NEW

func _ready():
	update_ui()

func update_ui():
	bank_display.text = "AVAILABLE SCORE: " + str(RunManager.score)
	# Show the player their vitals while shopping
	health_display.text = "SYSTEM INTEGRITY: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)

func _on_heal_button_pressed():
	# 1. Check if we even need healing
	if RunManager.current_health >= RunManager.max_health:
		print("SYSTEM: Health is already at maximum capacity.")
		return
		
	# 2. Check the bank
	if RunManager.score >= 500:
		RunManager.score -= 500
		RunManager.current_health += 1
		print("SYSTEM: Restored 1 HP.")
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_damage_button_pressed():
	if RunManager.score >= 1000:
		RunManager.score -= 1000
		RunManager.laser_damage += 1
		print("SYSTEM: Laser Damage upgraded to ", RunManager.laser_damage)
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_speed_button_pressed():
	if RunManager.score >= 800:
		RunManager.score -= 800
		RunManager.player_speed_multiplier += 0.1
		print("SYSTEM: Speed multiplier upgraded to ", RunManager.player_speed_multiplier)
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_close_button_pressed():
	# Hide the menu, lock the mouse, and unpause the world!
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
