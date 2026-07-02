extends Node

@onready var menu_music = $MenuMusicPlayer
@onready var arena_music = $ArenaMusicPlayer

func play_menu_music():
	# Only start the music if it isn't ALREADY playing.
	# This prevents the track from restarting when moving from Main Menu to Hub!
	if not menu_music.playing:
		arena_music.stop() # Ensure arena music turns off
		menu_music.play()

func play_arena_music():
	# Same logic: prevents restarting between arena stages
	if not arena_music.playing:
		menu_music.stop() # Ensure menu music turns off
		arena_music.play()

func stop_all_music():
	# For abrupt silence upon death
	menu_music.stop()
	arena_music.stop()
