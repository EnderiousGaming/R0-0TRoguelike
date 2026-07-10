extends CharacterBody3D

@onready var save_indicator = $HUD/SaveIndicator
@onready var tutorial_overlay = $HUD/TutorialOverlay
@onready var directive_text = $HUD/TutorialOverlay/MarginContainer/DirectiveText

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

var is_invulnerable = false
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector3.ZERO

# --- BLASTER COMBAT ---
var fire_cooldown = 0.0
var is_reloading = false
var reload_timer = 0.0
const BULLET = preload("res://scenes/player_projectile.tscn")

# --- OVERCLOCK RELOAD VARIABLES ---
# If standard reload is 1.5 seconds, the sweet spot is between 0.9s and 0.6s remaining.
var active_reload_start = 0.9 
var active_reload_end = 0.6   
var is_overclocked = false
var overclock_timer = 0.0
var overclock_duration = 3.0
var active_reload_failed = false # Tracks if they missed the sweet spot

# --- SWORD COMBAT ---
var sword_damage = 3
var is_swinging = false
var enemies_hit_this_swing = []
var has_slammed_this_swing = false

# --- SWORD THROW VARIABLES ---
var is_sword_thrown = false
var is_sword_returning = false
var sword_throw_timer = 0.0
var sword_throw_speed = 35.0
var sword_throw_direction = Vector3.ZERO
var enemies_hit_this_throw = [] # Tracks who got sliced so they don't take damage 60 times a second

# --- GRAPPLE VARIABLES ---
@onready var grapple_beam = $Head/Camera3D/GrappleBeam # Adjust path to match your tree
@onready var blaster_muzzle = $Head/Camera3D/BlasterMesh # Where the beam starts

var is_grappling: bool = false
var grapple_target_point: Vector3 = Vector3.ZERO
const GRAPPLE_SPEED = 35.0

var grapple_cooldown_max: float = 1.5 
var current_grapple_cooldown: float = 0.0

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

# --- NODE REFERENCES: AUDIO ---
@onready var blaster_sfx = $BlasterSFX

# --- NODE REFERENCES: UI ---
@onready var stage_display = $HUD/StageDisplay
@onready var announcement_label = $HUD/AnnouncementLabel
@onready var kills_display = $HUD/KillsDisplay
@onready var score_display = $HUD/ScoreDisplay
@onready var health_display = $HUD/HealthDisplay
@onready var ammo_display = $HUD/AmmoDisplay # <--- RESTORED!
@onready var ammo_circle = $HUD/AmmoCircle   # <--- KEEPS OUR NEW UI!
@onready var pause_menu = $HUD/PauseMenu
@onready var resume_button = $HUD/PauseMenu/VBoxContainer/ResumeButton
@onready var quit_button = $HUD/PauseMenu/VBoxContainer/QuitButton
@onready var options_button = $HUD/PauseMenu/VBoxContainer/OptionsButton
@onready var options_menu = $HUD/OptionsMenu # Assuming it's a child of the HUD
@onready var grapple_bar = $HUD/GrappleBar
@onready var damage_overlay = $HUD/DamageOverlay


# ==========================================
# CORE ENGINE LOOPS
# ==========================================

func _ready():	
	# Lock the mouse to the center of the screen for FPS controls
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Initialize visuals
	laser_pivot.visible = false
	ammo_circle.visible = false
	ammo_circle.step = 0.01 # <--- NEW LINE: Tells the UI to update in micro-decimals!
	announcement_label.text = ""
	
	# Connect UI button signals
	resume_button.pressed.connect(toggle_pause)
	quit_button.pressed.connect(quit_to_menu)
	options_button.pressed.connect(func():
		pause_menu.visible = false
		options_menu.visible = true
	)
	options_menu.back_pressed.connect(func():
		pause_menu.visible = true
	)
	
	update_weapon_loadout()
	
	save_indicator.modulate.a = 0.0 # Hide it by default
	SaveManager.memory_synced.connect(flash_save_indicator)
	
	# Hide the overlay by default unless we are explicitly in the tutorial
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.visible = false
	
