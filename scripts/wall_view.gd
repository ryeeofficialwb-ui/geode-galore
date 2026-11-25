class_name WallView
extends Control
## The mining wall (left screen). Fills itself with the wall tile and asks for one ACTION at a time:
##   tap    - circles pop up with a ring closing in on each; tap each one as its ring closes
##   zigzag - crack a zigzag into the wall from the glowing dot, passing every corner
##   slash  - one big, fast swipe along a long line
##   drill  - spam-click the same spot
##   pry    - hold on the wedge, let go while the gauge is in the gold zone
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
signal full_light   # the flame just reached full blaze (main flashes the screen)   # flicked a full lighter: half a life gone
signal stage_up(stage: int, at: Vector2)

const SAMPLES := 48
const STEP := 6.0               # px between checks while tracing (fast mouse moves are filled in)
const DENSIFY := 12.0           # px between path points on zigzags
const FLAME_ANCHOR := Vector2(64.5, 30)  # bottom-centre of the flame on the lighter art
const WHEEL := Vector2(71, 33)           # flint wheel on the lighter art (sparks come from here)
const MAX_MARKS := 14           # oldest cracks fade out after this many (only matters while practising)
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const KIND_INFO := {            # title, hint
	"tap": ["TAP!", "Tap each circle when its ring closes in"],
	"zigzag": ["ZIGZAG!", "Crack it from the glowing dot, hit every corner"],
	"slash": ["SLASH!", "One fast swipe from the glowing dot"],
	"drill": ["DRILL!", "Spam-click the same spot"],
	"pry": ["PRY!", "Hold on the wedge, let go in the gold zone"],
}

var tile_tex: Texture2D
var font: Font                  # set by main (falls back to the theme font)
var title_font: Font
var active := false             # set by main: the timer only runs while you're looking at the wall
var practice := ""              # tutorial: only this action, no timer, the wall never crumbles
var reserve_bottom := 0.0       # tutorial: keep actions above its panel
var actions_total := 0
var actions_left := 0
var combo := 0
var kind := ""                  # current action ("" = between actions)
var rise := 1.0                 # new-wall drop-in animation 0..1 (tweened)

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
var _flame_tex: Texture2D        # old single flame (used only if there are no flame_N.png frames)
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
var _strays := 0                        # misses during the action: no PERFECT
var _jolt := 0.0
# looks
var _marks: Array[Dictionary] = []     # what earlier actions left on this wall
var _chips: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _falling := false
var _miss_flash := 0.0
var _t := 0.0
var _gen := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	tile_tex = load(Config.WALL_TILE_FILE) if ResourceLoader.exists(Config.WALL_TILE_FILE) else Game.rock_texture("missing")
	_tile_img = tile_tex.get_image()
	for i in 32:
		var f := Config.LIGHTER_DIR + "lighter_%d.png" % i
		if not ResourceLoader.exists(f):
			break
		_lighter_frames.append(load(f))
	if ResourceLoader.exists(Config.LIGHTER_DIR + "flame.png"):
		_flame_tex = load(Config.LIGHTER_DIR + "flame.png")
	for i in 64:
		var f := Config.LIGHTER_DIR + "flame_%d.png" % i
		if not ResourceLoader.exists(f):
			break
		_flame_frames.append(load(f))
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


func _tile_px() -> float:
	return tile_tex.get_width() * Config.WALL_TILE_SCALE


func combo_multiplier() -> float:
	return minf(1.0 + maxi(combo - 1, 0) * Config.COMBO_BONUS_PER_STEP, Config.COMBO_MAX_MULTIPLIER)


