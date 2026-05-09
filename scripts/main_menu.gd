extends Control

@onready var main_buttons = $VBoxContainer 
@onready var options_menu = $OptionsMenu
@onready var options_button = $VBoxContainer/OptionsButton

func _ready():
	options_menu.visible = false
	options_button.pressed.connect(show_options)
	
	# Listen for the new signal!
	options_menu.back_pressed.connect(hide_options)

func show_options():
	print("SYSTEM: Options button clicked!")
	main_buttons.visible = false
	options_menu.visible = true
	# Force the menu to capture mouse clicks
	options_menu.mouse_filter = Control.MOUSE_FILTER_STOP 

func hide_options():
	options_menu.visible = false
	main_buttons.visible = true
	# Set it back to ignore so it doesn't block the main menu buttons
	options_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
