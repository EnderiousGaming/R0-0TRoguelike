extends Area3D

# ==========================================
# VARIABLES & REFERENCES
# ==========================================

# Export variables allow you to configure shop items directly in the Inspector!
@export var starting_upgrade_id: int = 1 
@export var cost: int = 0 # 0 for Uplink, 5000 for Shop
@export var is_shop_item: bool = false # Prevents deleting the whole shop when one is bought

@onready var label = $Label3D
var my_upgrade_id = 1
var player_in_range = false 

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
	17: "KINETIC PLATING\n+2 Max Health",
	18: "SCATTER SHOT\nFires an extra projectile per trigger pull in a wide spread.",
	19: "RICOCHET\nProjectiles violently bounce off walls and floors.",
	20: "SEISMIC SLAM\nStriking the terrain with the sword creates a massive damaging shockwave.",
	
	# --- NEW PREMIUM SHOP UPGRADES ---
	21: "HAZARD OVERRIDE\nCorrupted Domain heals instead of hurts",
	22: "COURIER PROTOCOL\nDrops automatically fly to R0-0T",
	23: "UPLINK REROLL\nGain an extra reroll at the Uplink"
}

# ==========================================
# INITIALIZATION
# ==========================================

func _ready():
	# Automatically set up the item if it was manually placed in the Shop scene
	setup(starting_upgrade_id, cost, is_shop_item)

func setup(id: int, item_cost: int = 0, is_shop: bool = false):
	my_upgrade_id = id
	cost = item_cost
	is_shop_item = is_shop
	
	var price_text = "\nFREE"
	if cost > 0:
		price_text = "\nCOST: " + str(cost) + " PTS"
		
	# Combine the description, the price, and the interact prompt
	label.text = upgrade_texts[my_upgrade_id] + price_text + "\n\n[Press E or F to Equip]"

# ==========================================
# INTERACTION LOGIC
# ==========================================

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact"):
		# 1. Check the wallet
		if RunManager.score >= cost:
			print("SYSTEM: Transaction approved. Upgrade ", my_upgrade_id, " acquired.")
			
			# 2. Charge the player and apply the upgrade
			RunManager.score -= cost
			RunManager.apply_upgrade(my_upgrade_id)
			
			# 3. Clean up the geometry
			if is_shop_item:
				queue_free() # Only destroy this specific shop item
			else:
				get_tree().call_group("upgrades", "queue_free") # Destroy all free Uplink options
		else:
			print("SYSTEM: Insufficient points. Need ", cost, " PTS.")
			# TODO: You could play a negative "buzzer" sound effect here!

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
