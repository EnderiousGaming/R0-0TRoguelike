extends Control

@onready var bank_display = $VBoxContainer/BankDisplay
@onready var health_display = $VBoxContainer/HealthDisplay

# Grab all the buttons so we can change their text dynamically
@onready var heal_button = $VBoxContainer/HealButton
@onready var speed_button = $VBoxContainer/SpeedButton
@onready var damage_button = $VBoxContainer/DamageButton
@onready var max_health_button = $VBoxContainer/MaxHealthButton

func _ready():
	update_ui()

func update_ui():
	bank_display.text = "AVAILABLE SCORE: " + str(RunManager.score)
	health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
	
	# Dynamically update the button text to show the current inflated price
	heal_button.text = "RESTORE HEALTH (+1 HP) - " + str(RunManager.heal_cost) + " SCORE"
	speed_button.text = "OVERCLOCK LEGS (+10% SPD) - " + str(RunManager.speed_cost) + " SCORE"
	damage_button.text = "UPGRADE LASER (+1 DMG) - " + str(RunManager.damage_cost) + " SCORE"
	max_health_button.text = "UPGRADE CHASSIS (+1 MAX HP) - " + str(RunManager.max_health_cost) + " SCORE"

func _on_heal_button_pressed():
	if RunManager.current_health >= RunManager.max_health:
		print("SYSTEM: Health is already at maximum capacity.")
		return
		
	if RunManager.score >= RunManager.heal_cost:
		RunManager.score -= RunManager.heal_cost
		RunManager.current_health += 1
		# Note: Healing usually stays a static price, but you can inflate it if you want!
		print("SYSTEM: Restored 1 HP.")
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_damage_button_pressed():
	if RunManager.score >= RunManager.damage_cost:
		RunManager.score -= RunManager.damage_cost
		RunManager.laser_damage += 1
		
		# INFLATION MATH: Multiply the cost by 1.5, and use int() to round off any decimals
		RunManager.damage_cost = int(RunManager.damage_cost * 1.5) 
		print("SYSTEM: Laser Damage upgraded to ", RunManager.laser_damage)
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_speed_button_pressed():
	if RunManager.score >= RunManager.speed_cost:
		RunManager.score -= RunManager.speed_cost
		RunManager.player_speed_multiplier += 0.1
		
		RunManager.speed_cost = int(RunManager.speed_cost * 1.5)
		print("SYSTEM: Speed multiplier upgraded to ", RunManager.player_speed_multiplier)
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_max_health_button_pressed():
	if RunManager.score >= RunManager.max_health_cost:
		RunManager.score -= RunManager.max_health_cost
		RunManager.max_health += 1
		RunManager.current_health += 1 # Give them the HP they just unlocked!
		
		RunManager.max_health_cost = int(RunManager.max_health_cost * 1.5)
		print("SYSTEM: Max HP upgraded to ", RunManager.max_health)
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_close_button_pressed():
	# NEW: Find the player and turn their HUD back on
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.get_node("HUD").visible = true
		
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
