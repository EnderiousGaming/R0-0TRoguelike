extends CharacterBody3D

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
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
var base_max_health = 4
var base_speed = 3.0
var health = 4
var speed = 3.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- ATTACK STATS ---
var attack_damage = 1
var attack_cooldown = 1.0 
var current_attack_timer = 0.0

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

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes the Daemon's stats scaled by the current difficulty."""
	player = get_tree().get_first_node_in_group("player")
	
	var diff = RunManager.current_difficulty
	
	base_max_health = int(base_max_health * RunManager.DIFF_HEALTH[diff])
	health = base_max_health 
	
	speed = base_speed * RunManager.DIFF_SPEED[diff]
	
	if player == null:
		print("ERROR: Enemy spawned but cannot find 'player' in groups!")
	else:
		print("Target Acquired: Hunting R0-0T.")

func _physics_process(delta):
	"""Handles Daemon movement, pathfinding, gravity, and physical attacks."""
	# 1. Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta 
		
	# 2. Pathfinding
	if player:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player > 1.0:
			nav_agent.target_position = player.global_position
			var next_path_position = nav_agent.get_next_path_position()
			var direction = global_position.direction_to(next_path_position)
			
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = 0
			velocity.z = 0
			
	move_and_slide()

	# 3. Combat Logic (Contact Damage)
	if current_attack_timer > 0.0:
		current_attack_timer -= delta
		
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			if current_attack_timer <= 0.0 and collider.has_method("take_damage"):
				collider.take_damage(attack_damage)
				current_attack_timer = attack_cooldown
				print("SYSTEM: Daemon inflicted ", attack_damage, " contact damage!")

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func take_damage(amount):
	"""Applies damage to the Daemon, applying combat modifiers, and popping numbers."""
	if is_dead:
		return
	
	var final_damage = amount
	RunManager.damage_dealt += amount
	
	if player:
		var dist = global_position.distance_to(player.global_position)
		if RunManager.has_close_combat and dist < 6.0:
			final_damage += 2
		elif RunManager.has_sniper_combat and dist > 15.0:
			final_damage += 2

	health -= final_damage
	
	var dmg_text = DAMAGE_NUMBER.instantiate()
	get_parent().add_child(dmg_text)
	dmg_text.global_position = global_position + Vector3(0, 1.5, 0)
	dmg_text.text = str(final_damage)
	dmg_text.animate()
	
	velocity = -velocity * 2 
	
	if health <= 0:
		die()

func die():
	"""Handles death sequence, spawning score drops, updating stats, and removal."""
	is_dead = true 
	
	death_sfx.reparent(get_parent())
	death_sfx.play()
	
	if not death_sfx.finished.is_connected(death_sfx.queue_free):
		death_sfx.finished.connect(death_sfx.queue_free)
	
	var drop_instance = SCORE_DROP.instantiate()
	
	SaveManager.save_data["stats"]["total_daemons_purged"] += 1
	RunManager.daemons_purged += 1
	
	drop_instance.point_value = 100
	RunManager.enemies_defeated_this_room += 1 
	
	get_parent().call_deferred("add_child", drop_instance)
	drop_instance.set_deferred("global_position", global_position + Vector3(0, 0.5, 0))
	
	queue_free()
