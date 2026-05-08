extends CharacterBody3D

# --- PRELOADS & CONSTANTS ---
const DAMAGE_NUMBER = preload("res://scenes/damage_number.tscn")
const SCORE_DROP = preload("res://scenes/score_drop.tscn")

# --- ENEMY STATS ---
var health = 4
const speed = 3.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Add these three lines for the Daemons' attack stats:
var attack_damage = 1
var attack_cooldown = 1.0 
var current_attack_timer = 0.0

# --- REFERENCES ---
var player = null
@onready var nav_agent = $NavigationAgent3D


# ==========================================
# CORE LOOP
# ==========================================

func _ready():
	# Search for the lowercase "player" tag upon spawning
	player = get_tree().get_first_node_in_group("player")
	
	# DEBUGGING: Tell us if the search worked!
	if player == null:
		print("ERROR: Enemy spawned but cannot find 'player' in groups!")
	else:
		print("Target Acquired: Hunting R0-0T.")

func _physics_process(delta):
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta 
		
	# 2. Pathfinding
	if player:
		# Check how close we are to R0-0T first
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Only move towards the player if we are further than 1 meter away
		if distance_to_player > 1.0:
			nav_agent.target_position = player.global_position
			var next_path_position = nav_agent.get_next_path_position()
			var direction = global_position.direction_to(next_path_position)
			
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			# Stop moving if we are right next to the player!
			velocity.x = 0
			velocity.z = 0
			
	move_and_slide()


# ==========================================
# DAEMON CONTACT DAMAGE LOGIC
# ==========================================
	
	# 1. Tick down the attack cooldown
	if current_attack_timer > 0.0:
		current_attack_timer -= delta
		
	# 2. Check everything the Daemon physically bumped into this frame
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 3. If it bumped into the player, bite them!
		if collider and collider.is_in_group("player"):
			if current_attack_timer <= 0.0 and collider.has_method("take_damage"):
				collider.take_damage(attack_damage)
				current_attack_timer = attack_cooldown
				print("SYSTEM: Daemon inflicted ", attack_damage, " contact damage!")

func take_damage(amount):
	var final_damage = amount
	
	# --- APPLY COMBAT MODIFIERS ---
	# Check distance to player for Sniper/Shotgun modifiers
	if player:
		var dist = global_position.distance_to(player.global_position)
		if RunManager.has_close_combat and dist < 6.0:
			final_damage += 2
		elif RunManager.has_sniper_combat and dist > 15.0:
			final_damage += 2

	health -= final_damage
	
	# --- SPAWN DAMAGE NUMBER ---
	var dmg_text = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(dmg_text)
	dmg_text.global_position = global_position + Vector3(0, 1.5, 0)
	dmg_text.text = str(final_damage)
	
	# Tell it to start floating NOW, after it has been teleported!
	dmg_text.animate()
	
	# Small knockback effect when hit
	velocity = -velocity * 2 
	
	if health <= 0:
		die()

func die():
	# 1. Spawn the physical drop
	var drop_instance = SCORE_DROP.instantiate()
	
	# 2. UPDATE THE LIFETIME STATS
	SaveManager.save_data["stats"]["total_daemons_purged"] += 1
	SaveManager.save_game() # Instantly write the new total to the hard drive
	
	# Pass any specific value you want (e.g., Bosses drop more)
	drop_instance.point_value = 100
	
	RunManager.enemies_defeated_this_room += 1 
	
	# Use call_deferred to safely add it to the world, just like we did with Aureus
	get_parent().call_deferred("add_child", drop_instance)
	drop_instance.set_deferred("global_position", global_position + Vector3(0, 0.5, 0))
	
	# 2. Delete the enemy
	queue_free()
