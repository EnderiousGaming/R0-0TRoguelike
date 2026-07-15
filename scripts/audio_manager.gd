extends Node

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
@onready var menu_music = $MenuMusicPlayer
@onready var arena_music = $ArenaMusicPlayer

# ==========================================
# BUILT-IN ENGINE METHODS
# ==========================================
# (None in this script)

# ==========================================
# CORE LOGIC / CUSTOM METHODS
# ==========================================

func play_menu_music():
	"""
	Plays the menu music track.
	Only starts if not already playing to prevent restarts between Main Menu and Hub.
	"""
	if not menu_music.playing:
		arena_music.stop() # Ensure arena music turns off
		menu_music.play()

func play_arena_music():
	"""
	Plays the combat/arena music track.
	Prevents restarting between arena stages.
	"""
	if not arena_music.playing:
		menu_music.stop() # Ensure menu music turns off
		arena_music.play()

func stop_all_music():
	"""Stops all currently playing music (e.g., for abrupt silence upon death)."""
	menu_music.stop()
	arena_music.stop()
