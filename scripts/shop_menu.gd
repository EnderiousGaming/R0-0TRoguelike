extends Control

# --- UI REFERENCES ---
@onready var bank_display = $VBoxContainer/BankDisplay
@onready var health_display = $VBoxContainer/HealthDisplay

@onready var heal_button = $VBoxContainer/HealButton
@onready var speed_button = $VBoxContainer/SpeedButton
@onready var damage_button = $VBoxContainer/DamageButton
@onready var max_health_button = $VBoxContainer/MaxHealthButton
@onready var fire_rate_button = $VBoxContainer/FireRateButton


# ==========================================
# CORE UI LOGIC
# ==========================================

func _ready():
	update_ui()

func update_ui():
	"""Refreshes all text and prices on the shop interface."""
	bank_display.text = "AVAILABLE SCORE: " + str(RunManager.score)
	health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
	
	# Update button labels with the current (inflated) prices
	fire_rate_button.text = "OVERCLOCK BLASTER (+FIRE RATE) - " + str(RunManager.fire_rate_cost) + " SCORE"
	heal_button.text = "RESTORE HEALTH (+1 HP) - " + str(RunManager.heal_cost) + " SCORE"
	speed_button.text = "OVERCLOCK LEGS (+10% SPD) - " + str(RunManager.speed_cost) + " SCORE"
	damage_button.text = "UPGRADE LASER (+1 DMG) - " + str(RunManager.damage_cost) + " SCORE"
	max_health_button.text = "UPGRADE MAX HP (+1 MAX HP) - " + str(RunManager.max_health_cost) + " SCORE"


# ==========================================
# SHOP PURCHASE EVENTS
# ==========================================

func _on_heal_button_pressed():
	# Only allow healing if player is below max health
	if RunManager.current_health < RunManager.max_health:
		if RunManager.score >= RunManager.heal_cost:
			RunManager.score -= RunManager.heal_cost
			RunManager.current_health += 1
			
			# Inflate price for next purchase
			RunManager.heal_cost = int(RunManager.heal_cost * 1.5)
			print("SYSTEM: Integrity restored. +1 HP.")
			update_ui()
		else:
			print("ERROR: INSUFFICIENT FUNDS")
	else:
		print("SYSTEM: Chassis integrity at maximum.")

func _on_speed_button_pressed():
	if RunManager.score >= RunManager.speed_cost:
		RunManager.score -= RunManager.speed_cost
		RunManager.player_speed_multiplier += 0.1
		
		# Inflate price for next purchase
		RunManager.speed_cost = int(RunManager.speed_cost * 1.5)
		print("SYSTEM: Locomotion systems overclocked.")
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_damage_button_pressed():
	if RunManager.score >= RunManager.damage_cost:
		RunManager.score -= RunManager.damage_cost
		RunManager.laser_damage += 1
		
		# Inflate price for next purchase
		RunManager.damage_cost = int(RunManager.damage_cost * 1.5)
		print("SYSTEM: Laser output increased.")
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_fire_rate_button_pressed():
	# Hard cap the fire rate to prevent potential engine/logic loops
	if RunManager.fire_rate <= 0.05: 
		print("SYSTEM: Blaster Overclock at maximum capacity!")
		return
		
	if RunManager.score >= RunManager.fire_rate_cost:
		RunManager.score -= RunManager.fire_rate_cost
		
		# Lower the delay between shots (faster fire rate)
		RunManager.fire_rate -= 0.05
		
		# Inflate price for next purchase
		RunManager.fire_rate_cost = int(RunManager.fire_rate_cost * 1.5)
		print("SYSTEM: Firing cycle optimized.")
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_max_health_button_pressed():
	if RunManager.score >= RunManager.max_health_cost:
		RunManager.score -= RunManager.max_health_cost
		RunManager.max_health += 1
		RunManager.current_health += 1 # Fill the new slot immediately
		
		# Inflate price for next purchase
		RunManager.max_health_cost = int(RunManager.max_health_cost * 1.5)
		print("SYSTEM: Max capacity upgraded to ", RunManager.max_health)
		update_ui()
	else:
		print("ERROR: INSUFFICIENT FUNDS")

func _on_close_button_pressed():
	# Re-enable the player HUD before closing the shop
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.get_node("HUD").visible = true
		
	# Resume game world
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().paused = false
