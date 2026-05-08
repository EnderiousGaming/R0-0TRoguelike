extends Area3D

var damage_amount = 1
var tick_rate = 1.0 # Tick every 1 second
var timer = 0.0

func _physics_process(delta):
	timer += delta
	
	if timer >= tick_rate:
		timer = 0.0
		
		for body in get_overlapping_bodies():
			# 1. PLAYER LOGIC
			if body.is_in_group("player"):
				if RunManager.has_hazard_override:
					if body.has_method("apply_hazard_buff"):
						body.apply_hazard_buff()
						print("SYSTEM: Hazard Override active. Buffing R0-0T.")
				else:
					if body.has_method("take_damage"):
						body.take_damage(damage_amount)
						print("SYSTEM: R0-0T is taking Corrupted Domain damage!")
			
			# 2. DAEMON LOGIC
			elif body.is_in_group("enemy"):
				if body.has_method("take_damage"):
					body.take_damage(damage_amount)
					# Optional: print("SYSTEM: Daemon taking Corrupted Domain damage.")
