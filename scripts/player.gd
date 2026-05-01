extends CharacterBody3D

# ==========================================
# VARIABLES & REFERENCES
# ==========================================

# --- MOVEMENT & CAMERA ---
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const DASH_SPEED = 25.0
const DASH_DURATION = 0.15

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@export var mouse_sensitivity := 0.002

var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector3.ZERO

# --- BLASTER COMBAT ---
var fire_cooldown = 0.0
var is_reloading = false
var reload_timer = 0.0

# --- SWORD COMBAT ---
var sword_damage = 3
var is_swinging = false
var enemies_hit_this_swing = [] 

# --- MODIFIERS ---
var drain_timer = 0.0
var radiation_timer = 0.0

# --- NODE REFERENCES: PLAYER ---
@onready var head = $Head
@onready var aim_raycast = $Head/Camera3D/RayCast3D
@onready var laser_pivot = $Head/Camera3D/BlasterMesh/LaserPivot
@onready var blaster_mesh = $Head/Camera3D/BlasterMesh
@onready var sword_pivot = $Head/Camera3D/SwordPivot
@onready var sword_hitbox = $Head/Camera3D/SwordPivot/SwordMesh/SwordHitbox

# --- NODE REFERENCES: UI ---
@onready var stage_display = $HUD/StageDisplay
@onready var announcement_label = $HUD/AnnouncementLabel
@onready var kills_display = $HUD/KillsDisplay
@onready var score_display = $HUD/ScoreDisplay
@onready var health_display = $HUD/HealthDisplay
@onready var ammo_display = $HUD/AmmoDisplay
@onready var reload_bar = $HUD/ReloadBar
@onready var pause_menu = $HUD/PauseMenu
@onready var resume_button = $HUD/PauseMenu/VBoxContainer/ResumeButton
@onready var quit_button = $HUD/PauseMenu/VBoxContainer/QuitButton


# ==========================================
# CORE ENGINE LOOPS
# ==========================================

func _ready():	
	# Lock the mouse to the center of the screen for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialize visuals
	laser_pivot.visible = false
	reload_bar.visible = false
	announcement_label.text = ""
	
	# Connect UI button signals
	resume_button.pressed.connect(toggle_pause)
	quit_button.pressed.connect(quit_to_menu)
	
	update_weapon_loadout()

func _unhandled_input(event):
	# 1. Capture Mouse: Re-lock the mouse if the player clicks the game window
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# 2. Camera Rotation: Only move the camera if the mouse is actively captured
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
	# 3. Game State Toggles
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		
	if event.is_action_pressed("toggle_fullscreen"):
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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

	# --- DASH LOGIC ---
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and not is_dashing:
		# Only allow a dash if the player is actively moving in a direction
		if direction != Vector3.ZERO:
			is_dashing = true
			dash_timer = DASH_DURATION
			dash_cooldown_timer = RunManager.dash_cooldown
			dash_direction = direction
			print("SYSTEM: DASH!")

	# --- APPLY FINAL MOVEMENT ---
	if is_dashing:
		# Override standard movement and lock velocity forward
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
		
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		# Standard walking and ice physics interpolation
		if direction:
			velocity.x = lerp(velocity.x, direction.x * current_speed, current_accel * delta)
			velocity.z = lerp(velocity.z, direction.z * current_speed, current_accel * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, current_accel * delta)
			velocity.z = lerp(velocity.z, 0.0, current_accel * delta)
			
	move_and_slide()

