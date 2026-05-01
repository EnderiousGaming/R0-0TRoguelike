extends CharacterBody3D

# --- DASH VARIABLES ---
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector3.ZERO
const DASH_SPEED = 25.0
const DASH_DURATION = 0.15

# --- RELOAD VARIABLES ---
var is_reloading = false
var reload_timer = 0.0

# --- SWORD VARIABLES ---
@onready var sword_pivot = $Head/Camera3D/SwordPivot # NEW!
@onready var sword_hitbox = $Head/Camera3D/SwordPivot/SwordMesh/SwordHitbox # Updated path!

var sword_damage = 3
var is_swinging = false
var enemies_hit_this_swing = [] # Prevents hitting the same enemy 60 times a frame!

# --- MODIFIER VARIABLES ---
var drain_timer = 0.0
var radiation_timer = 0.0

# --- MOVEMENT VARIABLES ---
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- UI REFERENCES ---
@onready var stage_display = $HUD/StageDisplay
@onready var announcement_label = $HUD/AnnouncementLabel
@onready var kills_display = $HUD/KillsDisplay
@onready var score_display = $HUD/ScoreDisplay
@onready var pause_menu = $HUD/PauseMenu
@onready var resume_button = $HUD/PauseMenu/VBoxContainer/ResumeButton
@onready var quit_button = $HUD/PauseMenu/VBoxContainer/QuitButton

# --- CAMERA VARIABLES ---
@export var mouse_sensitivity := 0.002
@onready var head = $Head

# --- HEALTH VARIABLES ---
@onready var health_display = $HUD/HealthDisplay

# --- WEAPON VARIABLES ---
@onready var aim_raycast = $Head/Camera3D/RayCast3D
@onready var laser_pivot = $Head/Camera3D/BlasterMesh/LaserPivot

# NEW: Auto-fire tracking
var fire_cooldown = 0.0

# --- INITIALIZATION ---
func _ready():	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	laser_pivot.visible = false
	announcement_label.text = ""

	# Connect the pause menu buttons via code
	resume_button.pressed.connect(toggle_pause)
	quit_button.pressed.connect(quit_to_menu)
	
	update_weapon_loadout()

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
		
	# 3. ESCAPE HATCH: Toggle the pause state
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		
	if event.is_action_pressed("toggle_fullscreen"):
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# --- PHYSICS PROCESSING ---
func _physics_process(delta):
	# --- CALCULATE MODIFIED PHYSICS ---
	var current_gravity = gravity
	var current_jump = JUMP_VELOCITY
	var current_accel = 10.0
	var current_speed = SPEED * RunManager.player_speed_multiplier
	
	if RunManager.has_moon_jump:
		current_gravity = gravity * 0.5
		current_jump = JUMP_VELOCITY * 1.2
		
	if RunManager.has_ice_physics:
		current_accel = 1.0

	# --- APPLY GRAVITY & JUMP ---
	if not is_on_floor():
		velocity.y -= current_gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = current_jump

	# --- DASH COOLDOWN ---
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# --- MOVEMENT INPUT (Declared ONLY ONCE here!) ---
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# --- DASH TRIGGER ---
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		# Only dash if we are actively walking in a direction!
		if direction != Vector3.ZERO:
			is_dashing = true
			dash_timer = DASH_DURATION
			dash_cooldown_timer = RunManager.dash_cooldown
			dash_direction = direction
			print("SYSTEM: DASH!")

	# --- APPLY FINAL MOVEMENT ---
	if is_dashing:
		# If dashing, override all normal movement and lock speed forward!
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
		
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		# Normal walking/ice physics logic
		if direction:
			velocity.x = lerp(velocity.x, direction.x * current_speed, current_accel * delta)
			velocity.z = lerp(velocity.z, direction.z * current_speed, current_accel * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, current_accel * delta)
			velocity.z = lerp(velocity.z, 0.0, current_accel * delta)
			
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
			# Shoot them with the global damage stat!
			target.take_damage(RunManager.laser_damage) 
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
	# 1. Subtract the damage from the GLOBAL health pool
	RunManager.current_health -= amount
	
	# 2. Instantly force the HUD to show the new global number
	health_display.text = "HP: " + str(RunManager.current_health)
	
	# 3. Check for system failure
	if RunManager.current_health <= 0:
		die()

func die():
	print("CRITICAL FAILURE: R0-0T Offline.")
	# DEFERRED: Wait for the enemy's bite physics to finish, THEN load the Game Over screen!
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")
	
