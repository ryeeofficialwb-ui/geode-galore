class_name RockView
extends Control
## The rock you click. Draws the rock big and pixel-perfect, adds cracks to its pixels on
## every hit, throws stone chips, and splits into chunks when it breaks.

signal hit(hits_done: int, hits_total: int)
signal broken(center: Vector2)

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

var rock_id := ""
var hits_total := 0
var hits_done := 0
var img: Image                 # working copy of the rock art, cracks are painted into it
var tex: ImageTexture
var art_tex: Texture2D         # hand-drawn crack stage (if the file exists)
var pop := 1.0                 # appear animation 0..1 (tweened)
var _used := Rect2i()          # the part of the art PNG that has pixels (empty border cropped off)
var _cell := 32                # size of the full art PNG (keeps big rocks big, small rocks small)

var _opaque: Array[Vector2i] = []
var _interior := {}            # Vector2i -> true (inside the outline)
var _cracks: Array[Vector2i] = []
var _shake := 0.0
var _squash := 0.0
var _chips: Array[Dictionary] = []
var _pieces: Array[Dictionary] = []
var _is_broken := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2.ONE * Config.ROCK_DISPLAY_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_rock(id: String) -> void:
	rock_id = id
	_is_broken = false
	_cracks.clear()
	_opaque.clear()
	_interior.clear()
	art_tex = null
	hits_done = 0
	if id == "":
		img = null
		queue_redraw()
		return
	hits_total = Game.hits_for(id)
	var full := Game.rock_texture(id).get_image()
	full.convert(Image.FORMAT_RGBA8)
	_cell = maxi(full.get_width(), full.get_height())
	_used = full.get_used_rect()
	img = full.get_region(_used)
	tex = ImageTexture.create_from_image(img)
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				_opaque.append(Vector2i(x, y))
	for p in _opaque:
		if _solid(p + Vector2i.LEFT) and _solid(p + Vector2i.RIGHT) and _solid(p + Vector2i.UP) and _solid(p + Vector2i.DOWN):
			_interior[p] = true
	pop = 0.0
	create_tween().tween_property(self, "pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	queue_redraw()


func is_ready_to_hit() -> bool:
	return rock_id != "" and not _is_broken


# ------------------------------------------------------------------ geometry
func _px() -> float:  # screen pixels per art pixel
	if img == null:
		return 1.0
	return floorf(Config.ROCK_DISPLAY_SIZE / float(_cell))


func _rock_rect() -> Rect2:
	var px := _px()
	var s := Vector2(img.get_width(), img.get_height()) * px
	var sq := Vector2(1.0 + _squash, 1.0 - _squash) * pop
	var bottom := Vector2(size.x * 0.5, (size.y + s.y) * 0.5)  # rock centered, squashes from its base
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	return Rect2(bottom - Vector2(s.x * sq.x * 0.5, s.y * sq.y) + shake, s * sq)


func _solid(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixelv(p).a > 0.1


# ------------------------------------------------------------------ input / hitting
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_ready_to_hit():
			do_hit(event.position)
			accept_event()


func do_hit(at: Vector2) -> void:
	hits_done += 1
	var rect := _rock_rect()
	var px := _px()
	var pixel := Vector2i(((at - rect.position) / px).floor())
	if not _interior.has(pixel):
		pixel = _nearest_interior(pixel)
	for i in Config.CRACKS_PER_HIT:
		var start: Vector2i = pixel if i == 0 or _cracks.is_empty() else _cracks.pick_random()
		_crack_from(start)
	tex.update(img)
	var stage := ceili(float(hits_done) / hits_total * Config.CRACK_ART_STAGES)
	var path := "res://assets/rocks/%s_crack_%d.png" % [rock_id, stage]
	if ResourceLoader.exists(path):
		art_tex = load(path)
	var hit_pos := rect.position + (Vector2(pixel) + Vector2(0.5, 0.5)) * px
	if hits_done >= hits_total:
		_break_apart()
		return
	_shake = Config.SHAKE_STRENGTH
	_squash = Config.SQUASH_AMOUNT
	_spawn_chips(hit_pos, Config.CHIPS_PER_HIT, 1.0)
	Sfx.play("hit")
	hit.emit(hits_done, hits_total)


func _nearest_interior(p: Vector2i) -> Vector2i:
	var best := p
	var best_d := INF
	for q: Vector2i in _interior:
		var d := Vector2(q - p).length_squared()
		if d < best_d:
			best_d = d
			best = q
	return best


## Random-walks a crack line through the rock's inner pixels.
func _crack_from(start: Vector2i) -> void:
	var p := start
	var dir := randi() % 8
	var length := randi_range(Config.CRACK_LENGTH_MIN, Config.CRACK_LENGTH_MAX)
	for step in length:
		if not _interior.has(p):
			break
		img.set_pixelv(p, Config.CRACK_COLOR)
		_cracks.append(p)
		var edge := p + Vector2i.DOWN  # a lighter pixel under the crack gives it depth
		if Config.CRACK_EDGE_COLOR.a > 0.0 and _interior.has(edge) and not _cracks.has(edge):
			img.set_pixelv(edge, Config.CRACK_EDGE_COLOR)
		if randf() < 0.35:
			dir = (dir + (1 if randf() < 0.5 else 7)) % 8
		p += DIRS[dir]


# ------------------------------------------------------------------ breaking
func _break_apart() -> void:
	_is_broken = true
	var rect := _rock_rect()
	var center := rect.get_center()
	var shown: Texture2D = art_tex if art_tex else tex
	var n := maxi(Config.BREAK_PIECES, 1)
	var cell := Vector2(img.get_width(), img.get_height()) / n
	for gy in n:
		for gx in n:
			var region := Rect2(Vector2(gx, gy) * cell, cell)
			if not _region_has_pixels(region):
				continue
			var screen_center := rect.position + region.get_center() * _px()
			var away := (screen_center - center).normalized()
			if away == Vector2.ZERO:
				away = Vector2.UP
			_pieces.append({
				"tex": shown, "region": Rect2(region.position + (Vector2(_used.position) if art_tex else Vector2.ZERO), region.size), "size": cell * _px(), "p": screen_center,
				"v": away * randf_range(180, 360) + Vector2(0, -320), "rot": 0.0,
				"w": randf_range(-6, 6), "life": 1.1,
			})
	_spawn_chips(center, Config.CHIPS_ON_BREAK, 1.6)
	Sfx.play("break")
	broken.emit(get_global_transform() * center)


func _region_has_pixels(r: Rect2) -> bool:
	for p in _opaque:
		if r.has_point(Vector2(p) + Vector2(0.5, 0.5)):
			return true
	return false


func _spawn_chips(at: Vector2, count: int, force: float) -> void:
	if _opaque.is_empty():
		return
	var px := _px()
	for i in count:
		var c := img.get_pixelv(_opaque.pick_random())
		_chips.append({
			"p": at, "c": c, "s": px * randf_range(0.6, 1.0), "life": randf_range(0.5, 0.9),
			"v": Vector2(randf_range(-1, 1), randf_range(-1.3, -0.2)).normalized() * randf_range(200, 480) * force,
		})


# ------------------------------------------------------------------ animate + draw
func _process(delta: float) -> void:
	var busy := pop < 1.0 or _shake > 0.0 or _squash > 0.0 or not _chips.is_empty() or not _pieces.is_empty()
	_shake = move_toward(_shake, 0.0, delta * 60.0)
	_squash = move_toward(_squash, 0.0, delta * 0.6)
	for c in _chips:
		var v: Vector2 = c.v
		v.y += Config.CHIP_GRAVITY * delta
		c.v = v
		c.p += v * delta
		c.life -= delta
	_chips = _chips.filter(func(c): return c.life > 0.0)
	for pc in _pieces:
		var v: Vector2 = pc.v
		v.y += Config.CHIP_GRAVITY * delta
		pc.v = v
		pc.p += v * delta
		pc.rot += pc.w * delta
		pc.life -= delta
	_pieces = _pieces.filter(func(pc): return pc.life > 0.0)
	if busy or img != null:  # cheap; keeps the rock right after layout changes
		queue_redraw()


func _draw() -> void:
	if img and not _is_broken:
		var rect := _rock_rect()
		# soft shadow on the ground
		var sh := Vector2(rect.size.x * 0.5, rect.size.x * 0.08)
		draw_set_transform(Vector2(size.x * 0.5, rect.end.y), 0.0, Vector2(1.0, sh.y / sh.x))
		draw_circle(Vector2.ZERO, sh.x, Color(0, 0, 0, 0.35))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if art_tex:
			draw_texture_rect_region(art_tex, rect, Rect2(_used))
		else:
			draw_texture_rect(tex, rect, false)
	for pc in _pieces:
		draw_set_transform(pc.p, pc.rot, Vector2.ONE)
		draw_texture_rect_region(pc.tex, Rect2(-pc.size * 0.5, pc.size), pc.region,
				Color(1, 1, 1, clampf(pc.life / 0.4, 0.0, 1.0)))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for c in _chips:
		var col: Color = c.c
		col.a = clampf(c.life / 0.3, 0.0, 1.0)
		draw_rect(Rect2(c.p - Vector2.ONE * c.s * 0.5, Vector2.ONE * c.s), col)
