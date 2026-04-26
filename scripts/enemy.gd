extends CharacterBody3D

var health = 3
const SPEED = 3.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player = null

@onready var nav_agent = $NavigationAgent3D

func _ready():
	# Search for the lowercase "player" tag
	player = get_tree().get_first_node_in_group("player")
	
	# DEBUGGING: Tell us if the search worked!
	if player == null:
		print("ERROR: Enemy spawned but cannot find 'player' in groups!")
	else:
		print("Target Acquired: Hunting R0-0T.")

func _physics_process(delta):
	# 1. Gravity (Keep whatever gravity code you already have)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	# 2. Pathfinding
	if player:
		# Tell the GPS where R0-0T currently is
		nav_agent.target_position = player.global_position
		
		# Ask the GPS: "Where is the very next step I need to take to get around this wall?"
		var next_path_position = nav_agent.get_next_path_position()
		
		# Calculate the direction to that specific step, NOT directly to the player
		var direction = global_position.direction_to(next_path_position)
		
		# Move along the path
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
		# THE FIX: Only turn if we are actively moving horizontally
		var flat_direction = Vector3(direction.x, 0, direction.z)
		if flat_direction.length() > 0.01:
			look_at(global_position + flat_direction, Vector3.UP)
		
		# Make the enemy face where it's walking
		if direction.length() > 0.1:
			look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
	
	move_and_slide()

# --- COMBAT LOGIC ---
func take_damage(amount):
	health -= amount
	print("Enemy hit! Health remaining: ", health)
	
	velocity = -velocity * 2 
	
	if health <= 0:
		die()

func die():
	print("Enemy destroyed!")
	
	RunManager.score += 200 # Currency for the shop
	RunManager.enemies_defeated_this_room += 1 # Progression for the portal
	
	queue_free()

func _on_hitbox_body_entered(body):
	# Did the thing that touched us have the "player" tag?
	if body.is_in_group("player"):
		# Does the player have a way to take damage?
		if body.has_method("take_damage"):
			body.take_damage(1) # Bite them for 1 HP!