func flash_save_indicator():
	# Cancel any running tweens so it doesn't glitch if saved rapidly
	var tween = create_tween()
	
	# Snap it to full visibility, wait 1.5 seconds, then fade out
	save_indicator.modulate.a = 1.0
	tween.tween_interval(1.5)
	tween.tween_property(save_indicator, "modulate:a", 0.0, 0.5)

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
			
	# DEBUG: Immediate Level Clear
	if OS.is_debug_build() and event.is_action_pressed("debug_clear_level"):
		force_level_clear()
		
	# ==========================================
	# UPLINK REROLL PROTOCOL
	# ==========================================
	if event.is_action_pressed("reroll_uplink"):
		
		# 1. Are there even upgrades nearby to reroll?
		var active_upgrades = get_tree().get_nodes_in_group("upgrades")
		
		# We only want to allow rerolls on FREE Uplink items, not the 5000-point Shop items!
		if active_upgrades.size() > 0 and active_upgrades[0].cost == 0:
			
			# 2. Do we have rerolls left?
			if RunManager.uplink_rerolls > 0:
				RunManager.uplink_rerolls -= 1
				print("SYSTEM: Uplink Reroll accepted. ", RunManager.uplink_rerolls, " remaining.")
				
				# 3. Wipe the current free upgrades
				get_tree().call_group("upgrades", "queue_free")
				
				# 4. Trigger the spawn logic again
				var world_scene = get_tree().current_scene
				if world_scene.has_method("spawn_upgrades"):
					world_scene.spawn_upgrades()
					
			else:
				print("SYSTEM: Reroll failed. No Uplink Rerolls available.")

func force_level_clear():
	print("DEBUG: Sequence broken. Warping to The Golden Process...")
	
	# 1. Force the room clear condition
	RunManager.enemies_defeated_this_room = 100 # (Or your max limit)
	
	# 2. HIJACK THE STAGE COUNTER
	# Set it to 9 so the next portal jump increments perfectly to 10!
	RunManager.current_stage = 9 
	
	# 3. Force the portal open
	var portal = get_tree().current_scene.get_node_or_null("Portal")
	if portal and portal.has_method("open_portal"):
		portal.open_portal()
		
	# Update the HUD
	_process(0)

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
	
	if Input.is_action_just_pressed("dash"):
		# 1. SWORD DASH LOGIC
		if RunManager.equipped_weapon == "sword" and dash_cooldown_timer <= 0.0 and not is_dashing:
			if direction != Vector3.ZERO:
				is_dashing = true
				is_invulnerable = true 
				dash_timer = DASH_DURATION
				dash_cooldown_timer = RunManager.dash_cooldown
				dash_direction = direction
				print("SYSTEM: SWORD DASH!")
				
				if not is_swinging:
					swing_sword()
					
		# 2. BLASTER GRAPPLE LOGIC
		elif RunManager.equipped_weapon == "blaster" and not is_grappling and current_grapple_cooldown <= 0.0:
			# Only fire the hook if we are actually looking at a surface
			if aim_raycast.is_colliding():
				var target = aim_raycast.get_collider()
				
				# Make sure we don't accidentally grapple onto a virus or an upgrade box!
				if not target.is_in_group("enemy") and not target.is_in_group("upgrades"):
					is_grappling = true
					grapple_target_point = aim_raycast.get_collision_point()
					print("SYSTEM: GRAPPLE ATTACHED!")

	# --- APPLY FINAL MOVEMENT ---
	if is_grappling:
		# THE ACROBATICS CANCELLATION
		if Input.is_action_just_pressed("jump"):
			is_grappling = false
			current_grapple_cooldown = grapple_cooldown_max # START COOLDOWN HERE
			velocity.y = JUMP_VELOCITY * 1.5 
		else:
			# Pull R0-0T straight towards the target point
			var pull_direction = (grapple_target_point - global_position).normalized()
			velocity = pull_direction * GRAPPLE_SPEED
			
			# Detach automatically if we get close enough
			if global_position.distance_to(grapple_target_point) < 2.5:
				is_grappling = false
				current_grapple_cooldown = grapple_cooldown_max # START COOLDOWN HERE

	elif is_dashing:
		# Override standard movement and lock velocity forward
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
		
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = false 
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
			
		# NEW: Handle the blade's flight path if it was thrown
		if is_sword_thrown:
			_process_sword_throw(delta)
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
	
	# 1. COOLDOWN LOGIC
	if current_grapple_cooldown > 0.0:
		current_grapple_cooldown -= delta
		
		# Update the UI Bar
		grapple_bar.visible = true
		grapple_bar.max_value = grapple_cooldown_max
		grapple_bar.value = current_grapple_cooldown
	else:
		grapple_bar.visible = false
		
	# 2. VISUAL INDICATOR LOGIC
	if is_grappling:
		grapple_beam.visible = true
		
		var distance = blaster_muzzle.global_position.distance_to(grapple_target_point)
		var midpoint = blaster_muzzle.global_position.lerp(grapple_target_point, 0.5)
		
		grapple_beam.global_position = midpoint
		
		# 1. Point the node at the target
		grapple_beam.look_at(grapple_target_point, Vector3.UP)
		
		# 2. Tilt the cylinder 90 degrees so its Y-axis points at the wall
		grapple_beam.rotate_x(deg_to_rad(90))
		
		# 3. Scale the Y-axis (the cylinder's height) to match the distance
		grapple_beam.scale = Vector3(1.0, distance, 1.0)
	else:
		grapple_beam.visible = false


