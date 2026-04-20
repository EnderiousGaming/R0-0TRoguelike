extends CharacterBody3D

# --- MOVEMENT VARIABLES ---
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var max_health = 5
var current_health = max_health
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- CAMERA VARIABLES ---
@export var mouse_sensitivity := 0.002
@onready var head = $Head

# --- HEALTH VARIABLES ---
@onready var health_display = $HUD/HealthDisplay

# --- WEAPON VARIABLES ---
@onready var aim_raycast = $Head/Camera3D/RayCast3D
@onready var laser_pivot = $Head/Camera3D/BlasterMesh/LaserPivot

# --- INITIALIZATION ---
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# --- INPUT HANDLING ---
func _unhandled_input(event):
	# 1. CLICK TO CAPTURE: If we click the left mouse button, lock the mouse!
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# 2. LOOK AROUND: Only rotate the camera IF the mouse is currently locked
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
	# 3. ESCAPE HATCH: Press ESC to free the mouse so you can close the window
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- PHYSICS PROCESSING ---
func _physics_process(delta):
	# Add gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# --- SHOOTING LOGIC ---
	if Input.is_action_just_pressed("shoot"):
		fire_weapon()

	# --- MOVEMENT LOGIC ---
	# Get WASD input
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

# --- CUSTOM FUNCTIONS ---
# Custom function to handle what happens when we pull the trigger
func fire_weapon():
	var hit_distance = 50.0 
	
	if aim_raycast.is_colliding():
		var target = aim_raycast.get_collider()
		hit_distance = aim_raycast.global_position.distance_to(aim_raycast.get_collision_point())
		
		# DEBUG: Tell us what we hit and how far away it is!
		print("Target hit: ", target.name, " | Distance: ", hit_distance)
		
		if target.has_method("take_damage"):
			target.take_damage(1) 
	else:
		# DEBUG: Tell us if we missed everything
		print("Fired into the void. Defaulting to 50m.")

	# --- THE COMBAT JUICE ---
	# Safety Net: Force the laser to be at least 0.5 meters long so it never vanishes
	hit_distance = max(hit_distance, 0.5)
	
	laser_pivot.scale.z = hit_distance
	laser_pivot.visible = true
	
	await get_tree().create_timer(0.05).timeout
	
	laser_pivot.visible = false

# --- PLAYER SURVIVAL LOGIC ---
func take_damage(amount):
	current_health -= amount
	health_display.text = "HP: " + str(current_health) # Updates the HUD!

	if current_health <= 0:
		die()

func die():
	print("CRITICAL FAILURE: R0-0T Offline.")
	# This instantly resets the current level back to the beginning!
	get_tree().reload_current_scene()
