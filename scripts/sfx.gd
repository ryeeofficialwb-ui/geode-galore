extends Node
## Autoload "Sfx": sound effects + music. Play a sound with Sfx.play("hit").
## Files: assets/audio/<name>.wav / .ogg / .mp3 (first one found wins).
## Volumes per sound are in Config.SOUNDS, music tracks in Config.MUSIC_TRACKS. Missing files are silent.
## Music and sound effects run on their own audio buses ("Music", "SFX") so each has its own volume.

const DIR := "res://assets/audio/"
const SETTINGS_PATH := "user://settings.cfg"
const VOICES := 12
const SILENT_DB := -60.0

var music_volume := Config.MUSIC_VOLUME
var sfx_volume := Config.SFX_VOLUME
var muted := false
var current_music := ""
var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music := {}   # track key -> AudioStreamPlayer (all keep playing; the current one is audible)
var _fades := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus("Music")
	_bus("SFX")
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		sfx_volume = cfg.get_value("audio", "sfx_volume", cfg.get_value("audio", "volume", sfx_volume))
		music_volume = cfg.get_value("audio", "music_volume", music_volume)
		muted = cfg.get_value("audio", "muted", muted)
	_apply()
	for sound_name in Config.SOUNDS:
		var s := _find(sound_name)
		if s:
			_streams[sound_name] = s
		else:
			push_warning("Sound missing: %s (put %s%s.wav/.ogg/.mp3)" % [sound_name, DIR, sound_name])
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		_voices.append(v)
	for key in Config.MUSIC_TRACKS:
		var m := _find(Config.MUSIC_TRACKS[key].file)
		if m == null:
			push_warning("Music missing: %s" % Config.MUSIC_TRACKS[key].file)
			continue
		var p := AudioStreamPlayer.new()
		p.stream = m
		p.bus = "Music"
		p.volume_db = SILENT_DB
		p.finished.connect(p.play)  # loop any format
		add_child(p)
		p.play()
		_music[key] = p
	play_music("main")


func _bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func _find(sound_name: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "%s%s.%s" % [DIR, sound_name, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## pitch: extra pitch on top of the random wobble (1.0 = normal).
func play(sound_name: String, pitch := 1.0) -> void:
	if not _streams.has(sound_name):
		return
	var voice := _voices[_next]
	for i in VOICES:  # prefer a free voice
		var c := _voices[(_next + i) % VOICES]
		if not c.playing:
			voice = c
			break
	_next = (_next + 1) % VOICES
	var info: Dictionary = Config.SOUNDS[sound_name]
	var pv := float(info.get("pitch_var", 0.0))
	voice.stream = _streams[sound_name]
	voice.volume_db = float(info.get("db", 0.0))
	voice.pitch_scale = pitch * (1.0 + randf_range(-pv, pv))
	voice.play()


## Cross-fades to another track from Config.MUSIC_TRACKS ("main", "mine", ...).
func play_music(key: String) -> void:
	if key == current_music or not _music.has(key):
		return
	current_music = key
	for k in _music:
		var p: AudioStreamPlayer = _music[k]
		var target := float(Config.MUSIC_TRACKS[k].get("db", -14.0)) if k == key else SILENT_DB
		if _fades.has(k) and _fades[k].is_valid():
			_fades[k].kill()
		var tw := create_tween()
		tw.tween_property(p, "volume_db", target, Config.MUSIC_FADE_TIME).set_trans(Tween.TRANS_SINE)
		_fades[k] = tw


func set_muted(m: bool) -> void:
	muted = m
	_apply()
	_save()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply()
	_save()


func _apply() -> void:
	AudioServer.set_bus_mute(0, muted)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.save(SETTINGS_PATH)
