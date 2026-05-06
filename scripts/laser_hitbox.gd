extends Area3D

var laser_damage = 2
var tick_rate = 0.25 # Deals damage every 0.25 seconds R0-0T is inside the beam
var current_tick = 0.0

func _physics_process(delta):
	# 1. Count down the damage timer
	if current_tick > 0.0:
		current_tick -= delta

	# 2. Check exactly what is currently standing inside the laser
	# (If the boss script disabled the collision shape, this will automatically be empty!)
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			if current_tick <= 0.0:
				body.take_damage(laser_damage)
				current_tick = tick_rate
				print("SYSTEM: AUREUS Laser connected for ", laser_damage, " damage!")
