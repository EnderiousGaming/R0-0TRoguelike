extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- CAMERA VARIABLES ---
@export var mouse_sensitivity := 0.002
@onready var head = $Head

# --- WEAPON VARIABLES ---
@onready var aim_raycast = $Head/Camera3D/RayCast3D

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

# Custom function to handle what happens when we pull the trigger
func fire_weapon():
	if aim_raycast.is_colliding():
		var target = aim_raycast.get_collider()
		
		# Check if the thing we hit has the 'take_damage' script attached
		if target.has_method("take_damage"):
			target.take_damage(1) # Deal 1 damage!
		else:
			print("PEW! You hit a wall: ", target.name)
