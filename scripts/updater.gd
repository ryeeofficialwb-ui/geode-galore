class_name Updater
extends Node
## AUTO-UPDATE from GitHub Releases (main.gd starts one of these when the game opens).
## (Ported from Seed Splicer's updater.)
##
## The game is RichFromRocks.exe (the Godot engine, never changes) + RichFromRocks.pck next to it
## (everything we make: scripts, scenes, art, sounds). An update is a new pack, published as a GitHub
## Release on GameVersion.RELEASES_REPO tagged v<version>, with RichFromRocks-update-<version>.pck and
## its .sha256 (tools/publish_update.py does all of that).
##
##   1. Ask GitHub for the latest release. Newer than this game? Download its pack next to the exe as
##      RichFromRocks.pck.new and check its SHA-256.
##   2. Write user://updates/apply_update.bat, run it and quit. The script waits for the game to close,
##      keeps the old pack as RichFromRocks.pck.old, puts the new one in its place and SELF-TESTS it:
##      `RichFromRocks.exe --headless -- --selftest` must exit with code 42 (main.gd does that once its
##      screen is built).
##   3. Test passed: the new version starts. Test failed: the old pack goes back, the version goes in
##      RichFromRocks-update-failed.txt (never tried again) and the old version starts.
## Offline, GitHub down, a bad hash, a folder we can't write to: the game just runs as it is.
## Never runs in the editor, in the screenshot demo, or with --no-update. The save is in AppData, so an
## update never touches it.

signal status_changed(text: String)

const UPDATES_DIR := "user://updates"
const UPDATE_PREFIX := "RichFromRocks-update-"
const FAILED_FILE := "RichFromRocks-update-failed.txt"
const SELFTEST_CODE := 42
const TIMEOUT := 8.0

var _http: HTTPRequest


## Only exported games check for updates (not the editor, the demo, the self-test or --no-update).
static func enabled() -> bool:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if OS.has_feature("editor") or "--no-update" in args or "--selftest" in args:
		return false
	for a in args:
		if a.begins_with("--shot="):
			return false
	return true


## The game's own pack (next to the exe).
static func game_dir() -> String:
	return OS.get_executable_path().get_base_dir()


static func pack_path() -> String:
	return game_dir().path_join(OS.get_executable_path().get_file().get_basename() + ".pck")


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_release)
	status_changed.emit("Checking for updates...")
	var url := "https://api.github.com/repos/%s/releases/latest" % GameVersion.RELEASES_REPO
	if _http.request(url, ["User-Agent: RichFromRocks", "Accept: application/vnd.github+json"]) != OK:
		_done("")


func _on_release(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_done("")  # offline, no releases yet, or the repo can't be read: play this version
		return
	var release: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not release is Dictionary:
		_done("")
		return
	var version := str(release.get("tag_name", "")).trim_prefix("v")
	if not GameVersion.is_newer(version, GameVersion.VERSION):
		_done("Up to date")
		return
	if _failed_before(version):
		_done("Update %s didn't start on this PC - still on %s" % [GameVersion.label(version), GameVersion.label()])
		return
	var pack_url := ""
	var hash_url := ""
	for asset in release.get("assets", []):
		var name := str(asset.get("name", ""))
		if name == UPDATE_PREFIX + version + ".pck":
			pack_url = str(asset.get("browser_download_url", ""))
		elif name == UPDATE_PREFIX + version + ".pck.sha256":
			hash_url = str(asset.get("browser_download_url", ""))
	if pack_url == "" or hash_url == "":
		_done("")  # a release without its pack or hash: never install it
		return
	var target := pack_path() + ".new"
	if not _can_write(target):
		_done("%s is out: download it from GitHub (this folder is read-only)" % GameVersion.label(version))
		return
	status_changed.emit("Downloading update %s..." % GameVersion.label(version))
	var hash_text := await _download_text(hash_url)
	if hash_text == "" or not await _download_file(pack_url, target):
		DirAccess.remove_absolute(target)
		_done("Update download failed - playing %s" % GameVersion.label())
		return
	if not _hash_ok(target, hash_text):
		DirAccess.remove_absolute(target)
		_done("Update failed its safety check - playing %s" % GameVersion.label())
		return
	_apply_and_restart(version)


static func _failed_before(version: String) -> bool:
	var f := game_dir().path_join(FAILED_FILE)
	return FileAccess.file_exists(f) and FileAccess.get_file_as_string(f).split("\n", false).has(version)


static func _can_write(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	return true


## The swap script (see the top of this file). Windows paths, quoted for spaces.
static func swap_script(exe: String, pack: String, version: String) -> String:
	exe = exe.replace("/", "\\")
	pack = pack.replace("/", "\\")
	var failed := exe.get_base_dir().path_join(FAILED_FILE).replace("/", "\\")
	var lines := PackedStringArray([
		"@echo off",
		"rem Rich From Rocks update to v%s: swap the game pack, self-test it, roll back if it fails." % version,
		"ping -n 3 127.0.0.1 >nul",
		"if not exist \"%s.new\" goto start" % pack,
		"move /y \"%s\" \"%s.old\" >nul" % [pack, pack],
		"move /y \"%s.new\" \"%s\" >nul" % [pack, pack],
		"\"%s\" --headless --quit-after 6000 -- --selftest --no-update" % exe,
		"if errorlevel %d if not errorlevel %d goto passed" % [SELFTEST_CODE, SELFTEST_CODE + 1],
		"move /y \"%s.old\" \"%s\" >nul" % [pack, pack],
		">>\"%s\" echo %s" % [failed, version],
		"goto start",
		":passed",
		"del \"%s.old\" >nul 2>nul" % pack,
		":start",
		"start \"\" \"%s\"" % exe,
	])
	return "\r\n".join(lines) + "\r\n"


func _apply_and_restart(version: String) -> void:
	DirAccess.make_dir_recursive_absolute(UPDATES_DIR)
	var bat := ProjectSettings.globalize_path(UPDATES_DIR.path_join("apply_update.bat"))
	var f := FileAccess.open(bat, FileAccess.WRITE)
	if f == null:
		DirAccess.remove_absolute(pack_path() + ".new")
		_done("")
		return
	f.store_string(swap_script(OS.get_executable_path(), pack_path(), version))
	f.close()
	status_changed.emit("Installing %s..." % GameVersion.label(version))
	Game.save()
	OS.create_process("cmd.exe", ["/c", bat.replace("/", "\\")])
	get_tree().quit()


func _download_text(url: String) -> String:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	if http.request(url, ["User-Agent: RichFromRocks"]) != OK:
		http.queue_free()
		return ""
	var r: Array = await http.request_completed
	http.queue_free()
	return (r[3] as PackedByteArray).get_string_from_utf8() if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200 else ""


func _download_file(url: String, path: String) -> bool:
	var http := HTTPRequest.new()
	http.download_file = path
	add_child(http)
	if http.request(url, ["User-Agent: RichFromRocks"]) != OK:
		http.queue_free()
		return false
	var r: Array = await http.request_completed
	http.queue_free()
	return r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200


## The file's SHA-256 matches the first word of `hash_text` (the .sha256 file's format).
static func _hash_ok(path: String, hash_text: String) -> bool:
	var want := hash_text.strip_edges().split(" ", false)
	return not want.is_empty() and FileAccess.file_exists(path) \
		and FileAccess.get_sha256(path).to_lower() == want[0].to_lower()


func _done(text: String) -> void:
	status_changed.emit(text)
	queue_free()