func toggle_pause():
	# Flip the pause state
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	
	# Show/Hide the pause menu itself
	pause_menu.visible = new_pause_state
	
	# NEW: Hide the gameplay HUD elements when paused, show them when unpaused
	var show_hud = not new_pause_state
	$HUD/Crosshair.visible = show_hud
	health_display.visible = show_hud
	score_display.visible = show_hud
	kills_display.visible = show_hud
	stage_display.visible = show_hud
	announcement_label.visible = show_hud
	
	# Manage the mouse cursor
	if new_pause_state:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func quit_to_menu():
	# ALWAYS unpause before changing scenes, or the main menu will be frozen!
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
func _process(delta): # Removed the underscore from delta!
	score_display.text = "SCORE: " + str(RunManager.score)
	kills_display.text = "CLEARED: " + str(RunManager.enemies_defeated_this_room)
	
	# NEW: Always keep the HP perfectly formatted and synced!
	health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
	
	# THE NEW STAGE TRACKER
	if RunManager.current_stage == 0:
		stage_display.text = "-- HUB --"
	else:
		stage_display.text = "STAGE: " + str(RunManager.current_stage) + " / 10"

	# --- AUTO-FIRE LOGIC ---
	# 1. Count down the cooldown timer
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
		
	# 2. Check if the player is holding the trigger AND the gun is ready
	# --- WEAPON TRIGGERS ---
	if RunManager.equipped_weapon == "blaster":
		# 1. Handle Active Reloading
		if is_reloading:
			reload_timer -= delta
			if reload_timer <= 0:
				is_reloading = false
				RunManager.current_ammo = RunManager.max_ammo
				print("SYSTEM: Reloaded!")
		else:
			# 2. Manual Reload Input
			if Input.is_action_just_pressed("reload") and RunManager.current_ammo < RunManager.max_ammo:
				is_reloading = true
				reload_timer = RunManager.reload_time
				print("SYSTEM: Reloading...")
				
			# 3. Firing the Blaster
			elif Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				if RunManager.current_ammo > 0:
					if fire_cooldown <= 0.0:
						fire_weapon()
						fire_cooldown = RunManager.fire_rate
						RunManager.current_ammo -= 1 # Spend 1 ammo!
				else:
					# Auto-reload if we try to shoot while empty!
					is_reloading = true
					reload_timer = RunManager.reload_time
					print("SYSTEM: Auto-Reloading...")
					
	# --- NEW: RE-WIRING THE SWORD ---
	elif RunManager.equipped_weapon == "sword":
		# 4. Swinging the Sword
		if Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if not is_swinging:
				swing_sword()
			
	# --- MODIFIER: HEALTH DRAIN ---
	if RunManager.has_health_drain:
		drain_timer += delta
		if drain_timer >= 30.0:
			drain_timer = 0.0
			take_damage(1) # Uses your normal damage function so the screen still flashes!

	# --- MODIFIER: RADIATION AURA ---
	if RunManager.has_radiation_aura:
		radiation_timer += delta
		if radiation_timer >= 1.0: # Tick once per second
			radiation_timer = 0.0
			# Find every enemy in the room and check their distance
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if global_position.distance_to(enemy.global_position) <= 8.0:
					if enemy.has_method("take_damage"):
						enemy.take_damage(1)

func announce(message: String):
	announcement_label.text = message
	
	# Wait 4 seconds, then erase the text
	await get_tree().create_timer(4.0).timeout
	announcement_label.text = ""
	
func update_weapon_loadout():
	if RunManager.equipped_weapon == "blaster":
		$Head/Camera3D/BlasterMesh.visible = true
		sword_pivot.visible = false
	elif RunManager.equipped_weapon == "sword":
		$Head/Camera3D/BlasterMesh.visible = false
		sword_pivot.visible = true
		sword_hitbox.scale = Vector3.ONE * RunManager.sword_range_multiplier
		
		# FORCE THE DEFAULT RESTING POSE!
		sword_pivot.position = Vector3(0.5, -0.4, -0.8)
		sword_pivot.rotation_degrees = Vector3(15, 0, -15) # Changed 45 to 15!

func swing_sword():
	is_swinging = true
	enemies_hit_this_swing.clear() 
	
	# --- THE TWEEN WORKAROUND ---
	var tween = create_tween()
	
	# 1. Whip the sword into the center
	tween.tween_property(sword_pivot, "position", Vector3(0.0, -0.4, -1.0), 0.1 / RunManager.sword_swing_speed)
	tween.parallel().tween_property(sword_pivot, "rotation_degrees", Vector3(15, 80, -80), 0.1 / RunManager.sword_swing_speed)
	
	# 2. Smoothly bring it back
	tween.tween_property(sword_pivot, "position", Vector3(0.5, -0.4, -0.8), 0.3 / RunManager.sword_swing_speed)
	tween.parallel().tween_property(sword_pivot, "rotation_degrees", Vector3(15, 0, -15), 0.3 / RunManager.sword_swing_speed)
	
	# 3. Tell the game we are done swinging!
	tween.tween_callback(func(): is_swinging = false)
	# -----------------------------
	
	# --- INSTANT HIT DETECTION ---
	# 1. Instantly deflect any projectiles currently touching the blade
	for area in sword_hitbox.get_overlapping_areas():
		if area.is_in_group("projectile") and area.has_method("deflect"):
			var aim_dir = -$Head/Camera3D.global_transform.basis.z
			area.deflect(aim_dir)
			print("SYSTEM: INSTANT PARRY!")
			
	# 2. Instantly slash any enemies currently touching the blade
	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			if not body in enemies_hit_this_swing:
				body.take_damage(sword_damage)
				enemies_hit_this_swing.append(body)
				print("SYSTEM: Sliced enemy for ", sword_damage, " damage!")

func _on_sword_hitbox_body_entered(body):
	# If the sword isn't actively swinging, it's harmless!
	if not is_swinging:
		return
		
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		# Make sure we haven't already sliced this specific enemy during this specific swing
		if not body in enemies_hit_this_swing:
			body.take_damage(sword_damage)
			enemies_hit_this_swing.append(body)
			print("SYSTEM: Sliced enemy for ", sword_damage, " damage!")

func _on_sword_hitbox_area_entered(area):
	# Make sure we are swinging AND the thing we hit is actually a projectile!
	if is_swinging and area.is_in_group("projectile") and area.has_method("deflect"):
		
		# Calculate the exact direction the camera is facing
		var aim_dir = -$Head/Camera3D.global_transform.basis.z
		area.deflect(aim_dir)
		print("SYSTEM: PARRIED PROJECTILE!")
		
		# --- KINETIC DEFLECTION BOOST ---
		if RunManager.has_deflect_boost:
			RunManager.player_speed_multiplier += 0.4
			await get_tree().create_timer(1.5).timeout
			RunManager.player_speed_multiplier -= 0.4
