extends Area3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
const SPEED = 40.0

# ==========================================
# EXPORT VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
var bounces_left = 0

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
@onready var raycast = $RayCast3D

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes projectile properties on spawn."""
	bounces_left = RunManager.blaster_bounces

func _physics_process(delta):
	"""Handles movement and bounce mechanics for the projectile."""
	var move_dist = SPEED * delta
	
	# --- RICOCHET PREDICTION MATH ---
	if bounces_left > 0:
		raycast.target_position = Vector3(0, 0, -move_dist * 2.0)
		raycast.force_raycast_update()
		
		if raycast.is_colliding():
			# Calculate the bounce angle using the wall's normal
			var normal = raycast.get_collision_normal()
			var forward = -transform.basis.z
			var reflect = forward.bounce(normal)
			
			# Snap the bullet to face the new ricochet direction
			look_at(global_position + reflect, Vector3.UP)
			bounces_left -= 1
			return # Skip standard movement this exact frame to prevent wall-clipping

	# --- STANDARD FLIGHT PATH ---
	position -= transform.basis.z * move_dist

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================
# (None in this script)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_timer_timeout():
	"""Deletes projectile when its lifetime expires."""
	queue_free()

func _on_body_entered(body):
	"""Handles collision with physics bodies."""
	if body.is_in_group("player"):
		return 

	if body.has_method("take_damage"):
		body.take_damage(RunManager.laser_damage)
		queue_free() # Always delete upon hitting flesh
	elif bounces_left <= 0:
		queue_free() # Delete upon hitting a wall IF we are out of bounces