# ==========================================
# WEAPON LOGIC
# ==========================================

func update_weapon_loadout():
	# SAFETY FIRST: Force catch the sword if it was in the air during a swap!
	if is_sword_thrown:
		catch_sword()
	
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
	# WEAPON LOCKOUT: Prevent firing or reloading if grappling
	if is_grappling:
		return 
		
	# ==========================================
	# OVERCLOCK DRAIN LOGIC
	# ==========================================
	if is_overclocked:
		overclock_timer -= delta
		if overclock_timer <= 0.0:
			is_overclocked = false
			ammo_display.modulate = Color.WHITE # Return UI to normal
			print("SYSTEM: Overclock depleted. Cooling down.")

	# ==========================================
	# ACTIVE RELOAD LOGIC
	# ==========================================
	if is_reloading:
		reload_timer -= delta
		
		# 1. Visual Cue: Turn GOLD when in the sweet spot (if they haven't failed yet!)
		if not active_reload_failed and reload_timer <= active_reload_start and reload_timer >= active_reload_end:
			ammo_circle.modulate = Color.GOLD
		elif not active_reload_failed:
			ammo_circle.modulate = Color.WHITE
		else:
			ammo_circle.modulate = Color.GRAY # Visual cue that the Overclock is locked out

		# 2. The Skill Check
		# Use (reload_time - 0.1) so they don't instantly fail the frame the reload starts
		if not active_reload_failed and reload_timer < (RunManager.reload_time - 0.1) and (Input.is_action_just_pressed("reload") or Input.is_action_just_pressed("shoot")):
			
			if reload_timer <= active_reload_start and reload_timer >= active_reload_end:
				# SUCCESS! OVERCLOCK ENGAGED
				reload_timer = 0.0
				is_overclocked = true
				overclock_timer = overclock_duration
				ammo_display.modulate = Color.CYAN 
				print("SYSTEM: PERFECT TIMING. BLASTER OVERCLOCKED!")
			else:
				# FAILURE! No jam penalty, just lock out the Overclock for this clip.
				active_reload_failed = true
				print("SYSTEM: TIMING FAILED. Standard reload continuing.")
				
		# 3. Standard Reload Finish
		if reload_timer <= 0.0:
			is_reloading = false
			RunManager.current_ammo = RunManager.max_ammo
			
			var tween = create_tween()
			tween.tween_property(blaster_mesh, "rotation_degrees", Vector3.ZERO, 0.2)
			
	# ==========================================
	# FIRING & MANUAL RELOAD INPUTS
	# ==========================================
	
	# Explicit Manual Reload Input
	elif Input.is_action_just_pressed("reload") and RunManager.current_ammo < RunManager.max_ammo:
		is_reloading = true
		reload_timer = RunManager.reload_time
		active_reload_failed = false # RESET FOR NEW RELOAD
		print("SYSTEM: Manual Reloading...")
		
		var tween = create_tween()
		tween.tween_property(blaster_mesh, "rotation_degrees", Vector3(45, 0, 0), 0.2)
		
	# 4. Firing Input
	elif Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if RunManager.current_ammo > 0:
			if fire_cooldown <= 0.0:
				if fire_weapon():
					RunManager.current_ammo -= 1 
					
					if is_overclocked:
						fire_cooldown = RunManager.fire_rate * 0.5
					else:
						fire_cooldown = RunManager.fire_rate
						
		else:
			# Auto-reload if trying to shoot on an empty mag
			is_reloading = true
			reload_timer = RunManager.reload_time
			active_reload_failed = false # RESET FOR NEW RELOAD
			print("SYSTEM: Auto-Reloading...")
			
			var tween = create_tween()
			tween.tween_property(blaster_mesh, "rotation_degrees", Vector3(45, 0, 0), 0.2)

