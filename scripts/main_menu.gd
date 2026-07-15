extends Control

# ==========================================
# SIGNALS
# ==========================================
# (None in this script)

# ==========================================
# ENUMS & CONSTANTS
# ==========================================
# (None in this script)

# ==========================================
# EXPORT VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PUBLIC VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# PRIVATE VARIABLES
# ==========================================
# (None in this script)

# ==========================================
# ONREADY VARIABLES
# ==========================================
@onready var main_buttons = $VBoxContainer 
@onready var options_menu = $OptionsMenu
@onready var options_button = $VBoxContainer/OptionsButton

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================

func _ready():
	"""Initializes the main menu, music, and connects UI signals."""
	AudioManager.play_menu_music()
	
	options_menu.visible = false
	options_button.pressed.connect(show_options)
	
	# Listen for the new signal!
	options_menu.back_pressed.connect(hide_options)

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func show_options():
	"""Hides the main buttons and shows the options menu."""
	print("SYSTEM: Options button clicked!")
	main_buttons.visible = false
	options_menu.visible = true
	# Force the menu to capture mouse clicks
	options_menu.mouse_filter = Control.MOUSE_FILTER_STOP 

func hide_options():
	"""Hides the options menu and shows the main buttons."""
	options_menu.visible = false
	main_buttons.visible = true
	# Set it back to ignore so it doesn't block the main menu buttons
	options_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ==========================================
# SIGNAL HANDLERS
# ==========================================
# (None in this script)
