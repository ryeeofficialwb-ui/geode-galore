extends SceneTree
## Encrypts one music file for the game (called by tools/make_music.py):
##   godot --headless --path . --script res://tools/encrypt_music.gd -- <in.ogg> <out.dat>
## The game decrypts it in memory (scripts/sfx.gd, Sfx.MUSIC_KEY), so the music never sits in the game
## files as a playable audio file.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <in.ogg> <out.dat>")
		quit(1)
		return
	var data := FileAccess.get_file_as_bytes(args[0])
	if data.is_empty():
		push_error("can't read " + args[0])
		quit(1)
		return
	var f := FileAccess.open_encrypted_with_pass(args[1], FileAccess.WRITE, preload("res://scripts/sfx.gd").MUSIC_KEY)
	if f == null:
		push_error("can't write " + args[1])
		quit(1)
		return
	f.store_buffer(data)
	f.close()
	print("encrypted %s -> %s (%d KB)" % [args[0].get_file(), args[1].get_file(), data.size() / 1024])
	quit(0)
