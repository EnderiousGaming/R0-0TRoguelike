extends CharacterBody3D

const PROJECTILE = preload("res://scenes/enemy_projectile.tscn")
const DAMAGE_NUMBER = preload("res://scenes/damage_number.tscn")
const SCORE_DROP = preload("res://scenes/score_drop.tscn")

# --- BOSS STATS ---
var max_health = 100
var health = max_health
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- STATE MACHINE ---
enum State {HUNT, BARRAGE, LASER_SWEEP}
var current_state = State.HUNT
var state_timer = 0.0

# --- COMBAT VARIABLES ---
var hunt_speed = 3.0
var contact_damage = 2
var contact_cooldown = 0.5
var current_contact_timer = 0.0

@onready var nav_agent = $NavigationAgent3D
@onready var laser_pivot = $LaserPivot
@onready var laser_mesh = $LaserPivot/MeshInstance3D # Adjust path
@onready var laser_hitbox = $LaserPivot/LaserHitbox/CollisionShape3D # Adjust path
var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	# Ensure the laser is off when spawning
	laser_mesh.visible = false
	laser_hitbox.disabled = true

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not player:
		return

	# Tick down the contact damage timer
	if current_contact_timer > 0.0:
		current_contact_timer -= delta

	# Run the logic for whatever state AUREUS is currently in
	match current_state:
		State.HUNT:
			_state_hunt(delta)
		State.BARRAGE:
			_state_barrage(delta)
		State.LASER_SWEEP:
			_state_laser_sweep(delta)

	move_and_slide()
	_check_contact_damage()

# ==========================================
# STATE LOGIC
# ==========================================

func _state_hunt(delta):
	state_timer += delta
	
	# 1. Ask the NavAgent where to step next
	nav_agent.target_position = player.global_position
	var next_pos = nav_agent.get_next_path_position()
	
	# 2. FLATTEN THE Y-AXIS: Tell Aureus to aim straight ahead, not down at the floor
	var flat_next_pos = Vector3(next_pos.x, global_position.y, next_pos.z)
	var dir = global_position.direction_to(flat_next_pos)
	
	velocity.x = dir.x * hunt_speed
	velocity.z = dir.z * hunt_speed
	
	# 3. Look at the player smoothly
	var flat_player_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	look_at(flat_player_pos, Vector3.UP)

	# 4. Transition to Barrage after 5 seconds of chasing
	if state_timer >= 5.0:
		transition_to(State.BARRAGE)

func _state_barrage(delta):
	state_timer += delta
	velocity.x = 0 # Stop moving to shoot
	velocity.z = 0
	
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)

	# Fire a shotgun spread every 1.5 seconds
	if fmod(state_timer, 1.5) < delta:
		fire_spread()

	# Transition to Laser after 4.5 seconds (3 volleys)
	if state_timer >= 4.5:
		transition_to(State.LASER_SWEEP)

func _state_laser_sweep(delta):
	state_timer += delta
	velocity.x = 0
	velocity.z = 0
	
	# Rotate the giant laser sweeping across the room
	laser_pivot.rotate_y(deg_to_rad(45 * delta)) # Spins 45 degrees per second

	# Transition back to Hunt after 6 seconds
	if state_timer >= 6.0:
		transition_to(State.HUNT)

func transition_to(new_state):
	current_state = new_state
	state_timer = 0.0
	
	# Handle entering new states (like turning the laser on/off)
	if current_state == State.LASER_SWEEP:
		print("WARNING: AUREUS INITIATING SWEEP PROTOCOL.")
		laser_mesh.visible = true
		laser_hitbox.disabled = false
	else:
		laser_mesh.visible = false
		laser_hitbox.disabled = true

# ==========================================
# ATTACKS & DAMAGE
# ==========================================

func fire_spread():
	for i in range(5): 
		var proj = PROJECTILE.instantiate()
		get_parent().add_child(proj)
		
		# LOWER THE SPAWN POINT: Fire from waist-level instead of chest-level
		proj.global_position = global_position + Vector3(0, 0.5, 0) 
		
		# LOWER THE TARGET: Aim closer to R0-0T's feet/base origin
		var target_pos = player.global_position + Vector3(0, 0.2, 0) 
		proj.look_at(target_pos, Vector3.UP)
		
		# (Keep your existing spread rotation math down here)
		var spread_angle = deg_to_rad(-30 + (i * 15))
		proj.rotate_y(spread_angle)

func _check_contact_damage():
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("player"):
			if current_contact_timer <= 0.0 and collider.has_method("take_damage"):
				collider.take_damage(contact_damage)
				current_contact_timer = contact_cooldown

func take_damage(amount):
	health -= amount
	
	RunManager.damage_dealt += amount
	
	var dmg_text = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(dmg_text)
	dmg_text.global_position = global_position + Vector3(0, 4.0, 0)
	dmg_text.text = str(amount)
	dmg_text.animate()
	
	if health <= 0:
		die()

func die():
	# 1. Spawn the physical drop
	var drop_instance = SCORE_DROP.instantiate()
	
	# Pass any specific value you want (e.g., Bosses drop more)
	drop_instance.point_value = 5000
	
	RunManager.enemies_defeated_this_room += 1
	
	# Use call_deferred to safely add it to the world, just like we did with Aureus
	get_parent().call_deferred("add_child", drop_instance)
	drop_instance.set_deferred("global_position", global_position + Vector3(0, 0.5, 0))
	
	# 2. Delete the enemy
	queue_free()
	
	# 2. Add a dramatic 3-second pause so the player sees the final damage number
	await get_tree().create_timer(3.0).timeout
	
	# 3. Unlock the mouse cursor so the player can use the Main Menu buttons
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 4. Boot to the title screen
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