func _process_sword():
	# WEAPON LOCKOUT: Prevent swinging if the blade is flying across the room
	if is_sword_thrown:
		return
		
	# 1. Orbital Blade Throw (Right Click)
	if Input.is_action_just_pressed("secondary_fire") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_swinging:
			throw_sword()
			
	# 2. Standard Swing (Left Click)
	elif Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_swinging:
			swing_sword()

func fire_weapon() -> bool:
	
	# ==========================================
	# ANTI-CLIPPING PROTOCOL
	# ==========================================
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create($Head/Camera3D.global_position, blaster_mesh.global_position)
	
	# Ignore R0-0T's own hitbox so we don't accidentally block our own shot
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	
	# If there is an object between the camera and the gun barrel...
	if result:
		# ...and that object IS NOT an enemy (we still want to allow point-blank shots on Daemons!)
		if not result.collider.is_in_group("enemy"):
			print("SYSTEM: Muzzle obstructed. Firing sequence aborted.")
			return false 
	# ==========================================
	
	var target_point = Vector3.ZERO
	if aim_raycast.is_colliding():
		target_point = aim_raycast.get_collision_point()
	else:
		target_point = aim_raycast.global_position - aim_raycast.global_transform.basis.z * 50.0
		
	RunManager.projectiles_fired += 1
	blaster_sfx.play()

	# Loop through the spawn sequence based on how many Scatter upgrades R0-0T has
	for i in range(RunManager.blaster_scatter_count):
		var bullet = BULLET.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = blaster_mesh.global_position
		bullet.look_at(target_point, Vector3.UP)
		
		# If Scatter Shot is active, apply randomized recoil to the bullet's flight path
		if RunManager.blaster_scatter_count > 1:
			var spread = 0.05 * (RunManager.blaster_scatter_count - 1)
			bullet.rotate_x(randf_range(-spread, spread))
			bullet.rotate_y(randf_range(-spread, spread))
			
	# Tell the system the shot was successful!
	return true

func swing_sword():
	is_swinging = true
	enemies_hit_this_swing.clear()
	has_slammed_this_swing = false
	
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
# SWORD THROW LOGIC
# ==========================================

func throw_sword():
	is_sword_thrown = true
	is_sword_returning = false
	sword_throw_timer = 3.0
	enemies_hit_this_throw.clear()

	# 1. Detach the sword from the camera's local space
	sword_pivot.top_level = true
	
	sword_pivot.global_position = $Head/Camera3D.global_position
	
	# --- THE FIX: RESET ROTATION ---
	# This removes the resting "wobble" and perfectly aligns the blade with the camera
	sword_pivot.global_transform.basis = $Head/Camera3D.global_transform.basis
	
	# --- THE FIX: LAY THE BLADE FLAT ---
	# Pitch it down 90 degrees so the blade points directly forward instead of straight up!
	sword_pivot.rotate_x(deg_to_rad(-90))

	# 2. Lock in the exact direction the player is looking
	sword_throw_direction = -$Head/Camera3D.global_transform.basis.z.normalized()
	print("SYSTEM: Executing Orbital Strike.")
	
	# --- THE FIX: SHRINK HITBOX ---
	# Scale the hitbox down so it only registers precise physical hits
	sword_hitbox.scale = Vector3(0.25, 0.25, 0.25) # Adjust these numbers if it needs to be slightly bigger/smaller!

