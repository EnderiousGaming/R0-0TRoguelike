extends Area3D

const SPEED = 40.0

func _physics_process(delta):
	# Always fly straight forward in local space
	position -= transform.basis.z * SPEED * delta

func _on_timer_timeout():
	queue_free() # Self-destruct after 3 seconds

func _on_body_entered(body):
	# Ignore R0-0T completely
	if body.is_in_group("player"):
		return 
		
	# DEBUG: Tell us exactly what the bullet touched!
	print("Bullet hit: ", body.name)

	# If we hit an enemy, deal damage!
	if body.has_method("take_damage"):
		body.take_damage(RunManager.laser_damage)
		
	# Delete the bullet the instant it hits ANYTHING else
	queue_free()
