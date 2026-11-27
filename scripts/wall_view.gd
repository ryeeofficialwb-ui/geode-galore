class_name WallView
extends Control
## The mining wall (left screen). Fills itself with the wall tile and asks for one ACTION at a time:
##   tap    - circles pop up with a ring closing in on each; tap each one as its ring closes
##   zigzag - crack a zigzag into the wall from the glowing dot, passing every corner
##   slash  - one big, fast swipe along a long line
##   drill  - spam-click the same spot
##   pry    - hold on the wedge, let go while the gauge is in the gold zone
##   track  - keep clicking a circle that drifts around the wall (a moving drill)
##   swirl  - trace a spiral from the glowing dot on the outside into the middle
##   bigslash - one huge, very fast swipe right across the wall
##   spin   - hold the button and spin your cursor round the circle, fast (like an osu! spinner)
## The further you get (stage + the cave's head start) the more actions a wall takes and the more move
## styles show up (Config.ACTION_UNLOCK).
## It's dark: your LIGHTER follows the mouse and lights the wall around it. Its flame is the timer
## (it shrinks as you work; each finished action refuels it). Finish in time to keep the combo; the
## combo multiplies coins. Lose the combo and the lighter goes out: hit SPACE the shown number of times
## within RELIGHT_TIME or you lose a life (see STAGES in Config).
## After a random number of actions the wall crumbles and a new one drops in.
## Everything you do leaves pixel-art cracks on the wall's own pixel grid.
## All numbers are in Config (MINING WALL).

signal action_done(perfect: bool, at: Vector2, combo: int, multiplier: float)
signal missed(reason: String, at: Vector2)
signal failed(reason: String, lost_combo: int, at: Vector2)   # timer ran out / every circle missed
signal wall_down(at: Vector2)
signal practiced(kind: String)  # an action was finished in practice mode (tutorial)
signal lighter_out(at: Vector2)
signal relit(at: Vector2)
signal life_lost(stage_down: bool, at: Vector2)
signal flooded(stage_down: bool, at: Vector2)
signal countdown_tick   # 3, 2, 1 after the beat practice (main shakes the screen)
signal full_light   # the flame just reached full blaze (main flashes the screen)   # flicked a full lighter: half a life gone
signal stage_up(stage: int, at: Vector2)
signal action_started(kind: String)  # a new action is on the wall (the tips use it)
signal dynamite_blown(at: Vector2)    # Dynamite blew the wall down
signal item_popped(text: String, at: Vector2)  # a run item did something here (main shows the text)

const SAMPLES := 48
const STEP := 6.0               # px between checks while tracing (fast mouse moves are filled in)
const DENSIFY := 12.0           # px between path points on zigzags
const FLAME_ANCHOR := Vector2(64.5, 30)  # bottom-centre of the flame on the lighter art
const WHEEL := Vector2(71, 33)           # flint wheel on the lighter art (sparks come from here)
const MAX_MARKS := 90           # oldest cracks fade out after this many (the wall's damage adds lots)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const KIND_INFO := {            # title, hint
	"tap": ["TAP!", "Tap each circle when its ring closes in"],
	"zigzag": ["ZIGZAG!", "Crack it from the glowing dot, hit every corner"],
	"slash": ["SLASH!", "One fast swipe from the glowing dot"],
	"drill": ["DRILL!", "Spam-click the same spot"],
	"pry": ["PRY!", "Hold on the wedge, let go in the gold zone"],
	"track": ["TRACK!", "Keep clicking the moving circle"],
	"swirl": ["SWIRL!", "Trace the spiral from the glowing dot into the middle"],
	"bigslash": ["SLASH IT ALL!", "One huge, fast swipe right across the wall"],
	"spin": ["SPIN!", "Hold the button and spin round and round, fast!"],
}

var tile_tex: Texture2D
var font: Font                  # set by main (falls back to the theme font)
var title_font: Font
var active := false             # set by main: the timer only runs while you're looking at the wall
var practice := ""              # tutorial / Practice: only this action, no timer, the wall never crumbles
var free_practice := false      # the Practice button (not the tutorial): no lighter to look after, no coins
var _saved := {}                # the mine as it was before Practice (restored after)
var reserve_bottom := 0.0       # tutorial: keep actions above its panel
var actions_total := 0
var actions_left := 0
var combo := 0
var kind := ""                  # current action ("" = between actions)
var rise := 1.0                 # new-wall drop-in animation 0..1 (tweened)
var resting := false            # the break after a wall (or a stage) is done: everything waits for you
var rest_ui_external := false   # main draws the break's panel (items, Midas cash-out) instead of us
var rest_hold := false          # main: something must be picked first (SPACE / clicks don't end the break)
var wick_extra := 0.0           # Extra Wick: the second wick, burns first (the light holds while it does)
var _burn_pending := false      # Little Light: you messed up a move - it burns your hand next frame (run over)
var _dark_step := -1            # Mandrake: the light's last visible step (it screams when it drops)
var _drop_t := 0.0              # the lighter's on the floor: seconds left to pick it up
var _drop_pos := Vector2.ZERO   # ... and where it lies
var _dropped_run := false       # it was knocked out of your hand: not relighting in time ends the run
var _gems: Array[Dictionary] = []  # Gilded Umbrella: gems falling from the roof
var _gem_t := 6.0               # seconds until the next one falls
var _torch_frames: Array[Texture2D] = []  # the Torch artifact's art (assets/torch/)
var _rest_cleared := false      # ... and that wall cleared the stage

# lighter
var light_state := "off"        # "off" = closed (press SPACE to start), "lit", "out" (relight it in time!)
var start_need := 0            # flicks needed to get the flame to catch when lighting it up
var start_hits := 0
var wick := 1.0                 # the most light you can get back by flicking. Burns down while an action
								# waits on you; only FINISHING actions restores it (misses burn some off).
var light := 1.0                # how bright the flame is, 1 = full. Fades over time; flick SPACE to bring it back.
var relight_need := 0
var relight_hits := 0
var relight_left := 0.0
var dev_mouse := Vector2(-1, -1)  # screenshot demo: fake mouse position
var _lighter_frames: Array[Texture2D] = []
var _flame_frames: Array[Texture2D] = []
var _hold := 0.0                 # seconds the flame stays at full blaze before it starts dying again
var _lid := 0.0                 # 0 closed .. 1 open (animates)
var _lid_target := 0.0
var _glow := 0.0                # light on/off (animates)
var _spark := 0.0
var _mouse := Vector2.ZERO
var _shake_l := 0.0             # lighter jolts on a misfire
var _shake_off := Vector2.ZERO  # this frame's shake (jolts + trembling when you're about to lose)
# relight timing game: a marker sweeps the track; hit SPACE while it's in the gold zone
var _fm := 0.0                  # the FLICK charge bar: 0..1, fills at this minigame's tempo; flick in the gold zone
var _fm_ok := 0.0               # flashes: a good flick / a mistimed one
var _fm_bad := 0.0
var _beat_used := false         # already flicked well on this heartbeat: another flick is "too soon"
var _beat_kick := 0.0           # the FLICK bar's jolt on each heartbeat (decays)
var bpm := 0.0                  # your heart rate: the FLICK bar fills once per beat. Only changes when a wall breaks
var _wall_moves := 0            # how you played this wall (sets the next wall's heart rate)
var _wall_perfects := 0
var _wall_fails := 0
var _beat_t := 0.0              # > 0: zoomed in on the FLICK bar after a wall, practising the new beat (the last
								#      BEAT_COUNTDOWN seconds count down 3, 2, 1 with a flash each)
var _beat_flicking := true      # false: Torch / Cat's Eyes - no bar to practise, just the countdown
var _count_flash := 0.0         # the screen flash on each number of the countdown
var _zoom := 0.0                # 0..1: how far the view is zoomed in on the FLICK bar
var _beat_hits := 0             # practice flicks on the beat / all practice flicks
var _beat_tries := 0
var perfect_streak := 0         # PERFECT moves in a row; DEEP_FOCUS_PERFECTS of them = Deep Focus (blue flame)
var _flame_frames_blue: Array[Texture2D] = []
var _hype_t := 0.0              # > 0: a new stage just started - the flame flares blue and huge (seconds left)
var _hype_pending := false      # the stage was cleared: flare up when the next stage's first wall starts
var _meter := 0.0
var _meter_dir := 1.0
var _meter_speed := 1.0
var _zone_c := 0.5
var _zone_w := 0.2
var _meter_hit := 0.0
var _meter_miss := 0.0
# layers: this node draws the wall + actions, then the darkness, then _top (sparks, lighter, HUD)
var _ci: CanvasItem = self      # the layer the draw helpers draw on right now
var _dark: ColorRect
var _top: Control

var _last_kind := ""
var _title := ""
var _tile_img: Image
var _tile_file := ""            # the wall tile in use (each cave has its own, Config.CAVES)
# zigzag / slash
var _path := PackedVector2Array()
var _cum := PackedFloat32Array()
var _total := 0.0
var _tracing := false
var _last_p := Vector2.ZERO
var _max_dev := 0.0
var _progress := 0.0
var _swipe_t := 0.0
var _corners := PackedVector2Array()     # zigzag corners you must pass (no shortcuts)
var _corner_s := PackedFloat32Array()    # how far along the line each corner is
var _next_corner := 0
var _crack_cells := PackedVector2Array() # the crack this line will leave, in wall pixels, ordered along the line
var _crack_s := PackedFloat32Array()
var _sound_s := 0.0
# tap
var _targets: Array[Dictionary] = []     # {p, spawn, hit_t, state (0 waiting, 1 hit, 2 missed), perfect}
var _tap_clock := 0.0
var _pops: Array[Dictionary] = []        # little "Perfect" / "Good" texts over circles
# drill / pry
var _spot := Vector2.ZERO
var _clicks_need := 0
var _clicks := 0
var _holding := false
var _fill := 0.0
var _zone := Vector2.ZERO               # gold zone (from, to) on the 0..1 gauge
var _pry_t := 0.0                       # pry: time held, 0..1 of this pry's fill time (_fill follows its style)
var _pry_a0 := -PI * 0.5                # pry: where the gauge starts on the ring
var _pry_dir := 1.0                     # pry: 1 = fills clockwise, -1 = anticlockwise
var _pry_time := 1.4                    # pry: seconds to fill (snaps at full)
var _pry_style := "steady"              # pry: how the gauge moves (Config.PRY_STYLES)
var _strays := 0                        # misses during the action: no PERFECT
# spin
var _spin_c := Vector2.ZERO
var _spin_need := 3.0                   # turns needed
var _spin_net := 0.0                    # radians turned (signed: wiggling back and forth cancels out)
var _spin_last := 0.0
var _spin_have := false                 # _spin_last is valid
var _spinning := false                  # button held
var _spin_started := false              # the timer starts at your first press
var _spin_t := 0.0
var _spin_sound := 0
# track (the moving drill)
var _track_rect := Rect2()
var _track_f := Vector2.ONE
var _track_ph := Vector2.ZERO
var _track_time := 0.0
var _jolt := 0.0
var _wick_flash := 0.0                  # the wick gauge glows when finishing a move refills it
# looks
var _marks: Array[Dictionary] = []     # what earlier actions left on this wall
var _chips: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _chunks: Array[Dictionary] = []      # round chunks of wall falling out (Spin, and the wall breaking up)
var _falling := false
var _miss_flash := 0.0
var _t := 0.0
var _gen := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # falling chunks carry the wall's tile across tile edges
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	_load_tile()
	for i in 32:
		var f := Config.LIGHTER_DIR + "lighter_%d.png" % i
		if not ResourceLoader.exists(f):
			break
		_lighter_frames.append(load(f))
	for i in 64:
		var f := Config.LIGHTER_DIR + "flame_%d.png" % i
		if not ResourceLoader.exists(f):
			break
		_flame_frames.append(load(f))
	for ft in _flame_frames:
		_flame_frames_blue.append(_blue_flame(ft))
	for i in 32:
		var f := "res://assets/torch/torch_%d.png" % i
		if not ResourceLoader.exists(f):
			break
		_torch_frames.append(load(f))
	Game.lighter_knocked.connect(_drop_lighter)
	_dark = ColorRect.new()
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/darkness.gdshader")
	_dark.material = mat
	add_child(_dark)
	_top = Control.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(_draw_top)
	add_child(_top)
	resized.connect(_on_resized)


## The wall changed size (window resized, phone rotated...): the first wall waits for a real size, and an
## action nobody has touched yet is placed again so nothing ends up off screen or in a corner.
func _on_resized() -> void:
	if size.x < 400 or size.y < 300:
		return
	if kind == "" and actions_total == 0:
		new_wall()
	elif kind != "" and not _touched():
		new_action(kind)


func _touched() -> bool:
	if _tracing or _holding or _clicks > 0:
		return true
	for tg in _targets:
		if tg.state != 0:
			return true
	return false


## Loads the wall tile of the cave you're in. Returns true if it changed.
func _load_tile() -> bool:
	var f: String = Game.cave_info().get("tile", Config.WALL_TILE_FILE)
	if not ResourceLoader.exists(f):
		f = Config.WALL_TILE_FILE
	if f == _tile_file and tile_tex != null:
		return false
	_tile_file = f
	tile_tex = load(f) if ResourceLoader.exists(f) else Game.rock_texture("missing")
	_tile_img = tile_tex.get_image()
	return true


## A trip started in another cave: swap in its wall straight away.
func change_cave() -> void:
	if _load_tile() and not _falling and size.x >= 400 and practice == "":
		new_wall()
	queue_redraw()


func _tile_px() -> float:
	return tile_tex.get_width() * Config.WALL_TILE_SCALE


func combo_multiplier() -> float:
	return minf(1.0 + maxi(combo - 1, 0) * Config.COMBO_BONUS_PER_STEP, Config.COMBO_MAX_MULTIPLIER)


## Where actions may appear: away from the edges, the timer at the top and the Back button.
func _area() -> Rect2:
	var m: Vector4 = Config.WALL_MARGINS  # left, top, right, bottom
	var b := float(Config.SAFE_BORDER)
	m = Vector4(maxf(m.x, b), maxf(m.y, b), maxf(m.z, b), maxf(m.w, b))
	return Rect2(Vector2(m.x, m.y), size - Vector2(m.x + m.z, m.y + m.w + reserve_bottom))


## Where the lighter is (wherever it leans). Actions never go here.
func _lighter_box() -> Rect2:
	var sc := float(Config.LIGHTER_SCALE)
	var o := Vector2(Config.LIGHTER_POS.x, size.y - Config.LIGHTER_POS.y) - FLAME_ANCHOR * sc
	return Rect2(o + Vector2(0, 12) * sc, Vector2(84, 68) * sc).grow_individual(
			Config.LIGHTER_SWAY.x, Config.LIGHTER_SWAY.y, Config.LIGHTER_SWAY.x + 16, 0)


## A random point in r that's at least pad px away from the lighter.
func _free_point(r: Rect2, pad: float) -> Vector2:
	var box := _lighter_box().grow(pad)
	var p := _rand_in(r)
	for attempt in 40:
		if not box.has_point(p):
			break
		p = _rand_in(r)
	return p


# ------------------------------------------------------------------ wall + actions
func new_wall() -> void:
	_beat_t = 0.0
	_show_wall()
	_start_wall()


