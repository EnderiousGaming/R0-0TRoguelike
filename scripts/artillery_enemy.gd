extends CharacterBody3D

# --- PRELOADS & CONSTANTS ---
const PROJECTILE = preload("res://scenes/enemy_projectile.tscn")
const DAMAGE_NUMBER = preload("res://scenes/damage_number.tscn")

# --- ENEMY STATS ---
var health = 2 # Weaker than the melee brutes
const speed = 2.0 # Slower movement
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- REFERENCES ---
var player = null
@onready var nav_agent = $NavigationAgent3D


# ==========================================
# CORE LOOP
# ==========================================

func _ready():
	# Find and store the player reference upon spawning
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# 2. Always aim at the player so projectiles shoot straight
		var flat_direction = Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z).normalized()
		if flat_direction.length() > 0.05:
			look_at(global_position + flat_direction, Vector3.UP)
		
		# 3. Standard Pathfinding (Stop moving if within 15 meters)
		if distance_to_player > 15.0:
			nav_agent.target_position = player.global_position
			var next_path_position = nav_agent.get_next_path_position()
			var move_dir = global_position.direction_to(next_path_position)
			
			velocity.x = move_dir.x * speed
			velocity.z = move_dir.z * speed
		else:
			# We are in range! Stop moving and act as a stationary turret
			velocity.x = 0
			velocity.z = 0
			
	move_and_slide()


# ==========================================
# COMBAT & SPAWNING LOGIC
# ==========================================

func _on_timer_timeout():
	# Fire at the player if they are within sniper range (30 meters)
	if player and global_position.distance_to(player.global_position) <= 30.0:
		var proj = PROJECTILE.instantiate()
		get_parent().add_child(proj)
		
		# Spawn the projectile at chest height
		proj.global_position = global_position + Vector3(0, 0.25, 0)
		proj.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)

func take_damage(amount):
	health -= amount
	
	# Spawn floating damage text
	var dmg_text = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(dmg_text)
	dmg_text.global_position = global_position + Vector3(0, 1.5, 0)
	dmg_text.text = str(amount)
	dmg_text.animate()
	
	# Small knockback effect when hit
	velocity = -velocity * 2 
	
	if health <= 0:
		die()

func die():
	# Reward the player and notify the run manager
	RunManager.score += 300 
	RunManager.enemies_defeated_this_room += 1 
	queue_free()
