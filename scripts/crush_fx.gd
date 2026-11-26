class_name CrushFx
extends Control
## Crush All: the screen goes black, the camera zooms onto the rock on the anvil, it charges up,
## then goes supernova and every rock breaks at once. Pure drawing (no nodes per particle), and the
## particle counts are capped, so it costs the same whether you crush 2 rocks or 20,000.
## Main builds the drop summary on top when `revealed` fires and calls close() when you're done.

signal burst      # the rock just blew up (shake the screen)
signal revealed   # the dust settled: show what dropped
signal finished   # faded out and gone

const FADE_END := 0.45      # black fades in, the rock stays where it was
const ZOOM_END := 1.45      # the rock has slid to the middle and grown
const IMPLODE := 1.6        # it sucks in on itself...
const BURST_AT := 1.75      # ...and blows
const REVEAL_AT := 2.45
const MAX_SPARKS := 260
const MAX_MOTES := 70
const PIECE_GRID := 6       # the rock flies apart in up to 6 x 6 chunks

var t := 0.0
var _tex: Texture2D
var _from: Rect2            # where the rock was (in this control's space)
var _to: Rect2              # where it zooms to
var _colors: Array[Color] = []
var _has_burst := false
var _has_revealed := false
var _closing := -1.0
var _motes: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _rings: Array[Dictionary] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # nothing behind it can be clicked while it plays
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## tex: the rock's art (with its cracks); from: its rect on screen (global); colors: spark colours
## (the colours of what dropped, so the explosion hints at the loot).
func play(tex: Texture2D, from_global: Rect2, colors: Array[Color]) -> void:
	_tex = tex
	_from = Rect2(from_global.position - global_position, from_global.size)
	_colors = colors.duplicate()
	if _colors.is_empty():
		_colors.append(Color("#ffe9b0"))
	var s := size if size != Vector2.ZERO else get_viewport_rect().size
	var grow := minf(s.y * 0.46 / maxf(_from.size.y, 1.0), 2.4)
	var sz := _from.size * maxf(grow, 1.0)
	_to = Rect2(s * 0.5 - sz * 0.5 + Vector2(0, -s.y * 0.04), sz)


func close() -> void:
	if _closing < 0.0:
		_closing = 0.0


func _ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _rock_rect() -> Rect2:
	var z := _ease_io(inverse_lerp(FADE_END * 0.6, ZOOM_END, t))
	var r := Rect2(_from.position.lerp(_to.position, z), _from.size.lerp(_to.size, z))
	if t > ZOOM_END:  # breathe in, then implode
		var k := 1.0 + 0.04 * sin(t * 30.0) * inverse_lerp(ZOOM_END, IMPLODE, t)
		if t > IMPLODE:
			k = lerpf(1.0, 0.7, inverse_lerp(IMPLODE, BURST_AT, t))
		var c := r.get_center()
		r = Rect2(c - r.size * k * 0.5, r.size * k)
	return r


func _charge() -> float:  # 0..1 how charged up the rock is
	return clampf(inverse_lerp(FADE_END, BURST_AT, t), 0.0, 1.0)


func _process(delta: float) -> void:
	t += delta
	var c := _to.get_center()
	# light motes get sucked into the rock while it charges
	if not _has_burst and t > FADE_END and _motes.size() < MAX_MOTES:
		for i in 2:
			var a := randf() * TAU
			var d := randf_range(0.45, 0.75) * maxf(size.x, size.y)
			_motes.append({"a": a, "d": d, "sp": randf_range(1.4, 2.4), "c": _colors.pick_random()})
	for m in _motes:
		m.d = m.d * (1.0 - delta * m.sp * (1.0 + _charge() * 2.0))
	_motes = _motes.filter(func(m): return m.d > _to.size.x * 0.18)
	if not _has_burst and t >= BURST_AT:
		_explode(c)
	for s in _sparks:
		s.p += s.v * delta
		s.v *= 1.0 - delta * s.drag
		s.v.y += s.g * delta
		s.life -= delta
	_sparks = _sparks.filter(func(s): return s.life > 0.0)
	for pc in _pieces:
		pc.p += pc.v * delta
		pc.v *= 1.0 - delta * 0.9
		pc.rot += pc.w * delta
		pc.life -= delta
	_pieces = _pieces.filter(func(pc): return pc.life > 0.0)
	for r in _rings:
		r.r += r.sp * delta
		r.sp *= 1.0 - delta * 1.6
		r.life -= delta
	_rings = _rings.filter(func(r): return r.life > 0.0)
	# keep a few embers drifting behind the summary
	if _has_revealed and _sparks.size() < 40 and randf() < 0.5:
		_spark(Vector2(randf() * size.x, size.y + 10), Vector2(randf_range(-20, 20), randf_range(-90, -40)), 6.0, 0.0, 0.0)
	if not _has_revealed and t >= REVEAL_AT:
		_has_revealed = true
		revealed.emit()
	if _closing >= 0.0:
		_closing += delta
		modulate.a = 1.0 - _closing / 0.35
		if _closing >= 0.35:
			finished.emit()
			queue_free()
	queue_redraw()