## The next wall drops in (no moves yet).
func _show_wall() -> void:
	_load_tile()
	_falling = false
	resting = false
	_gen += 1
	kind = ""
	_reset_input()
	_pieces.clear()
	_marks.clear()
	_chunks.clear()
	_gems.clear()
	if light_state == "dropped":  # (a new wall after the run ended with the lighter on the floor)
		light_state = "off"
	rise = 0.0
	create_tween().tween_property(self, "rise", 1.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## The wall's moves start.
func _start_wall() -> void:
	_wall_moves = 0
	_wall_perfects = 0
	_wall_fails = 0
	var extra := mini(floori((Game.skill_stage() - 1) * Config.WALL_ACTIONS_PER_STAGE), Config.WALL_ACTIONS_EXTRA_MAX)
	actions_total = randi_range(Config.WALL_ACTIONS_MIN, Config.WALL_ACTIONS_MAX) + maxi(extra, 0)
	if _run_on() and Game.half_walls():  # Dice of Dwarves 3-4: half the moves this stage
		actions_total = maxi(1, ceili(actions_total / 2.0))
	actions_left = actions_total
	if _hype_pending:
		_hype_pending = false
		_hype_t = Config.STAGE_HYPE_TIME  # the new stage begins: the flame flares up
	new_action()


## Tutorial: keep asking for this one action (no timer). "relight" = practise relighting.
## "" = back to normal.
func set_practice(k: String) -> void:
	practice = k
	if (resting or in_beat_practice()) and k != "":
		new_wall()  # the tutorial's tour wants to show something: skip the break
	if _falling:
		return
	ensure_lit()
	if k == "relight":
		_go_out()
		return
	if k == "flick":  # just keep the light alive, no actions
		_gen += 1
		kind = ""
		_reset_input()
		return
	new_action(k)


## The Practice button: play one activity over and over with no lighter to look after and no coins.
## Whatever the mine was doing (your trip's wall, combo, light, a break...) is put aside and comes back
## exactly as it was when you stop (end_free_practice).
func begin_free_practice(k: String) -> void:
	if not free_practice:
		_saved = {
			"combo": combo, "light": light, "wick": wick, "light_state": light_state, "hold": _hold,
			"lid": _lid_target, "start_hits": start_hits, "actions_left": actions_left,
			"marks": _marks.duplicate(), "rest": resting or _falling or in_beat_practice(), "rest_cleared": _rest_cleared,
			"relight": [relight_need, relight_hits, relight_left, _meter, _meter_dir, _meter_speed, _zone_c, _zone_w],
		}
	free_practice = true
	_falling = false
	resting = false
	_beat_t = 0.0
	_pieces.clear()
	rise = 1.0
	combo = 0
	wick = 1.0
	set_practice(k)


func end_free_practice() -> void:
	if not free_practice:
		return
	free_practice = false
	practice = ""
	_gen += 1  # cancels a pending next practice action
	kind = ""
	_reset_input()
	combo = _saved.combo
	light = _saved.light
	wick = _saved.wick
	_hold = _saved.hold
	start_hits = _saved.start_hits
	actions_left = _saved.actions_left
	_marks.assign(_saved.marks)
	light_state = _saved.light_state
	_lid_target = _saved.lid
	_lid = _lid_target
	_glow = 1.0 if light_state == "lit" else 0.0
	var rl: Array = _saved.relight
	relight_need = rl[0]
	relight_hits = rl[1]
	relight_left = rl[2]
	_meter = rl[3]
	_meter_dir = rl[4]
	_meter_speed = rl[5]
	_zone_c = rl[6]
	_zone_w = rl[7]
	if _saved.rest:  # you were on a break (or the wall was just coming down): back to the break
		_falling = true
		resting = true
		_rest_cleared = _saved.rest_cleared
	elif light_state == "lit":
		new_action()
	queue_redraw()


## The run ended (cashed out, or over): a fresh wall with a closed lighter for the next run.
func reset_run() -> void:
	_gen += 1
	resting = false
	_beat_t = 0.0
	_hype_t = 0.0
	_hype_pending = false
	perfect_streak = 0
	_wall_moves = 0
	_wall_perfects = 0
	_wall_fails = 0
	bpm = 0.0  # a new run starts from a calm heart (set by the first wall)
	_falling = false
	light_state = "off"
	_lid_target = 0.0
	_lid = 0.0
	_glow = 0.0
	start_hits = 0
	combo = 0
	wick = 1.0
	wick_extra = 0.0
	light = 1.0
	_dropped_run = false
	_burn_pending = false
	if size.x >= 400:
		new_wall()


## Light the lighter right away (no animation, no SPACE needed).
func ensure_lit() -> void:
	light_state = "lit"
	_full_blaze(false)
	_lid = 1.0
	_lid_target = 1.0
	_glow = 1.0


func new_action(force := "") -> void:
	_gen += 1
	_reset_input()
	if force == "" and practice in ["flick", "relight"]:
		kind = ""
		return
	kind = force if force != "" else (practice if practice != "" else _pick_kind())
	_last_kind = kind
	_title = KIND_INFO.get(kind, ["?", ""])[0]
	var area := _area()
	match kind:
		"tap":
			_setup_tap(area)
		"zigzag":
			_set_path(_zigzag_points(area))
			_build_crack(Config.ZIGZAG_CRACK_WIDTH)
		"slash":
			_set_path(_slash_points(area))
			_build_crack(Config.SLASH_CRACK_WIDTH)
		"drill":
			_spot = _free_point(area.grow(-60), Config.DRILL_RADIUS)
			_clicks_need = randi_range(Config.DRILL_CLICKS_MIN, Config.DRILL_CLICKS_MAX)
		"pry":
			_spot = _free_point(area.grow(-60), Config.PRY_RADIUS)
			_setup_pry()
		"swirl":
			_set_path(_swirl_points(area))
			_build_crack(Config.SWIRL_CRACK_WIDTH)
		"bigslash":
			_set_path(_bigslash_points(area))
			_build_crack(Config.SLASH_CRACK_WIDTH + 1)
		"spin":
			_spin_c = _free_point(_inner(area, Config.SPIN_RADIUS + 20.0), Config.SPIN_RADIUS + 20.0)
			_spin_need = roundf(randf_range(Config.SPIN_TURNS_MIN, Config.SPIN_TURNS_MAX) * 2.0) / 2.0
			_spot = _spin_c
		"track":
			_setup_track(area)
	if kind != "":
		action_started.emit(kind)
		_fireflies()
	queue_redraw()


## Fireflies: 1 in 7 moves (each Fireflies rolls) they finish it for you, a moment after it shows up.
func _fireflies() -> void:
	if not _run_on() or not Game.has_item("fireflies"):
		return
	var lucky := false
	for k in Game.item_count("fireflies"):
		lucky = lucky or randf() * 100.0 < Config.FIREFLIES_CHANCE
	if not lucky:
		return
	var g := _gen
	var k0 := kind
	get_tree().create_timer(0.45).timeout.connect(func():
		if g == _gen and kind == k0 and kind != "" and light_state == "lit" and not _falling and not resting and _run_on():
			var at := _action_center()
			for i in 3:
				_spray(at + Vector2(randf_range(-40, 40), randf_range(-30, 30)), 4)
			item_popped.emit("FIREFLIES!  They did that one for you", at + Vector2(0, -60))
			_complete(true, at))


## Every pry is different: the gold zone sits anywhere on the gauge, the gauge starts anywhere round the
## ring and goes either way, at its own speed and in its own style (steady, speeding up, slowing down,
## stuttering).
func _setup_pry() -> void:
	var z := randf_range(Config.PRY_ZONE_MIN, Config.PRY_ZONE_MAX)
	_zone = Vector2(z, minf(z + randf_range(Config.PRY_ZONE_SIZE_MIN, Config.PRY_ZONE_SIZE_MAX), 0.97))
	_pry_a0 = randf() * TAU if Config.PRY_RANDOM_START else -PI * 0.5
	_pry_dir = -1.0 if randf() < Config.PRY_REVERSE_CHANCE else 1.0
	_pry_time = Config.PRY_FILL_TIME * randf_range(Config.PRY_SPEED_MIN, Config.PRY_SPEED_MAX) * _ease()
	_pry_style = "steady"
	var total := 0.0
	for k in Config.PRY_STYLES:
		total += maxf(float(Config.PRY_STYLES[k]), 0.0)
	var r := randf() * total
	for k in Config.PRY_STYLES:
		r -= maxf(float(Config.PRY_STYLES[k]), 0.0)
		if r <= 0.0 and float(Config.PRY_STYLES[k]) > 0.0:
			_pry_style = k
			break


## Where the gauge is (0..1) after holding for t (0..1 of the fill time), in this pry's style.
func _pry_shape(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	match _pry_style:
		"speedup":
			return t * t
		"slowdown":
			return 1.0 - (1.0 - t) * (1.0 - t)
		"stutter":  # four quick bursts with a short stop after each
			var seg := minf(floorf(t * 4.0), 3.0)
			var f := clampf((t * 4.0 - seg) / 0.6, 0.0, 1.0)
			return (seg + f * f * (3.0 - 2.0 * f)) / 4.0
	return t


## The angle on the ring for a point f (0..1) of the gauge.
func _pry_angle(f: float) -> float:
	return _pry_a0 + _pry_dir * TAU * f


func _pick_kind() -> String:
	var pool := {}
	var skill := Game.skill_stage()
	# Diamond Pick / Familiar Circle: only their moves (unlocked or not); both = only the moves they share
	var only: Array = []
	if _run_on() and Game.has_item("diamond_pick"):
		only = Config.DIAMOND_PICK_MOVES.duplicate()
	if _run_on() and Game.has_item("familiar_circle"):
		only = Config.FAMILIAR_MOVES.duplicate() if only.is_empty() else only.filter(func(k): return k in Config.FAMILIAR_MOVES)
		if only.is_empty():
			only = Config.FAMILIAR_MOVES.duplicate()
	for k in Config.ACTION_WEIGHTS:
		if not KIND_INFO.has(k) or float(Config.ACTION_WEIGHTS[k]) <= 0.0:
			continue
		if (only.is_empty() and skill >= int(Config.ACTION_UNLOCK.get(k, 1))) or k in only:
			pool[k] = float(Config.ACTION_WEIGHTS[k])
	if pool.is_empty():
		return "tap"
	if Config.NO_REPEAT_ACTION and pool.size() > 1:
		pool.erase(_last_kind)
	var total := 0.0
	for k in pool:
		total += pool[k]
	var r := randf() * total
	for k in pool:
		r -= pool[k]
		if r <= 0.0:
			return k
	return pool.keys().back()


func _reset_input() -> void:
	_tracing = false
	_holding = false
	_path = PackedVector2Array()
	_corners = PackedVector2Array()
	_corner_s = PackedFloat32Array()
	_crack_cells = PackedVector2Array()
	_crack_s = PackedFloat32Array()
	_next_corner = 0
	_targets.clear()
	_clicks = 0
	_fill = 0.0
	_pry_t = 0.0
	_strays = 0
	_max_dev = 0.0
	_progress = 0.0
	_sound_s = 0.0
	_spin_reset()
	_track_time = 0.0


func _spin_reset() -> void:
	_spinning = false
	_spin_have = false
	_spin_started = false
	_spin_net = 0.0
	_spin_t = 0.0
	_spin_sound = 0


## r shrunk by m on every side (or a tiny box in its middle if that leaves nothing).
func _inner(r: Rect2, m: float) -> Rect2:
	var g := r.grow(-m)
	return g if g.size.x > 1.0 and g.size.y > 1.0 else Rect2(r.get_center(), Vector2.ONE)


func _rand_in(r: Rect2) -> Vector2:
	return r.position + Vector2(randf(), randf()) * r.size


## Circles close one after another, but each ring has its own speed, so the order they APPEAR in
## is not the order they CLOSE in. Hit times are spaced out; spawn = hit time - ring speed.
func _setup_tap(area: Rect2) -> void:
	var n := randi_range(Config.TAP_COUNT_MIN, Config.TAP_COUNT_MAX)
	var inner := area.grow(-Config.TAP_RADIUS)
	var speed := Game.stage_fuel_factor()  # rings close faster on higher stages
	var hit_t := 0.0
	var earliest := INF
	var prev_spawn := -INF
	for i in n:
		var p := _free_point(inner, Config.TAP_RADIUS)
		for attempt in 60:  # keep circles apart, off the lighter, and their order lines apart
			if _tap_spot_ok(p):
				break
			p = _free_point(inner, Config.TAP_RADIUS)
		if i > 0:
			hit_t += randf_range(Config.TAP_GAP_MIN, Config.TAP_GAP_MAX) * speed
		var spawn := hit_t - randf_range(Config.TAP_APPROACH_MIN, Config.TAP_APPROACH_MAX) * speed
		# the circle that shows up first is always the one to tap first: each appears after the one before
		if spawn < prev_spawn + Config.TAP_SPAWN_GAP:
			spawn = prev_spawn + Config.TAP_SPAWN_GAP
			hit_t = maxf(hit_t, spawn + Config.TAP_APPROACH_MIN * speed)  # and still gets time to close
		prev_spawn = spawn
		earliest = minf(earliest, spawn)
		_targets.append({"p": p, "spawn": spawn, "hit_t": hit_t, "state": 0, "perfect": false, "order": i})
	var shift := 0.35 - earliest  # first circle appears a moment after the action starts
	for tg in _targets:
		tg.spawn += shift
		tg.hit_t += shift
	_tap_clock = 0.0


## Can the next tap circle go at p? Away from the lighter and the other circles, and the line from the
## circle before it must not run over another circle, cross an earlier line or fold back on itself.
func _tap_spot_ok(p: Vector2) -> bool:
	var rad := Config.TAP_RADIUS
	if _lighter_box().grow(rad).has_point(p) or flick_bar_rect().grow(rad + 40.0).has_point(p):
		return false
	for tg in _targets:
		if p.distance_to(tg.p) < rad * Config.TAP_SPACING:
			return false
	var i := _targets.size()
	if i == 0:
		return true
	var prev: Vector2 = _targets[i - 1].p
	for j in i - 1:  # the new line passes well clear of the other circles
		var q: Vector2 = _targets[j].p
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, prev, p)) < rad * 1.7:
			return false
	for j in i - 2:  # ... and never crosses an earlier line
		if Geometry2D.segment_intersects_segment(_targets[j].p, _targets[j + 1].p, prev, p) != null:
			return false
	if i >= 2:  # ... and doesn't double back over the line before it
		var pp: Vector2 = _targets[i - 2].p
		if (prev - pp).normalized().dot((p - prev).normalized()) < -0.55:
			return false
	return true


## How many turns a zigzag can have: ZIGZAG_CORNERS_MIN..MAX on the easy stages, the most going up
## with the stage until ZIGZAG_CORNERS_CAP.
func zigzag_corner_range() -> Vector2i:
	var st := maxi(Game.skill_stage() - 1, 0) if practice == "" else 0
	var hi := mini(Config.ZIGZAG_CORNERS_MAX + floori(st * Config.ZIGZAG_CORNERS_PER_STAGE), Config.ZIGZAG_CORNERS_CAP)
	return Vector2i(Config.ZIGZAG_CORNERS_MIN, maxi(hi, Config.ZIGZAG_CORNERS_MIN))


