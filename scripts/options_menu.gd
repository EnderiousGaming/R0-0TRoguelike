extends Panel

# --- UI REFERENCES ---
@onready var fullscreen_toggle = $VBoxContainer/FullscreenToggle
@onready var resolution_dropdown = $VBoxContainer/HBoxContainer/ResolutionDropdown
@onready var sensitivity_slider = $VBoxContainer/HBoxContainer2/SensitivitySlider
@onready var crt_toggle = $VBoxContainer/CRTToggle
@onready var back_button = $VBoxContainer/BackButton

# --- RESOLUTION DATA ---
const RESOLUTIONS = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
	Vector2i(1024, 576)
]

func _ready():
	# 1. Hide the menu by default
	visible = false
	
	# 2. Populate the Resolution Dropdown
	for res in RESOLUTIONS:
		resolution_dropdown.add_item(str(res.x) + " x " + str(res.y))
		
	# 3. Connect Signals
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	resolution_dropdown.item_selected.connect(_on_resolution_selected)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	crt_toggle.toggled.connect(_on_crt_toggled)
	back_button.pressed.connect(hide_options)
	
	# 4. Load saved settings and apply them to the UI
	load_and_apply_settings()

func load_and_apply_settings():
	var opts = SaveManager.save_data["options"]
	
	# Update UI elements without triggering their signals
	fullscreen_toggle.set_pressed_no_signal(opts["fullscreen"])
	resolution_dropdown.select(opts["resolution_index"])
	sensitivity_slider.set_value_no_signal(opts["mouse_sensitivity"])
	crt_toggle.set_pressed_no_signal(opts["crt_shader_enabled"])
	
	# Apply actual engine changes based on the loaded save data
	apply_fullscreen(opts["fullscreen"])
	apply_resolution(opts["resolution_index"])
	apply_crt(opts["crt_shader_enabled"])
	
	# Update the player's actual mouse sensitivity variable
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.mouse_sensitivity = opts["mouse_sensitivity"]

# ==========================================
# SIGNAL HANDLERS
# ==========================================

func _on_fullscreen_toggled(toggled_on: bool):
	apply_fullscreen(toggled_on)
	SaveManager.save_data["options"]["fullscreen"] = toggled_on
	SaveManager.save_game()

func _on_resolution_selected(index: int):
	apply_resolution(index)
	SaveManager.save_data["options"]["resolution_index"] = index
	SaveManager.save_game()

func _on_sensitivity_changed(value: float):
	SaveManager.save_data["options"]["mouse_sensitivity"] = value
	SaveManager.save_game()
	
	# Immediately update R0-0T if they exist in the scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.mouse_sensitivity = value

func _on_crt_toggled(toggled_on: bool):
	apply_crt(toggled_on)
	SaveManager.save_data["options"]["crt_shader_enabled"] = toggled_on
	SaveManager.save_game()

# ==========================================
# ENGINE APPLICATION LOGIC
# ==========================================

func apply_fullscreen(is_full: bool):
	if is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		resolution_dropdown.disabled = true 
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		resolution_dropdown.disabled = false
		
		# NEW: Wait one frame for the OS to actually exit fullscreen before resizing
		await get_tree().process_frame
		
		var saved_res_index = SaveManager.save_data["options"]["resolution_index"]
		apply_resolution(saved_res_index)

func apply_resolution(index: int):
	var is_fullscreen = SaveManager.save_data["options"].get("fullscreen", false)
	
	if not is_fullscreen:
		var target_size = RESOLUTIONS[index]
		var window = get_window() # Grab the actual Godot Viewport Window
		
		# 1. Instantly resize both the OS window and the internal rendering canvas
		window.size = target_size
		
		# 2. Calculate the screen center (We still use DisplayServer to read monitor stats)
		var screen_center = DisplayServer.screen_get_position() + Vector2i(DisplayServer.screen_get_size() / 2.0)
		
		# 3. Move the window flawlessly
		window.position = screen_center - Vector2i(target_size / 2.0)

func apply_crt(is_enabled: bool):
	# Grab the root player node
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Search down the correct path from the root
		var crt_rect = player.get_node_or_null("CRTFilter/CRTEffect")
		if crt_rect:
			crt_rect.visible = is_enabled

func hide_options():
	visible = false
	get_parent().get_node("PauseMenu").visible = true
