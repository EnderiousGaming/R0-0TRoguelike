extends CharacterBody3D

var health = 3

func take_damage(amount):
	health -= amount
	print("Enemy hit! Health remaining: ", health)
	
	if health <= 0:
		die()

func die():
	print("Enemy destroyed!")
	queue_free() # This completely deletes the node from the game
