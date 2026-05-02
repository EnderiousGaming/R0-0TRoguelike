extends Area3D

# --- PROJECTILE STATS ---
const SPEED = 22.0
const DAMAGE = 1
var deflected = false


# ==========================================
# CORE LOOP
# ==========================================

func _ready():
	# Self-destruct timer: destroy the projectile after 3 seconds if it misses everything
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	# Always move forward in local space
	position -= transform.basis.z * SPEED * delta


# ==========================================
# COMBAT & COLLISION LOGIC
# ==========================================

func deflect(player_aim_direction: Vector3):
	deflected = true
	
	# Point the projectile exactly where R0-0T is currently looking
	look_at(global_position + player_aim_direction, Vector3.UP)
	
	# Swap Collision Masks: Stop hitting the Player (Layer 2), start hitting Enemies (Layer 3)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, true)

func _on_body_entered(body):
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
