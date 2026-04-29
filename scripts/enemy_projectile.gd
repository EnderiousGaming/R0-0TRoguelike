extends Area3D

const SPEED = 15.0
const DAMAGE = 1

func _physics_process(delta):
	# Move forward in local space
	position -= transform.basis.z * SPEED * delta

func _on_body_entered(body):
	# Did we hit R0-0T?
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	
	# Destroy the projectile regardless of whether it hit the player or a wall
	queue_free()
