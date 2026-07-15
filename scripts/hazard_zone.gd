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
var damage_amount = 1
var tick_rate = 1.0 # Tick every 1 second
var timer = 0.0

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

func _physics_process(delta):
	"""Handles periodic damage ticks for bodies within the hazard zone."""
	if not monitoring:
		return # Stop right here! Don't do the math below.
	
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

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func set_hazard_active(is_active: bool):
	"""Toggles the hazard zone on or off."""
	$CollisionShape3D.set_deferred("disabled", not is_active)
	set_deferred("monitoring", is_active)
	visible = is_active
	
	# Tell Godot to stop running _physics_process for this node!
	set_physics_process(is_active)

# ==========================================
# SIGNAL HANDLERS
# ==========================================
# (None in this script)
