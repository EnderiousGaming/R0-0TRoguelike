extends Area3D

# ==========================================
# VARIABLES & REFERENCES
# ==========================================

@onready var label = $Label3D
var my_upgrade_id = 1
var player_in_range = false # Tracks if R0-0T is standing close enough

# Dictionary for upgrade text descriptions
var upgrade_texts = {
	1: "HEAVY BARREL\n+Damage, -Fire Rate",
	2: "FRICTIONLESS COATING\n+Speed, Ice Physics",
	3: "TITANIUM PLATING\n+Max HP, -Speed",
	4: "OVERCLOCKED EMITTER\n+Fire Rate, -Damage",
	5: "CURSED CHASSIS\n++Max HP, Health slowly drains",
	6: "VAMPIRIC ALGORITHM\nHeal on kill, Health slowly drains",
	7: "MOON BOOTS\nHigh Jump, Low Gravity",
	8: "SHOTGUN LOGIC\n+Damage when close to targets",
	9: "SNIPER LOGIC\n+Damage when far from targets",
	10: "RADIATION AURA\nNearby enemies take damage",
	11: "EXTENDED MAG\n+10 Max Ammo",
	12: "SLEIGHT OF HAND\nFaster Reload Speed",
	13: "CARBON-FIBER HILT\nFaster Sword Swing",
	14: "EXTENDED BLADE\nMassive Melee Hitbox",
	15: "KINETIC DEFLECTOR\nParrying grants a burst of speed",
	16: "HYDRAULIC SERVOS\nShorter Dash Cooldown",
	17: "KINETIC PLATING\n+2 Max Health"
}

# ==========================================
# INITIALIZATION
# ==========================================

func _ready():
	pass

func setup(id: int):
	my_upgrade_id = id
	# Add a helpful prompt so the player knows what buttons to press!
	label.text = upgrade_texts[my_upgrade_id] + "\n\n[Press E or F to Equip]"

# ==========================================
# INTERACTION LOGIC
# ==========================================

func _process(_delta):
	# NEW: Check if the player is in range AND just pressed the interact button
	if player_in_range and Input.is_action_just_pressed("interact"):
		print("SYSTEM: Upgrade ", my_upgrade_id, " acquired.")
		RunManager.apply_upgrade(my_upgrade_id)
		get_tree().call_group("upgrades", "queue_free")

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true # R0-0T is close enough to buy it!

# NEW: We need to know if the player walks away without grabbing it!
func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