## Zigzags come in lots of shapes: few or many turns, short or long, narrow or wide, on a straight line
## or bent into an arch, with sharp or rounded turns.
func _zigzag_points(area: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := zigzag_corner_range()
	for attempt in 60:
		# later tries also take fewer turns, so a small wall gets a clean zigzag instead of a squashed one
		var corners := randi_range(cr.x, maxi(cr.x, cr.y - attempt / 6))
		if attempt >= 40:
			corners = maxi(2, cr.x - (attempt - 40) / 6)
		var shrink := lerpf(1.0, 0.55, attempt / 59.0)  # later tries get smaller so one always fits
		var lo := maxf(Config.ZIGZAG_LENGTH_MIN, corners * Config.ZIGZAG_STEP_MIN)  # each turn needs room
		var length := minf(randf_range(lo, maxf(lo, Config.ZIGZAG_LENGTH_MAX)) * shrink, area.size.length() * 0.8)
		var width := Config.ZIGZAG_WIDTH * randf_range(Config.ZIGZAG_WIDTH_VARY.x, Config.ZIGZAG_WIDTH_VARY.y) * lerpf(1.0, 0.75, attempt / 59.0)
		width = minf(width, length / (corners + 1) * 1.3)  # a short zigzag with lots of turns stays a zigzag, not a scribble
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var flip := 1.0 if randf() < 0.5 else -1.0
		var start := _rand_in(area) - dir * length * 0.5
		var bend := 0.0  # an arched zigzag: its middle line curves
		if randf() * 100.0 < Config.ZIGZAG_CURVE_CHANCE:
			bend = length * randf_range(0.12, 0.3) * (1.0 if randf() < 0.5 else -1.0)
		var corner_pts := PackedVector2Array()
		for i in corners + 2:
			var t := float(i) / (corners + 1)
			var spine := start + dir * length * t + dir.orthogonal() * bend * 4.0 * t * (1.0 - t)
			var tangent := (dir * length + dir.orthogonal() * bend * 4.0 * (1.0 - 2.0 * t)).normalized()
			var amp := width * randf_range(0.75, 1.0) * (1.0 if i % 2 == 0 else -1.0)
			if i == 0 or i == corners + 1:
				amp *= 0.4
			corner_pts.append((spine + tangent.orthogonal() * flip * amp).clamp(area.position, area.end))  # never off the wall
		if attempt < 59 and not _zigzag_clean(corner_pts):
			continue  # it folds over itself or squashes against an edge: roll a new one
		var checks := PackedVector2Array()
		if randf() * 100.0 < Config.ZIGZAG_ROUND_CHANCE:
			var r: Array = _round_corners(corner_pts)  # smooth, wavy turns
			pts = r[0]
			checks = r[1]
		else:
			pts = _densify(corner_pts)
			for i in range(1, corner_pts.size() - 1):  # the inner corners (not start / end)
				checks.append(corner_pts[i])
		_set_checkpoints(pts, checks)
		if _all_inside(pts, area):
			break
	return pts


## True if a zigzag's legs never stack on top of each other: legs that aren't next to each other stay
## ZIGZAG_MIN_GAP apart (an arch bent too hard, or turns squashed against the wall's edge, would cross
## or pile up), and each turn is open enough that its two legs don't lie on top of each other.
func _zigzag_clean(c: PackedVector2Array) -> bool:
	var gap := Config.ZIGZAG_MIN_GAP
	var min_dot := cos(deg_to_rad(Config.ZIGZAG_MIN_ANGLE))
	for i in c.size() - 1:
		if c[i].distance_to(c[i + 1]) < gap:
			return false
		if i >= 1:  # the turn at c[i]: angle between the leg back and the leg forward
			if (c[i - 1] - c[i]).normalized().dot((c[i + 1] - c[i]).normalized()) > min_dot:
				return false
		for j in range(i + 2, c.size() - 1):
			if _seg_dist(c[i], c[i + 1], c[j], c[j + 1]) < gap:
				return false
	return true


## Shortest distance between segments a-b and c-d (0 if they cross).
func _seg_dist(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	return minf(minf(Geometry2D.get_closest_point_to_segment(a, c, d).distance_to(a),
			Geometry2D.get_closest_point_to_segment(b, c, d).distance_to(b)),
			minf(Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c),
			Geometry2D.get_closest_point_to_segment(d, a, b).distance_to(d)))


## A zigzag with rounded turns: straight bits joined by smooth curves. Returns [path, checkpoints]
## (each checkpoint is the tip of a curve, right on the path).
func _round_corners(c: PackedVector2Array) -> Array:
	var out := PackedVector2Array([c[0]])
	var checks := PackedVector2Array()
	for i in range(1, c.size() - 1):
		var a := c[i].lerp(c[i - 1], 0.4)
		var b := c[i].lerp(c[i + 1], 0.4)
		out.append_array(_line_pts(out[out.size() - 1], a))
		for k in range(1, 11):
			var t := k / 10.0
			out.append(a.lerp(c[i], t).lerp(c[i].lerp(b, t), t))
		checks.append(a * 0.25 + c[i] * 0.5 + b * 0.25)
	out.append_array(_line_pts(out[out.size() - 1], c[c.size() - 1]))
	return [out, checks]


## Points along a straight line from a (not included) to b.
func _line_pts(a: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var steps := maxi(1, ceili(a.distance_to(b) / DENSIFY))
	for k in steps:
		out.append(a.lerp(b, float(k + 1) / steps))
	return out


## The turns you must pass: each checkpoint snapped to the path, with how far along the path it is.
func _set_checkpoints(pts: PackedVector2Array, checks: PackedVector2Array) -> void:
	_corners = PackedVector2Array()
	_corner_s = PackedFloat32Array()
	var s := 0.0
	var j := 0
	for i in pts.size():
		if i > 0:
			s += pts[i - 1].distance_to(pts[i])
		while j < checks.size() and pts[i].distance_to(checks[j]) <= DENSIFY * 0.75:
			_corners.append(pts[i])
			_corner_s.append(s)
			j += 1
	while j < checks.size():  # (never happens: every checkpoint is on the path)
		_corners.append(checks[j])
		_corner_s.append(s)
		j += 1


func _slash_points(area: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for attempt in 60:
		# later tries get shorter, so a small wall (the tutorial's panel, a short window) still fits one
		var shrink := lerpf(1.0, 0.45, attempt / 59.0)
		var length := randf_range(Config.SLASH_LENGTH_MIN, minf(Config.SLASH_LENGTH_MAX, area.size.length() * 0.85)) * shrink
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var center := _rand_in(area)
		var a := center - dir * length * 0.5
		var b := center + dir * length * 0.5
		var bend := Vector2.ZERO
		if randf() * 100.0 < Config.SLASH_CURVE_CHANCE:
			bend = dir.orthogonal() * length * Config.SLASH_CURVE_AMOUNT * (1.0 if randf() < 0.5 else -1.0)
		var ctrl := center + bend
		pts = PackedVector2Array()
		for i in SAMPLES + 1:
			var t := float(i) / SAMPLES
			pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))  # quadratic curve (straight if no bend)
		if _all_inside(pts, area):
			return pts
	return _clamp_path(pts, area)


## Last resort: pull every point of a path onto the wall's free area, so no part of it is out of reach.
func _clamp_path(pts: PackedVector2Array, area: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q.clamp(area.position, area.end))
	return out


## A spiral from the outside in. Checkpoints every quarter turn, so you can't cut across the middle.
func _swirl_points(area: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for attempt in 60:
		var turns := randf_range(Config.SWIRL_TURNS_MIN, Config.SWIRL_TURNS_MAX)
		var r0 := randf_range(Config.SWIRL_RADIUS_MIN, Config.SWIRL_RADIUS_MAX)
		var c := _free_point(_inner(area, r0), r0)
		var a0 := randf() * TAU
		var dir := 1.0 if randf() < 0.5 else -1.0
		var n := maxi(24, ceili(turns * 72.0))
		pts = PackedVector2Array()
		for i in n + 1:
			var u := float(i) / n
			pts.append(c + Vector2.RIGHT.rotated(a0 + dir * TAU * turns * u) * lerpf(r0, Config.SWIRL_INNER_RADIUS, u))
		_corners = PackedVector2Array()
		_corner_s = PackedFloat32Array()
		var every := maxi(1, roundi(float(n) / maxf(turns * 4.0, 1.0)))
		var s := 0.0
		for i in range(1, pts.size()):
			s += pts[i - 1].distance_to(pts[i])
			if i % every == 0 and i < pts.size() - 1:
				_corners.append(pts[i])
				_corner_s.append(s)
		if _all_inside(pts, area):
			break
	return pts


## Edge to edge across the whole wall (its left end stays above the lighter), maybe a little bent.
func _bigslash_points(area: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a_in := _inner(area, 4.0)
	var box := _lighter_box().grow(30)
	for attempt in 60:
		var y_hi := maxf(a_in.position.y, minf(a_in.end.y, box.position.y))
		var a := Vector2(a_in.position.x, randf_range(a_in.position.y, y_hi))
		var b := Vector2(a_in.end.x, randf_range(a_in.position.y, a_in.end.y))
		var bend := (b - a).orthogonal().normalized() * randf_range(-1.0, 1.0) * a_in.size.y * Config.BIGSLASH_CURVE
		var ctrl := a.lerp(b, 0.5) + bend
		pts = PackedVector2Array()
		for i in SAMPLES + 1:
			var t := float(i) / SAMPLES
			pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
		if randf() < 0.5:
			pts.reverse()  # right to left
		if _all_inside(pts, area):
			return pts
	return _clamp_path(pts, area)


## The moving drill drifts around in the bigger free part of the wall: right of the lighter, or above it.
func _setup_track(area: Rect2) -> void:
	var r := Config.TRACK_RADIUS
	var box := _lighter_box().grow(r)
	var right := Rect2(Vector2(maxf(area.position.x, box.end.x), area.position.y), Vector2.ZERO)
	right.end = area.end
	var above := Rect2(area.position, Vector2(area.size.x, minf(area.end.y, box.position.y) - area.position.y))
	var rr := right
	if above.size.x > 0.0 and above.size.y > 0.0 and (right.size.x <= 0.0 or right.size.y <= 0.0 or above.get_area() > right.get_area()):
		rr = above
	if rr.size.x <= 0.0 or rr.size.y <= 0.0:
		rr = area
	_track_rect = _inner(rr, r)
	_track_f = Vector2(randf_range(0.7, 1.0), randf_range(1.1, 1.5))
	if randf() < 0.5:
		_track_f = Vector2(_track_f.y, _track_f.x)
	_track_ph = Vector2(randf() * TAU, randf() * TAU)
	_track_time = 0.0
	_clicks_need = randi_range(Config.TRACK_CLICKS_MIN, Config.TRACK_CLICKS_MAX)
	_spot = _track_pos_at(0.0)


## Where the moving drill is t seconds into the action (a smooth figure-of-eight-ish loop).
func _track_pos_at(t: float) -> Vector2:
	var h := _track_rect.size * 0.5
	var sp := Config.TRACK_SPEED / maxf(Game.stage_fuel_factor(), 0.3) / maxf(h.length(), 1.0)
	return _track_rect.get_center() + Vector2(h.x * sin(_track_f.x * t * sp + _track_ph.x), h.y * sin(_track_f.y * t * sp + _track_ph.y))


## Seconds you get to finish a spin (shorter on later stages / harder caves).
func _spin_time() -> float:
	return Config.SPIN_TIME * lerpf(1.0, Game.stage_fuel_factor(), 0.5) * _ease()


func _densify(corners: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([corners[0]])
	for i in corners.size() - 1:
		var steps := maxi(1, ceili(corners[i].distance_to(corners[i + 1]) / DENSIFY))
		for k in steps:
			out.append(corners[i].lerp(corners[i + 1], float(k + 1) / steps))
	return out


func _all_inside(pts: PackedVector2Array, area: Rect2) -> bool:
	var box := _lighter_box().grow(20)
	var bar := flick_bar_rect().grow(40)
	for p in pts:
		if not area.has_point(p) or box.has_point(p) or bar.has_point(p):
			return false
	return true


func _set_path(pts: PackedVector2Array) -> void:
	_path = pts
	_cum.resize(_path.size())
	_cum[0] = 0.0
	for i in range(1, _path.size()):
		_cum[i] = _cum[i - 1] + _path[i - 1].distance_to(_path[i])
	_total = _cum[_cum.size() - 1]


## Distance from p to the path (only the part between s_lo and s_hi), and how far along it that is.
func _closest(p: Vector2, s_lo := -INF, s_hi := INF) -> Vector2:
	var best_d := INF
	var best_s := 0.0
	for i in _path.size() - 1:
		if _cum[i + 1] < s_lo or _cum[i] > s_hi:
			continue
		var a := _path[i]
		var ab := _path[i + 1] - a
		var seg := ab.length()
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		# stay inside the window, even within one segment
		t = clampf(t, (s_lo - _cum[i]) / maxf(seg, 0.001), (s_hi - _cum[i]) / maxf(seg, 0.001))
		t = clampf(t, 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_s = _cum[i] + seg * t
	return Vector2(best_d, best_s)


func _point_at(s: float) -> Vector2:
	for i in _path.size() - 1:
		if _cum[i + 1] >= s:
			var seg := _cum[i + 1] - _cum[i]
			return _path[i].lerp(_path[i + 1], (s - _cum[i]) / maxf(seg, 0.001))
	return _path[_path.size() - 1]


func can_act() -> bool:
	return kind != "" and not _falling and rise >= 1.0 and light_state == "lit"


## How bright the flame is, 0..1 (this is the timer now: it's shown only by how lit the wall is).
func fuel() -> float:
	return clampf(light, 0.0, 1.0)


func _action_center() -> Vector2:
	match kind:
		"tap":
			var c := Vector2.ZERO
			for tg in _targets:
				c += tg.p
			return c / maxf(_targets.size(), 1)
		"zigzag", "slash", "swirl", "bigslash":
			return _point_at(_total * 0.5) if not _path.is_empty() else size * 0.5
	return _spot


# ------------------------------------------------------------------ pixel cracks
## One wall-art pixel on screen (cracks line up with the wall tile's pixels).
func _g() -> float:
	return float(Config.CRACK_PIXEL if Config.CRACK_PIXEL > 0 else Config.WALL_TILE_SCALE)


func _cell(p: Vector2) -> Vector2i:
	var g := _g()
	return Vector2i(floori(p.x / g), floori(p.y / g))


## Pixel line between two cells (Bresenham), both ends included.
func _line_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := (b - a).abs()
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := d.x - d.y
	var p := a
	while true:
		out.append(p)
		if p == b:
			break
		var e2 := 2 * err
		if e2 > -d.y:
			err -= d.y
			p.x += sx
		if e2 < d.x:
			err += d.x
			p.y += sy
	return out


func _put(cells: Dictionary, c: Vector2i, s: float) -> void:
	if not cells.has(c) or cells[c] > s:
		cells[c] = s


## Thick pixel: grows down for flat-ish lines, right for steep ones (like hand-drawn pixel lines).
func _stamp(cells: Dictionary, c: Vector2i, s: float, width: int, tangent: Vector2) -> void:
	var grow := Vector2i.DOWN if absf(tangent.x) >= absf(tangent.y) else Vector2i.RIGHT
	for k in width:
		_put(cells, c + grow * (k - width / 2), s)


## A small side-crack: random 8-direction walk, like the cracks in the rocks.
func _branch(cells: Dictionary, from: Vector2i, dir: Vector2, s: float) -> void:
	var d := posmod(roundi(dir.angle() / (PI / 4.0)), 8)
	var p := from
	for k in randi_range(Config.CRACK_BRANCH_LENGTH_MIN, Config.CRACK_BRANCH_LENGTH_MAX):
		if randf() < 0.35:
			d = (d + (1 if randf() < 0.5 else 7)) % 8
		p += DIRS[d]
		_put(cells, p, s + k * _g())


## Turns the current line into a jagged pixel crack that wanders a little off it and splits now and then.
## Cells are stored in the order the crack reaches them, so it can grow as you trace.
func _build_crack(width: int) -> void:
	var g := _g()
	var cells := {}
	var wob := 0
	var prev := _cell(_path[0])
	var next_branch := 40.0
	var s := 0.0
	while true:
		var p := _point_at(s)
		var tangent := (_point_at(minf(s + g * 2.0, _total)) - _point_at(maxf(s - g * 2.0, 0.0))).normalized()
		if randf() < 0.3 and s > g * 3.0 and s < _total - g * 3.0:
			wob = clampi(wob + (1 if randf() < 0.5 else -1), -Config.CRACK_JAGGEDNESS, Config.CRACK_JAGGEDNESS)
		var c := _cell(p + tangent.orthogonal() * wob * g)
		for q in _line_cells(prev, c):
			_stamp(cells, q, s, width, tangent)
		prev = c
		if s >= next_branch:
			next_branch += 50.0
			if randf() * 100.0 < Config.CRACK_BRANCH_CHANCE:
				_branch(cells, c, tangent.orthogonal() * (1.0 if randf() < 0.5 else -1.0) + tangent * 0.6, s)
		if s >= _total:
			break
		s = minf(s + g, _total)
	var keys := cells.keys()
	keys.sort_custom(func(a, b): return cells[a] < cells[b])
	for k in keys:
		_crack_cells.append(Vector2(k))
		_crack_s.append(cells[k])


## A star of little cracks (where a circle was tapped / a wedge popped out).
func _burst(at: Vector2, rays: int, center := 1) -> PackedVector2Array:
	var cells := {}
	var c := _cell(at)
	for y in range(-center, center + 1):
		for x in range(-center, center + 1):
			_put(cells, c + Vector2i(x, y), 0.0)
	var a0 := randf() * TAU
	for k in rays:
		_branch(cells, c, Vector2.RIGHT.rotated(a0 + k * TAU / rays + randf_range(-0.3, 0.3)), 0.0)
	var out := PackedVector2Array()
	for k in cells:
		out.append(Vector2(k))
	return out


func _crack_line(a: Vector2, b: Vector2, width: int) -> PackedVector2Array:
	var cells := {}
	var tangent := (b - a).normalized()
	for q in _line_cells(_cell(a), _cell(b)):
		_stamp(cells, q, 0.0, width, tangent)
	for k in 3:
		var from := _cell(a.lerp(b, randf()))
		_branch(cells, from, tangent.orthogonal() * (1.0 if k % 2 == 0 else -1.0) + tangent * randf_range(-0.6, 0.6), 0.0)
	var out := PackedVector2Array()
	for k in cells:
		out.append(Vector2(k))
	return out


# ------------------------------------------------------------------ input
func _gui_input(event: InputEvent) -> void:
	if resting:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not rest_hold:
				end_rest()
			accept_event()
		return
	if light_state == "dropped":  # the only thing that matters: picking your lighter back up
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.position.distance_to(_drop_pos) < 110.0:
				_pick_up_lighter()
			accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and lighter_hit(event.position) and not _torch():  # (the Torch: no lighter to click)
			flick()  # clicking / tapping the lighter = SPACE (that's how phones flick it)
			accept_event()
			return
		if event.pressed:
			press(event.position)
		else:
			release(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _tracing:
		drag(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _spinning:
		_spin_move(event.position)
		accept_event()


func press(p: Vector2) -> void:
	if not can_act():
		return
	match kind:
		"tap":
			_tap(p)
		"zigzag", "slash", "swirl", "bigslash":
			if p.distance_to(_path[0]) > Config.SLICE_START_RADIUS:
				missed.emit("Start at the glowing dot!", p)
				return
			_tracing = true
			_last_p = p
			_max_dev = 0.0
			_progress = 0.0
			_next_corner = 0
			_swipe_t = 0.0
			_sound_s = 0.0
		"drill":
			_drill(p)
		"track":
			_track_click(p)
		"spin":
			_spinning = true
			_spin_started = true
			_spin_have = false
			_spin_move(p)
		"pry":
			if p.distance_to(_spot) > Config.PRY_RADIUS * _ease():
				missed.emit("Hold on the wedge!", p)
				return
			_holding = true
			_fill = 0.0
			_pry_t = 0.0


func release(p: Vector2) -> void:
	if _spinning:
		_spinning = false  # letting go just stops the spin counting (the clock keeps going)
		_spin_have = false
	elif _tracing:
		_miss("Too short!", p)
	elif _holding:
		_holding = false
		if _fill >= _zone.x and _fill <= _zone.y:
			_pry_out(true)
		elif _fill >= _zone.x - Config.PRY_GOOD_MARGIN and _fill <= _zone.y + Config.PRY_GOOD_MARGIN:
			_pry_out(false)
		elif _fill < _zone.x:
			_miss("Too early!", _spot)
		else:
			_miss("Too late!", _spot)


func _tap(p: Vector2) -> void:
	# the circle under the click that closes soonest
	var best := -1
	for i in _targets.size():
		var tg: Dictionary = _targets[i]
		if tg.state != 0 or _tap_clock < tg.spawn or p.distance_to(tg.p) > Config.TAP_RADIUS * _ease():
			continue
		if best < 0 or tg.hit_t < _targets[best].hit_t:
			best = i
	if best < 0:
		return  # empty wall: nothing happens
	var tg: Dictionary = _targets[best]
	var e: float = _tap_clock - tg.hit_t
	if e < -Config.TAP_EARLY_IGNORE:
		_pop(tg.p, "Wait for it!", Config.MUTED_TEXT)
		return
	if e < -Config.TAP_GOOD_WINDOW:
		_tap_miss(tg, "Too early!")
		return
	if e > Config.TAP_GOOD_WINDOW:
		_tap_miss(tg, "Too late!")
		return
	var perfect := absf(e) <= Config.TAP_PERFECT_WINDOW
	tg.state = 1
	tg.perfect = perfect
	_marks.append({"t": "cells", "cells": _burst(tg.p, 5)})
	_spray(tg.p, 9)
	Sfx.play("tap", 1.15 if perfect else 0.95)
	_pop(tg.p, "Perfect" if perfect else "Good", Config.ACCENT if perfect else Config.TEXT_COLOR)
	_check_tap_done()


## A sloppy motion burns some of the wick right away.
func _burn_wick(amount: float) -> void:
	if practice != "" or light_state != "lit":
		return
	if wick_extra > 0.0 and Game.trip_active:  # Extra Wick takes it first
		wick_extra = maxf(wick_extra - amount, 0.0)
		return
	wick = maxf(wick - amount, 0.0)
	light = minf(light, wick)


## What a messed-up move burns off the wick. Cat's Eyes: the cat plays with it, CATS_EYES_MISS_WICK of it each.
func _miss_cost(base: float) -> float:
	if _cats_eyes():
		return maxf(base, Config.CATS_EYES_MISS_WICK * Game.item_count("cats_eyes"))
	return base


func _tap_miss(tg: Dictionary, reason: String) -> void:
	_burn_wick(_miss_cost(Config.MISS_WICK_COST))
	tg.state = 2
	_strays += 1
	_miss_flash = 0.25
	_note_fail()
	missed.emit(reason, tg.p)
	_check_tap_done()


func _check_tap_done() -> void:
	var hits := 0
	var all_perfect := true
	for tg in _targets:
		if tg.state == 0:
			queue_redraw()
			return
		if tg.state == 1:
			hits += 1
			all_perfect = all_perfect and tg.perfect
	if hits == 0:
		_fail("Missed them all!", _action_center())
	else:
		_complete(all_perfect and _strays == 0, _action_center())


func _pop(at: Vector2, text: String, col: Color) -> void:
	_pops.append({"p": at, "text": text, "c": col, "life": 0.6})


func _drill(p: Vector2) -> void:
	if p.distance_to(_spot) > Config.DRILL_RADIUS * _ease():
		_stray(p, "Same spot!")
		return
	_clicks += 1
	_jolt = 1.0
	_spray(_spot + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 5)
	Sfx.play("drill", 0.85 + 0.5 * float(_clicks) / _clicks_need)
	if _clicks >= _clicks_need:
		_marks.append({"t": "hole", "p": _spot, "r": Config.DRILL_RADIUS * 0.55, "cells": _burst(_spot, 6, 0)})
		_complete(_strays == 0, _spot)
	queue_redraw()


## The moving drill: click it wherever it is right now.
func _track_click(p: Vector2) -> void:
	if p.distance_to(_spot) > Config.TRACK_RADIUS * _ease():
		_stray(p, "Missed it!", Config.TRACK_MISS_WICK_COST)
		return
	_clicks += 1
	_jolt = 1.0
	_spray(_spot, 5)
	Sfx.play("drill", 0.85 + 0.5 * float(_clicks) / _clicks_need)
	_marks.append({"t": "cells", "cells": _burst(_spot, 3, 0)})
	if _clicks >= _clicks_need:
		_marks.append({"t": "hole", "p": _spot, "r": Config.TRACK_RADIUS * 0.4, "cells": _burst(_spot, 6, 0)})
		_complete(_strays == 0, _spot)
	queue_redraw()


## Spinning: every bit you turn round the middle counts (either way round; turning back takes it off).
func _spin_move(p: Vector2) -> void:
	var v := p - _spin_c
	if v.length() < Config.SPIN_DEAD_ZONE:
		_spin_have = false  # right in the middle you can't tell which way you're going
		return
	var a := v.angle()
	if _spin_have:
		_spin_net += wrapf(a - _spin_last, -PI, PI)
	_spin_last = a
	_spin_have = true
	var turns := absf(_spin_net) / TAU
	var quarter := floori(turns * 4.0)
	if quarter > _spin_sound:
		_spin_sound = quarter
		Sfx.play("drill", 0.8 + 0.6 * minf(turns / maxf(_spin_need, 0.5), 1.0))
		_spray(p, 2)
	if turns >= _spin_need:
		var perfect := _spin_t <= _spin_time() * Config.SPIN_PERFECT_PART and _strays == 0
		_break_chunk(_spin_c, Config.SPIN_RADIUS * Config.SPIN_CHUNK_SIZE)  # the circle you spun comes out of the wall
		_spray(_spin_c, 18)
		Sfx.play("pry")
		_complete(perfect, _spin_c)
	queue_redraw()


func _pry_out(perfect: bool) -> void:
	var dir := Vector2.DOWN.rotated(randf_range(-0.6, 0.6))
	_marks.append({"t": "cells", "cells": _crack_line(_spot - dir * 34.0, _spot + dir * 34.0, 3)})
	_spray(_spot, 16)
	Sfx.play("pry")
	_complete(perfect, _spot)


func drag(p: Vector2) -> void:
	if not _tracing:
		return
	var tc := _trace_cfg()
	var ok_tol: float = tc.x
	var ahead: float = tc.y
	var steps := maxi(1, ceili(_last_p.distance_to(p) / STEP))
	for k in steps:
		var q := _last_p.lerp(p, float(k + 1) / steps)
		# only the bit of line right around where you are counts: you can't jump ahead
		var r := _closest(q, _progress - 40.0, _progress + ahead)
		_max_dev = maxf(_max_dev, r.x)
		if r.x > ok_tol:
			_miss("Off the line!", q)
			return
		# every corner must be visited; until it is, the crack can't go past it
		if _next_corner < _corners.size() and q.distance_to(_corners[_next_corner]) <= Config.ZIGZAG_CORNER_RADIUS:
			_next_corner += 1
		var cap := _corner_s[_next_corner] if _next_corner < _corner_s.size() else INF
		_progress = maxf(_progress, minf(r.y, cap))
	_last_p = p
	if Config.CRACK_SOUND_EVERY > 0.0 and _progress - _sound_s >= Config.CRACK_SOUND_EVERY:
		_sound_s = _progress
		Sfx.play("crack", 0.9 + 0.4 * _progress / maxf(_total, 1.0))
		_spray(_point_at(_progress), 2)
	if _progress >= _total * Config.SLICE_FINISH:
		var perfect := _max_dev <= tc.z
		_marks.append({"t": "cells", "cells": _crack_cells.duplicate()})
		_spray(p, 8)
		_complete(perfect, p)
	queue_redraw()


## How strict tracing this line is: (miss distance, line ahead that counts, perfect distance) in px.
func _trace_cfg() -> Vector3:
	var e := _ease()
	match kind:
		"slash":
			return Vector3(Config.SLASH_OK_TOLERANCE, Config.SLASH_LOOKAHEAD, Config.SLASH_PERFECT_TOLERANCE) * e
		"bigslash":
			return Vector3(Config.BIGSLASH_OK_TOLERANCE, Config.BIGSLASH_LOOKAHEAD, Config.BIGSLASH_PERFECT_TOLERANCE) * e
		"swirl":
			return Vector3(Config.SWIRL_OK_TOLERANCE, Config.SWIRL_LOOKAHEAD, Config.SWIRL_PERFECT_TOLERANCE) * e
	return Vector3(Config.ZIGZAG_OK_TOLERANCE, Config.ZIGZAG_LOOKAHEAD, Config.ZIGZAG_PERFECT_TOLERANCE) * e


## How forgiving the moves are (1 = normal): Beginner's Luck makes them slower / bigger / easier; Drunk,
## Familiar Circle and Death's Gambit make them stricter.
func _ease() -> float:
	if not _run_on():
		return 1.0
	var e := pow(Config.BEGINNERS_LUCK_EASE, Game.item_count("beginners_luck"))
	e *= pow(Config.DRUNK_HARDER, Game.item_count("drunk"))
	e *= pow(Config.FAMILIAR_HARDER, Game.item_count("familiar_circle"))
	e /= pow(Config.GAMBIT_HARDER, Game.item_count("deaths_gambit"))
	e /= Game.hot_harder()  # Sapphire's Clover
	return clampf(e, 0.35, 3.0)


## How long the wick lasts (x WICK_TIME): Beginner's Luck and Drunk longer, Death's Gambit and Sapphire's Clover shorter.
func _wick_mult() -> float:
	if not _run_on():
		return 1.0
	var m := pow(Config.BEGINNERS_LUCK_EASE, Game.item_count("beginners_luck")) * pow(Config.DRUNK_WICK, Game.item_count("drunk"))
	m /= pow(Config.GAMBIT_HARDER, Game.item_count("deaths_gambit")) * Game.hot_harder()
	return m


## How long the light lasts (x LIGHT_DURATION): Standard Gloves longer, Death's Gambit shorter.
func _light_mult() -> float:
	if not _run_on():
		return 1.0
	return pow(Config.STANDARD_GLOVES_LIGHT, Game.item_count("standard_gloves")) / (pow(Config.GAMBIT_HARDER, Game.item_count("deaths_gambit")) * Game.hot_harder())


## Art of Peace: no screen shaking, flashing or red edges.
func peaceful() -> bool:
	return _run_on() and Game.has_item("art_of_peace")


func _cats_eyes() -> bool:
	return _run_on() and Game.has_item("cats_eyes")


## Ram (R or main's button): crashes through RAM_WALLS walls at once (this one too). Returns true if it did.
func use_ram() -> bool:
	if not _run_on() or _falling or resting or rise < 1.0 or light_state == "dropped" or not Game.use_ram():
		return false
	_gen += 1
	kind = ""
	_reset_input()
	if light_state == "out":
		light_state = "lit"
		_lid_target = 1.0
		light = maxf(light, 0.6)
	wick = 1.0
	var mid := size * 0.5
	for i in 8:
		_spray(mid + Vector2(randf_range(-300, 300), randf_range(-180, 180)), 10)
	_shake_l = 1.0
	item_popped.emit("RAM!  %d walls down" % Config.RAM_WALLS, mid + Vector2(0, -80))
	dynamite_blown.emit(mid)
	_crumble()
	return true


## Knocked out of your hand (Gilded Umbrella's gem, an overflowing Draupnir): the lighter drops to the floor.
## Click it within DROPPED_LIGHTER_TIME, then relight it in time - or the run is over.
func _drop_lighter(text: String) -> void:
	if not _run_on() or _falling or resting or light_state == "dropped":
		return
	_gen += 1
	kind = ""
	_reset_input()
	light_state = "dropped"
	_lid_target = 0.0
	_drop_t = Config.DROPPED_LIGHTER_TIME
	_drop_pos = Vector2(randf_range(size.x * 0.3, size.x * 0.6), size.y - 190.0)
	_shake_l = 1.0
	Sfx.play("misfire")
	item_popped.emit(text, _drop_pos + Vector2(0, -120))


func _pick_up_lighter() -> void:
	Sfx.play("lid")
	_dropped_run = true  # now relight it in time, or the run's over
	_go_out()


## Gilded Umbrella: a gem drops from the roof every UMBRELLA_EVERY seconds.
func _spawn_gem() -> void:
	var gems: Array = Config.ORES.keys().filter(func(o): return Game.is_gem(o))
	var w := {}
	for g in gems:
		w[g] = 1.0 / float(Config.ORES[g].sell_price)
	var hit := randf() * 100.0 < Config.UMBRELLA_HIT_CHANCE
	var x := _flame_pos().x if hit else randf_range(size.x * 0.25, size.x * 0.85)
	_gems.append({"id": Game._weighted_pick(w), "p": Vector2(x, -30), "v": 0.0, "hit": hit, "spin": randf() * TAU})


## Falling gems land: one aimed at you knocks the lighter out of your hand; the rest shatter or are yours.
func _fall_gems(delta: float) -> void:
	for i in range(_gems.size() - 1, -1, -1):
		var g: Dictionary = _gems[i]
		g.v = float(g.v) + 900.0 * delta
		g.p = g.p + Vector2(0, g.v * delta)
		g.spin = float(g.spin) + delta * 6.0
		var floor_y := _flame_pos().y - 30.0 if g.hit else size.y - 90.0
		if g.p.y < floor_y:
			continue
		_gems.remove_at(i)
		if g.hit:
			_spray(g.p, 10)
			_drop_lighter("A falling %s hit you!  Grab your lighter!" % Game.ore_name(g.id))
		elif randf() * 100.0 < Config.UMBRELLA_BREAK_CHANCE:
			_spray(g.p, 8)
			Sfx.play("slice_miss", 1.3)
			_pop(g.p, "%s shattered" % Game.ore_name(g.id), Config.MUTED_TEXT)
		else:
			var n := roundi(Game.reward_mult())
			Game.gain_ore(g.id, n)
			Game.changed.emit()
			Game.save()
			Sfx.play("drop_rare")
			_pop(g.p, "+%d %s!" % [n, Game.ore_name(g.id)], Config.ORES[g.id].color)


func _run_on() -> bool:
	return practice == "" and Game.trip_active


## Torch: this stage the light looks after itself.
func _torch() -> bool:
	return _run_on() and Game.has_item("torch")


## Great Ham (H or main's button): +2 lives. Returns true if you ate it.
func eat_ham() -> bool:
	if not _run_on():
		return false
	var got := Game.eat_ham()
	if got <= 0.0:
		if Game.run_items.has("great_ham"):
			_pop(_flame_pos() + Vector2(190, 70), "You're too full - lives are maxed", Config.MUTED_TEXT)
		return false
	Sfx.play("ignite", 1.3)
	item_popped.emit("GREAT HAM!  +%s lives" % str(got).trim_suffix(".0"), size * 0.5 + Vector2(0, -80))
	return true


## Dynamite (D or main's button): blows the wall straight down, even with the lighter out. Returns true if it did.
func use_dynamite() -> bool:
	if not _run_on() or _falling or resting or rise < 1.0 or light_state == "dropped" or not Game.use_dynamite():
		return false
	_gen += 1
	kind = ""
	_reset_input()
	if light_state == "out":  # saved: the blast lights it back up
		light_state = "lit"
		_lid_target = 1.0
		light = maxf(light, 0.6)
	wick = 1.0
	wick_extra = 1.0 if Game.has_extra_wick() else 0.0
	var mid := size * 0.5
	for i in 6:
		_spray(mid + Vector2(randf_range(-260, 260), randf_range(-160, 160)), 10)
	_shake_l = 1.0
	dynamite_blown.emit(mid)
	_crumble()
	return true


## A miss on this move: it knocks COMBO_LOST_PER_FAIL off your combo.
## Little Light: any miss burns your hand (the run is over).
func _note_fail() -> void:
	_lose_combo(_action_center() + Vector2(0, -40))
	_little_light_burn()
	_wall_fails += 1 if practice == "" else 0
	_break_focus()


## A fail or a move that wasn't PERFECT: the PERFECT streak is over (and Deep Focus with it).
func _break_focus() -> void:
	if deep_focus():
		_pop(_flame_pos() + Vector2(190, 10), "Focus lost", Config.MUTED_TEXT)
	perfect_streak = 0


## Deep Focus: DEEP_FOCUS_PERFECTS PERFECT moves in a row. Your flame burns blue until you break it.
func deep_focus() -> bool:
	return Config.DEEP_FOCUS_PERFECTS > 0 and perfect_streak >= Config.DEEP_FOCUS_PERFECTS


## A fail (a miss, a mistimed flick, a flood...) knocks COMBO_LOST_PER_FAIL off the combo.
func _lose_combo(at: Vector2) -> void:
	if combo > 0 and practice == "":
		_pop(at, "Combo -%d" % mini(Config.COMBO_LOST_PER_FAIL, combo), Config.SLICE_MISS_COLOR)
	combo = maxi(combo - Config.COMBO_LOST_PER_FAIL, 0)


## Little Light: you messed up, so it burns your hand - you drop the lighter and the run is over (next frame,
## so the move that failed can finish what it was doing first).
func _little_light_burn() -> void:
	if _run_on() and Game.has_item("little_light"):
		_burn_pending = true


func _stray(p: Vector2, reason: String, cost := -1.0) -> void:
	_burn_wick(_miss_cost(Config.MISS_WICK_COST if cost < 0.0 else cost))
	_strays += 1
	_miss_flash = 0.25
	_note_fail()
	missed.emit(reason, p)


func _miss(reason: String, at: Vector2) -> void:
	_burn_wick(_miss_cost(Config.MISS_WICK_COST))
	_tracing = false
	_holding = false
	_fill = 0.0
	_pry_t = 0.0
	_progress = 0.0
	_next_corner = 0
	_miss_flash = 0.4
	_note_fail()
	missed.emit(reason, at)
	queue_redraw()


func _complete(perfect: bool, at: Vector2) -> void:
	if wick < 0.97 and practice == "":
		_wick_flash = 0.8  # show it: finishing the move is what filled the wick back up
	wick = 1.0  # finishing the motion is the only thing that gives the wick back
	wick_extra = 1.0 if _run_on() and Game.has_extra_wick() else 0.0
	while _marks.size() > MAX_MARKS:
		_marks.pop_front()
	var done_kind := kind
	kind = ""
	_reset_input()
	if perfect or not Config.COMBO_NEEDS_PERFECT:
		combo += 1
	else:
		combo = 0
	if practice == "":
		_wall_moves += 1
		_wall_perfects += 1 if perfect else 0
	if perfect:
		perfect_streak += 1
		if perfect_streak == Config.DEEP_FOCUS_PERFECTS:
			_pop(_flame_pos() + Vector2(190, 10), "DEEP FOCUS!", Config.DEEP_FOCUS_COLOR)
			Sfx.play("ignite", 1.3)
			_shake_l = maxf(_shake_l, 0.4)
	else:
		_break_focus()
	action_done.emit(perfect, at, combo, combo_multiplier())
	if practice != "":
		practiced.emit(done_kind)
	else:
		actions_left -= Config.SPIKE_BOOTS_COUNT * Game.item_count("spike_boots") if _run_on() and Game.has_item("spike_boots") else 1
	if actions_left <= 0 and practice == "":
		_crumble()
	else:
		if practice == "":
			_wall_damage()
		_next_action_soon()
	queue_redraw()


## Every finished move breaks the wall up a bit more: cracks run in from its edges, longer and thicker
## the closer it is to coming down, and later on chunks start falling out.
func _wall_damage() -> void:
	var f := 1.0 - float(actions_left) / maxf(actions_total, 1.0)  # 0 = untouched .. 1 = about to fall
	var mid := size * 0.5
	for k in 1 + floori(f * Config.WALL_DAMAGE_CRACKS):
		var a := _edge_point()
		var to := a.lerp(mid + Vector2(randf_range(-0.3, 0.3) * size.x, randf_range(-0.25, 0.25) * size.y), lerpf(0.18, 0.5, f) * randf_range(0.7, 1.1))
		_marks.append({"t": "cells", "cells": _crack_line(a, to, 2 if f < 0.5 else 3)})
		if f >= 0.3 and randf() < 0.6:
			_marks.append({"t": "cells", "cells": _burst(to, 3, 0)})
	if f >= Config.WALL_CHUNKS_FROM:
		for k in 1 + floori((f - Config.WALL_CHUNKS_FROM) * 4.0):
			var a := _edge_point().lerp(mid, randf_range(0.05, 0.25))
			_break_chunk(a, randf_range(14.0, 22.0) + 18.0 * f)
	_jolt = maxf(_jolt, 0.4 * f)
	Sfx.play("crack", 0.8)


## A random point just inside the wall's edge (where the cracks start).
func _edge_point() -> Vector2:
	var m := 6.0
	var side := randi() % 4
	if side == 0:
		return Vector2(randf_range(m, size.x - m), m)
	if side == 1:
		return Vector2(randf_range(m, size.x - m), size.y - m)
	if side == 2:
		return Vector2(m, randf_range(m, size.y - m))
	return Vector2(size.x - m, randf_range(m, size.y - m))


## A round chunk of wall (radius r, ragged edge) breaks out at p and falls away, leaving a hole.
func _break_chunk(p: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var n := clampi(roundi(r / 4.0), 10, 32)
	for i in n:
		pts.append(Vector2.RIGHT.rotated(TAU * i / n) * r * randf_range(0.84, 1.0))
	var world := PackedVector2Array()
	for q in pts:
		world.append(p + q)
	_marks.append({"t": "pit", "p": p, "pts": world, "cells": _burst(p, maxi(4, roundi(r / 14.0)), 0)})
	_chunks.append({"p": p, "home": p, "pts": pts, "rot": 0.0, "w": randf_range(-2.5, 2.5),
			"v": Vector2(randf_range(-90, 90), randf_range(-260, -120)), "delay": 0.06})
	_spray(p, maxi(6, roundi(r / 6.0)))


func _next_action_soon() -> void:
	var g := _gen
	get_tree().create_timer(Config.ACTION_GAP).timeout.connect(func():
		if g == _gen and kind == "" and not _falling:
			new_action())


## Fuel ran out or every circle was missed: combo lost, and the lighter goes out with it.
## Dice of Dwarves: no relighting, the life is gone straight away.
func _fail(reason: String, at: Vector2) -> void:
	var lost := combo
	combo = 0
	_wall_fails += 1 if practice == "" else 0
	_break_focus()
	kind = ""
	_reset_input()
	_miss_flash = 0.5
	failed.emit(reason, lost, at)
	_little_light_burn()
	if practice != "":
		_next_action_soon()  # the tutorial keeps the lighter lit
	elif _run_on() and Game.has_item("dice_of_dwarves") and not _burn_pending:
		item_popped.emit("DICE OF DWARVES: no relighting - a life is gone", at + Vector2(0, -50))
		_lose_life()
	else:
		_go_out()


## The light faded all the way: combo lost, lighter out. Cat's Eyes: the wick's gone - a life with it.
func _light_died() -> void:
	light = 0.0
	if _cats_eyes():
		var lost := combo
		combo = 0
		kind = ""
		_reset_input()
		_miss_flash = 0.5
		failed.emit("The cat ate your wick!", lost, _flame_pos() + Vector2(160, -60))
		_lose_life()
		return
	_fail("Your light died!", _flame_pos() + Vector2(160, -60))


# ------------------------------------------------------------------ the lighter
func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode == Config.LIGHTER_KEY:
		if resting:
			if not rest_hold:
				end_rest()
		else:
			flick()
		get_viewport().set_input_as_handled()
	elif active and event is InputEventKey and event.pressed and not event.echo and event.keycode == Config.DYNAMITE_KEY:
		use_dynamite()
		get_viewport().set_input_as_handled()
	elif active and event is InputEventKey and event.pressed and not event.echo and event.keycode == Config.RAM_KEY:
		use_ram()
		get_viewport().set_input_as_handled()
	elif active and event is InputEventKey and event.pressed and not event.echo and event.keycode == Config.GREAT_HAM_KEY:
		eat_ham()
		get_viewport().set_input_as_handled()


## SPACE: open the lighter / strike the wheel.
## Out: only a strike while the marker is in the gold zone counts. Each good strike lowers the bar,
## speeds the marker up and shrinks the zone; a mistimed one pushes the bar back up.
func flick() -> void:
	if in_beat_practice():
		_practice_flick()
		return
	if _falling or rise < 1.0:
		return
	match light_state:
		"off":
			# a real lighter doesn't catch first time: flick until it does
			if _lid_target < 1.0:
				_lid_target = 1.0
				Sfx.play("lid")
				start_need = randi_range(Config.START_FLICKS_MIN, Config.START_FLICKS_MAX)
				start_hits = 0
			start_hits += 1
			if start_hits >= start_need:
				_ignite()
			else:
				_sparks(3 + start_hits * 3)
				Sfx.play("flick", 0.9 + 0.1 * start_hits)
		"lit":
			# keep it burning: every flick only adds a little light (RECHARGE_MIN..MAX), so you keep
			# flicking while you work. Flick it when it's already full and you flood it: half a life.
			if _torch():
				_pop(_flame_pos() + Vector2(190, 70), "The Torch keeps it lit!", Config.ACCENT)
				return
			if _cats_eyes():
				_pop(_flame_pos() + Vector2(190, 70), "Cat's Eyes see for you - no flicking", Config.ACCENT)
				return
			if _hold > 0.0 and light >= Config.FLOOD_AT:
				_flood()  # flicked during the steady full blaze
				return
			if light >= wick - 0.001:
				# the wick is spent this far: flicking can't help, finish the action!
				_shake_l = maxf(_shake_l, 0.3)
				Sfx.play("misfire", 1.3)
				_pop(_flame_pos() + Vector2(190, 70), "Wick's burnt down - finish it!", Config.SLICE_MISS_COLOR)
				return
			# timing: only a flick while the FLICK bar is in its gold zone adds light. Spamming (too soon)
			# or waiting too long (too late) fails: no light, and it burns some wick.
			# the bar keeps the beat (it never restarts on a flick): one good flick per heartbeat
			var z := flick_zone()
			if _fm < z.x or _fm > z.y or _beat_used:
				var early := _fm < z.x or (_beat_used and _fm <= z.y)
				_fm_bad = 0.3
				_shake_l = maxf(_shake_l, 0.35)
				Sfx.play("misfire", 1.15)
				_burn_wick(Config.FLICK_FAIL_WICK_COST)
				var br := flick_bar_rect()
				_pop(Vector2(br.end.x + 90, br.position.y + 60), "Too soon!" if early else "Too late!", Config.SLICE_MISS_COLOR)
				if Config.FLICK_FAIL_LOSES_COMBO:
					_lose_combo(Vector2(br.end.x + 90, br.position.y + 30))
				_wall_fails += 1 if practice == "" else 0
				_break_focus()
				return
			_beat_used = true
			_fm_ok = 0.25
			var gain := flick_gain()
			if _run_on() and Game.has_item("stronger_fluids"):
				gain = maxf(gain, Config.STRONGER_FLUIDS_GAIN)  # two good flicks = full blaze
			light = minf(light + gain, wick)
			if light >= 1.0:
				_full_blaze()
			_sparks(4)
			Sfx.play("flick", 0.9 + 0.3 * light)
			if practice == "flick":
				practiced.emit("flick")
		"out":
			if _lid_target < 1.0:
				_lid_target = 1.0
				Sfx.play("lid")
			if absf(_meter - _zone_c) <= _zone_w * 0.5:
				relight_hits += 1
				_meter_hit = 0.25
				_sparks(5 + relight_hits * 3)
				if relight_hits >= relight_need:
					_ignite()
					return
				Sfx.play("flick", 0.9 + 0.08 * relight_hits)
				_meter_speed *= Config.RELIGHT_SPEED_UP
				_zone_w = maxf(_zone_w * Config.RELIGHT_ZONE_SHRINK, Config.RELIGHT_ZONE_MIN)
				_new_zone()
			else:
				relight_hits = maxi(relight_hits - Config.RELIGHT_MISS_PENALTY, 0)
				_meter_miss = 0.3
				_shake_l = 1.0
				Sfx.play("misfire")


## The FLICK bar's tempo: [seconds per heartbeat, gold zone size]. It's your heart rate (bpm), which
## only changes when a wall breaks - never in the middle of a wall, whatever move you're doing.
func flick_tempo() -> Vector2:
	return Vector2(60.0 / maxf(heart_bpm(), 1.0), lerpf(Config.FLICK_ZONE_CALM, Config.FLICK_ZONE_STRESS, heart_stress()))


## Your heart rate right now. Before the first wall of a run breaks it's just the stage's.
func heart_bpm() -> float:
	return bpm if bpm > 0.0 else _next_bpm(false)


## The heart rate for the next wall: a resting heart, plus HEART_STAGE_BPM a stage, plus up to
## HEART_PERFORM_BPM for how you played the last wall (mostly PERFECT = +, sloppy and failing = -), in steps of HEART_BPM_STEP.
func _next_bpm(with_play := true) -> float:
	var b := Config.HEART_REST_BPM + Config.HEART_STAGE_BPM * maxf(Game.skill_stage() - 1, 0)
	if with_play and _wall_moves > 0:
		var perf := clampf((float(_wall_perfects) - float(_wall_fails)) / _wall_moves, -1.0, 1.0)
		b += Config.HEART_PERFORM_BPM * perf
	if Config.HEART_BPM_STEP > 0.0:
		b = snappedf(b, Config.HEART_BPM_STEP)  # 60, 70, 80 ... never 73
	return clampf(b, Config.HEART_REST_BPM, Config.HEART_STRESS_BPM)


## Light one good flick adds. A slow bar gives fewer flicks, so each one gives more: timed perfectly,
## flicking always brings light back FLICK_GAIN times as fast as it fades (at any tempo and stage).
## Never less than RECHARGE_MIN..MAX %.
func flick_gain() -> float:
	var fade_per_sec := 1.0 / maxf(Config.LIGHT_DURATION * Game.stage_fuel_factor(), 0.1)
	var by_tempo := fade_per_sec * Config.FLICK_GAIN * flick_tempo().x * randf_range(0.85, 1.15)
	var gain := maxf(by_tempo, randf_range(Config.RECHARGE_MIN, Config.RECHARGE_MAX) / 100.0)
	if _run_on():
		gain *= pow(Config.STANDARD_GLOVES_LIGHT, Game.item_count("standard_gloves"))  # Standard Gloves
	return gain * (1.0 + Game.upgrade_value("heat_of_the_forge") / 100.0)  # Heat of the Forge: more light per flick


## The gold zone on the FLICK bar (from, to), at the top end of the bar. Drunk: a bigger zone.
func flick_zone() -> Vector2:
	var w := flick_tempo().y
	if _run_on():
		w = minf(w * pow(Config.DRUNK_FLICK_ZONE, Game.item_count("drunk")), Config.FLICK_ZONE_END - 0.05)
	return Vector2(Config.FLICK_ZONE_END - w, Config.FLICK_ZONE_END)


## Dev / screenshot demo: flick exactly in the gold zone.
func dev_flick() -> void:
	var z := flick_zone()
	_fm = (z.x + z.y) * 0.5
	_beat_used = false
	flick()


## Moves the gold zone somewhere away from the marker.
func _new_zone() -> void:
	var w := _zone_w
	for attempt in 20:
		_zone_c = randf_range(w * 0.5, 1.0 - w * 0.5)
		if absf(_zone_c - _meter) >= 0.3:
			break


## Dev / screenshot demo: strike exactly in the zone.
func dev_relight_hit() -> void:
	_meter = _zone_c
	flick()


## The flame reached full: it burns steady for LIGHT_HOLD_MIN..MAX seconds, the lighter jolts and the
## screen flashes. Flicking while it's at full blaze floods it.
func _full_blaze(flash := true) -> void:
	wick = 1.0
	light = 1.0
	_hold = randf_range(Config.LIGHT_HOLD_MIN, Config.LIGHT_HOLD_MAX)
	if flash:
		_shake_l = maxf(_shake_l, Config.FULL_SHAKE)
		full_light.emit()


func _ignite() -> void:
	light_state = "lit"
	_dropped_run = false
	_full_blaze()
	_lid_target = 1.0
	_sparks(10)
	Sfx.play("ignite")
	relit.emit(_mouse)
	if practice == "relight":
		practiced.emit("relight")
		get_tree().create_timer(1.3).timeout.connect(func():
			if practice == "relight" and light_state == "lit":
				_go_out())
		return
	if kind == "":
		_next_action_soon()


## The Torch: lit straight away, at full light (no lid, no flicks, no sparks).
func _torch_light() -> void:
	light_state = "lit"
	_dropped_run = false
	_full_blaze(false)
	_lid = 1.0
	_lid_target = 1.0
	if kind == "":
		_next_action_soon()


## The flame dies and the lid snaps shut. Relight within RELIGHT_TIME or lose a life.
func _go_out() -> void:
	_gen += 1  # cancels a pending next action
	light_state = "out"
	_lid_target = 0.0
	kind = ""
	_reset_input()
	var r := Game.relight_range()
	relight_need = randi_range(r.x, r.y)
	relight_hits = 0
	relight_left = Config.RELIGHT_TIME
	_meter = 0.0
	_meter_dir = 1.0
	_meter_speed = Config.RELIGHT_SPEED
	_zone_w = Config.RELIGHT_ZONE
	_new_zone()
	Sfx.play("fizzle")
	lighter_out.emit(_flame_pos())


## Flicked a full lighter: it floods (dips and sputters) and you lose half a life.
## Losing the last half drops you a stage, like any other lost life.
func _flood() -> void:
	light = maxf(light - 0.12, 0.02)
	_shake_l = 0.8
	Sfx.play("misfire")
	_pop(_flame_pos() + Vector2(190, 70), "Flooded!", Config.SLICE_MISS_COLOR)
	if practice != "":
		return  # the tutorial doesn't take lives
	_wall_fails += 1 if practice == "" else 0
	_break_focus()
	if Config.FLICK_FAIL_LOSES_COMBO:
		_lose_combo(_flame_pos() + Vector2(190, 40))
	if _run_on() and Game.has_item("hard_as_nails") and randf() * 100.0 < Config.HARD_AS_NAILS_CHANCE:
		item_popped.emit("HARD AS NAILS!  No harm done", _flame_pos() + Vector2(220, -120))
		return
	var down := Game.lose_life(Config.FLOOD_LIFE_COST, false)
	flooded.emit(down, _flame_pos() + Vector2(220, -120))
	if down:
		light_state = "off"
		_lid_target = 0.0
		start_hits = 0
		combo = 0
		new_wall()


## Didn't relight in time: a life is gone and the stage starts over on a fresh wall.
func _lose_life() -> void:
	light_state = "off"
	_lid_target = 0.0
	start_hits = 0
	combo = 0
	var down := Game.lose_life()
	life_lost.emit(down, size * 0.5)
	new_wall()


func _sparks(n: int) -> void:
	_spark = 1.0
	var at := _lighter_origin() + WHEEL * Config.LIGHTER_SCALE
	for i in n:
		_chips.append({"p": at, "v": Vector2(randf_range(-200, 260), randf_range(-460, -140)),
				"life": randf_range(0.2, 0.5), "s": _g() * randi_range(1, 3), "glow": true,
				"c": [Color("#fff4d6"), Color("#ffd166"), Color("#ff9a3c")].pick_random()})


## Bottom-centre of the flame on screen: the lighter is held at the left, leaning a little
## towards where you aim, bobbing like it's in your hand.
func _flame_pos() -> Vector2:
	var lean := (_mouse / size.max(Vector2.ONE) - Vector2(0.5, 0.5)) * Config.LIGHTER_SWAY
	var bob := Vector2(sin(_t * 1.3) * 2.0, sin(_t * 2.1) * 3.0)
	var raise := Config.TORCH_RAISE if _torch() and light_state != "dropped" else 0.0  # the torch is held higher
	return Vector2(Config.LIGHTER_POS.x, size.y - Config.LIGHTER_POS.y - raise) + lean + bob + _shake_off


## 0..1: how close you are to losing. Lit: the wick or the light is nearly gone. Out: the relight
## countdown is nearly over. The lighter trembles this much.
func danger() -> float:
	if practice != "" or _falling:
		return 0.0
	match light_state:
		"lit":
			var w := clampf((Config.DANGER_AT - wick) / Config.DANGER_AT, 0.0, 1.0) if kind != "" else 0.0
			var l := clampf((Config.DANGER_AT - light) / Config.DANGER_AT, 0.0, 1.0)
			return maxf(w, l)
		"dropped":
			return 1.0 - clampf(_drop_t / Config.DROPPED_LIGHTER_TIME, 0.0, 1.0) * 0.5
		"out":
			return clampf((Config.DANGER_RELIGHT_SECONDS - relight_left) / Config.DANGER_RELIGHT_SECONDS, 0.0, 1.0)
	return 0.0


## Is p on the lighter (to click / tap it)?
func lighter_hit(p: Vector2) -> bool:
	var sc := float(Config.LIGHTER_SCALE)
	return Rect2(_lighter_origin() + Vector2(0, 8) * sc, Vector2(84, 72) * sc).has_point(p)


func _lighter_origin() -> Vector2:
	return (_flame_pos() - FLAME_ANCHOR * Config.LIGHTER_SCALE).round()


## How lit the whole wall is, 0..1, in steps (pixel-art style) with a little flicker.
func _ambient() -> float:
	if _cats_eyes():
		return 1.0  # Cat's Eyes: you see the whole wall, light or no light
	var steps := float(maxi(Config.LIGHT_STEPS, 1))
	var a := ceilf(pow(fuel(), Config.LIGHT_CURVE) * steps - 0.0001) / steps
	a *= 1.0 - Config.LIGHT_FLICKER * 0.5 * (1.0 + sin(_t * 23.0) * sin(_t * 37.0))
	if fuel() < 0.2 and light_state == "lit" and fmod(_t, 0.17) < 0.05:
		a *= 0.8  # sputtering
	return a * _glow


## The glow around the lighter itself (and the flash of sparks when you strike it).
func _halo_radius() -> float:
	var r := Config.LIGHTER_GLOW_RADIUS * lerpf(Config.GLOW_MIN, 1.0, fuel()) * (1.0 + Config.LIGHT_FLICKER * sin(_t * 29.0))
	return r * _glow * (1.0 + 0.6 * _hype().x) + 150.0 * _spark  # the new-stage flare lights up more of the wall


func _crumble() -> void:
	_falling = true
	var ts := _tile_px()
	var half := ts * 0.5
	var src := tile_tex.get_size() * 0.5
	var mid := size * 0.5
	for y in ceili(size.y / half):
		for x in ceili(size.x / half):
			var c := Vector2(x + 0.5, y + 0.5) * half
			_pieces.append({
				"p": c, "region": Rect2(Vector2(x % 2, y % 2) * src, src), "rot": 0.0,
				"w": randf_range(-4, 4), "delay": randf() * 0.25,
				"v": (c - mid).normalized() * randf_range(60, 260) + Vector2(0, randf_range(-260, -40)),
			})
	wall_down.emit(mid)
	var cleared := false
	if practice == "" and Game.wall_cleared():
		cleared = true
		_hype_pending = true
		stage_up.emit(Game.stage, mid)
	await get_tree().create_timer(Config.WALL_RESPAWN_DELAY).timeout
	if not _falling:
		return  # something already put a new wall up meanwhile
	if Config.REST_BETWEEN_WALLS and practice == "":
		resting = true  # a break: nothing burns down until you're ready (end_rest)
		_rest_cleared = cleared
		return
	if practice == "" and not free_practice:
		_start_beat_practice()
		return
	new_wall()


## The break between walls is over: practise the new heartbeat, a countdown, then the next wall drops in.
func end_rest() -> void:
	if not resting:
		return
	resting = false
	Sfx.play("click")
	_start_beat_practice()


## The wall broke, so your heart rate changes: the next wall drops in and the view zooms in on the FLICK bar
## for BEAT_PRACTICE_TIME seconds to feel the new beat (flicks don't count). The last BEAT_COUNTDOWN seconds
## count down 3, 2, 1 with a flash each; after 1 the moves start.
func _start_beat_practice() -> void:
	bpm = _next_bpm()
	_fm = 0.0
	_beat_used = false
	_beat_hits = 0
	_beat_tries = 0
	_beat_flicking = light_state == "lit" and not _torch() and not _cats_eyes()
	var t := Config.BEAT_PRACTICE_TIME if _beat_flicking else float(Config.BEAT_COUNTDOWN)
	_show_wall()  # the next wall is up behind it, its moves wait for the countdown
	if t <= 0.0:
		_start_wall()
		return
	_beat_t = t
	_beat_tick(ceili(t))


## Each new second of the practice: 3, 2, 1 shake the screen and the stress comes in red.
func _beat_tick(n: int) -> void:
	if n >= 1 and n <= Config.BEAT_COUNTDOWN:
		_count_flash = 1.0
		_shake_l = maxf(_shake_l, 0.35)
		countdown_tick.emit()
		Sfx.play("click", 0.9)


## Zoomed in on the FLICK bar after a wall (practising the beat, then 3, 2, 1).
func in_beat_practice() -> bool:
	return _beat_t > 0.0


## A flick while practising the beat: it just tells you how you did and costs nothing.
func _practice_flick() -> void:
	if light_state != "lit":
		return
	var z := flick_zone()
	var br := _zoomed_bar_rect()
	var at := Vector2(br.get_center().x, br.end.y + 100)
	_beat_tries += 1
	if _fm < z.x or _fm > z.y or _beat_used:
		var early := _fm < z.x or (_beat_used and _fm <= z.y)
		_fm_bad = 0.3
		Sfx.play("misfire", 1.15)
		_pop(at, "Too soon!" if early else "Too late!", Config.SLICE_MISS_COLOR)
		return
	_beat_used = true
	_beat_hits += 1
	_fm_ok = 0.25
	Sfx.play("flick", 1.1)
	_pop(at, "On the beat!", Config.ACCENT)


## Little stone bits in the wall tile's own colours (sized in whole wall pixels).
func _spray(at: Vector2, n: int) -> void:
	for i in n:
		var col := Color.GRAY
		for attempt in 8:
			var c := _tile_img.get_pixel(randi() % _tile_img.get_width(), randi() % _tile_img.get_height())
			if c.a > 0.5:
				col = c
				break
		_chips.append({"p": at, "v": Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120, 380) + Vector2(0, -120),
				"life": randf_range(0.35, 0.7), "s": _g() * randi_range(1, 3), "c": col})


# ------------------------------------------------------------------ animate
func _process(delta: float) -> void:
	_t += delta
	_mouse = dev_mouse if dev_mouse.x >= 0.0 else get_local_mouse_position()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lighter_hit(_mouse) and not _torch() else Control.CURSOR_CROSS
	_lid = move_toward(_lid, _lid_target, delta / maxf(Config.LIGHTER_LID_TIME, 0.01))
	var glow_to := 1.0 if light_state == "lit" and _lid >= 1.0 else 0.0
	_glow = move_toward(_glow, glow_to, delta * (5.0 if glow_to > _glow else 2.5))
	_spark = maxf(_spark - delta * 6.0, 0.0)
	_shake_l = maxf(_shake_l - delta * 4.0, 0.0)
	var tremble := 0.0 if peaceful() else Config.DANGER_SHAKE * danger()
	_shake_off = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_shake_l * (0.0 if peaceful() else 10.0) + tremble)).round()
	_meter_hit = maxf(_meter_hit - delta, 0.0)
	_fm_ok = maxf(_fm_ok - delta, 0.0)
	_fm_bad = maxf(_fm_bad - delta, 0.0)
	_beat_kick = maxf(_beat_kick - delta * 6.0, 0.0)
	_hype_t = maxf(_hype_t - delta, 0.0)
	var practising := active and in_beat_practice()
	_zoom = move_toward(_zoom, 1.0 if in_beat_practice() else 0.0, delta / 0.45)
	if active and light_state == "lit" and ((not _falling and rise >= 1.0) or practising):
		_fm += delta / flick_tempo().x
		if _fm >= 1.0:
			_fm = fmod(_fm, 1.0)  # the next heartbeat: the bar starts filling again
			_beat_used = false
			_beat_kick = 1.0
	_count_flash = maxf(_count_flash - delta * 1.6, 0.0)
	if practising:
		var before := ceili(_beat_t)
		_beat_t -= delta
		if _beat_t <= 0.0:
			_beat_t = 0.0
			Sfx.play("ignite", 1.2)
			_start_wall()  # after 1: back to the game
		elif ceili(_beat_t) != before:
			_beat_tick(ceili(_beat_t))
	_meter_miss = maxf(_meter_miss - delta, 0.0)
	# the Torch: you hold it instead of the lighter - it's burning as soon as the wall is up, no flicking
	if active and _torch() and light_state in ["off", "out"] and not _falling and not resting and rise >= 1.0 and practice == "":
		_torch_light()
	if active and light_state == "out" and not _falling and rise >= 1.0:
		_meter += _meter_dir * _meter_speed * delta  # bounces back and forth along the track
		while _meter > 1.0 or _meter < 0.0:
			if _meter > 1.0:
				_meter = 2.0 - _meter
				_meter_dir = -1.0
			else:
				_meter = -_meter
				_meter_dir = 1.0
		if practice == "":
			relight_left -= delta
			if relight_left <= 0.0:
				if _dropped_run:  # it was knocked out of your hand and you didn't get it going again
					_dropped_run = false
					light_state = "off"
					Game.fail_run("You didn't relight your lighter in time - the run is over!")
				else:
					_lose_life()
	# the lighter's on the floor: pick it up in time or the run's over
	if active and light_state == "dropped" and not _falling:
		_drop_t -= delta
		if _drop_t <= 0.0:
			light_state = "off"
			Game.fail_run("You didn't pick up your lighter - the run is over!")
	# Little Light: you messed up - it burns your hand, you drop the lighter and the run is over
	if _burn_pending:
		_burn_pending = false
		if _run_on():
			_gen += 1
			kind = ""
			_reset_input()
			light_state = "off"
			_lid_target = 0.0
			_shake_l = 1.0
			Sfx.play("fizzle")
			Game.fail_run("LITTLE LIGHT burned your hand!  You dropped the lighter - the run is over!")
	# Gilded Umbrella: gems fall from the roof
	if active and _run_on() and Game.has_item("gilded_umbrella") and light_state == "lit" and not _falling and rise >= 1.0 and not in_beat_practice():
		_gem_t -= delta
		if _gem_t <= 0.0:
			_gem_t = randf_range(Config.UMBRELLA_EVERY.x, Config.UMBRELLA_EVERY.y)
			_spawn_gem()
	_fall_gems(delta)
	_mandrake()
	_miss_flash = maxf(_miss_flash - delta, 0.0)
	_jolt = maxf(_jolt - delta * 8.0, 0.0)
	_wick_flash = maxf(_wick_flash - delta, 0.0)
	if active and light_state == "lit" and not _falling and rise >= 1.0 and not in_beat_practice():
		var burn := delta / maxf(Config.WICK_TIME * Game.stage_fuel_factor() * _wick_mult(), 0.1)
		var extra := _run_on() and wick_extra > 0.0  # Extra Wick: while it burns, the light holds
		if _hold > 0.0:
			_hold -= delta  # still at full blaze
		elif not extra and not _torch() and not _cats_eyes():
			light -= delta / maxf(Config.LIGHT_DURATION * Game.stage_fuel_factor() * _light_mult(), 0.1)
		if kind != "" and practice == "" and _hold <= 0.0 and not _torch():  # the Torch never burns down
			if extra:
				wick_extra = maxf(wick_extra - burn, 0.0)
			else:
				wick -= burn
		if _torch():
			wick = 1.0
		if _torch() or _cats_eyes():
			light = maxf(wick, 0.0)  # the Torch / Cat's Eyes: as bright as the wick allows, no flicking
		elif not extra:
			light = minf(light, maxf(wick, 0.0))
		if _run_on() and Game.has_item("little_light") and not _torch() and not _cats_eyes() and kind != "":
			# Little Light: flicks for you in the gold zone (never when it would flood or can't help)
			var z := flick_zone()
			if _hold <= 0.0 and light < 0.85 and light < wick - 0.02 and not _beat_used and _fm >= lerpf(z.x, z.y, 0.35) and _fm <= z.y:
				flick()
		if free_practice and practice not in ["flick", "relight"]:
			light = 1.0  # practising a move: the lighter just stays bright, nothing to look after
		elif practice != "":
			light = maxf(light, 0.15)  # the tutorial lets you practise flicking without going out
		elif light <= 0.0:
			_light_died()
	if active and can_act():
		if kind == "tap":
			_tap_clock += delta / _ease()  # Beginner's Luck: the rings close slower
			for tg in _targets.duplicate():
				if kind != "tap":
					break  # the action just ended
				if tg.state == 0 and _tap_clock > tg.hit_t + Config.TAP_GOOD_WINDOW:
					_tap_miss(tg, "Missed!")
		if _tracing:
			_swipe_t += delta
			if (kind == "slash" and _swipe_t > Config.SLASH_SWIPE_TIME * _ease()) or (kind == "bigslash" and _swipe_t > Config.BIGSLASH_SWIPE_TIME * _ease()):
				_miss("Too slow, swipe it!", _last_p)
		if kind == "track":
			_track_time += delta / _ease()
			_spot = _track_pos_at(_track_time)
		if kind == "spin" and _spin_started:
			_spin_t += delta
			if _spin_t > _spin_time():
				_spin_reset()
				_miss("Too slow, spin faster!", _spin_c)
		if _holding:
			_pry_t += delta / maxf(_pry_time, 0.1)
			_fill = _pry_shape(_pry_t)
			if _pry_t >= 1.0:
				_spray(_spot, 6)
				_miss("Snapped! Let go sooner", _spot)
	for i in range(_chunks.size() - 1, -1, -1):
		var ch: Dictionary = _chunks[i]
		if ch.delay > 0.0:
			ch.delay -= delta
			continue
		var cv: Vector2 = ch.v
		cv.y += 1500.0 * delta
		ch.v = cv
		ch.p += cv * delta
		ch.rot += ch.w * delta
		if ch.p.y > size.y + 300.0:
			_chunks.remove_at(i)
	for pc in _pieces:
		if pc.delay > 0.0:
			pc.delay -= delta
			continue
		var v: Vector2 = pc.v
		v.y += 1500.0 * delta
		pc.v = v
		pc.p += v * delta
		pc.rot += pc.w * delta
	for i in range(_chips.size() - 1, -1, -1):
		var c: Dictionary = _chips[i]
		c.life -= delta
		if c.life <= 0.0:
			_chips.remove_at(i)
			continue
		var v: Vector2 = c.v
		v.y += 1400.0 * delta
		c.v = v
		c.p += v * delta
	for i in range(_pops.size() - 1, -1, -1):
		var pp: Dictionary = _pops[i]
		pp.life -= delta
		pp.p = pp.p + Vector2(0, -50.0 * delta)
		if pp.life <= 0.0:
			_pops.remove_at(i)
	_update_layers()
	queue_redraw()


## Mandrake: screams every time the light drops a visible step darker.
func _mandrake() -> void:
	var step := -1
	if active and light_state == "lit" and not _falling and not resting:
		step = int(ceilf(pow(fuel(), Config.LIGHT_CURVE) * float(maxi(Config.LIGHT_STEPS, 1)) - 0.0001))
	if step >= 0 and _dark_step >= 0 and step < _dark_step and _run_on() and Game.has_item("mandrake"):
		Sfx.play("scream")
		_pop(_flame_pos() + Vector2(150, -170), "AAAAAH!", Config.SLICE_MISS_COLOR)
	_dark_step = step


func _update_layers() -> void:
	_dark.size = size
	_top.size = size
	var mat := _dark.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("ambient", _ambient())
	var halo := _flame_pos() - Vector2(0, 80 * lerpf(Config.FLAME_MIN_SIZE, 1.0, fuel()))
	mat.set_shader_parameter("light1", Vector4(halo.x, halo.y, _halo_radius(), 0.0))
	var hat := _run_on() and Game.has_item("miners_hat")  # Miner's Hat: a lamp lights the wall round your cursor
	mat.set_shader_parameter("light0", Vector4(_mouse.x, _mouse.y, Config.MINERS_HAT_RADIUS if hat else 0.0, 0.0))
	mat.set_shader_parameter("darkness", Config.WALL_DARKNESS)
	mat.set_shader_parameter("soft", clampf(Config.LIGHT_SOFT_EDGE, 0.0, 1.0))
	mat.set_shader_parameter("bands", float(Config.LIGHT_BANDS))
	mat.set_shader_parameter("pixel", float(maxi(Config.LIGHT_PIXEL, 1)))
	mat.set_shader_parameter("tint", Config.LIGHT_TINT)
	_top.queue_redraw()


# ------------------------------------------------------------------ draw helpers (pixel grid)
func _px_rect(c: Vector2, w := 1.0, h := 1.0) -> Rect2:
	var g := _g()
	return Rect2(c * g, Vector2(w, h) * g)


## Crack pixels: a light pixel under each one, then the dark crack on top.
func _draw_cells(cells: PackedVector2Array, count := -1) -> void:
	var n := cells.size() if count < 0 else mini(count, cells.size())
	if Config.CUT_EDGE_COLOR.a > 0.0:
		for i in n:
			_ci.draw_rect(_px_rect(cells[i] + Vector2.DOWN), Config.CUT_EDGE_COLOR)
	for i in n:
		_ci.draw_rect(_px_rect(cells[i]), Config.CUT_COLOR)


## The chunks falling out of the wall: the wall's own tile on them, a dark rim, a little shading.
func _draw_chunks() -> void:
	var ts := _tile_px()
	for ch in _chunks:
		var pts: PackedVector2Array = ch.pts
		var home: Vector2 = ch.home
		var p: Vector2 = ch.p
		var world := PackedVector2Array()
		var uvs := PackedVector2Array()
		for q in pts:
			world.append((p + q.rotated(ch.rot)).round())
			uvs.append((home + q) / ts)
		_ci.draw_colored_polygon(world, Color.WHITE, uvs, tile_tex)
		_ci.draw_colored_polygon(world, Color(0, 0, 0, 0.18))
		var rim := world.duplicate()
		rim.append(world[0])
		_ci.draw_polyline(rim, Config.CUT_COLOR, maxf(_g(), 2.0))


## Filled pixel circle, one rect per pixel row.
func _pixel_disc(center: Vector2, r: float, col: Color) -> void:
	var g := _g()
	var cc := center / g
	var rc := r / g
	for y in range(floori(cc.y - rc), ceili(cc.y + rc) + 1):
		var dy := (y + 0.5) - cc.y
		if absf(dy) > rc:
			continue
		var half := sqrt(rc * rc - dy * dy)
		var x0 := roundi(cc.x - half)
		var x1 := roundi(cc.x + half)
		if x1 > x0:
			_ci.draw_rect(Rect2(Vector2(x0, y) * g, Vector2(x1 - x0, 1) * g), col)


## Pixel ring / arc, thick = pixels inward.
func _pixel_arc(center: Vector2, r: float, a0: float, a1: float, thick: int, col: Color) -> void:
	var g := _g()
	var seen := {}
	for k in thick:
		var rr := r - k * g
		if rr <= 0.0:
			break
		var steps := maxi(8, ceili(absf(a1 - a0) * rr / (g * 0.7)))
		for i in steps + 1:
			var c := _cell(center + Vector2.RIGHT.rotated(lerpf(a0, a1, float(i) / steps)) * rr)
			if not seen.has(c):
				seen[c] = true
				_ci.draw_rect(_px_rect(Vector2(c)), col)


func _pixel_ring(center: Vector2, r: float, thick: int, col: Color) -> void:
	_pixel_arc(center + Vector2(0, _g()), r, 0.0, TAU, thick, Color(0, 0, 0, 0.5 * col.a))
	_pixel_arc(center, r, 0.0, TAU, thick, col)


## Filled pixel polygon (cell centres inside the shape).
func _pixel_poly(pts: PackedVector2Array, col: Color) -> void:
	var g := _g()
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	var a := _cell(box.position)
	var b := _cell(box.end)
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if Geometry2D.is_point_in_polygon((Vector2(x, y) + Vector2(0.5, 0.5)) * g, pts):
				_ci.draw_rect(_px_rect(Vector2(x, y)), col)


func _offset(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


# ------------------------------------------------------------------ draw
## Bottom layer: the wall, its cracks and the current action. The darkness covers this.
func _draw() -> void:
	_ci = self
	var ts := _tile_px()
	if _falling:
		var half := Vector2.ONE * ts * 0.5
		for pc in _pieces:
			_ci.draw_set_transform(pc.p, pc.rot, Vector2.ONE)
			_ci.draw_texture_rect_region(tile_tex, Rect2(-half * 0.5, half), pc.region)
		_ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		_draw_chips(false)
		return
	var drop := (1.0 - rise) * -size.y
	_ci.draw_set_transform(Vector2(0, drop), 0.0, Vector2.ONE)
	for y in ceili(size.y / ts):
		for x in ceili(size.x / ts):
			_ci.draw_texture_rect(tile_tex, Rect2(Vector2(x, y) * ts, Vector2(ts, ts)), false)
	for m in _marks:
		_draw_mark(m)
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_chunks()
	if can_act():
		var col := Config.SLICE_MISS_COLOR if _miss_flash > 0.0 else Config.SLICE_GUIDE_COLOR
		match kind:
			"tap": _draw_tap(col)
			"zigzag", "slash", "swirl", "bigslash": _draw_path(col)
			"drill": _draw_drill(col)
			"pry": _draw_pry(col)
			"track": _draw_track(col)
			"spin": _draw_spin(col)
	_draw_chips(false)


## Top layer (above the darkness): sparks, your lighter, little texts and the HUD.
## Where the wick gauge sits: the bottom-right corner of the screen (outside the area actions use).
func wick_gauge_rect() -> Rect2:
	var sc := float(Config.LIGHTER_SCALE)
	var cells := Vector2i(5, int(Config.WICK_GAUGE_HEIGHT / sc))  # 1 frame + 3 wick + 1 frame wide
	var sz := Vector2(cells) * sc
	return Rect2((size - sz - Config.WICK_GAUGE_MARGIN).round(), sz)


## About to lose (danger() > 0): a red border creeps in from the screen edges and throbs like a
## heartbeat, faster and stronger the closer you are. Drawn in hard steps, pixel-art style.
func _draw_stress() -> void:
	if peaceful():
		return  # Art of Peace: no red edges
	var d := danger()
	if d <= 0.0 or Config.STRESS_ALPHA <= 0.0:
		return
	var rate := lerpf(1.2, 3.0, d)  # heartbeats per second
	var beat := pow(maxf(sin(_t * TAU * rate), 0.0), 3.0)  # a sharp thump, then quiet
	_draw_red_edges(d, beat)


## The red stress border: d = how strong (0..1), beat = the thump (0..1).
func _draw_red_edges(d: float, beat: float) -> void:
	var bands := maxi(Config.STRESS_BANDS, 1)
	var bw := Config.STRESS_WIDTH * lerpf(0.6, 1.0, d) * (1.0 + 0.25 * beat) / bands
	for i in bands:
		var a := Config.STRESS_ALPHA * d * (0.55 + 0.45 * beat) * (1.0 - float(i) / bands)
		var c := Config.STRESS_COLOR
		c.a = a
		var inset := float(i) * bw
		var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
		_ci.draw_rect(Rect2(r.position, Vector2(r.size.x, bw)), c)                         # top
		_ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - bw), Vector2(r.size.x, bw)), c)  # bottom
		_ci.draw_rect(Rect2(r.position + Vector2(0, bw), Vector2(bw, r.size.y - bw * 2.0)), c)  # left
		_ci.draw_rect(Rect2(r.position + Vector2(r.size.x - bw, bw), Vector2(bw, r.size.y - bw * 2.0)), c)  # right


## The wick, as pixel art: a braided cotton wick in a slot that burns down from the top, with a
## glowing ember on its tip. The slot's frame flashes red when it's nearly gone.
func _draw_wick_gauge() -> void:
	if not Config.WICK_GAUGE or light_state != "lit":
		return
	var sc := float(Config.LIGHTER_SCALE)
	var r := wick_gauge_rect()
	var cols := int(r.size.x / sc)
	var rows := int(r.size.y / sc)
	var low := kind != "" and practice == "" and wick < Config.DANGER_AT
	var frame_col := Config.SLICE_MISS_COLOR if low and fmod(_t, 0.4) < 0.2 else Config.TEXT_OUTLINE_COLOR
	_ci.draw_rect(r.grow(sc), frame_col)
	_ci.draw_rect(r, Color("#2a1d16"))
	var fill := int(ceil(clampf(wick, 0.0, 1.0) * (rows - 2)))
	var light_c := Color("#e8d9b5")
	var dark_c := Color("#a8875c")
	for i in fill:
		var y := rows - 2 - i                       # from the bottom up
		for x in range(1, cols - 1):
			var c := dark_c if (x + y) % 3 == 0 else light_c  # braided stripes
			_ci.draw_rect(Rect2(r.position + Vector2(x, y) * sc, Vector2(sc, sc)), c)
	if fill > 0:
		# the burning tip: charred row + a flickering ember on top
		var ty := rows - 1 - fill
		for x in range(1, cols - 1):
			var ember := Color("#ffd166") if (x + int(_t * 12.0)) % 2 == 0 else Color("#ff9a3c")
			_ci.draw_rect(Rect2(r.position + Vector2(x, ty + 1) * sc, Vector2(sc, sc)), Color("#3a2a22"))
			if ty >= 1:
				_ci.draw_rect(Rect2(r.position + Vector2(x, ty) * sc, Vector2(sc, sc)), ember)
	_text("WICK", Vector2(r.get_center().x, r.position.y - 12), 15, Config.SLICE_MISS_COLOR if low else Config.TEXT_COLOR, font)
	if _wick_flash > 0.0:  # just refilled by finishing a move
		var fc := Config.ACCENT
		fc.a = clampf(_wick_flash / 0.4, 0.0, 1.0)
		_ci.draw_rect(r.grow(sc * 2.0), fc, false, sc)
		_text("REFILLED!", Vector2(r.position.x - 70, r.position.y + 40 - (0.8 - _wick_flash) * 30.0), 18, fc, title_font)
	elif Game.show_hints and kind != "" and practice == "" and wick < 0.7:
		# while it burns: say what it's for, right next to it
		var hc := Config.SLICE_MISS_COLOR if low else Config.TEXT_COLOR
		_text("Finish the move", Vector2(r.position.x - (104.0 if _run_on() and Game.has_extra_wick() else 78.0), r.get_center().y - 8), 15, hc, font)
		_text("to refill it", Vector2(r.position.x - (104.0 if _run_on() and Game.has_extra_wick() else 78.0), r.get_center().y + 12), 15, hc, font)
	if _run_on() and Game.has_extra_wick():  # the Extra Wick: a slimmer bar beside it, burns first
		var er := Rect2(r.position - Vector2(sc * 4.0 + 10.0, 0), Vector2(sc * 4.0, r.size.y))
		_ci.draw_rect(er.grow(sc), Config.TEXT_OUTLINE_COLOR)
		_ci.draw_rect(er, Color("#2a1d16"))
		var eh := (er.size.y - sc * 2.0) * clampf(wick_extra, 0.0, 1.0)
		_ci.draw_rect(Rect2(er.position.x + sc, er.end.y - sc - eh, er.size.x - sc * 2.0, eh), Color("#ffd166"))
		_text("EXTRA", Vector2(er.get_center().x, er.position.y - 12), 15, Config.ACCENT, font)


func _draw_top() -> void:
	_ci = _top
	_draw_stress()
	_draw_chips(true)
	_draw_gems()
	_draw_lighter()
	var zoomed := _zoom > 0.0
	if not zoomed:
		_draw_flick_bar()
	_draw_wick_gauge()
	if not zoomed:
		_draw_pops()
	_draw_hud()
	if zoomed:  # practising the beat after a wall: the whole game goes dark, only the FLICK bar is lit
		_ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, Config.BEAT_PRACTICE_DIM * _zoom_e()))
		_draw_flick_bar()
		_draw_beat_practice()
		_draw_pops()
	if _count_flash > 0.0 and not peaceful():  # 3, 2, 1: the stress comes in red from the edges
		_draw_red_edges(Config.COUNTDOWN_RED * _count_flash, _count_flash)
	_ci = self


func _draw_pops() -> void:
	for pp in _pops:
		var c: Color = pp.c
		c.a = clampf(pp.life * 3.0, 0.0, 1.0)
		_text(pp.text, pp.p - Vector2(0, Config.TAP_RADIUS + 8), 20, c, title_font)


func _zoom_e() -> float:
	return smoothstep(0.0, 1.0, _zoom)


## 0..1: how far into the beat practice's zoom (main darkens the wall's buttons with it).
func zoom_amount() -> float:
	return _zoom_e()


## How racing your heart is: 0 = resting, 1 = under stress.
func heart_stress() -> float:
	return clampf(inverse_lerp(Config.HEART_REST_BPM, Config.HEART_STRESS_BPM, heart_bpm()), 0.0, 1.0)


## Where the FLICK bar is drawn: zoomed in to the middle of the screen while you practise the beat,
## and it jolts on every heartbeat (harder the faster your heart goes). Returns (origin, scale).
func _bar_xform() -> Array:
	var r := flick_bar_rect()
	var e := _zoom_e()
	var sc := lerpf(1.0, Config.BEAT_PRACTICE_ZOOM, e)
	var target := Vector2(size.x * 0.4, size.y * 0.5 + 70.0)  # left of centre (the words go on the right), under the HUD
	var c := r.get_center().lerp(target, e)
	var jolt := Config.FLICK_BEAT_SHAKE * _beat_kick * lerpf(0.6, 1.6, heart_stress()) * lerpf(1.0, 2.0, e)
	if peaceful():
		jolt = 0.0  # Art of Peace: nothing shakes
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * jolt
	return [(c - r.get_center() * sc + off).round(), sc]


## The FLICK bar's rect on screen (zoomed in while you practise the beat).
func _zoomed_bar_rect() -> Rect2:
	var r := flick_bar_rect()
	var xf := _bar_xform()
	var o: Vector2 = xf[0]
	var sc: float = xf[1]
	return Rect2(o + r.position * sc, r.size * sc)


## After a wall: "feel the beat" for BEAT_PRACTICE_TIME seconds, then a 3, 2, 1 countdown.
func _draw_beat_practice() -> void:
	if _zoom <= 0.0:
		return
	var a := _zoom_e()
	var br := _zoomed_bar_rect()
	var mid := Vector2(lerpf(br.end.x, size.x - 150.0, 0.5), br.get_center().y)  # between the bar and the Back button
	if not _beat_flicking:
		mid = size * 0.5
	if _beat_t <= 0.0:
		return  # zooming back out: the words are gone already
	var n := ceili(_beat_t)
	var counting := n <= Config.BEAT_COUNTDOWN
	if _beat_flicking:
		_text("FEEL THE BEAT" if not counting else "GET READY", mid + Vector2(0, -70), 40, Color(Config.ACCENT, a), title_font)
		_text("Your heart: %d BPM" % roundi(heart_bpm()), mid + Vector2(0, -28), 22, Color(Config.TEXT_COLOR, a), font)
		if not counting:
			_text("Flick SPACE on every beat", mid + Vector2(0, 2), 18, Color(Config.TEXT_COLOR, a), font)
			_text("(practice - it doesn't count)", mid + Vector2(0, 26), 16, Color(Config.MUTED_TEXT, a), font)
			_text("%d / %d on the beat" % [_beat_hits, _beat_tries], mid + Vector2(0, 66), 18, Color(Config.ACCENT, a), font)
	elif _beat_t > 0.0:
		_text("GET READY", mid + Vector2(0, -70), 40, Color(Config.ACCENT, a), title_font)
	if counting:
		var pulse := 1.0 + 0.35 * clampf(_beat_t - floorf(_beat_t) - 0.6, 0.0, 0.4) / 0.4
		_text(str(n), mid + Vector2(0, 90), roundi(100 * pulse), Color(Config.ACCENT, a), title_font)


## Where the FLICK bar sits: on the left edge of the screen, above the lighter (doesn't follow the lean).
func flick_bar_rect() -> Rect2:
	var sc := float(Config.LIGHTER_SCALE)
	var cells := Vector2i(5, int(Config.FLICK_BAR_HEIGHT / sc))
	var sz := Vector2(cells) * sc
	return Rect2(Vector2(Config.FLICK_BAR_POS.x, size.y - Config.FLICK_BAR_POS.y - sz.y).round(), sz)


## The FLICK bar, pixel art like the wick: it charges up from the bottom at this minigame's tempo;
## the gold band near the top is when a flick counts. Green flash = good flick, red = mistimed.
func _draw_flick_bar() -> void:
	if light_state != "lit" or _glow < 0.5 or _torch() or _cats_eyes():
		return
	var xf := _bar_xform()
	var o: Vector2 = xf[0]
	var sc: float = xf[1]
	_ci.draw_set_transform(o, 0.0, Vector2(sc, sc))
	_draw_flick_bar_body()
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_flick_bar_body() -> void:
	var sc := float(Config.LIGHTER_SCALE)
	var r := flick_bar_rect()
	if _run_on() and Game.has_item("little_light") and not _flame_frames.is_empty():
		# Little Light: a tiny flame bobbing over the FLICK bar (it does the flicking)
		var ft := _flame_frames[int(_t * 10.0) % _flame_frames.size()]
		var fs := ft.get_size() * sc * 0.35
		var fp := Vector2(r.get_center().x - fs.x * 0.5, r.position.y - fs.y - 26.0 + sin(_t * 4.0) * 4.0)
		_ci.draw_texture_rect(ft, Rect2(fp.round(), fs), false)
	var rows := int(r.size.y / sc)
	var cols := int(r.size.x / sc)
	var full := _hold > 0.0  # steady full blaze: flicking now floods it
	var frame_col := Config.TEXT_OUTLINE_COLOR
	if _fm_bad > 0.0:
		frame_col = Config.SLICE_MISS_COLOR
	elif _fm_ok > 0.0:
		frame_col = Color("#91db69")
	_ci.draw_rect(r.grow(sc), frame_col)
	_ci.draw_rect(r, Color("#2a1d16"))
	var z := flick_zone()
	var inner := rows - 2
	var fill := int(floor(clampf(_fm, 0.0, 1.0) * inner))
	var in_zone := _fm >= z.x and _fm <= z.y
	for i in inner:
		var y := rows - 2 - i                         # from the bottom up
		var f0 := float(i) / inner
		var zone_row := f0 + 0.5 / inner >= z.x and f0 + 0.5 / inner <= z.y
		var c := Color("#3e3546")
		if zone_row:
			c = Color("#8a6a2a")                      # the gold zone, dim
		if i < fill:
			c = Color("#ffd166") if zone_row else Color("#cd683d")
			if full:
				c = Color("#7f708a")
		for x in range(1, cols - 1):
			_ci.draw_rect(Rect2(r.position + Vector2(x, y) * sc, Vector2(sc, sc)), c)
	var label := "FULL" if full else ("FLICK!" if in_zone else "FLICK")
	var col := Config.MUTED_TEXT if full else (Config.ACCENT if in_zone else Config.TEXT_COLOR)
	_text(label, Vector2(r.get_center().x, r.position.y - 12), 16, col, font)
	_draw_heart(Vector2(r.get_center().x, r.position.y - 40))


## Your heart rate over the FLICK bar: a pixel heart that thumps on every beat, and the BPM.
func _draw_heart(at: Vector2) -> void:
	const HEART := [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
	var px := 3.0 * (1.0 + 0.3 * _beat_kick)
	var hc := Config.SLICE_MISS_COLOR.lerp(Color.WHITE, 0.35 * _beat_kick)
	var txt := "%d" % roundi(heart_bpm())
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, Config.font_px(15)).x if font else 24.0
	var hw := 7.0 * px
	var x0 := at.x - (hw + 6.0 + tw) * 0.5
	var y0 := at.y - 6.0 * px * 0.5 - 5.0
	for row in HEART.size():
		var line: String = HEART[row]
		for i in line.length():
			if line[i] == "X":
				_ci.draw_rect(Rect2(Vector2(x0 + i * px, y0 + row * px).round(), Vector2(px, px).ceil()), hc)
	_text(txt, Vector2(x0 + hw + 6.0 + tw * 0.5, at.y), 15, Config.TEXT_COLOR, font)


## Deep Focus: your flame art with its warm colours turned blue (its blue gas and white core stay as they are).
func _blue_flame(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0 or c.s < 0.08 or (c.h > 0.4 and c.h < 0.8):
				continue
			var warm := c.h if c.h < 0.5 else c.h - 1.0  # red 0, orange ~0.08, yellow ~0.16
			img.set_pixel(x, y, Color.from_hsv(clampf(0.64 - warm * 0.9, 0.45, 0.75), c.s, c.v, c.a))
	return ImageTexture.create_from_image(img)


## The new-stage flare: x = how far the flame has grown (0..1, towards STAGE_HYPE_SCALE), y = how blue (0..1).
## It shoots up blue, roars at full size for a moment, then shrinks back and its colour comes home.
func _hype() -> Vector2:
	if _hype_t <= 0.0 or Config.STAGE_HYPE_TIME <= 0.0:
		return Vector2.ZERO
	var p := 1.0 - _hype_t / Config.STAGE_HYPE_TIME  # 0 -> 1 over the flare
	var grow := 1.0
	if p < 0.2:
		grow = 1.0 - pow(1.0 - p / 0.2, 3.0)  # shoots up fast
	elif p < 0.5:
		grow = 1.0 + 0.05 * sin(_t * 40.0)    # roaring
	else:
		grow = 1.0 - smoothstep(0.5, 1.0, p)  # settles back down
	var blue := 1.0
	if p < 0.08:
		blue = p / 0.08
	elif p > 0.55:
		blue = 1.0 - smoothstep(0.55, 0.9, p)
	return Vector2(grow, blue)


## Your lighter, held at the left like a torch. Lid frame from the open/close animation; the flame is the timer.
func _draw_lighter() -> void:
	if _lighter_frames.is_empty():
		return
	var sc := float(Config.LIGHTER_SCALE)
	var torch := _torch() and not _torch_frames.is_empty()
	if light_state == "dropped":  # on the floor, on its side: click it!
		var t0 := _torch_frames[0] if torch else _lighter_frames[0]
		_ci.draw_set_transform(_drop_pos, PI * 0.5, Vector2.ONE)
		_ci.draw_texture_rect(t0, Rect2(-t0.get_size() * sc * 0.5, t0.get_size() * sc), false)
		_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var blink := 0.6 + 0.4 * sin(_t * 10.0)
		_text("CLICK IT - PICK IT UP!  %.1fs" % maxf(_drop_t, 0.0), _drop_pos + Vector2(0, -110), 26, Color(Config.SLICE_MISS_COLOR, blink), title_font)
		return
	if torch:
		# the Torch artifact: you hold the torch, the lighter's put away (its flame is where the light comes from)
		var tt := _torch_frames[int(_t * Config.FLAME_FPS) % _torch_frames.size()]
		var ts := tt.get_size() * sc
		_ci.draw_texture_rect(tt, Rect2((_flame_pos() - Vector2(ts.x * 0.62, ts.y * 0.32)).round(), ts), false)
		return
	var n := _lighter_frames.size()
	var tex := _lighter_frames[clampi(roundi(_lid * (n - 1)), 0, n - 1)]
	var o := _lighter_origin()
	_ci.draw_texture_rect(tex, Rect2(o, tex.get_size() * sc), false)
	if _glow <= 0.01 or _lid < 1.0:
		return
	var f := fuel()
	# the flame gets smaller and smaller as the light goes down
	var k := lerpf(Config.FLAME_MIN_SIZE, 1.0, f) * _glow
	if f < 0.2 and kind != "":
		k *= 0.85 + 0.15 * randf()  # sputtering
	var base := o + FLAME_ANCHOR * sc
	if not _flame_frames.is_empty():
		# your 8-frame flicker; its bottom (the blue gas) sits in the chimney
		var has_blue := _flame_frames_blue.size() == _flame_frames.size()
		var frames := _flame_frames_blue if deep_focus() and has_blue else _flame_frames
		var hype := _hype()  # a new stage: x = how much bigger, y = how blue
		k = lerpf(k, Config.STAGE_HYPE_SCALE, hype.x)
		var i := int(_t * Config.FLAME_FPS) % frames.size()
		var ftex := frames[i]
		var fs := (ftex.get_size() * sc * k).round()
		var bottom := base + Vector2(0, Config.FLAME_SINK * sc)
		var rect := Rect2((bottom - Vector2(fs.x * 0.5, fs.y)).round(), fs)
		_ci.draw_texture_rect(ftex, rect, false)
		if hype.y > 0.0 and has_blue and frames != _flame_frames_blue:
			_ci.draw_texture_rect(_flame_frames_blue[i], rect, false, Color(1, 1, 1, hype.y))  # fades blue over the top


## Gilded Umbrella: the gems falling from the roof (spinning), with a warning line under the one aimed at you.
func _draw_gems() -> void:
	for g in _gems:
		var tex := Game.ore_texture(g.id)
		var s := Vector2(40, 40)
		if g.hit:
			_text("!", Vector2(g.p.x, _flame_pos().y - 140.0), 32, Config.SLICE_MISS_COLOR, title_font)
		_ci.draw_set_transform(g.p, float(g.spin), Vector2.ONE)
		_ci.draw_texture_rect(tex, Rect2(-s * 0.5, s), false)
		_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_mark(m: Dictionary) -> void:
	match m.t:
		"cells":
			_draw_cells(m.cells)
		"pit":  # where a chunk broke out: a dark hole with a lit lower lip and cracks round it
			_draw_cells(m.cells)
			var pts: PackedVector2Array = m.pts
			var p: Vector2 = m.p
			_pixel_poly(_offset(pts, Vector2(0, _g())), Config.CUT_EDGE_COLOR)
			_pixel_poly(pts, Config.CUT_COLOR)
			var inner := PackedVector2Array()
			for q in pts:
				inner.append(p + (q - p) * 0.62 + Vector2(0, -(q - p).length() * 0.12))
			_pixel_poly(inner, Config.CUT_COLOR.darkened(0.45))
		"hole":
			var r: float = m.r
			_draw_cells(m.cells)
			_pixel_disc(m.p + Vector2(0, _g()), r, Config.CUT_EDGE_COLOR)
			_pixel_disc(m.p, r, Config.CUT_COLOR)
			_pixel_disc(m.p + Vector2(0, -r * 0.25), r * 0.55, Config.CUT_COLOR.darkened(0.4))


## Stone chips go under the darkness (glow = false), sparks above it (glow = true).
func _draw_chips(glow: bool) -> void:
	for c in _chips:
		if c.get("glow", false) != glow:
			continue
		var col: Color = c.c
		col.a = clampf(c.life * 3.0, 0.0, 1.0)
		_ci.draw_rect(Rect2(c.p - Vector2.ONE * c.s * 0.5, Vector2.ONE * c.s), col)


## A circle's colour: each one in its own colour, in the order they close (Settings > Coloured circles),
## or all the same. A miss still flashes them all red.
func _tap_color(tg: Dictionary, col: Color) -> Color:
	if not Game.color_circles or _miss_flash > 0.0 or Config.TAP_COLORS.is_empty():
		return col
	return Config.TAP_COLORS[int(tg.get("order", 0)) % Config.TAP_COLORS.size()]


func _draw_tap(col: Color) -> void:
	var r := Config.TAP_RADIUS
	_draw_next_line(col)
	# draw the ones that close LAST first, so the most urgent circle is on top
	var order := _targets.duplicate()
	order.sort_custom(func(a, b): return a.hit_t > b.hit_t)
	for tg in order:
		if tg.state != 0 or _tap_clock < tg.spawn:
			continue
		var left: float = tg.hit_t - _tap_clock               # seconds until the ring closes
		var appr: float = tg.hit_t - tg.spawn
		var fade := clampf((_tap_clock - tg.spawn) / 0.15, 0.0, 1.0)
		var near := absf(left) <= Config.TAP_PERFECT_WINDOW
		var tc := _tap_color(tg, col)
		var body := Config.TEXT_OUTLINE_COLOR.lerp(tc, 0.22 if Game.color_circles else 0.0)
		body.a = 0.55 * fade
		_pixel_disc(tg.p, r, body)
		var ring_col := Config.SLICE_TRAIL_COLOR if near else tc
		ring_col.a = fade
		_pixel_ring(tg.p, r, 3, ring_col)
		_pixel_disc(tg.p, r * 0.22, ring_col)
		# the closing ring: big -> touches the circle at the right moment
		if left > -Config.TAP_GOOD_WINDOW:
			var k := clampf(left / maxf(appr, 0.01), 0.0, 1.0)
			var ar := r * (1.0 + (Config.TAP_APPROACH_SIZE - 1.0) * k)
			var ac := tc.lerp(Config.SLICE_TRAIL_COLOR, 1.0 - k)
			ac.a = fade * (0.55 + 0.45 * (1.0 - k))
			_pixel_ring(tg.p, ar + _g() * 2.0, 2, ac)


## Lines from circle to circle in the order they close, so you always know where to go next. The line
## that matters NOW (from the circle closing now to the next one) is long dashes with an arrow; the ones
## after it are just dots.
func _draw_next_line(col: Color) -> void:
	if not Config.TAP_NEXT_LINE:
		return
	var live: Array[Dictionary] = []
	for tg in _targets:
		if tg.state == 0 and _tap_clock >= tg.spawn:
			live.append(tg)
	if live.size() < 2:
		return
	live.sort_custom(func(x, y): return x.hit_t < y.hit_t)
	for i in live.size() - 1:
		var a: Vector2 = live[i].p
		var b: Vector2 = live[i + 1].p
		var d := b - a
		var gap := Config.TAP_RADIUS + 10.0
		if d.length() <= gap * 2.0 + 8.0:
			continue
		var dir := d.normalized()
		var from := a + dir * gap
		var to := b - dir * gap
		var fade := clampf((_tap_clock - float(live[i + 1].spawn)) / 0.25, 0.0, 1.0)
		var c := _tap_color(live[i + 1], col).lerp(Config.SLICE_TRAIL_COLOR, 0.35)
		var length := from.distance_to(to)
		if i == 0:
			# priority: long dashes + an arrow head
			c.a = 0.9 * fade
			var dash := 18.0
			var space := 8.0
			var u := 0.0
			while u < length:
				var e := minf(u + dash, length)
				var w := u
				while w <= e:
					_ci.draw_rect(_px_rect(Vector2(_cell(from + dir * w)), 2, 2), c)
					w += 3.0
				u += dash + space
			var tri := PackedVector2Array([to, to - dir * 14.0 + dir.orthogonal() * 8.0, to - dir * 14.0 - dir.orthogonal() * 8.0])
			_pixel_poly(tri, c)
		else:
			# later on: dots
			c.a = 0.8 * fade
			var steps := maxi(1, floori(length / 16.0))
			for k in steps + 1:
				_ci.draw_rect(_px_rect(Vector2(_cell(from.lerp(to, float(k) / steps))), 2, 2), c)


func _draw_path(col: Color) -> void:
	var slash := kind == "slash" or kind == "bigslash"
	var g := _g()
	var pulse := 0.65 + 0.35 * sin(_t * 6.0)
	if kind == "swirl":
		_draw_swirl_line(col)
	# guide dots ahead of the crack, on the pixel grid
	var dot := 3.0 if slash else 2.0
	var s := 0.0 if kind != "swirl" else INF
	while s <= _total:
		if not (_tracing and s <= _progress):
			var c := Vector2(_cell(_point_at(s))) - Vector2.ONE * floorf(dot * 0.5)
			var cc := col
			cc.a = pulse
			_ci.draw_rect(_px_rect(c + Vector2(0, 1), dot, dot), Color(0, 0, 0, 0.45 * pulse))
			_ci.draw_rect(_px_rect(c, dot, dot), cc)
		s += 24.0 if slash else 15.0
	# corners still to hit
	for i in range(_next_corner if _tracing else 0, _corners.size()):
		if kind == "swirl":  # bright checkpoints you can't miss
			var bright := col.lerp(Color.WHITE, 0.4)
			var big := i == (_next_corner if _tracing else 0)
			_pixel_ring(_corners[i], Config.ZIGZAG_CORNER_RADIUS * 0.45 + _g(), 2, Color(0, 0, 0, 0.5))
			_pixel_ring(_corners[i], Config.ZIGZAG_CORNER_RADIUS * 0.45, 2, Color(Config.SLICE_TRAIL_COLOR if big else bright, 0.75 + 0.25 * sin(_t * 8.0 + i)))
			_pixel_disc(_corners[i], 3.0, bright)
			continue
		var ca := 0.35 + 0.25 * sin(_t * 8.0 + i)
		_pixel_ring(_corners[i], Config.ZIGZAG_CORNER_RADIUS * 0.45, 1, Color(col, ca))
	# the crack you've made so far
	if _tracing:
		_draw_cells(_crack_cells, _crack_s.bsearch(_progress, false))
	# start dot
	var start := _path[0]
	if not _tracing:
		_pixel_ring(start, Config.SLICE_START_RADIUS * (0.55 + 0.15 * sin(_t * 5.0)), 1, col)
		_pixel_disc(start, 9.0, col)
	# pixel arrow head at the end
	var end := _path[_path.size() - 1]
	var dir := (end - _path[_path.size() - 3]).normalized()
	var tip := end + dir * 16.0
	var tri := PackedVector2Array([tip, end - dir * 6.0 + dir.orthogonal() * 13.0, end - dir * 6.0 - dir.orthogonal() * 13.0])
	_pixel_poly(_offset(tri, Vector2(0, g)), Color(0, 0, 0, 0.5))
	_pixel_poly(tri, col)
	# the tip of your pick
	if _tracing:
		var at := Vector2(_cell(_last_p)) - Vector2.ONE
		_ci.draw_rect(_px_rect(at - Vector2.ONE, 4, 4), Config.TEXT_OUTLINE_COLOR)
		_ci.draw_rect(_px_rect(at, 2, 2), Config.SLICE_TRAIL_COLOR)


## The swirl's guide: one smooth, bright, solid spiral (with a shadow) instead of faint dots, and a
## glint running along it towards the middle.
func _draw_swirl_line(col: Color) -> void:
	var bright := col.lerp(Color.WHITE, 0.35)
	var from := _progress if _tracing else 0.0
	for pass_i in 2:
		var s := from
		while s <= _total:
			var c := Vector2(_cell(_point_at(s)))
			if pass_i == 0:
				_ci.draw_rect(_px_rect(c + Vector2(0, 1), 2, 2), Color(0, 0, 0, 0.5))
			else:
				var glint := fposmod(s - _t * 320.0, 260.0) < 36.0
				_ci.draw_rect(_px_rect(c, 2, 2), Config.SLICE_TRAIL_COLOR if glint else Color(bright, 0.95))
			s += 3.0


func _draw_drill(col: Color) -> void:
	var r := Config.DRILL_RADIUS
	var at := _spot + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _jolt * 6.0
	var frac := float(_clicks) / maxf(_clicks_need, 1)
	_pixel_disc(at, r * 0.3 * frac + 5.0, Config.CUT_COLOR)  # the hole getting deeper
	_pixel_ring(at, r, 3, Color(col, 0.35))
	if frac > 0.0:
		_pixel_arc(at, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 3, Config.SLICE_TRAIL_COLOR)
	var pulse := 1.0 + 0.08 * sin(_t * 14.0)
	_pixel_ring(at, r * 0.62 * pulse, 1, col)
	_text(str(_clicks_need - _clicks), at + Vector2(0, 11), 30, Config.TEXT_COLOR, title_font)


## The moving drill: a ring that fills as you click it, with faint dots showing where it's heading.
func _draw_track(col: Color) -> void:
	var r := Config.TRACK_RADIUS
	var at := _spot + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _jolt * 5.0
	var frac := float(_clicks) / maxf(_clicks_need, 1)
	for k in range(1, 4):
		_pixel_disc(_track_pos_at(_track_time + k * 0.12), r * 0.16, Color(col, 0.3 - k * 0.07))
	_pixel_disc(at, r, Color(Config.TEXT_OUTLINE_COLOR, 0.45))
	_pixel_ring(at, r, 3, Color(col, 0.7))
	if frac > 0.0:
		_pixel_arc(at, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 3, Config.SLICE_TRAIL_COLOR)
	_text(str(_clicks_need - _clicks), at + Vector2(0, 11), 30, Config.TEXT_COLOR, title_font)


## The spinner: a big ring that fills as you turn, a marker going round, turns left in the middle.
func _draw_spin(col: Color) -> void:
	var r := Config.SPIN_RADIUS
	var frac := clampf(absf(_spin_net) / TAU / maxf(_spin_need, 0.5), 0.0, 1.0)
	_pixel_arc(_spin_c, r + _g() * 2.0, 0.0, TAU, 4, Color(0, 0, 0, 0.5))
	_pixel_ring(_spin_c, r, 2, Color(col, 0.45))
	if frac > 0.0:
		_pixel_arc(_spin_c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 3, Config.SLICE_TRAIL_COLOR)
	var a := _spin_last if _spin_have else _t * 3.0
	_pixel_disc(_spin_c + Vector2.RIGHT.rotated(a) * r, 9.0, Config.SLICE_TRAIL_COLOR if _spinning else col)
	_pixel_disc(_spin_c, 6.0, col)
	var left := maxf(_spin_need - absf(_spin_net) / TAU, 0.0)
	_text(String.num(ceilf(left * 2.0) / 2.0, 1).trim_suffix(".0"), _spin_c + Vector2(0, 12), 30, Config.TEXT_COLOR, title_font)
	if _spin_started:
		var tl := maxf(_spin_time() - _spin_t, 0.0)
		_text("%.1fs" % tl, _spin_c + Vector2(0, r + 34), 18, Config.SLICE_MISS_COLOR if tl < 1.0 else Config.TEXT_COLOR, font)
	else:
		_text("HOLD & SPIN", _spin_c + Vector2(0, r + 34), 20, Config.TEXT_COLOR, font)


func _draw_pry(col: Color) -> void:
	var r := Config.PRY_RADIUS
	_pixel_arc(_spot, r + _g() * 2.0, 0, TAU, 5, Color(0, 0, 0, 0.55))
	var good_a := _pry_angle(maxf(_zone.x - Config.PRY_GOOD_MARGIN, 0.0))
	var good_b := _pry_angle(minf(_zone.y + Config.PRY_GOOD_MARGIN, 1.0))
	_pixel_arc(_spot, r + _g(), good_a, good_b, 3, Color(col, 0.35))
	_pixel_arc(_spot, r + _g(), _pry_angle(_zone.x), _pry_angle(_zone.y), 3, col)
	# where the gauge starts (a notch) and which way it goes (a little arrow next to it)
	var a0 := _pry_angle(0.0)
	var out := Vector2.RIGHT.rotated(a0)
	_ci.draw_rect(_px_rect(Vector2(_cell(_spot + out * (r + 9.0))), 2, 2), Config.TEXT_COLOR)
	if _fill <= 0.0:
		var ah := _spot + Vector2.RIGHT.rotated(_pry_angle(0.06)) * (r + 12.0)
		var tang := Vector2.RIGHT.rotated(_pry_angle(0.06) + _pry_dir * PI * 0.5)
		_pixel_poly(PackedVector2Array([ah + tang * 8.0, ah - tang * 4.0 + tang.orthogonal() * 6.0,
				ah - tang * 4.0 - tang.orthogonal() * 6.0]), Config.TEXT_COLOR)
	if _fill > 0.0:
		_pixel_arc(_spot, r, a0, _pry_angle(_fill), 2, Config.SLICE_TRAIL_COLOR)
		var tip := _spot + Vector2.RIGHT.rotated(_pry_angle(_fill)) * r
		_pixel_disc(tip, 7.0, Config.SLICE_TRAIL_COLOR)
	# the wedge (wiggles while you pull)
	var wig := sin(_t * 40.0) * 3.0 * (_fill if _holding else 0.0)
	var w := PackedVector2Array([_spot + Vector2(-13 + wig, -18), _spot + Vector2(13 + wig, -18), _spot + Vector2(wig * 0.3, 20)])
	_pixel_poly(_offset(w, Vector2(0, _g())), Color(0, 0, 0, 0.5))
	_pixel_poly(w, Config.SLICE_TRAIL_COLOR if _holding else col)
	if not _holding:
		_text("HOLD", _spot + Vector2(0, r + 30), 20, Config.TEXT_COLOR, font)
	var style_txt: String = {"speedup": "speeds up!", "slowdown": "slows down", "stutter": "stutters"}.get(_pry_style, "")
	if style_txt != "":
		_text(style_txt, _spot + Vector2(0, r + (52 if not _holding else 30)), 16, Config.MUTED_TEXT, font)


## Action name, stage, lives, combo and wall progress across the top; the relight prompt in the middle.
func _draw_hud() -> void:
	var cx := size.x * 0.5
	var title := _title if kind != "" else ""
	var red := _miss_flash > 0.0
	if resting:
		title = ("STAGE %d CLEARED!" % (Game.stage - 1)) if _rest_cleared else "WALL DOWN!"
	elif _falling:
		title = "WALL DOWN!"
	elif light_state == "out":
		title = "LIGHTER'S OUT!"
		red = true
	elif light_state == "off":
		title = "STAGE %d" % Game.stage
	if title != "":
		_text(title, Vector2(cx, 46), 36, Config.SLICE_MISS_COLOR if red else Config.ACCENT, title_font)
	if kind != "" and light_state == "lit" and Game.show_hints:
		_text(KIND_INFO[kind][1], Vector2(cx, 70), 17, Config.TEXT_COLOR, font)
	if free_practice:
		var what := "no lives to lose" if practice in ["flick", "relight"] else "no lighter to look after"
		_text("PRACTICE   -   %s, no coins   -   Back to stop" % what, Vector2(cx, 98), 17, Config.TEXT_COLOR, font)
	elif practice != "":
		_text("PRACTICE - your lighter won't run out", Vector2(cx, 98), 16, Config.MUTED_TEXT, font)
	else:
		var line := "%s   -   Stage %d   -   Wall %d / %d" % [Game.cave_name(), Game.stage, mini(Game.stage_walls + 1, Game.walls_need), Game.walls_need]
		if Game.stage > 1:
			line += "   -   coins x%s" % _num(Game.stage_coin_mult())
		_text(line, Vector2(cx, 98), 17, Config.TEXT_COLOR, font)
		# actions left on this wall
		var done := actions_total - actions_left
		var pip := 12.0
		var px0 := cx - (actions_total * (pip + 6.0) - 6.0) * 0.5
		for i in actions_total:
			var r := Rect2(px0 + i * (pip + 6.0), 110, pip, pip)
			_ci.draw_rect(r.grow(2), Config.TEXT_OUTLINE_COLOR)
			_ci.draw_rect(r, Config.ACCENT if i < done else Config.PANEL_BORDER)
		_draw_lives()
	# combo (left side)
	if combo > 1:
		var pop := 1.0 + 0.15 * maxf(0.0, sin(_t * 9.0)) * minf(combo / 10.0, 1.0)
		_text("COMBO x%d" % combo, Vector2(150, 104), int(32 * pop), Config.ACCENT, title_font)  # under the lives
		_text("coins x%s" % _num(combo_multiplier()), Vector2(150, 128), 18, Config.TEXT_COLOR, font)
	if _run_on() and Game.has_item("midas_touch"):  # Midas: the multiplier and the pot at stake
		var glow := 0.75 + 0.25 * sin(_t * 3.0)
		_text("MIDAS x%s" % _num(Game.midas), Vector2(150, 162), 26, Color(1.0, 0.85 * glow + 0.1, 0.3), title_font)
		_text("pot: %d coins" % Game.run_pot, Vector2(150, 186), 17, Config.ACCENT, font)
	if _torch() and not resting:
		_text("TORCH: no flicking this stage", Vector2(size.x * 0.5, 140), 17, Config.ACCENT, font)
	if _cats_eyes() and light_state == "lit" and not resting and not _falling:
		_text("CAT'S EYES: no flicking - but every miss costs 25% wick", Vector2(size.x * 0.5, 162), 17, Config.TEXT_COLOR, font)
	if resting:
		_draw_rest()
		return
	if _falling or rise < 1.0:
		return
	if light_state == "out":
		_draw_relight()
	elif light_state == "off" and fmod(_t, 1.0) < 0.75 and Game.show_hints:
		var msg := "Flick SPACE (or tap the lighter) to light it" if _lid_target < 1.0 else "Keep flicking! It hasn't caught yet"
		_text(msg, Vector2(size.x * 0.5 + 60, size.y * 0.5 - 20), 30, Config.ACCENT, title_font)


## The break between walls: a box in the middle; click or SPACE when you're ready.
func _draw_rest() -> void:
	if rest_ui_external:
		return
	var c := Vector2(size.x * 0.5 + 60, size.y * 0.5 - 30)
	var box := Rect2(c - Vector2(290, 92), Vector2(580, 184))
	_ci.draw_rect(box.grow(6), Config.TEXT_OUTLINE_COLOR)
	_ci.draw_rect(box, Color(Config.PANEL_COLOR, 0.92))
	_ci.draw_rect(Rect2(box.position, Vector2(box.size.x, 4)), Config.ACCENT)
	var head := "Stage cleared - take a breather" if _rest_cleared else "Take a breather"
	_text(head, c + Vector2(0, -48), 28, Config.ACCENT, title_font)
	_text("Your light, wick and timers are paused while you rest.", c + Vector2(0, -12), 17, Config.TEXT_COLOR, font)
	var next := "Next: Stage %d, wall %d / %d" % [Game.stage, mini(Game.stage_walls + 1, Game.walls_need), Game.walls_need]
	_text(next, c + Vector2(0, 16), 17, Config.MUTED_TEXT, font)
	var blink := 0.65 + 0.35 * sin(_t * 4.0)
	_text("Click or press SPACE for the next wall", c + Vector2(0, 60), 24, Color(Config.SLICE_TRAIL_COLOR, blink), title_font)


## Lives: one little lighter each (dark = lost), top right.
func _draw_lives() -> void:
	if _lighter_frames.is_empty():
		return
	var tex := _lighter_frames[0]
	var region := Rect2(40, 29, 41, 51)  # the closed lighter on the frame canvas
	var slots := ceili(Game.max_lives() - 0.001)  # Pack of Fluid adds lighters (half ones too)
	var x0 := 24.0  # top-left corner (the Back button has the top-right)
	_text("LIVES", Vector2(x0 + slots * 50.0 + 34.0, 50), 18, Config.TEXT_COLOR, font)
	var dim := Color(0.25, 0.22, 0.22, 0.8)
	for i in slots:
		var r := Rect2(Vector2(x0 + i * 50.0, maxf(14.0, float(Config.SAFE_BORDER))), region.size)
		var left := Game.lives - i  # >= 1 full, 0.5 half, <= 0 lost
		if left >= 1.0:
			_ci.draw_texture_rect_region(tex, r, region, Color.WHITE)
		elif left >= 0.5:  # half a life: left half lit, right half dark
			var hw := floorf(region.size.x * 0.5)
			_ci.draw_texture_rect_region(tex, Rect2(r.position, Vector2(hw, r.size.y)), Rect2(region.position, Vector2(hw, region.size.y)), Color.WHITE)
			_ci.draw_texture_rect_region(tex, Rect2(r.position + Vector2(hw, 0), Vector2(r.size.x - hw, r.size.y)),
					Rect2(region.position + Vector2(hw, 0), Vector2(region.size.x - hw, region.size.y)), dim)
		else:
			_ci.draw_texture_rect_region(tex, r, region, dim)


## The relight timing game: a marker sweeps the track; strike SPACE while it's in the gold zone.
## The bar on the right drops with every good strike - get it to the bottom before time runs out.
func _draw_relight() -> void:
	var c := Vector2(size.x * 0.5 + 60, size.y * 0.5 - 60)
	if Game.show_hints:
		_text("Hit SPACE (or tap the lighter) in the gold zone!", c + Vector2(0, -34), 26, Config.ACCENT, title_font)
	# the track
	var track := Rect2(c.x - 230, c.y - 17, 460, 34)
	_ci.draw_rect(track.grow(4), Config.TEXT_OUTLINE_COLOR)
	_ci.draw_rect(track, Config.SLICE_MISS_COLOR.darkened(0.5) if _meter_miss > 0.0 else Config.PANEL_COLOR)
	var zone := Rect2(track.position.x + (_zone_c - _zone_w * 0.5) * track.size.x, track.position.y, _zone_w * track.size.x, track.size.y)
	_ci.draw_rect(zone, Config.SLICE_TRAIL_COLOR if _meter_hit > 0.0 else Config.ACCENT)
	_ci.draw_rect(Rect2(zone.position, Vector2(zone.size.x, 5)), Config.SLICE_TRAIL_COLOR)
	var mx := track.position.x + _meter * track.size.x
	var marker := Rect2(mx - 4, track.position.y - 10, 8, track.size.y + 20)
	_ci.draw_rect(marker.grow(3), Config.TEXT_OUTLINE_COLOR)
	_ci.draw_rect(marker, Config.SLICE_MISS_COLOR if _meter_miss > 0.0 else Config.TEXT_COLOR)
	_text("speed x%s" % _num(snappedf(_meter_speed / Config.RELIGHT_SPEED, 0.1)), Vector2(track.position.x + 50, track.end.y + 26), 16, Config.MUTED_TEXT, font)
	# the bar that goes lower with every good strike
	var bar := Rect2(track.end.x + 34, c.y - 80, 30, 160)
	var left := float(relight_need - relight_hits) / maxf(relight_need, 1)
	_ci.draw_rect(bar.grow(4), Config.TEXT_OUTLINE_COLOR)
	_ci.draw_rect(bar, Config.PANEL_COLOR)
	var fill := Rect2(bar.position.x, bar.end.y - bar.size.y * left, bar.size.x, bar.size.y * left)
	_ci.draw_rect(fill, Config.SLICE_MISS_COLOR if _meter_miss > 0.0 else Color("#ff9a3c"))
	_ci.draw_rect(Rect2(fill.position, Vector2(fill.size.x, minf(4.0, fill.size.y))), Color("#ffd166"))
	for i in range(1, relight_need):
		var y := bar.end.y - bar.size.y * float(i) / relight_need
		_ci.draw_rect(Rect2(bar.position.x, y - 1, bar.size.x, 2), Config.TEXT_OUTLINE_COLOR)
	_text("%d" % (relight_need - relight_hits), Vector2(bar.get_center().x, bar.end.y + 30), 24, Config.TEXT_COLOR, title_font)
	if practice != "":
		return
	# countdown before you lose a life
	var frac := clampf(relight_left / maxf(Config.RELIGHT_TIME, 0.01), 0.0, 1.0)
	var cd := Rect2(track.position.x + 110, track.end.y + 14, 240, 12)
	var cols: Array = Config.TIMER_COLORS
	var col: Color = cols[0].lerp(cols[1], clampf((1.0 - frac) * 2.0, 0.0, 1.0)) if frac > 0.5 else cols[1].lerp(cols[2], clampf(1.0 - frac * 2.0, 0.0, 1.0))
	if frac < 0.3 and fmod(_t, 0.3) < 0.15:
		col = col.lightened(0.4)
	_ci.draw_rect(cd.grow(3), Config.TEXT_OUTLINE_COLOR)
	_ci.draw_rect(cd, Config.PANEL_COLOR)
	_ci.draw_rect(Rect2(cd.position, Vector2(cd.size.x * frac, cd.size.y)), col)
	_text("%.1fs or lose a life" % maxf(relight_left, 0.0), Vector2(cd.get_center().x, cd.end.y + 24), 16, Config.TEXT_COLOR, font)


func _num(v: float) -> String:
	return str(snappedf(v, 0.01)).trim_suffix(".0")


func _text(s: String, center_baseline: Vector2, fs: int, col: Color, f: Font = null) -> void:
	if f == null:
		f = font if font else get_theme_default_font()
	fs = Config.font_px(fs)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(center_baseline.x - w * 0.5, center_baseline.y).round()
	if Config.TEXT_SHADOW_COLOR.a > 0.0:  # drop shadow under the outlined text
		var sh := Color(Config.TEXT_SHADOW_COLOR, Config.TEXT_SHADOW_COLOR.a * col.a)
		var sp := p + Vector2(Config.TEXT_SHADOW_OFFSET)
		if Config.TEXT_OUTLINE_SIZE > 0:
			_ci.draw_string_outline(f, sp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Config.TEXT_OUTLINE_SIZE + 2, sh)
		_ci.draw_string(f, sp, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, sh)
	if Config.TEXT_OUTLINE_SIZE > 0:
		_ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Config.TEXT_OUTLINE_SIZE + 2, Color(Config.TEXT_OUTLINE_COLOR, col.a))
	_ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ------------------------------------------------------------------ dev
## Finishes the current action automatically (used by the screenshot demo). sloppy = not perfect.
func dev_do(sloppy := false, stop_at := 1.0) -> void:
	match kind:
		"tap":
			var order := _targets.duplicate()
			order.sort_custom(func(a, b): return a.hit_t < b.hit_t)
			for tg in order:
				_tap_clock = tg.hit_t + (0.15 if sloppy else 0.0)
				press(tg.p)
		"zigzag", "slash", "swirl", "bigslash":
			_dev_trace(28.0 if sloppy else 3.0, stop_at)
		"spin":
			var r := Config.SPIN_RADIUS * 0.8
			press(_spin_c + Vector2.RIGHT * r)
			for k in 400:
				if kind != "spin":
					break
				_spin_move(_spin_c + Vector2.RIGHT.rotated(k * 0.35) * r)
		"drill":
			for i in _clicks_need:
				press(_spot + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
				release(_spot)
		"pry":
			press(_spot)
			_fill = (_zone.y + Config.PRY_GOOD_MARGIN * 0.5) if sloppy else (_zone.x + _zone.y) * 0.5
			_pry_t = _fill  # (only used for the snap; close enough for the demo)
			if stop_at >= 1.0:
				release(_spot)


func _dev_trace(wobble: float, stop_at: float) -> void:
	press(_path[0])
	var s := 0.0
	while s <= _total * stop_at and _tracing:
		var p := _point_at(s)
		var i := clampi(int(s / maxf(_total, 1.0) * (_path.size() - 1)), 0, _path.size() - 2)
		var normal := (_path[i + 1] - _path[i]).normalized().orthogonal()
		drag(p + normal * sin(s * 0.05) * wobble)
		s += 8.0


## Dev check: tries to cut straight across the current zigzag. Returns true if it got through (bad).
func dev_shortcut() -> bool:
	if kind != "zigzag":
		return false
	var a := _path[0]
	var b := _path[_path.size() - 1]
	press(a)
	var steps := ceili(a.distance_to(b) / 8.0)
	for k in steps + 1:
		if not _tracing:
			return false
		drag(a.lerp(b, float(k) / steps))
	return kind != "zigzag"


## Dev check: generates n tap actions and counts circles that land where they can't be clicked
## (off the wall, under the lighter, or under an optional blocking rect such as a button / panel).
func dev_check_taps(n: int, blockers: Array) -> Dictionary:
	var bad := {"off_wall": 0, "lighter": 0, "blocked": 0, "total": 0}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in n:
		new_action("tap")
		for tg in _targets:
			var p: Vector2 = tg.p
			bad.total += 1
			lo = lo.min(p)
			hi = hi.max(p)
			if not Rect2(Vector2.ZERO, size).grow(-Config.TAP_RADIUS).has_point(p):
				bad.off_wall += 1
			if _lighter_box().has_point(p):
				bad.lighter += 1
			for r in blockers:
				if (r as Rect2).grow(Config.TAP_RADIUS * 0.5).has_point(p):
					bad.blocked += 1
	bad["min"] = lo
	bad["max"] = hi
	bad["size"] = size
	return bad
