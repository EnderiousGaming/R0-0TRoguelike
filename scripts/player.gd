extends CharacterBody3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
const SPEED = 7.0
const JUMP_VELOCITY = 4.5
const DASH_SPEED = 25.0
const DASH_DURATION = 0.15
const GRAPPLE_SPEED = 35.0
const BULLET = preload("res://scenes/player_projectile.tscn")

# ==========================================
# EXPORT VARIABLES
# ==========================================
@export var mouse_sensitivity := 0.002

# ==========================================
# PUBLIC VARIABLES
# ==========================================
# --- ABILITIES & ULTIMATES ---
var emp_mat: StandardMaterial3D
var emp_particle_mat: StandardMaterial3D

var is_hovering = false
var hover_timer = 0.0

var is_chrono_active = false
var chrono_timer = 0.0

var are_blades_active = false
var blades_timer = 0.0
var blades_tick = 0.0
var phantom_pivot: Node3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- MOVEMENT ---
var is_invulnerable = false
var is_dashing = false
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var dash_direction = Vector3.ZERO

# --- BLASTER ---
var fire_cooldown = 0.0
var is_reloading = false
var reload_timer = 0.0

# If standard reload is 1.5 seconds, sweet spot is between 0.9s and 0.6s remaining.
var active_reload_start = 0.9 
var active_reload_end = 0.6   
var is_overclocked = false
var overclock_timer = 0.0
var overclock_duration = 3.0
var active_reload_failed = false 

# --- SWORD ---
var sword_damage = 3
var is_swinging = false
var enemies_hit_this_swing = []
var has_slammed_this_swing = false

var is_sword_thrown = false
var is_sword_returning = false
var sword_throw_timer = 0.0
var sword_throw_speed = 35.0
var sword_throw_direction = Vector3.ZERO
var enemies_hit_this_throw = [] 

# --- GRAPPLE ---
var is_grappling: bool = false
var grapple_target_point: Vector3 = Vector3.ZERO
var grapple_cooldown_max: float = 1.5 
var current_grapple_cooldown: float = 0.0

# --- MODIFIERS ---
var drain_timer = 0.0
var radiation_timer = 0.0

# --- NODE REFERENCES: TETHER ---
@onready var tether_zone = $Head/TetherDetectionZone
@onready var tether_timer = $TetherTickTimer

var active_tether_targets = []
var tether_visuals = [] # Holds our generated 3D beams

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
# --- UI ---
@onready var save_indicator = $HUD/SaveIndicator
@onready var tutorial_overlay = $HUD/TutorialOverlay
@onready var directive_text = $HUD/TutorialOverlay/MarginContainer/DirectiveText
@onready var stage_display = $HUD/StageDisplay
@onready var announcement_label = $HUD/AnnouncementLabel
@onready var kills_display = $HUD/KillsDisplay
@onready var score_display = $HUD/ScoreDisplay
@onready var health_display = $HUD/HealthDisplay
@onready var ammo_display = $HUD/AmmoDisplay
@onready var ammo_circle = $HUD/AmmoCircle
@onready var pause_menu = $HUD/PauseMenu
@onready var resume_button = $HUD/PauseMenu/VBoxContainer/ResumeButton
@onready var quit_button = $HUD/PauseMenu/VBoxContainer/QuitButton
@onready var options_button = $HUD/PauseMenu/VBoxContainer/OptionsButton
@onready var options_menu = $HUD/OptionsMenu
@onready var grapple_bar = $HUD/GrappleBar
@onready var damage_overlay = $HUD/DamageOverlay