func _process(delta):
	# --- DYNAMIC HUD UPDATES ---
	score_display.text = "SCORE: " + str(RunManager.score)
	kills_display.text = "CLEARED: " + str(RunManager.enemies_defeated_this_room)
	health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
	
	if RunManager.current_stage == 0:
		stage_display.text = "-- HUB --"
	else:
		stage_display.text = "STAGE: " + str(RunManager.current_stage) + " / 10"

	# --- WEAPON TRIGGERS & COOLDOWNS ---
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
		
	if RunManager.equipped_weapon == "blaster":
		_process_blaster(delta)
	elif RunManager.equipped_weapon == "sword":
		_process_sword()
			
	# --- PASSIVE MODIFIERS ---
	if RunManager.has_health_drain:
		drain_timer += delta
		if drain_timer >= 30.0:
			drain_timer = 0.0
			take_damage(1) 
			
	if RunManager.has_radiation_aura:
		radiation_timer += delta
		if radiation_timer >= 1.0: 
			radiation_timer = 0.0
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if global_position.distance_to(enemy.global_position) <= 8.0:
					if enemy.has_method("take_damage"):
						enemy.take_damage(1)
	
	_update_weapon_ui()


# ==========================================
# WEAPON LOGIC
# ==========================================

func update_weapon_loadout():
	# Sync visuals and hitboxes with the global RunManager state
	if RunManager.equipped_weapon == "blaster":
		blaster_mesh.visible = true
		sword_pivot.visible = false
		blaster_mesh.rotation_degrees = Vector3.ZERO 
		
	elif RunManager.equipped_weapon == "sword":
		blaster_mesh.visible = false
		sword_pivot.visible = true
		sword_hitbox.scale = Vector3.ONE * RunManager.sword_range_multiplier
		
		# Force the sword into its default resting pose
		sword_pivot.position = Vector3(0.5, -0.4, -0.8)
		sword_pivot.rotation_degrees = Vector3(15, 0, -15) 

func _process_blaster(delta):
	# 1. Handle Active Reloading
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			is_reloading = false
			RunManager.current_ammo = RunManager.max_ammo
			print("SYSTEM: Reloaded!")
			
			# Tween: Snap the gun back to the firing position
			var tween = create_tween()
			tween.tween_property(blaster_mesh, "rotation_degrees", Vector3.ZERO, 0.15)
	else:
		# 2. Manual Reload Input
		if Input.is_action_just_pressed("reload") and RunManager.current_ammo < RunManager.max_ammo:
			is_reloading = true
			reload_timer = RunManager.reload_time
			print("SYSTEM: Reloading...")
			
			# Tween: Tilt the gun up into the air
			var tween = create_tween()
			tween.tween_property(blaster_mesh, "rotation_degrees", Vector3(45, 0, 0), 0.2)
			
		# 3. Firing Input
		elif Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			if RunManager.current_ammo > 0:
				if fire_cooldown <= 0.0:
					fire_weapon()
					fire_cooldown = RunManager.fire_rate
					RunManager.current_ammo -= 1 
			else:
				# Auto-reload if trying to shoot on an empty mag
				is_reloading = true
				reload_timer = RunManager.reload_time
				print("SYSTEM: Auto-Reloading...")
				
				var tween = create_tween()
				tween.tween_property(blaster_mesh, "rotation_degrees", Vector3(45, 0, 0), 0.2)

func _process_sword():
	if Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_swinging:
			swing_sword()

func fire_weapon():
	var hit_distance = 50.0 
	
	if aim_raycast.is_colliding():
		var target = aim_raycast.get_collider()
		hit_distance = aim_raycast.global_position.distance_to(aim_raycast.get_collision_point())
		
		print("Target hit: ", target.name, " | Distance: ", hit_distance)
		
		if target.has_method("take_damage"):
			target.take_damage(RunManager.laser_damage) 
		else:
			print("Fired into the void. Defaulting to 50m.")

	# Render the laser beam
	hit_distance = max(hit_distance, 0.5) # Minimum length safety net
	laser_pivot.scale.z = hit_distance
	laser_pivot.visible = true
	await get_tree().create_timer(0.05).timeout
	laser_pivot.visible = false

