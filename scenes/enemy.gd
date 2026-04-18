extends CharacterBody3D

var health = 3
const SPEED = 3.0
var player = null

func _ready():
	# Search for the lowercase "player" tag
	player = get_tree().get_first_node_in_group("player")
	
	# DEBUGGING: Tell us if the search worked!
	if player == null:
		print("ERROR: Enemy spawned but cannot find 'player' in groups!")
	else:
		print("Target Acquired: Hunting R0-0T.")

func _physics_process(_delta): # Warning fixed here!
	# If the player exists, hunt them down
	if player:
		var direction = (player.global_position - global_position).normalized()
		direction.y = 0 
		
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		
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
	queue_free()


func _on_hitbox_body_entered(body):
	# Did the thing that touched us have the "player" tag?
	if body.is_in_group("player"):
		# Does the player have a way to take damage?
		if body.has_method("take_damage"):
			body.take_damage(1) # Bite them for 1 HP!
