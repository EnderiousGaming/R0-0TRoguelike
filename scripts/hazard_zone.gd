extends Area3D

var damage_amount = 1
var tick_rate = 1.0 # Deals damage every 1 second
var timer = 0.0

func _physics_process(delta):
	timer += delta
	
	# Every time the timer hits 1.0, check who is standing in the fire!
	if timer >= tick_rate:
		timer = 0.0
		
		for body in get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(damage_amount)
				print("SYSTEM: R0-0T is taking Corrupted Domain damage!")