func swing_sword():
	is_swinging = true
	enemies_hit_this_swing.clear() 
	
	# Tween Animation: Sweep the sword across the screen
	var tween = create_tween()
	
	# 1. Whip the sword into the center
	tween.tween_property(sword_pivot, "position", Vector3(0.0, -0.4, -1.0), 0.1 / RunManager.sword_swing_speed)
	tween.parallel().tween_property(sword_pivot, "rotation_degrees", Vector3(15, 80, -80), 0.1 / RunManager.sword_swing_speed)
	
	# 2. Smoothly bring it back
	tween.tween_property(sword_pivot, "position", Vector3(0.5, -0.4, -0.8), 0.3 / RunManager.sword_swing_speed)
	tween.parallel().tween_property(sword_pivot, "rotation_degrees", Vector3(15, 0, -15), 0.3 / RunManager.sword_swing_speed)
	
	# 3. Reset the swing state
	tween.tween_callback(func(): is_swinging = false)
	
	# Instant Hit Detection (Projectiles)
	for area in sword_hitbox.get_overlapping_areas():
		if area.is_in_group("projectile") and area.has_method("deflect"):
			var aim_dir = -$Head/Camera3D.global_transform.basis.z
			area.deflect(aim_dir)
			print("SYSTEM: INSTANT PARRY!")
			
	# Instant Hit Detection (Enemies)
	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			if not body in enemies_hit_this_swing:
				body.take_damage(sword_damage)
				enemies_hit_this_swing.append(body)
				print("SYSTEM: Sliced enemy for ", sword_damage, " damage!")


# ==========================================
# PLAYER STATE & UI
# ==========================================

func take_damage(amount):
	RunManager.current_health -= amount
	health_display.text = "HP: " + str(RunManager.current_health)
	
	if RunManager.current_health <= 0:
		die()

func die():
	print("CRITICAL FAILURE: R0-0T Offline.")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")
	
func toggle_pause():
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	
	# Toggle UI visibility
	pause_menu.visible = new_pause_state
	var show_hud = not new_pause_state
	$HUD/Crosshair.visible = show_hud
	health_display.visible = show_hud
	score_display.visible = show_hud
	kills_display.visible = show_hud
	stage_display.visible = show_hud
	announcement_label.visible = show_hud
	
	# Toggle mouse cursor
	if new_pause_state:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func quit_to_menu():
	# Always unpause before changing scenes to prevent a frozen menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func announce(message: String):
	announcement_label.text = message
	await get_tree().create_timer(4.0).timeout
	announcement_label.text = ""

func _update_weapon_ui():
	# Hide/Show HUD elements based on the equipped weapon
	if RunManager.equipped_weapon == "blaster":
		ammo_display.visible = true
		ammo_display.text = "AMMO: " + str(RunManager.current_ammo) + " / " + str(RunManager.max_ammo)
		
		if is_reloading:
			reload_bar.visible = true
			reload_bar.max_value = RunManager.reload_time 
			reload_bar.value = reload_timer 
		else:
			reload_bar.visible = false
			
	elif RunManager.equipped_weapon == "sword":
		ammo_display.visible = false
		reload_bar.visible = false


# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_sword_hitbox_body_entered(body):
	# Lingering Hitbox Detection (Enemies walking into the swing mid-animation)
	if not is_swinging:
		return
		
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		if not body in enemies_hit_this_swing:
			body.take_damage(sword_damage)
			enemies_hit_this_swing.append(body)
			print("SYSTEM: Sliced enemy for ", sword_damage, " damage!")

func _on_sword_hitbox_area_entered(area):
	# Lingering Hitbox Detection (Projectiles flying into the swing mid-animation)
	if is_swinging and area.is_in_group("projectile") and area.has_method("deflect"):
		var aim_dir = -$Head/Camera3D.global_transform.basis.z
		area.deflect(aim_dir)
		print("SYSTEM: PARRIED PROJECTILE!")
		
		# Kinetic Deflection Speed Boost Modifier
		if RunManager.has_deflect_boost:
			RunManager.player_speed_multiplier += 0.4
			await get_tree().create_timer(1.5).timeout
			RunManager.player_speed_multiplier -= 0.4