## Where actions may appear: away from the edges, the timer at the top and the Back button.
func _area() -> Rect2:
	var m: Vector4 = Config.WALL_MARGINS  # left, top, right, bottom
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
	_falling = false
	_pieces.clear()
	_marks.clear()
	actions_total = randi_range(Config.WALL_ACTIONS_MIN, Config.WALL_ACTIONS_MAX)
	actions_left = actions_total
	rise = 0.0
	create_tween().tween_property(self, "rise", 1.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	new_action()


## Tutorial: keep asking for this one action (no timer). "relight" = practise relighting.
## "" = back to normal.
func set_practice(k: String) -> void:
	practice = k
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
			var z := randf_range(Config.PRY_ZONE_MIN, Config.PRY_ZONE_MAX)
			_zone = Vector2(z, minf(z + Config.PRY_ZONE_SIZE, 0.97))
	queue_redraw()


func _pick_kind() -> String:
	var pool := {}
	for k in Config.ACTION_WEIGHTS:
		if KIND_INFO.has(k) and float(Config.ACTION_WEIGHTS[k]) > 0.0:
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
	_strays = 0
	_max_dev = 0.0
	_progress = 0.0
	_sound_s = 0.0


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
	for i in n:
		var p := _free_point(inner, Config.TAP_RADIUS)
		for attempt in 30:  # keep circles apart (and off the lighter)
			var ok := not _lighter_box().grow(Config.TAP_RADIUS).has_point(p)
			for tg in _targets:
				if p.distance_to(tg.p) < Config.TAP_RADIUS * 3.0:
					ok = false
			if ok:
				break
			p = _free_point(inner, Config.TAP_RADIUS)
		if i > 0:
			hit_t += randf_range(Config.TAP_GAP_MIN, Config.TAP_GAP_MAX) * speed
		var spawn := hit_t - randf_range(Config.TAP_APPROACH_MIN, Config.TAP_APPROACH_MAX) * speed
		earliest = minf(earliest, spawn)
		_targets.append({"p": p, "spawn": spawn, "hit_t": hit_t, "state": 0, "perfect": false})
	var shift := 0.35 - earliest  # first circle appears a moment after the action starts
	for tg in _targets:
		tg.spawn += shift
		tg.hit_t += shift
	_tap_clock = 0.0


func _zigzag_points(area: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for attempt in 60:
		var corners := randi_range(Config.ZIGZAG_CORNERS_MIN, Config.ZIGZAG_CORNERS_MAX)
		var length := randf_range(Config.ZIGZAG_LENGTH_MIN, minf(Config.ZIGZAG_LENGTH_MAX, area.size.length() * 0.75))
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var side := dir.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		var center := _rand_in(area)
		var start := center - dir * length * 0.5
		var corner_pts := PackedVector2Array()
		for i in corners + 2:
			var t := float(i) / (corners + 1)
			var amp := Config.ZIGZAG_WIDTH * randf_range(0.75, 1.0) * (1.0 if i % 2 == 0 else -1.0)
			if i == 0 or i == corners + 1:
				amp *= 0.4
			corner_pts.append(start + dir * length * t + side * amp)
		pts = _densify(corner_pts)
		_corners = PackedVector2Array()
		_corner_s = PackedFloat32Array()
		var s := 0.0
		for i in range(1, corner_pts.size()):
			s += corner_pts[i - 1].distance_to(corner_pts[i])
			if i < corner_pts.size() - 1:  # the inner corners (not start / end)
				_corners.append(corner_pts[i])
				_corner_s.append(s)
		if _all_inside(pts, area):
			break
	return pts


func _slash_points(area: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for attempt in 60:
		var length := randf_range(Config.SLASH_LENGTH_MIN, minf(Config.SLASH_LENGTH_MAX, area.size.length() * 0.85))
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
			break
	return pts


func _densify(corners: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([corners[0]])
	for i in corners.size() - 1:
		var steps := maxi(1, ceili(corners[i].distance_to(corners[i + 1]) / DENSIFY))
		for k in steps:
			out.append(corners[i].lerp(corners[i + 1], float(k + 1) / steps))
	return out


func _all_inside(pts: PackedVector2Array, area: Rect2) -> bool:
	var box := _lighter_box().grow(20)
	for p in pts:
		if not area.has_point(p) or box.has_point(p):
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
		"zigzag", "slash":
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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and lighter_hit(event.position):
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


func press(p: Vector2) -> void:
	if not can_act():
		return
	match kind:
		"tap":
			_tap(p)
		"zigzag", "slash":
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
		"pry":
			if p.distance_to(_spot) > Config.PRY_RADIUS:
				missed.emit("Hold on the wedge!", p)
				return
			_holding = true
			_fill = 0.0


func release(p: Vector2) -> void:
	if _tracing:
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
		if tg.state != 0 or _tap_clock < tg.spawn or p.distance_to(tg.p) > Config.TAP_RADIUS:
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
	wick = maxf(wick - amount, 0.0)
	light = minf(light, wick)


func _tap_miss(tg: Dictionary, reason: String) -> void:
	_burn_wick(Config.MISS_WICK_COST)
	tg.state = 2
	_strays += 1
	_miss_flash = 0.25
	if Config.MISS_BREAKS_COMBO:
		combo = 0
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
	if p.distance_to(_spot) > Config.DRILL_RADIUS:
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


func _pry_out(perfect: bool) -> void:
	var dir := Vector2.DOWN.rotated(randf_range(-0.6, 0.6))
	_marks.append({"t": "cells", "cells": _crack_line(_spot - dir * 34.0, _spot + dir * 34.0, 3)})
	_spray(_spot, 16)
	Sfx.play("pry")
	_complete(perfect, _spot)


func drag(p: Vector2) -> void:
	if not _tracing:
		return
	var slash := kind == "slash"
	var ok_tol := Config.SLASH_OK_TOLERANCE if slash else Config.ZIGZAG_OK_TOLERANCE
	var ahead := Config.SLASH_LOOKAHEAD if slash else Config.ZIGZAG_LOOKAHEAD
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
		var perfect := _max_dev <= (Config.SLASH_PERFECT_TOLERANCE if slash else Config.ZIGZAG_PERFECT_TOLERANCE)
		_marks.append({"t": "cells", "cells": _crack_cells.duplicate()})
		_spray(p, 8)
		_complete(perfect, p)
	queue_redraw()


func _stray(p: Vector2, reason: String) -> void:
	_burn_wick(Config.MISS_WICK_COST)
	_strays += 1
	_miss_flash = 0.25
	if Config.MISS_BREAKS_COMBO:
		combo = 0
	missed.emit(reason, p)


func _miss(reason: String, at: Vector2) -> void:
	_burn_wick(Config.MISS_WICK_COST)
	_tracing = false
	_holding = false
	_fill = 0.0
	_progress = 0.0
	_next_corner = 0
	_miss_flash = 0.4
	if Config.MISS_BREAKS_COMBO:
		combo = 0
	missed.emit(reason, at)
	queue_redraw()


func _complete(perfect: bool, at: Vector2) -> void:
	wick = 1.0  # finishing the motion is the only thing that gives the wick back
	while _marks.size() > MAX_MARKS:
		_marks.pop_front()
	var done_kind := kind
	kind = ""
	_reset_input()
	if perfect or not Config.COMBO_NEEDS_PERFECT:
		combo += 1
	else:
		combo = 0
	action_done.emit(perfect, at, combo, combo_multiplier())
	if practice != "":
		practiced.emit(done_kind)
	else:
		actions_left -= 1
	if actions_left <= 0 and practice == "":
		_crumble()
	else:
		_next_action_soon()
	queue_redraw()


func _next_action_soon() -> void:
	var g := _gen
	get_tree().create_timer(Config.ACTION_GAP).timeout.connect(func():
		if g == _gen and kind == "" and not _falling:
			new_action())


## Fuel ran out or every circle was missed: combo lost, and the lighter goes out with it.
func _fail(reason: String, at: Vector2) -> void:
	var lost := combo
	combo = 0
	kind = ""
	_reset_input()
	_miss_flash = 0.5
	failed.emit(reason, lost, at)
	if practice != "":
		_next_action_soon()  # the tutorial keeps the lighter lit
	else:
		_go_out()


## The light faded all the way: combo lost, lighter out.
func _light_died() -> void:
	light = 0.0
	_fail("Your light died!", _flame_pos() + Vector2(160, -60))


# ------------------------------------------------------------------ the lighter
func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode == Config.LIGHTER_KEY:
		flick()
		get_viewport().set_input_as_handled()


## SPACE: open the lighter / strike the wheel.
## Out: only a strike while the marker is in the gold zone counts. Each good strike lowers the bar,
## speeds the marker up and shrinks the zone; a mistimed one pushes the bar back up.
func flick() -> void:
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
			if _hold > 0.0 and light >= Config.FLOOD_AT:
				_flood()  # flicked during the steady full blaze
				return
			if light >= wick - 0.001:
				# the wick is spent this far: flicking can't help, finish the action!
				_shake_l = maxf(_shake_l, 0.3)
				Sfx.play("misfire", 1.3)
				_pop(_flame_pos() + Vector2(190, 70), "Wick's burnt down - finish it!", Config.SLICE_MISS_COLOR)
				return
			light = minf(light + randf_range(Config.RECHARGE_MIN, Config.RECHARGE_MAX) / 100.0, wick)
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
	return Vector2(Config.LIGHTER_POS.x, size.y - Config.LIGHTER_POS.y) + lean + bob + _shake_off


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
	var steps := float(maxi(Config.LIGHT_STEPS, 1))
	var a := ceilf(pow(fuel(), Config.LIGHT_CURVE) * steps - 0.0001) / steps
	a *= 1.0 - Config.LIGHT_FLICKER * 0.5 * (1.0 + sin(_t * 23.0) * sin(_t * 37.0))
	if fuel() < 0.2 and light_state == "lit" and fmod(_t, 0.17) < 0.05:
		a *= 0.8  # sputtering
	return a * _glow


## The glow around the lighter itself (and the flash of sparks when you strike it).
func _halo_radius() -> float:
	var r := Config.LIGHTER_GLOW_RADIUS * lerpf(Config.GLOW_MIN, 1.0, fuel()) * (1.0 + Config.LIGHT_FLICKER * sin(_t * 29.0))
	return r * _glow + 150.0 * _spark


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
	if practice == "" and Game.wall_cleared():
		stage_up.emit(Game.stage, mid)
	await get_tree().create_timer(Config.WALL_RESPAWN_DELAY).timeout
	new_wall()


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
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lighter_hit(_mouse) else Control.CURSOR_CROSS
	_lid = move_toward(_lid, _lid_target, delta / maxf(Config.LIGHTER_LID_TIME, 0.01))
	var glow_to := 1.0 if light_state == "lit" and _lid >= 1.0 else 0.0
	_glow = move_toward(_glow, glow_to, delta * (5.0 if glow_to > _glow else 2.5))
	_spark = maxf(_spark - delta * 6.0, 0.0)
	_shake_l = maxf(_shake_l - delta * 4.0, 0.0)
	var tremble := Config.DANGER_SHAKE * danger()
	_shake_off = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (_shake_l * 10.0 + tremble)).round()
	_meter_hit = maxf(_meter_hit - delta, 0.0)
	_meter_miss = maxf(_meter_miss - delta, 0.0)
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
				_lose_life()
	_miss_flash = maxf(_miss_flash - delta, 0.0)
	_jolt = maxf(_jolt - delta * 8.0, 0.0)
	if active and light_state == "lit" and not _falling and rise >= 1.0:
		if _hold > 0.0:
			_hold -= delta  # still at full blaze
		else:
			light -= delta / maxf(Config.LIGHT_DURATION * Game.stage_fuel_factor(), 0.1)
		if kind != "" and practice == "" and _hold <= 0.0:
			wick -= delta / maxf(Config.WICK_TIME * Game.stage_fuel_factor(), 0.1)
		light = minf(light, maxf(wick, 0.0))
		if practice != "":
			light = maxf(light, 0.15)  # the tutorial lets you practise flicking without going out
		elif light <= 0.0:
			_light_died()
	if active and can_act():
		if kind == "tap":
			_tap_clock += delta
			for tg in _targets.duplicate():
				if kind != "tap":
					break  # the action just ended
				if tg.state == 0 and _tap_clock > tg.hit_t + Config.TAP_GOOD_WINDOW:
					_tap_miss(tg, "Missed!")
		if _tracing:
			_swipe_t += delta
			if kind == "slash" and _swipe_t > Config.SLASH_SWIPE_TIME:
				_miss("Too slow, swipe it!", _last_p)
		if _holding:
			_fill += delta / Config.PRY_FILL_TIME
			if _fill >= 1.0:
				_spray(_spot, 6)
				_miss("Snapped! Let go sooner", _spot)
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


func _update_layers() -> void:
	_dark.size = size
	_top.size = size
	var mat := _dark.material as ShaderMaterial
	mat.set_shader_parameter("rect_size", size)
	mat.set_shader_parameter("ambient", _ambient())
	var halo := _flame_pos() - Vector2(0, 80 * lerpf(Config.FLAME_MIN_SIZE, 1.0, fuel()))
	mat.set_shader_parameter("light1", Vector4(halo.x, halo.y, _halo_radius(), 0.0))
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
	if can_act():
		var col := Config.SLICE_MISS_COLOR if _miss_flash > 0.0 else Config.SLICE_GUIDE_COLOR
		match kind:
			"tap": _draw_tap(col)
			"zigzag", "slash": _draw_path(col)
			"drill": _draw_drill(col)
			"pry": _draw_pry(col)
	_draw_chips(false)


## Top layer (above the darkness): sparks, your lighter, little texts and the HUD.
## Where the wick gauge sits: the bottom-right corner of the screen (outside the area actions use).
func wick_gauge_rect() -> Rect2:
	var sc := float(Config.LIGHTER_SCALE)
	var cells := Vector2i(5, int(Config.WICK_GAUGE_HEIGHT / sc))  # 1 frame + 3 wick + 1 frame wide
	var sz := Vector2(cells) * sc
	return Rect2((size - sz - Config.WICK_GAUGE_MARGIN).round(), sz)


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


func _draw_top() -> void:
	_ci = _top
	_draw_chips(true)
	_draw_lighter()
	_draw_wick_gauge()
	for pp in _pops:
		var c: Color = pp.c
		c.a = clampf(pp.life * 3.0, 0.0, 1.0)
		_text(pp.text, pp.p - Vector2(0, Config.TAP_RADIUS + 8), 20, c, title_font)
	_draw_hud()
	_ci = self


## Your lighter, held at the left like a torch. Lid frame from the open/close animation; the flame is the timer.
func _draw_lighter() -> void:
	if _lighter_frames.is_empty():
		return
	var sc := float(Config.LIGHTER_SCALE)
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
		var ftex := _flame_frames[int(_t * Config.FLAME_FPS) % _flame_frames.size()]
		var fs := (ftex.get_size() * sc * k).round()
		var bottom := base + Vector2(0, Config.FLAME_SINK * sc)
		_ci.draw_texture_rect(ftex, Rect2((bottom - Vector2(fs.x * 0.5, fs.y)).round(), fs), false)
	elif _flame_tex:
		var fs := (_flame_tex.get_size() * sc * Vector2(0.85 + 0.15 * k, k)).round()
		_ci.draw_texture_rect(_flame_tex, Rect2((base - Vector2(fs.x * 0.5, fs.y)).round(), fs), false)


func _draw_mark(m: Dictionary) -> void:
	match m.t:
		"cells":
			_draw_cells(m.cells)
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


func _draw_tap(col: Color) -> void:
	var r := Config.TAP_RADIUS
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
		var body := Config.TEXT_OUTLINE_COLOR
		body.a = 0.55 * fade
		_pixel_disc(tg.p, r, body)
		var ring_col := Config.SLICE_TRAIL_COLOR if near else col
		ring_col.a = fade
		_pixel_ring(tg.p, r, 3, ring_col)
		_pixel_disc(tg.p, r * 0.22, ring_col)
		# the closing ring: big -> touches the circle at the right moment
		if left > -Config.TAP_GOOD_WINDOW:
			var k := clampf(left / maxf(appr, 0.01), 0.0, 1.0)
			var ar := r * (1.0 + (Config.TAP_APPROACH_SIZE - 1.0) * k)
			var ac := col.lerp(Config.SLICE_TRAIL_COLOR, 1.0 - k)
			ac.a = fade * (0.55 + 0.45 * (1.0 - k))
			_pixel_ring(tg.p, ar + _g() * 2.0, 2, ac)


func _draw_path(col: Color) -> void:
	var slash := kind == "slash"
	var g := _g()
	var pulse := 0.65 + 0.35 * sin(_t * 6.0)
	# guide dots ahead of the crack, on the pixel grid
	var dot := 3.0 if slash else 2.0
	var s := 0.0
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


func _draw_pry(col: Color) -> void:
	var r := Config.PRY_RADIUS
	var top := -PI * 0.5
	_pixel_arc(_spot, r + _g() * 2.0, 0, TAU, 5, Color(0, 0, 0, 0.55))
	var good_a := top + TAU * maxf(_zone.x - Config.PRY_GOOD_MARGIN, 0.0)
	var good_b := top + TAU * minf(_zone.y + Config.PRY_GOOD_MARGIN, 1.0)
	_pixel_arc(_spot, r + _g(), good_a, good_b, 3, Color(col, 0.35))
	_pixel_arc(_spot, r + _g(), top + TAU * _zone.x, top + TAU * _zone.y, 3, col)
	if _fill > 0.0:
		_pixel_arc(_spot, r, top, top + TAU * _fill, 2, Config.SLICE_TRAIL_COLOR)
		var tip := _spot + Vector2.RIGHT.rotated(top + TAU * _fill) * r
		_pixel_disc(tip, 7.0, Config.SLICE_TRAIL_COLOR)
	# the wedge (wiggles while you pull)
	var wig := sin(_t * 40.0) * 3.0 * (_fill if _holding else 0.0)
	var w := PackedVector2Array([_spot + Vector2(-13 + wig, -18), _spot + Vector2(13 + wig, -18), _spot + Vector2(wig * 0.3, 20)])
	_pixel_poly(_offset(w, Vector2(0, _g())), Color(0, 0, 0, 0.5))
	_pixel_poly(w, Config.SLICE_TRAIL_COLOR if _holding else col)
	if not _holding:
		_text("HOLD", _spot + Vector2(0, r + 30), 20, Config.TEXT_COLOR, font)


## Action name, stage, lives, combo and wall progress across the top; the relight prompt in the middle.
func _draw_hud() -> void:
	var cx := size.x * 0.5
	var title := _title if kind != "" else ""
	var red := _miss_flash > 0.0
	if _falling:
		title = "WALL DOWN!"
	elif light_state == "out":
		title = "LIGHTER'S OUT!"
		red = true
	elif light_state == "off":
		title = "STAGE %d" % Game.stage
	if title != "":
		_text(title, Vector2(cx, 46), 36, Config.SLICE_MISS_COLOR if red else Config.ACCENT, title_font)
	if kind != "" and light_state == "lit":
		_text(KIND_INFO[kind][1], Vector2(cx, 70), 17, Config.TEXT_COLOR, font)
	if practice != "":
		_text("PRACTICE - your lighter won't run out", Vector2(cx, 98), 16, Config.MUTED_TEXT, font)
	else:
		var line := "Stage %d   -   Wall %d / %d" % [Game.stage, mini(Game.stage_walls + 1, Config.WALLS_PER_STAGE), Config.WALLS_PER_STAGE]
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
		_text("COMBO x%d" % combo, Vector2(150, 52), int(32 * pop), Config.ACCENT, title_font)
		_text("coins x%s" % _num(combo_multiplier()), Vector2(150, 78), 18, Config.TEXT_COLOR, font)
	if _falling or rise < 1.0:
		return
	if light_state == "out":
		_draw_relight()
	elif light_state == "off" and fmod(_t, 1.0) < 0.75:
		var msg := "Flick SPACE (or tap the lighter) to light it" if _lid_target < 1.0 else "Keep flicking! It hasn't caught yet"
		_text(msg, Vector2(size.x * 0.5 + 60, size.y * 0.5 - 20), 30, Config.ACCENT, title_font)


## Lives: one little lighter each (dark = lost), top right.
func _draw_lives() -> void:
	if _lighter_frames.is_empty():
		return
	var tex := _lighter_frames[0]
	var region := Rect2(40, 29, 41, 51)  # the closed lighter on the frame canvas
	var x0 := size.x - 24.0 - Config.LIVES * 50.0
	_text("LIVES", Vector2(x0 - 40, 50), 18, Config.TEXT_COLOR, font)
	var dim := Color(0.25, 0.22, 0.22, 0.8)
	for i in Config.LIVES:
		var r := Rect2(Vector2(x0 + i * 50.0, 14), region.size)
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
		"zigzag", "slash":
			_dev_trace(28.0 if sloppy else 3.0, stop_at)
		"drill":
			for i in _clicks_need:
				press(_spot + Vector2(randf_range(-20, 20), randf_range(-20, 20)))
				release(_spot)
		"pry":
			press(_spot)
			_fill = (_zone.y + Config.PRY_GOOD_MARGIN * 0.5) if sloppy else (_zone.x + _zone.y) * 0.5
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

