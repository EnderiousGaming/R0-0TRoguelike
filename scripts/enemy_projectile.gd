extends Area3D

const SPEED = 15.0
const DAMAGE = 1

func _ready():
	# NEW: The self-destruct timer!
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	# Move forward in local space
	position -= transform.basis.z * SPEED * delta

var deflected = false

func deflect(player_aim_direction: Vector3):
	deflected = true
	# Point the projectile exactly where R0-0T is looking
	look_at(global_position + player_aim_direction, Vector3.UP)
	
	# Stop looking for Player (Layer 2), Start looking for Enemies (Layer 3)
	set_collision_mask_value(2, false)
	set_collision_mask_value(3, true)

func _on_body_entered(body):
	if deflected and body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(DAMAGE * 5) # Deflected shots deal massive damage!
		
	elif not deflected and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	
	queue_free()
