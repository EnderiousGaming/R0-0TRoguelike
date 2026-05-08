extends RigidBody3D

var point_value = 100
var magnet_force = 80.0 # Adjust this to make the Courier magnet pull harder/softer
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	# Blast the drop upward and slightly outward when it spawns!
	var random_dir = Vector3(randf_range(-2, 2), 6.0, randf_range(-2, 2))
	apply_impulse(random_dir)

func _physics_process(_delta):
	# ==========================================
	# THE COURIER PROTOCOL LOGIC (PHYSICS BASED)
	# ==========================================
	if RunManager.has_courier_protocol and is_instance_valid(player):
		# Create a powerful physical vacuum pulling the drop to R0-0T
		var dir = global_position.direction_to(player.global_position)
		apply_central_force(dir * magnet_force)

# CRUCIAL: Connect this signal from the child 'PickupZone' Area3D, not the root!
func _on_pickup_zone_body_entered(body):
	if body.is_in_group("player"):
		RunManager.score += point_value
		print("SYSTEM: Points acquired. Current balance: ", RunManager.score)
		queue_free()