# --- PLAYER NODES ---
@onready var head = $Head
@onready var aim_raycast = $Head/Camera3D/RayCast3D
@onready var laser_pivot = $Head/Camera3D/BlasterMesh/LaserPivot
@onready var blaster_mesh = $Head/Camera3D/BlasterMesh
@onready var blaster_muzzle = $Head/Camera3D/BlasterMesh
@onready var sword_pivot = $Head/Camera3D/SwordPivot
@onready var sword_hitbox = $Head/Camera3D/SwordPivot/SwordMesh/SwordHitbox
@onready var grapple_beam = $Head/Camera3D/GrappleBeam
@onready var blaster_sfx = $BlasterSFX

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():	
	"""Initializes player state, UI bindings, and weapon loadout."""
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	laser_pivot.visible = false
	ammo_circle.visible = false
	ammo_circle.step = 0.01 
	announcement_label.text = ""
	
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
	
	save_indicator.modulate.a = 0.0 
	SaveManager.memory_synced.connect(flash_save_indicator)
	
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.visible = false
		
	tether_timer.timeout.connect(_on_tether_tick)
	
	# --- THE FIX: STUTTER & SHADER CACHING ---
	# Pre-generate a pool of 10 beams so the graphics card doesn't panic mid-combat
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.0, 0.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color.RED
	mat.emission_energy_multiplier = 4.0
	
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.0)
	
	for i in range(10): # 10 is more than enough for maximum upgrades
		var new_beam = MeshInstance3D.new()
		new_beam.mesh = box
		new_beam.material_override = mat
		new_beam.top_level = true
		new_beam.visible = false
		add_child(new_beam)
		tether_visuals.append(new_beam)
		
	# 1. CACHE EMP MATERIALS (Fixes the stutter)
	emp_mat = StandardMaterial3D.new()
	emp_mat.albedo_color = Color(0.0, 0.8, 1.0, 0.6)
	emp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emp_mat.emission_enabled = true
	emp_mat.emission = Color.CYAN
	emp_mat.emission_energy_multiplier = 8.0
	
	emp_particle_mat = StandardMaterial3D.new()
	emp_particle_mat.albedo_color = Color.CYAN
	emp_particle_mat.emission_enabled = true
	emp_particle_mat.emission = Color.CYAN
	emp_particle_mat.emission_energy_multiplier = 5.0

	# 2. PRE-BUILD PHANTOM BLADES
	phantom_pivot = Node3D.new()
	add_child(phantom_pivot)
	for i in range(5):
		var blade = MeshInstance3D.new()
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(0.1, 1.5, 0.3)
		blade.mesh = b_mesh
		blade.material_override = emp_particle_mat
		
		# --- THE FIX: Add to the tree before calling look_at ---
		phantom_pivot.add_child(blade)
		
		var angle = (i / 5.0) * TAU
		blade.position = Vector3(cos(angle) * 3.5, 0, sin(angle) * 3.5)
		# Aim inward toward R0-0T rather than map coordinate (0, 0, 0)
		blade.look_at(global_position, Vector3.UP)
		
	phantom_pivot.visible = false
	