func start_sword_return():
	is_sword_returning = true
	# Clear the array so it can damage the exact SAME enemies on the way back!
	enemies_hit_this_throw.clear() 
	print("SYSTEM: Blade returning.")

func catch_sword():
	is_sword_thrown = false
	is_sword_returning = false

	# 1. Reattach the sword to the camera
	sword_pivot.top_level = false

	# 2. Snap it perfectly back into its resting pose
	sword_pivot.position = Vector3(0.5, -0.4, -0.8)
	sword_pivot.rotation_degrees = Vector3(15, 0, -15)
	
	# --- THE FIX: RESTORE HITBOX ---
	# Return the sweeping hitbox to its full size, respecting any range upgrades!
	sword_hitbox.scale = Vector3.ONE * RunManager.sword_range_multiplier
	
	print("SYSTEM: Blade caught.")

func _process_sword_throw(delta):
	# --- THE FIX: GLOBAL HORIZONTAL SPIN ---
	# Explicitly spin the blade around the world's vertical axis (Vector3.UP)
	sword_pivot.global_rotate(Vector3.UP, deg_to_rad(1440) * delta) 

	if not is_sword_returning:
		# --- OUTWARD FLIGHT ---
		sword_pivot.global_position += sword_throw_direction * sword_throw_speed * delta
		sword_throw_timer -= delta

		# 1. Timeout Check
		if sword_throw_timer <= 0.0:
			start_sword_return()
			return

		# 2. Collision Check
		var hit_something = false
		for body in sword_hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				continue # Ignore R0-0T!

			hit_something = true

			if body.is_in_group("enemy"):
				if not body in enemies_hit_this_throw:
					if body.has_method("take_damage"):
						body.take_damage(sword_damage)
					enemies_hit_this_throw.append(body)
					print("SYSTEM: Blade sliced Daemon on outward throw!")
			else:
				# It hit the level geometry!
				print("SYSTEM: Blade struck environment.")

		# If it touched ANY non-player physics body, instantly rebound!
		if hit_something:
			start_sword_return()

	else:
		# --- RETURN FLIGHT ---
		var target_pos = $Head/Camera3D.global_position
		var return_dir = sword_pivot.global_position.direction_to(target_pos)

		# Pull it back even faster than it was thrown (feels punchier)
		sword_pivot.global_position += return_dir * (sword_throw_speed * 1.5) * delta

		# Damage enemies on the way back
		for body in sword_hitbox.get_overlapping_bodies():
			if body.is_in_group("enemy") and not body in enemies_hit_this_throw:
				if body.has_method("take_damage"):
					body.take_damage(sword_damage)
				enemies_hit_this_throw.append(body)
				print("SYSTEM: Blade sliced Daemon on return flight!")

		# Catch Check
		if sword_pivot.global_position.distance_to(target_pos) < 1.5:
			catch_sword()

# ==========================================
# PLAYER STATE & UI
# ==========================================

func take_damage(amount):
	# SAFETY CHECK: If we are dashing, ignore all damage!
	if is_invulnerable:
		print("SYSTEM: Damage deflected by Dash!")
		return

	RunManager.current_health -= amount
	health_display.text = "HP: " + str(RunManager.current_health)
	
	# 1. Trigger the Visual Flash
	flash_damage_screen()
	
	# 2. Check for critical failure (THIS WAS MISSING!)
	if RunManager.current_health <= 0:
		die()

func apply_hazard_buff():
	# Example 1: Healing
	if RunManager.current_health < RunManager.max_health:
		RunManager.current_health += 1
		print("SYSTEM: R0-0T cooling systems engaged. Health restored.")
		
	# Example 2: You could also trigger a temporary fire-rate or speed multiplier here!
	# (Just remember to set a timer to turn the buff off if they leave the hazard zone)

