extends CharacterBody3D

const DAMAGE_NUMBER = preload("res://scenes/damage_number.tscn")

var health = 3
const speed = 3.0
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
		# Check how close we are to R0-0T first
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Only move and turn if we are further than 1 meter away
		if distance_to_player > 1.0:
			nav_agent.target_position = player.global_position
			var next_path_position = nav_agent.get_next_path_position()
			var direction = global_position.direction_to(next_path_position)
			
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			
			var flat_direction = Vector3(direction.x, 0, direction.z)
			if flat_direction.length() > 0.05:
				look_at(global_position + flat_direction, Vector3.UP)
		else:
			# We are close enough to bite! Stop pushing forward.
			velocity.x = 0
			velocity.z = 0
	
	move_and_slide()

# --- COMBAT LOGIC ---
func take_damage(amount):
	health -= amount
	print("Enemy hit! Health remaining: ", health)
	
	# --- SPAWN DAMAGE NUMBER ---
	var dmg_text = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(dmg_text)
	dmg_text.global_position = global_position + Vector3(0, 1.5, 0)
	dmg_text.text = str(amount)
	
	# NEW: Tell it to start floating NOW, after it has been teleported!
	dmg_text.animate()
	# ---------------------------
	
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


func _on_timer_timeout() -> void:
	pass # Replace with function body.