func _unhandled_input(event):
	"""Handles mouse capture, camera rotation, and game state toggles."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		
	if event.is_action_pressed("toggle_fullscreen"):
		var current_mode = DisplayServer.window_get_mode()
		if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			
	if OS.is_debug_build() and event.is_action_pressed("debug_clear_level"):
		force_level_clear()
		
	# --- UPLINK REROLL PROTOCOL ---
	if event.is_action_pressed("reroll_uplink"):
		var active_upgrades = get_tree().get_nodes_in_group("upgrades")
		if active_upgrades.size() > 0 and active_upgrades[0].cost == 0:
			if RunManager.uplink_rerolls > 0:
				RunManager.uplink_rerolls -= 1
				print("SYSTEM: Uplink Reroll accepted. ", RunManager.uplink_rerolls, " remaining.")
				get_tree().call_group("upgrades", "queue_free")
				var world_scene = get_tree().current_scene
				if world_scene.has_method("spawn_upgrades"):
					world_scene.spawn_upgrades()
			else:
				print("SYSTEM: Reroll failed. No Uplink Rerolls available.")

func _physics_process(delta):
	# Ensure we never divide by zero if time_scale is 0!
	var real_delta = delta
	if Engine.time_scale > 0.0:
		real_delta = delta / Engine.time_scale
	
	"""Handles movement, jumping, dashing, grappling, and modifiers."""
	var current_gravity = gravity
	var current_jump = JUMP_VELOCITY
	var current_accel = 10.0
	var current_speed = SPEED * RunManager.player_speed_multiplier
	
	if RunManager.has_moon_jump:
		current_gravity = gravity * 0.5
		current_jump = JUMP_VELOCITY * 1.2
		
	if RunManager.has_ice_physics:
		current_accel = 1.0

	if not is_on_floor():
		velocity.y -= current_gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = current_jump

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= real_delta

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# --- SWORD DASH ---
	if Input.is_action_just_pressed("dash"):
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
					
	# --- BLASTER GRAPPLE ---
	if Input.is_action_just_pressed("secondary_fire"):
		if RunManager.equipped_weapon == "blaster" and not is_grappling and current_grapple_cooldown <= 0.0:
			if aim_raycast.is_colliding():
				var target = aim_raycast.get_collider()
				if not target.is_in_group("enemy") and not target.is_in_group("upgrades"):
					is_grappling = true
					grapple_target_point = aim_raycast.get_collision_point()
					print("SYSTEM: GRAPPLE ATTACHED!")

	# --- FINAL MOVEMENT ---
	if is_grappling:
		if Input.is_action_just_pressed("jump"):
			is_grappling = false
			current_grapple_cooldown = grapple_cooldown_max 
			velocity.y = JUMP_VELOCITY * 1.5 
		else:
			var pull_direction = (grapple_target_point - global_position).normalized()
			velocity = pull_direction * GRAPPLE_SPEED
			if global_position.distance_to(grapple_target_point) < 2.5:
				is_grappling = false
				current_grapple_cooldown = grapple_cooldown_max 
	elif is_dashing:
		velocity.x = dash_direction.x * DASH_SPEED
		velocity.z = dash_direction.z * DASH_SPEED
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = false 
	else:
		if direction:
			velocity.x = lerp(velocity.x, direction.x * current_speed, current_accel * delta)
			velocity.z = lerp(velocity.z, direction.z * current_speed, current_accel * delta)
		else:
			velocity.x = lerp(velocity.x, 0.0, current_accel * delta)
			velocity.z = lerp(velocity.z, 0.0, current_accel * delta)
			
	# Trick the engine by inflating velocity, moving, then instantly deflating it!
	if Engine.time_scale > 0.0:
		velocity /= Engine.time_scale
		
	move_and_slide()
	
	if Engine.time_scale > 0.0:
		velocity *= Engine.time_scale
	
	# --- TETHER GRAVITY HACK (L-Shift) ---
	if Input.is_action_just_pressed("dash"):
		if RunManager.equipped_weapon == "tether" and current_grapple_cooldown <= 0.0:
			is_hovering = true
			hover_timer = 3.0
			velocity.y = JUMP_VELOCITY * 1.8 # Launch R0-0T up!
			current_grapple_cooldown = grapple_cooldown_max
			print("SYSTEM: GRAVITY HACK ENGAGED.")
			
	# --- PROCESS HOVER ---
	if is_hovering:
		hover_timer -= delta
		# Once R0-0T reaches the peak of the jump, drastically cut gravity
		if velocity.y < 0:
			current_gravity = gravity * 0.15 
		if hover_timer <= 0.0 or is_on_floor():
			is_hovering = false
			
	

func _process(delta):
	# Ensure we never divide by zero if time_scale is 0!
	var real_delta = delta
	if Engine.time_scale > 0.0:
		real_delta = delta / Engine.time_scale
	
	"""Handles dynamic HUD updates, weapon logic processing, and passive modifiers."""
	score_display.text = "SCORE: " + str(RunManager.score)
	kills_display.text = "CLEARED: " + str(RunManager.enemies_defeated_this_room)
	health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
	
	if RunManager.current_stage == 0:
		stage_display.text = "-- HUB --"
	else:
		stage_display.text = "STAGE: " + str(RunManager.current_stage) + " / 10"

	# --- COOLDOWNS ---
	if fire_cooldown > 0.0:
		fire_cooldown -= real_delta
		
	if RunManager.equipped_weapon == "blaster":
		_process_blaster(delta)
	elif RunManager.equipped_weapon == "sword":
		_process_sword()
		if is_sword_thrown:
			_process_sword_throw(delta)
	elif RunManager.equipped_weapon == "tether":
		_process_tether()
			
	# --- MODIFIERS ---
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
	
	# --- GRAPPLE UI ---
	if current_grapple_cooldown > 0.0:
		current_grapple_cooldown -= delta
		grapple_bar.visible = true
		grapple_bar.max_value = grapple_cooldown_max
		grapple_bar.value = current_grapple_cooldown
	else:
		grapple_bar.visible = false
		
	if is_grappling:
		grapple_beam.visible = true
		var distance = blaster_muzzle.global_position.distance_to(grapple_target_point)
		var midpoint = blaster_muzzle.global_position.lerp(grapple_target_point, 0.5)
		grapple_beam.global_position = midpoint
		grapple_beam.look_at(grapple_target_point, Vector3.UP)
		grapple_beam.rotate_x(deg_to_rad(90))
		grapple_beam.scale = Vector3(1.0, distance, 1.0)
	else:
		grapple_beam.visible = false
		
	# --- ULTIMATE UI ---
	var ult_percent = int((RunManager.ultimate_charge / RunManager.max_ultimate_charge) * 100)
	$HUD/UltimateDisplay.text = "ULTIMATE: " + str(ult_percent) + "%"
	if RunManager.ultimate_charge >= RunManager.max_ultimate_charge:
		$HUD/UltimateDisplay.modulate = Color.CYAN
	else:
		$HUD/UltimateDisplay.modulate = Color.WHITE

	# --- ULTIMATE TRIGGERS ---
	if Input.is_action_just_pressed("ultimate_ability") and RunManager.ultimate_charge >= RunManager.max_ultimate_charge:
		RunManager.ultimate_charge = 0.0
		
		if RunManager.equipped_weapon == "tether":
			execute_emp_blast() 
			
		elif RunManager.equipped_weapon == "blaster":
			is_chrono_active = true
			chrono_timer = 5.0 
			Engine.time_scale = 0.25
			print("SYSTEM: CHRONO-DRIVE ENGAGED.")
			
		elif RunManager.equipped_weapon == "sword":
			are_blades_active = true
			blades_timer = 10.0
			phantom_pivot.visible = true
			print("SYSTEM: PHANTOM BLADES DEPLOYED.")

	# --- PROCESS CHRONO-DRIVE ---
	if is_chrono_active:
		# Use unscaled delta so the timer runs in real-world time, not slow-mo time
		var unscaled_delta = delta / Engine.time_scale 
		chrono_timer -= unscaled_delta
		if chrono_timer <= 0.0:
			is_chrono_active = false
			Engine.time_scale = 1.0
			print("SYSTEM: CHRONO-DRIVE DISENGAGED.")

	# --- PROCESS PHANTOM BLADES ---
	if are_blades_active:
		# Spin the blades rapidly!
		phantom_pivot.rotate_y(8.0 * delta)
		blades_timer -= delta
		blades_tick -= delta
		
		if blades_tick <= 0.0:
			blades_tick = 0.25 # Damage enemies 4 times a second
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if not enemy.is_dead and global_position.distance_to(enemy.global_position) <= 4.0:
					enemy.take_damage(10)
					
		if blades_timer <= 0.0:
			are_blades_active = false
			phantom_pivot.visible = false

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

# --- WEAPON MANAGEMENT ---

func update_weapon_loadout():
	"""Updates visual weapon mesh and variables when switching weapons."""
	if is_sword_thrown:
		catch_sword()
	
	if RunManager.equipped_weapon == "blaster":
		blaster_mesh.visible = true
		sword_pivot.visible = false
		blaster_mesh.rotation_degrees = Vector3.ZERO 
	elif RunManager.equipped_weapon == "sword":
		blaster_mesh.visible = false
		sword_pivot.visible = true
		sword_hitbox.scale = Vector3.ONE * RunManager.sword_range_multiplier
		sword_pivot.position = Vector3(0.5, -0.4, -0.8)
		sword_pivot.rotation_degrees = Vector3(15, 0, -15)
		
		# --- THE FIX: TETHER UI ---
	elif RunManager.equipped_weapon == "tether":
		blaster_mesh.visible = false
		sword_pivot.visible = false
		ammo_display.visible = true
		# Display as a clean percentage (e.g., "EMP: 100%")
		var charge_percent = int((RunManager.ultimate_charge / RunManager.max_ultimate_charge) * 100)
		ammo_display.text = "EMP: " + str(charge_percent) + "%"
		
		ammo_circle.visible = true
		ammo_circle.max_value = RunManager.max_ultimate_charge
		ammo_circle.value = RunManager.ultimate_charge
		
		# Flash cyan when fully charged and ready to detonate!
		if RunManager.ultimate_charge >= RunManager.max_ultimate_charge:
			ammo_circle.modulate = Color.CYAN
		else:
			ammo_circle.modulate = Color.WHITE

func _process_blaster(delta):
	"""Processes firing and reloading for the blaster."""
	if is_grappling:
		return 
		
	if is_overclocked:
		overclock_timer -= delta
		if overclock_timer <= 0.0:
			is_overclocked = false
			ammo_display.modulate = Color.WHITE
			print("SYSTEM: Overclock depleted. Cooling down.")

	if is_reloading:
		reload_timer -= delta
		if not active_reload_failed and reload_timer <= active_reload_start and reload_timer >= active_reload_end:
			ammo_circle.modulate = Color.GOLD
		elif not active_reload_failed:
			ammo_circle.modulate = Color.WHITE
		else:
			ammo_circle.modulate = Color.GRAY

		if not active_reload_failed and reload_timer < (RunManager.reload_time - 0.1) and (Input.is_action_just_pressed("reload") or Input.is_action_just_pressed("shoot")):
			if reload_timer <= active_reload_start and reload_timer >= active_reload_end:
				reload_timer = 0.0
				is_overclocked = true
				overclock_timer = overclock_duration
				ammo_display.modulate = Color.CYAN 
				print("SYSTEM: PERFECT TIMING. BLASTER OVERCLOCKED!")
				
				# --- NEW: ACTIVE RELOAD HEAL ---
				if RunManager.current_health < RunManager.max_health:
					RunManager.current_health += 1
					health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
					print("SYSTEM: Coolant flush successful. Hull repaired.")
				# -------------------------------
			else:
				active_reload_failed = true
				print("SYSTEM: TIMING FAILED. Standard reload continuing.")
				
		if reload_timer <= 0.0:
			is_reloading = false
			RunManager.current_ammo = RunManager.max_ammo
			var tween = create_tween()
			tween.tween_property(blaster_mesh, "rotation_degrees", Vector3.ZERO, 0.2)
			
	elif Input.is_action_just_pressed("reload") and RunManager.current_ammo < RunManager.max_ammo:
		is_reloading = true
		reload_timer = RunManager.reload_time
		active_reload_failed = false 
		print("SYSTEM: Manual Reloading...")
		var tween = create_tween()
		tween.tween_property(blaster_mesh, "rotation_degrees", Vector3(45, 0, 0), 0.2)
		
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
			is_reloading = true
			reload_timer = RunManager.reload_time
			active_reload_failed = false 
			print("SYSTEM: Auto-Reloading...")
			var tween = create_tween()
			tween.tween_property(blaster_mesh, "rotation_degrees", Vector3(45, 0, 0), 0.2)

func _process_sword():
	"""Processes input for sword swings and throws."""
	if is_sword_thrown:
		return
		
	if Input.is_action_just_pressed("secondary_fire") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_swinging:
			throw_sword()
	elif Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if not is_swinging:
			swing_sword()

func fire_weapon() -> bool:
	"""Instantiates a projectile and handles scatter shot mechanics."""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create($Head/Camera3D.global_position, blaster_mesh.global_position)
	query.exclude = [self.get_rid()] 
	
	var result = space_state.intersect_ray(query)
	if result and not result.collider.is_in_group("enemy"):
		print("SYSTEM: Muzzle obstructed. Firing sequence aborted.")
		return false 
	
	var target_point = Vector3.ZERO
	if aim_raycast.is_colliding():
		target_point = aim_raycast.get_collision_point()
	else:
		target_point = aim_raycast.global_position - aim_raycast.global_transform.basis.z * 50.0
		
	RunManager.projectiles_fired += 1
	blaster_sfx.play()

	for i in range(RunManager.blaster_scatter_count):
		var bullet = BULLET.instantiate()
		get_parent().add_child(bullet)
		bullet.global_position = blaster_mesh.global_position
		bullet.look_at(target_point, Vector3.UP)
		
		if RunManager.blaster_scatter_count > 1:
			var spread = 0.05 * (RunManager.blaster_scatter_count - 1)
			bullet.rotate_x(randf_range(-spread, spread))
			bullet.rotate_y(randf_range(-spread, spread))
			
	return true

func swing_sword():
	"""Executes sword swing animation and initial hit detection."""
	is_swinging = true
	enemies_hit_this_swing.clear()
	has_slammed_this_swing = false
	
	var tween = create_tween()
	tween.tween_property(sword_pivot, "position", Vector3(0.0, -0.4, -1.0), 0.1 / RunManager.sword_swing_speed)
	tween.parallel().tween_property(sword_pivot, "rotation_degrees", Vector3(15, 80, -80), 0.1 / RunManager.sword_swing_speed)
	tween.tween_property(sword_pivot, "position", Vector3(0.5, -0.4, -0.8), 0.3 / RunManager.sword_swing_speed)
	tween.parallel().tween_property(sword_pivot, "rotation_degrees", Vector3(15, 0, -15), 0.3 / RunManager.sword_swing_speed)
	tween.tween_callback(func(): is_swinging = false)
	
	for area in sword_hitbox.get_overlapping_areas():
		if area.is_in_group("projectile") and area.has_method("deflect"):
			var aim_dir = -$Head/Camera3D.global_transform.basis.z
			area.deflect(aim_dir)
			print("SYSTEM: INSTANT PARRY!")
			
	for body in sword_hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			if not body in enemies_hit_this_swing:
				body.take_damage(sword_damage)
				enemies_hit_this_swing.append(body)
				print("SYSTEM: Sliced enemy for ", sword_damage, " damage!")

func throw_sword():
	"""Throws the sword as a boomerang projectile."""
	is_sword_thrown = true
	is_sword_returning = false
	sword_throw_timer = 3.0
	enemies_hit_this_throw.clear()

	sword_pivot.top_level = true
	sword_pivot.global_position = $Head/Camera3D.global_position
	sword_pivot.global_transform.basis = $Head/Camera3D.global_transform.basis
	sword_pivot.rotate_x(deg_to_rad(-90))

	sword_throw_direction = -$Head/Camera3D.global_transform.basis.z.normalized()
	print("SYSTEM: Executing Orbital Strike.")
	sword_hitbox.scale = Vector3(0.25, 0.25, 0.25) 

func start_sword_return():
	"""Recalls the thrown sword."""
	is_sword_returning = true
	enemies_hit_this_throw.clear() 
	print("SYSTEM: Blade returning.")

func catch_sword():
	"""Catches the sword and returns it to hand."""
	is_sword_thrown = false
	is_sword_returning = false
	sword_pivot.top_level = false
	sword_pivot.position = Vector3(0.5, -0.4, -0.8)
	sword_pivot.rotation_degrees = Vector3(15, 0, -15)
	sword_hitbox.scale = Vector3.ONE * RunManager.sword_range_multiplier
	print("SYSTEM: Blade caught.")

func _process_sword_throw(delta):
	"""Processes the physics of the flying sword."""
	sword_pivot.global_rotate(Vector3.UP, deg_to_rad(1440) * delta) 

	if not is_sword_returning:
		sword_pivot.global_position += sword_throw_direction * sword_throw_speed * delta
		sword_throw_timer -= delta

		if sword_throw_timer <= 0.0:
			start_sword_return()
			return

		var hit_something = false
		for body in sword_hitbox.get_overlapping_bodies():
			if body.is_in_group("player"):
				continue 

			hit_something = true
			if body.is_in_group("enemy"):
				if not body in enemies_hit_this_throw:
					if body.has_method("take_damage"):
						body.take_damage(sword_damage)
					enemies_hit_this_throw.append(body)
					print("SYSTEM: Blade sliced Daemon on outward throw!")
			else:
				print("SYSTEM: Blade struck environment.")

		if hit_something:
			start_sword_return()
	else:
		var target_pos = $Head/Camera3D.global_position
		var return_dir = sword_pivot.global_position.direction_to(target_pos)

		sword_pivot.global_position += return_dir * (sword_throw_speed * 1.5) * delta

		for body in sword_hitbox.get_overlapping_bodies():
			if body.is_in_group("enemy") and not body in enemies_hit_this_throw:
				if body.has_method("take_damage"):
					body.take_damage(sword_damage)
				enemies_hit_this_throw.append(body)
				print("SYSTEM: Blade sliced Daemon on return flight!")

		if sword_pivot.global_position.distance_to(target_pos) < 1.5:
			catch_sword()

# --- HEALTH & STATUS ---

func take_damage(amount):
	"""Applies damage to the player and handles death check."""
	if is_invulnerable:
		print("SYSTEM: Damage deflected by Dash!")
		return

	RunManager.current_health -= amount
	health_display.text = "HP: " + str(RunManager.current_health)
	
	flash_damage_screen()
	
	if RunManager.current_health <= 0:
		die()

func apply_hazard_buff():
	"""Applies a buff from a hazard zone."""
	if RunManager.current_health < RunManager.max_health:
		RunManager.current_health += 1
		print("SYSTEM: R0-0T cooling systems engaged. Health restored.")

func flash_damage_screen():
	"""Flashes a red overlay on taking damage."""
	var tween = get_tree().create_tween()
	damage_overlay.color.a = 0.3
	tween.tween_property(damage_overlay, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func die():
	"""Handles player death, updates stats, and loads game over screen."""
	AudioManager.stop_all_music()
	print("CRITICAL FAILURE: R0-0T Offline.")
	
	SaveManager.save_data["stats"]["r0_0t_deaths"] += 1
	SaveManager.save_data["stats"]["total_daemons_purged"] += RunManager.daemons_purged
	SaveManager.save_data["stats"]["projectiles_fired"] += RunManager.projectiles_fired
	SaveManager.save_data["stats"]["damage_dealt"] += RunManager.damage_dealt
	SaveManager.save_data["stats"]["bosses_purged"] += RunManager.bosses_purged
	SaveManager.save_data["stats"]["points_spent"] += RunManager.points_spent
	
	if RunManager.score > SaveManager.save_data["stats"]["highest_score"]:
		SaveManager.save_data["stats"]["highest_score"] = RunManager.score
		
	if RunManager.current_stage > SaveManager.save_data["stats"]["highest_stage_reached"]:
		SaveManager.save_data["stats"]["highest_stage_reached"] = RunManager.current_stage
	
	SaveManager.save_game()
	print("SYSTEM: Autosave complete. Memory core updated.")
	
	get_tree().call_deferred("change_scene_to_file", "res://scenes/game_over.tscn")

# --- UI VISUALS & SYSTEM ---

func flash_save_indicator():
	"""Flashes the save icon on screen."""
	var tween = create_tween()
	save_indicator.modulate.a = 1.0
	tween.tween_interval(1.5)
	tween.tween_property(save_indicator, "modulate:a", 0.0, 0.5)

func toggle_pause():
	"""Toggles the pause state and pause menu UI."""
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	
	pause_menu.visible = new_pause_state
	var show_hud = not new_pause_state
	
	$HUD/Crosshair.visible = show_hud
	health_display.visible = show_hud
	score_display.visible = show_hud
	kills_display.visible = show_hud
	stage_display.visible = show_hud
	announcement_label.visible = show_hud
	ammo_display.visible = show_hud
	
	if new_pause_state:
		ammo_circle.visible = false
		grapple_bar.visible = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func quit_to_menu():
	"""Quits to main menu."""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func announce(message: String):
	"""Shows a text announcement on the HUD."""
	announcement_label.text = message
	await get_tree().create_timer(4.0).timeout
	announcement_label.text = ""

func show_tutorial_directive(message: String):
	"""Displays a tutorial directive."""
	if not is_instance_valid(tutorial_overlay):
		return
	tutorial_overlay.visible = true
	directive_text.text = message
	print("DIRECTIVE POSTED: ", message)

func hide_tutorial_directive():
	"""Hides the tutorial directive."""
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.visible = false

func _update_weapon_ui():
	"""Updates the weapon UI elements."""
	if RunManager.equipped_weapon == "blaster":
		ammo_display.visible = true
		ammo_display.text = "AMMO: " + str(RunManager.current_ammo) + " / " + str(RunManager.max_ammo)
		ammo_circle.visible = true 
		
		if is_reloading:
			ammo_circle.max_value = RunManager.reload_time 
			ammo_circle.value = RunManager.reload_time - reload_timer 
		else:
			ammo_circle.max_value = RunManager.max_ammo
			ammo_circle.value = RunManager.current_ammo
			if is_overclocked:
				ammo_circle.modulate = Color.CYAN
			else:
				ammo_circle.modulate = Color.WHITE
			
	elif RunManager.equipped_weapon == "sword":
		ammo_display.visible = false
		ammo_circle.visible = false

	elif RunManager.equipped_weapon == "tether":
		# The new UltimateDisplay label handles the UI now, so we just hide the blaster ammo!
		ammo_display.visible = false
		ammo_circle.visible = false
			
func force_level_clear():
	"""DEBUG: Forces a level clear for testing."""
	print("DEBUG: Sequence broken. Warping to The Golden Process...")
	RunManager.enemies_defeated_this_room = 100 
	RunManager.current_stage = 9 
	var portal_node = get_tree().current_scene.get_node_or_null("Portal")
	if portal_node and portal_node.has_method("open_portal"):
		portal_node.open_portal()
	_process(0)

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_sword_hitbox_body_entered(body):
	"""Handles sword physics body collisions (Enemies and Slams)."""
	if not is_swinging:
		return
		
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		if not body in enemies_hit_this_swing:
			body.take_damage(sword_damage)
			enemies_hit_this_swing.append(body)
			
			# --- NEW: GLORY KILL HEAL ---
			if body.is_dead and RunManager.current_health < RunManager.max_health:
				RunManager.current_health += 1
				health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
				print("SYSTEM: Daemon code extracted. Hull repaired.")
			
	elif RunManager.sword_has_slam and not body.is_in_group("player"):
		if not has_slammed_this_swing:
			has_slammed_this_swing = true
			print("SYSTEM: SEISMIC SLAM DETONATED!")
			
			for enemy in get_tree().get_nodes_in_group("enemy"):
				if global_position.distance_to(enemy.global_position) <= 6.0:
					if enemy.has_method("take_damage"):
						enemy.take_damage(sword_damage)

func _on_sword_hitbox_area_entered(area):
	"""Handles sword area collisions (Projectile deflection)."""
	if is_swinging and area.is_in_group("projectile") and area.has_method("deflect"):
		var aim_dir = -$Head/Camera3D.global_transform.basis.z
		area.deflect(aim_dir)
		print("SYSTEM: PARRIED PROJECTILE!")
		
		# --- NEW: PARRY HEAL ---
		if RunManager.current_health < RunManager.max_health:
			RunManager.current_health += 1
			health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
			print("SYSTEM: Kinetic energy absorbed. Hull repaired.")
		
		if RunManager.has_deflect_boost:
			RunManager.player_speed_multiplier += 0.4
			await get_tree().create_timer(1.5).timeout
			RunManager.player_speed_multiplier -= 0.4
			
	

func _on_options_button_pressed() -> void:
	"""Handles options button press."""
	pass 

# ==========================================
# SIPHON TETHER LOGIC
# ==========================================

func _process_tether():
	if Input.is_action_pressed("shoot") and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var bodies = tether_zone.get_overlapping_bodies()
		var valid_enemies = []
		var space_state = get_world_3d().direct_space_state
		
		# --- THE FIX: FORWARD VECTOR ---
		# Grab the exact direction the camera is facing
		var aim_dir = -$Head/Camera3D.global_transform.basis.z.normalized()
		
		for body in bodies:
			if body.is_in_group("enemy") and not body.is_dead:
				
				# --- THE FIX: DOT PRODUCT (FOV CHECK) ---
				# Get a vector pointing straight from R0-0T to the enemy
				var dir_to_enemy = global_position.direction_to(body.global_position)
				
				# Compare the two vectors! 
				# 1.0 = Dead center of crosshair. 0.0 = Exactly 90 degrees to the side. -1.0 = Directly behind.
				# A value of 0.5 gives you a generous 120-degree cone of vision.
				if aim_dir.dot(dir_to_enemy) > 0.5:
					
					# (Keep your existing LOS check here)
					var target_center = body.global_position + Vector3(0, 0.5, 0) 
					var query = PhysicsRayQueryParameters3D.create($Head/Camera3D.global_position, target_center)
					query.exclude = [self.get_rid()]
					var result = space_state.intersect_ray(query)
					
					if result and result.collider == body:
						valid_enemies.append(body)
					
		# Sort by distance
		valid_enemies.sort_custom(func(a, b): 
			return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
		)
		
		active_tether_targets = valid_enemies.slice(0, RunManager.tether_count)
		
		if active_tether_targets.size() > 0 and tether_timer.is_stopped():
			tether_timer.start(RunManager.tether_tick_rate)
			
		_update_tether_visuals()
		
	else:
		active_tether_targets.clear()
		_update_tether_visuals()
		tether_timer.stop()
		

func _update_tether_visuals():
	for i in range(tether_visuals.size()):
		# Safety check to ensure the enemy didn't despawn this exact frame
		if i < active_tether_targets.size() and is_instance_valid(active_tether_targets[i]):
			tether_visuals[i].visible = true
			var enemy = active_tether_targets[i]
			
			# Use the exact same lowered target point as the LOS check
			var target_pos = enemy.global_position + Vector3(0, 0.5, 0)
			var start_pos = blaster_muzzle.global_position
			var distance = start_pos.distance_to(target_pos)
			
			tether_visuals[i].global_position = start_pos.lerp(target_pos, 0.5)
			
			if Vector3.UP.cross(target_pos - start_pos).is_zero_approx():
				tether_visuals[i].look_at(target_pos, Vector3.RIGHT)
			else:
				tether_visuals[i].look_at(target_pos, Vector3.UP)
			
			tether_visuals[i].scale = Vector3(1, 1, distance)
		else:
			# Hide any unused beams from the pool
			tether_visuals[i].visible = false
			
func _on_tether_tick():
	var total_charge_gained = 0.0
	
	for enemy in active_tether_targets:
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_damage(RunManager.tether_damage)
			total_charge_gained += RunManager.tether_charge_rate
			
	if total_charge_gained > 0:
		# --- THE FIX: Point only to the universal Ultimate pool ---
		RunManager.ultimate_charge += total_charge_gained
		
		if RunManager.ultimate_charge >= RunManager.max_ultimate_charge:
			RunManager.ultimate_charge = RunManager.max_ultimate_charge
		
		# Cap the charge at the max
		if RunManager.ultimate_charge >= RunManager.max_ultimate_charge:
			RunManager.ultimate_charge = RunManager.max_ultimate_charge
			print("SYSTEM: TETHER OVERCHARGED. ABILITY READY.")

func execute_emp_blast():
	var emp_radius = 20.0
	var emp_damage = 25 
	var enemies_caught = 0 
	
	print("SYSTEM: EMP DETONATED!")
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and not enemy.is_dead:
			if global_position.distance_to(enemy.global_position) <= emp_radius:
				enemy.take_damage(emp_damage)
				enemies_caught += 1
				print("DEBUG: EMP zapped an enemy. Tally: ", enemies_caught)
				
	# --- BULLETPROOF HEAL LOGIC ---
	if enemies_caught > 0:
		if RunManager.current_health < RunManager.max_health:
			RunManager.current_health = min(RunManager.current_health + enemies_caught, RunManager.max_health)
			health_display.text = "HP: " + str(RunManager.current_health) + " / " + str(RunManager.max_health)
			print("SYSTEM: EMP Siphon tapped ", enemies_caught, " targets. Health is now ", RunManager.current_health)
		else:
			print("SYSTEM: EMP Siphon successful, but R0-0T is already at max health.")
	else:
		print("SYSTEM: EMP detonated, but caught 0 enemies.")
		
	# --- 1. SHOCKWAVE MESH ---
	var shockwave = MeshInstance3D.new()
	shockwave.mesh = SphereMesh.new()
	shockwave.top_level = true
	
	# Duplicate the cached material! This prevents the shader compilation hitch 
	# while allowing us to safely fade out the alpha without making future EMPs invisible.
	var shockwave_mat = emp_mat.duplicate()
	shockwave.material_override = shockwave_mat
	
	get_parent().add_child(shockwave)
	shockwave.global_position = global_position
	
	var tween = create_tween()
	tween.tween_property(shockwave, "scale", Vector3(emp_radius * 2, emp_radius * 2, emp_radius * 2), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(shockwave_mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(shockwave.queue_free)
	
	# --- 2. THE PARTICLE BURST ---
	var particles = GPUParticles3D.new()
	particles.amount = 150
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 0.9 
	particles.top_level = true
	
	var p_mat = ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_mat.emission_sphere_radius = 1.0
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 180.0
	p_mat.initial_velocity_min = 25.0
	p_mat.initial_velocity_max = 40.0
	p_mat.gravity = Vector3.ZERO
	particles.process_material = p_mat
	
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.2, 0.2, 0.2)
	
	# Assign the cached material directly to the mesh
	p_mesh.material = emp_particle_mat
	particles.draw_pass_1 = p_mesh
	
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)