func _spark(p: Vector2, v: Vector2, life: float, drag: float, g := 260.0) -> void:
	if _sparks.size() >= MAX_SPARKS:
		return
	var col: Color = _colors.pick_random() if randf() < 0.7 else Color("#fff6dc")
	_sparks.append({"p": p, "v": v, "life": life, "max": life, "drag": drag, "g": g, "c": col, "s": randf_range(3.0, 7.0)})


func _explode(c: Vector2) -> void:
	_has_burst = true
	_motes.clear()
	var r := _rock_rect()
	if _tex:
		var ts := _tex.get_size()
		var cell := ts / PIECE_GRID
		var img := _tex.get_image()
		for gy in PIECE_GRID:
			for gx in PIECE_GRID:
				var region := Rect2(Vector2(gx, gy) * cell, cell)
				var used := false
				if img:
					var probe := Vector2i(region.get_center()).clamp(Vector2i.ZERO, Vector2i(ts) - Vector2i.ONE)
					used = img.get_pixelv(probe).a > 0.1
				if not used:
					continue
				var at := r.position + (region.get_center() / ts) * r.size
				var away := (at - c).normalized()
				if away == Vector2.ZERO:
					away = Vector2.from_angle(randf() * TAU)
				_pieces.append({"region": region, "size": r.size / PIECE_GRID, "p": at, "rot": 0.0,
						"v": away * randf_range(500, 1100), "w": randf_range(-9, 9), "life": randf_range(0.9, 1.4)})
	for i in MAX_SPARKS:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(150, 1300)
		_spark(c, v, randf_range(0.7, 1.8), randf_range(0.8, 2.2))
	_rings.append({"r": 10.0, "sp": 1900.0, "life": 0.9, "max": 0.9, "w": 14.0, "c": Color("#fff6dc")})
	_rings.append({"r": 10.0, "sp": 1200.0, "life": 1.2, "max": 1.2, "w": 8.0, "c": _colors[0]})
	_rings.append({"r": 10.0, "sp": 700.0, "life": 1.5, "max": 1.5, "w": 5.0, "c": Color("#ff8a3d")})
	burst.emit()


## The whole screen plus a margin, so the screen shake never shows the window's edge.
func _bleed(s: Vector2) -> Rect2:
	return Rect2(-Vector2.ONE * 120.0, s + Vector2.ONE * 240.0)


func _draw() -> void:
	var s := size
	# the black
	var black := _ease_io(t / FADE_END)
	draw_rect(_bleed(s), Color(0.0, 0.0, 0.0, black * (0.97 if not _has_revealed else 0.9)))
	var c := _to.get_center()
	var ch := _charge()
	# glow around the rock while it charges
	if not _has_burst and t > FADE_END:
		var base := _rock_rect().size.x * 0.5
		for k in 5:
			var rad := base * (1.0 + 0.25 * k) * (1.0 + 0.06 * sin(t * 14.0 + k))
			var col: Color = _colors[k % _colors.size()]
			col.a = 0.08 * ch * (1.0 - k * 0.15)
			draw_circle(c, rad, col)
		for m in _motes:
			var p: Vector2 = c + Vector2.from_angle(m.a) * m.d
			var mc: Color = m.c
			mc.a = 0.9
			draw_circle(p, 2.5 + ch * 2.0, mc)
	# the rock itself (gone once it blows)
	if _tex and not _has_burst:
		var r := _rock_rect()
		var shake := ch * ch * 10.0
		r.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		var hot := clampf(inverse_lerp(ZOOM_END, BURST_AT, t), 0.0, 1.0)
		draw_texture_rect(_tex, r, false)
		if hot > 0.0:  # it glows white-hot just before it goes
			draw_texture_rect(_tex, r, false, Color(1.0, 0.95, 0.8, hot * 0.85))
	# rings, chunks, sparks
	for ring in _rings:
		var rc: Color = ring.c
		rc.a = ring.life / ring.max
		draw_arc(c, ring.r, 0.0, TAU, 72, rc, ring.w * rc.a + 1.0)
	for pc in _pieces:
		draw_set_transform(pc.p, pc.rot, Vector2.ONE)
		draw_texture_rect_region(_tex, Rect2(-pc.size * 0.5, pc.size), pc.region, Color(1, 1, 1, clampf(pc.life / 0.4, 0.0, 1.0)))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for sp in _sparks:
		var col: Color = sp.c
		col.a = clampf(sp.life / sp.max * 1.5, 0.0, 1.0)
		var sz: float = sp.s
		draw_rect(Rect2(sp.p - Vector2.ONE * sz * 0.5, Vector2.ONE * sz), col)
	# the flash
	if _has_burst:
		var f := 1.0 - (t - BURST_AT) / 0.55
		if f > 0.0:
			draw_rect(_bleed(s), Color(1.0, 0.97, 0.88, f * f))
