extends Area3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
# (None in this script)

# ==========================================
# EXPORT VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
var point_value = 100
var magnet_speed = 25.0 # Speed it flies to R0-0T when Courier is active
var player = null

# --- Hover Animation Variables ---
var float_speed = 3.0
var float_amplitude = 0.15
var base_y = 0.0
var time_passed = 0.0
var is_magnetized = false

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
	"""Initializes the drop and starts its pop-up animation."""
	player = get_tree().get_first_node_in_group("player")
	
	# Wait one frame so the Daemon's 'set_deferred' location applies first!
	await get_tree().physics_frame
	
	# Pop the drop up slightly based on its TRUE global position
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", global_position.y + 0.5, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Lock in that height as the center of our hover animation
	await tween.finished
	base_y = global_position.y

func _process(delta):
	"""Handles the hover animation and Courier Protocol magnet logic."""
	# --- THE COURIER PROTOCOL LOGIC (KINEMATIC) ---
	if is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		# Magnetize if they have the global upgrade OR if R0-0T is within 2.5 meters!
		if RunManager.has_courier_protocol or distance <= 2.5:
			is_magnetized = true
			var dir = global_position.direction_to(player.global_position)
			global_position += dir * magnet_speed * delta
			return 
		
	# --- HOVER & SPIN ANIMATION ---
	if not is_magnetized:
		rotate_y(2.0 * delta) 
		
		if base_y != 0.0:
			time_passed += delta
			global_position.y = base_y + sin(time_passed * float_speed) * float_amplitude

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================
# (None in this script)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_body_entered(body):
	"""Handles collection by the player."""
	if body.is_in_group("player"):
		RunManager.score += point_value
		print("SYSTEM: Points acquired. Current balance: ", RunManager.score)
		queue_free()
