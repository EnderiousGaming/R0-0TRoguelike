extends Label3D

func animate():
	var tween = create_tween()
	
	# Use global_position here so it animates from wherever the enemy spawned it
	tween.tween_property(self, "global_position", global_position + Vector3(0, 2, 0), 0.5)
	
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	
	tween.tween_callback(queue_free)