func flash_damage_screen():
	# If a tween is already running from a previous hit, kill it so they don't fight
	var tween = get_tree().create_tween()
	
	# 1. Instantly snap the overlay to 30% opacity red
	damage_overlay.color.a = 0.3
	
	# 2. Smoothly fade it back to 0.0 over 0.4 seconds
	tween.tween_property(damage_overlay, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func die():
	AudioManager.stop_all_music()
	print("CRITICAL FAILURE: R0-0T Offline.")
	
	# 1. Update standard accumulative lifetime stats
	SaveManager.save_data["stats"]["r0_0t_deaths"] += 1
	SaveManager.save_data["stats"]["total_daemons_purged"] += RunManager.daemons_purged
	SaveManager.save_data["stats"]["projectiles_fired"] += RunManager.projectiles_fired
	SaveManager.save_data["stats"]["damage_dealt"] += RunManager.damage_dealt
	SaveManager.save_data["stats"]["bosses_purged"] += RunManager.bosses_purged
	SaveManager.save_data["stats"]["points_spent"] += RunManager.points_spent
	
	# 2. Check for New Personal Bests!
	if RunManager.score > SaveManager.save_data["stats"]["highest_score"]:
		SaveManager.save_data["stats"]["highest_score"] = RunManager.score
		
	if RunManager.current_stage > SaveManager.save_data["stats"]["highest_stage_reached"]:
		SaveManager.save_data["stats"]["highest_stage_reached"] = RunManager.current_stage
	
	# 3. NOW trigger the autosave
	SaveManager.save_game()
	print("SYSTEM: Autosave complete. Memory core updated.")
	
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
	
	# --- NEW WEAPON UI FIX ---
	ammo_display.visible = show_hud
	
	# Always hide these bars when paused. 
	# When unpaused, your _process() loop will automatically turn them back on if needed!
	if new_pause_state:
		ammo_circle.visible = false
		grapple_bar.visible = false
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

func show_tutorial_directive(message: String):
	if not is_instance_valid(tutorial_overlay):
		return
		
	tutorial_overlay.visible = true
	directive_text.text = message
	
	# Optional: Play a subtle UI beep sound here to grab the player's attention
	print("DIRECTIVE POSTED: ", message)

func hide_tutorial_directive():
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.visible = false

func _update_weapon_ui():
	# Hide/Show HUD elements based on the equipped weapon
	if RunManager.equipped_weapon == "blaster":
		ammo_display.visible = true
		ammo_display.text = "AMMO: " + str(RunManager.current_ammo) + " / " + str(RunManager.max_ammo)
		
		# Keep the circle visible at all times when holding the blaster
		ammo_circle.visible = true 
		
		if is_reloading:
			# RELOAD MODE: Fill up as the timer goes down
			ammo_circle.max_value = RunManager.reload_time 
			ammo_circle.value = RunManager.reload_time - reload_timer 
		else:
			# AMMO MODE: Show remaining ammo
			ammo_circle.max_value = RunManager.max_ammo
			ammo_circle.value = RunManager.current_ammo
			
			# SYNC COLOR WITH OVERCLOCK STATE
			if is_overclocked:
				ammo_circle.modulate = Color.CYAN
			else:
				ammo_circle.modulate = Color.WHITE
			
	elif RunManager.equipped_weapon == "sword":
		ammo_display.visible = false
		ammo_circle.visible = false


# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_sword_hitbox_body_entered(body):
	if not is_swinging:
		return
		
	# 1. Hitting an Enemy
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		if not body in enemies_hit_this_swing:
			body.take_damage(sword_damage)
			enemies_hit_this_swing.append(body)
			
	# 2. Hitting the Terrain (SEISMIC SLAM)
	elif RunManager.sword_has_slam and not body.is_in_group("player"):
		if not has_slammed_this_swing:
			has_slammed_this_swing = true
			print("SYSTEM: SEISMIC SLAM DETONATED!")
			
			# Find every enemy in the room and check if they are caught in the blast radius (6 meters)
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if global_position.distance_to(enemy.global_position) <= 6.0:
					if enemy.has_method("take_damage"):
						enemy.take_damage(sword_damage)

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
			


func _on_options_button_pressed() -> void:
	pass # Replace with function body.
