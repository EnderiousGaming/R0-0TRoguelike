extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- CAMERA VARIABLES ---
@export var mouse_sensitivity := 0.002
@onready var head = $Head

func _ready():
	# Lock the mouse to the center of the game window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	# Listen for mouse movement
	if event is InputEventMouseMotion:
		# 1ST PERSON MAGIC: Rotate the WHOLE BODY left and right (Y axis)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate ONLY THE HEAD up and down (X axis)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp the head so you can't break your neck looking too far up/down
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
	# Press ESC to get your mouse back
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	# Add gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get WASD input
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# THE MAGIC: Move relative to where the BODY is facing!
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
