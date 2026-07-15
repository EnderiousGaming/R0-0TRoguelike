extends Area3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
const SPEED = 22.0
const DAMAGE = 1

# ==========================================
# EXPORT VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
var deflected = false

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes a self-destruct timer for the projectile."""
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	"""Handles projectile forward movement."""
	position -= transform.basis.z * SPEED * delta

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func deflect(player_aim_direction: Vector3):
	"""Reverses projectile direction and aligns its collision mask to hit enemies."""
	deflected = true
	
	# Point the projectile exactly where R0-0T is currently looking
	look_at(global_position + player_aim_direction, Vector3.UP)
	
	# Swap Collision Masks: Stop hitting the Player (Layer 2), start hitting Enemies (Layer 3)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, true)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_body_entered(body):
	"""Handles collision damage and projectile destruction."""
	# SAFETY CHECK: If deflected, completely ignore the player's body so it doesn't instantly delete itself!
	if deflected and body.is_in_group("player"):
		return 

	# Apply damage based on who gets hit
	if deflected and body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(DAMAGE * 5) # Deflected shots deal 5x massive damage!
		
	elif not deflected and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE) # Normal hit on the player
	
	# Delete the projectile after hitting a valid target
	queue_free()
