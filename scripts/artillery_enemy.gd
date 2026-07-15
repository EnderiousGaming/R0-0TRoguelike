extends CharacterBody3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
const PROJECTILE = preload("res://scenes/enemy_projectile.tscn")
const DAMAGE_NUMBER = preload("res://scenes/damage_number.tscn")
const SCORE_DROP = preload("res://scenes/score_drop.tscn")

# ==========================================
# EXPORT VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
# --- ENEMY STATS ---
var base_max_health = 2
var base_speed = 2.0
var base_fire_cooldown = 3.0
var health = 2 # Weaker than the melee brutes
var speed = 2.0 # Slower movement
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_dead = false
var player = null

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
@onready var nav_agent = $NavigationAgent3D
@onready var death_sfx = $DeathSound
@onready var blaster_sfx = $BlasterSFX

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes the Daemon's stats scaled by current difficulty."""
	player = get_tree().get_first_node_in_group("player")
	
	var diff = RunManager.current_difficulty
	
	base_max_health = int(base_max_health * RunManager.DIFF_HEALTH[diff])
	health = base_max_health 
	
	speed = base_speed * RunManager.DIFF_SPEED[diff]
	
	var fire_timer = $Timer 
	if fire_timer:
		fire_timer.wait_time = base_fire_cooldown * RunManager.DIFF_FIRE_RATE[diff]

func _physics_process(delta):
	"""Handles Daemon movement, gravity, pathfinding, and facing the player."""
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Always aim at the player so projectiles shoot straight
		var flat_direction = Vector3(player.global_position.x - global_position.x, 0, player.global_position.z - global_position.z).normalized()
		if flat_direction.length() > 0.05:
			look_at(global_position + flat_direction, Vector3.UP)
		
		# Standard Pathfinding (Stop moving if within 15 meters)
		if distance_to_player > 15.0:
			nav_agent.target_position = player.global_position
			var next_path_position = nav_agent.get_next_path_position()
			var move_dir = global_position.direction_to(next_path_position)
			
			velocity.x = move_dir.x * speed
			velocity.z = move_dir.z * speed
		else:
			# We are in range! Stop moving and act as a stationary turret
			velocity.x = 0
			velocity.z = 0
			
	move_and_slide()

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func take_damage(amount):
	"""Applies damage to the Daemon and checks for death."""
	if is_dead:
		return
		
	health -= amount
	RunManager.damage_dealt += amount
	
	var dmg_text = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(dmg_text)
	dmg_text.global_position = global_position + Vector3(0, 1.5, 0)
	dmg_text.text = str(amount)
	dmg_text.animate()
	
	velocity = -velocity * 2 
	
	if health <= 0:
		die()

func die():
	"""Handles death sequence and spawns drops."""
	is_dead = true 
	
	death_sfx.reparent(get_parent())
	death_sfx.play()
	
	if not death_sfx.finished.is_connected(death_sfx.queue_free):
		death_sfx.finished.connect(death_sfx.queue_free)
	
	var drop_instance = SCORE_DROP.instantiate()
	
	SaveManager.save_data["stats"]["total_daemons_purged"] += 1
	SaveManager.save_game() 
	
	drop_instance.point_value = 300
	RunManager.enemies_defeated_this_room += 1
	
	get_parent().call_deferred("add_child", drop_instance)
	drop_instance.set_deferred("global_position", global_position + Vector3(0, 0.5, 0))
	
	queue_free()

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_timer_timeout():
	"""Fires a projectile at the player if they are within sniper range."""
	if player and global_position.distance_to(player.global_position) <= 30.0:
		var proj = PROJECTILE.instantiate()
		get_parent().add_child(proj)
		
		blaster_sfx.play()
		
		proj.global_position = global_position + Vector3(0, 0.25, 0)
		proj.look_at(player.global_position + Vector3(0, 1.0, 0), Vector3.UP)
