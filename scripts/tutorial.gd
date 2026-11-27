class_name Tutorial
extends Control
## Tips as you play: the first time something happens (your first rock, first sale, first trip down the
## mine, each move style the first time it shows up, the lighter going out...) a short tip pops up once,
## with a spotlight on what it's about. The mine pauses while a tip is up. "No more tips" turns them off
## (Settings can turn them back on). The "?" button plays a short tour of the basics instead.
## The texts are in _tips() below; edit them freely.

signal closed

const PANEL_W := 680.0
const PANEL_H := 130.0
## (Old saves that finished the old tutorial count the basics as seen: Game.BASIC_TIPS.)
## The "?" tour: tip ids in order. Wall steps with a "practice" let you try it with no timer.
const TOUR := ["anvil", "backpack", "shop", "mine", "lighter", "act_slash", "wick", "beat"]
## Practicing in the tour: once you've done the move (or this many good flicks) the step finishes by itself.
const PRACTICE_FLICKS := 6
const PRACTICE_NEXT_DELAY := 1.0  # seconds to see "Nice!" before the next step
## A tip up during a real trip freezes the light and wick, but you can still do moves under it: after this
## many finished moves the tip closes by itself (otherwise leaving it open = a wick that never burns).
const TIP_CLOSE_AFTER_MOVES := 3

var main                        # scripts/main.gd (set before adding the tutorial)
var steps: Array[Dictionary] = []
var index := 0
var touring := false            # the "?" tour (several steps) rather than a single tip
var _queue: Array[String] = []  # tips waiting for the right screen / for the current one to close
var _panel: PanelContainer
var _title: Label
var _body: Label
var _count: Label
var _status: Label
var _back: Button
var _next: Button
var _stop: Button
var _tries := 0
var _moves_under := 0           # moves finished while this tip is up (see TIP_CLOSE_AFTER_MOVES)
var _t := 0.0
var _table := {}                # the tips (built once, see _tips())


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # you can still click the highlighted thing
	visible = false
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	if main._skinned():  # tighter padding than other panels: leaves more of the wall free
		var pm: Vector4i = Config.UI_SKIN_PANEL_MARGINS
		_panel.add_theme_stylebox_override("panel", main._skin("panel", pm, Vector4(8, 6, 8, 6), true))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = _label("", 26, Config.ACCENT)
	_title.add_theme_font_override("font", main.title_font)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = _label("", 15, Config.MUTED_TEXT)
	head.add_child(_count)
	_body = _label("", 17, Config.TEXT_COLOR)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = PANEL_W - 30
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_stop = _button("No more tips", _no_more_tips)
	row.add_child(_stop)
	_status = _label("", 16, Config.ACCENT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_status)
	_back = _button("Back", func(): _go(index - 1))
	row.add_child(_back)
	_next = _button("Got it", func(): _go(index + 1))
	_next.custom_minimum_size.x = 110
	row.add_child(_next)
	main.wall_view.practice_done.connect(_on_practice_done)
	main.wall_view.action_done.connect(_on_action_done)


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Config.font_px(fs))
	l.add_theme_color_override("font_color", col)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


# ------------------------------------------------------------------ the tips
## id -> {title, text, screen ("main" / "wall"), target (spotlight, a func giving a global rect; none = no
## spotlight), nodim (don't darken anything: you need to see the wall), practice (tour only: try it)}
func _tips() -> Dictionary:
	if not _table.is_empty():
		return _table
	var m = main
	var wick_box := func() -> Rect2:
		var wv: Control = m.wall_view
		var g: Rect2 = wv.wick_gauge_rect()
		return Rect2(wv.global_position + g.position, g.size).grow(18)
	var stage_hud := func() -> Rect2:
		var wv: Control = m.wall_view
		return Rect2(wv.global_position + Vector2(wv.size.x * 0.5 - 230, 8), Vector2(wv.size.x * 0.5 + 220, 128))
	var t := {
		"anvil": {"title": "Break it open!", "screen": "main", "target": func(): return m.rock_stack.get_global_rect().grow(16),
			"text": "Click the rock to crack it. After a few hits it breaks, and whatever's inside flies into your Backpack."},
		"backpack": {"title": "Your finds", "screen": "main", "target": func(): return m.backpack_btn.get_global_rect().grow(6),
			"text": "Ores and gems go in your Backpack. Open it to sell them for coins."},
		"shop": {"title": "Buy more rocks", "screen": "main", "target": func(): return m.shop_btn.get_global_rect().grow(6),
			"text": "The Shop sells rocks (and upgrades). Prices move every restock. A + means it's good for you (profit), a - means a loss. Shop > Stock Prices lists every price."},
		"mine": {"title": "Short on coins?", "screen": "main", "target": func(): return m.mine_btn.get_global_rect().grow(6),
			"text": "Earn coins down the Mine. Every trip needs a ticket for that cave: there's a free %s ticket every %d minutes in Shop > Caves." % [Game.cave_name(Game.first_cave()), int(Config.FREE_TICKET_SECONDS / 60.0)]},
		"lighter": {"title": "It's dark down here", "screen": "wall", "practice": "flick", "nodim": true,
			"text": "Flick SPACE (or tap the lighter) to light it. The light fades: that's your timer. The FLICK bar on the left fills once per heartbeat: flick once a beat, while it's in the gold zone, to top it up - but not while it blazes full, or you flood it (-1/2 life)."},
		"wick": {"title": "Your WICK", "screen": "wall", "target": wick_box,
			"text": "This bar is your wick: the most light your lighter can have. It BURNS DOWN while a move waits for you, and flicking can't light the wall brighter than it. FINISH the move and it fills right back up. Too slow and it burns out: the lighter dies."},
		"danger": {"title": "Finish the move!", "screen": "wall", "target": wick_box,
			"text": "Your wick is nearly gone, so flicking won't help any more. Finish the move on the wall to refill it! Red edges and shaking = your light's about to die."},
		"relight": {"title": "Lighter's out!", "screen": "wall", "nodim": true,
			"text": "Strike SPACE while the marker is in the gold zone until the bar is empty - before the countdown runs out, or you lose a life."},
		"beat": {"title": "Feel the beat", "screen": "wall", "nodim": true,
			"text": "Your heart rate (the BPM over the FLICK bar) reacts to you: every mistake makes it jump - more when your wick is low - and every 2 good flicks of the lighter calm it down. Deeper stages and pricier caves keep it higher. After every wall you get 2 seconds to practice the beat - these flicks don't count - then a fast 3, 2, 1. Get 5 PERFECT moves in a row and your flame burns BLUE: Deep Focus."},
		"lives": {"title": "Lives & stages", "screen": "wall", "target": stage_hud,
			"text": "Break %d walls to clear a stage (one more every %d stages - the top of the screen says how many): it pays more but gets harder. Lose a life and the stage restarts; lose them all and you drop a stage and your trip ends." % [Config.WALLS_PER_STAGE, Config.WALLS_PER_STAGE_EVERY]},
	}
	var acts := {
		"tap": "Tap each circle the moment its ring closes on it, in the order they appear. The long dashed line points to the NEXT one; dots show the ones after it.",
		"zigzag": "Press the glowing dot and drag along the line, through every corner.",
		"slash": "Press the glowing dot and swipe the whole line in one fast move.",
		"drill": "Click the same spot until the counter hits 0.",
		"pry": "Hold on the wedge and let go while the gauge is in the gold zone.",
		"track": "The circle drifts around: keep clicking it until the counter hits 0.",
		"swirl": "Press the glowing dot and trace the spiral into the middle - no cutting across.",
		"bigslash": "Press the glowing dot and swipe right across the wall - fast!",
		"spin": "Hold the mouse button and spin round the circle, fast, before the time runs out.",
		"nail": "Nails pop up all over the wall! Click every one, in any order, as fast as you can. The clock starts at your first hit - too slow and they pop back up.",
		"letters": "The Blackboard: trace the letters to crack them into the wall. You can let go and carry on whenever you like, any stroke in any order - just don't wander off the letter while you press. Your wick is the clock (the seconds over the letters).",
	}
	for k in acts:
		t["act_" + k] = {"title": WallView.KIND_INFO.get(k, [k.to_upper()])[0], "screen": "wall", "nodim": true,
				"text": acts[k], "practice": k}
	_table = t
	return t


## Show tip `id` once (if tips are on). now_only: it's about something on screen right now - if it can't
## show straight away, skip it (it comes back next time) instead of waiting.
func tip(id: String, now_only := false) -> void:
	if not Game.show_tips or Game.tip_seen(id) or _queue.has(id):
		return
	if _can_show(id):
		_show_tip(id)
	elif not now_only:
		_queue.append(id)


func _can_show(id: String) -> bool:
	if visible or main.shop_overlay.visible or main.backpack_overlay.visible or main.settings_overlay.visible \
			or main.practice_overlay.visible or main.mine_overlay.visible or main.book_overlay.visible:
		return false
	var want: String = _tips().get(id, {}).get("screen", "main")
	return (want == "wall") == main.on_wall


func _show_tip(id: String) -> void:
	var s: Dictionary = _tips().get(id, {})
	if s.is_empty():
		return
	s = s.duplicate()
	s.erase("practice")  # a tip while you play just pauses the mine; practicing is for the tour
	s["id"] = id
	touring = false
	steps.assign([s])
	Game.mark_tip(id)
	_moves_under = 0
	visible = true
	_go(0)


## The "?" button: a short tour of the basics (you can try the lighter and a move, with no timer).
func start() -> void:
	var all := _tips()
	steps.clear()
	for id in TOUR:
		var s: Dictionary = all[id].duplicate()
		s["id"] = id
		steps.append(s)
	touring = true
	_queue.clear()
	main.close_overlays_silent()
	visible = true
	_go(0)


func close() -> void:
	if not visible:
		return
	visible = false
	main.wall_view.reserve_bottom = 0.0
	if main.wall_view.practice != "":
		main.wall_view.set_practice("")
	if touring:
		for s in steps:
			Game.mark_tip(s.get("id", ""))
		if main.on_wall and not Game.trip_active:
			main.go_main()  # the tour was free; the real mine needs a ticket
	touring = false
	Game.set_tutorial_done()
	closed.emit()


func _no_more_tips() -> void:
	Game.set_show_tips(false)
	_queue.clear()
	close()
	main.show_toast("Tips off - turn them back on in Settings")


func _go(i: int) -> void:
	if i >= steps.size():
		close()
		return
	index = clampi(i, 0, steps.size() - 1)
	var s: Dictionary = steps[index]
	_title.text = s.title
	_body.text = s.text
	_count.text = "%d / %d" % [index + 1, steps.size()] if touring else ""
	_back.visible = touring
	_back.disabled = index == 0
	_stop.visible = not touring
	_next.text = ("Let's go!" if index == steps.size() - 1 else "Next") if touring else "Got it"
	_tries = 0
	_status.text = "Try it! (no timer)" if touring and s.has("practice") else ""
	if touring:  # the tour moves between the screens; a tip shows where you are
		if s.screen == "wall":
			main.go_wall()
		else:
			main.go_main()
	var want: String = s.get("practice", "") if touring else ""
	if main.wall_view.practice != want:
		main.wall_view.set_practice(want)
	if touring and s.screen == "wall" and want == "":
		main.wall_view.ensure_lit()


func _on_practice_done(_kind: String) -> void:
	if not visible or not touring:
		return
	_tries += 1
	# practice doesn't go on forever (no timer, no wick burning): do it once (a few good flicks) and the
	# step completes itself
	var done := _tries >= (PRACTICE_FLICKS if _kind == "flick" else 1)
	if _kind == "flick" and not done:
		_status.text = "Good flick! %d more..." % (PRACTICE_FLICKS - _tries)
		return
	if not done or _tries > (PRACTICE_FLICKS if _kind == "flick" else 1):
		return
	_status.text = "Nice! You've got it."
	var at := index
	get_tree().create_timer(PRACTICE_NEXT_DELAY).timeout.connect(func():
		if visible and touring and index == at:
			_go(index + 1))


## A move finished on the wall while a tip is up (a real trip, not the tour's practice): the mine is frozen
## under the tip, so after a few moves the tip goes away and the wick burns again.
func _on_action_done(_perfect: bool, _at: Vector2, _combo: int, _mult: float) -> void:
	if not visible or touring or main.wall_view.practice != "":
		return
	_moves_under += 1
	var left := TIP_CLOSE_AFTER_MOVES - _moves_under
	if left <= 0:
		close()
	else:
		_status.text = "%d more move%s and this tip closes" % [left, "" if left == 1 else "s"]


func in_practice() -> bool:
	return visible and touring and steps.size() > 0 and steps[index].has("practice")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				close()
			KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER:
				_go(index + 1)
			KEY_LEFT:
				if touring:
					_go(index - 1)
			_:
				return  # other keys (SPACE for the lighter) go through
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		for id in _queue.duplicate():  # waiting tips: show the first one that fits now
			if Game.tip_seen(id):
				_queue.erase(id)
			elif _can_show(id):
				_queue.erase(id)
				_show_tip(id)
				break
		return
	_t += delta
	var area: Vector2 = get_parent().size
	if position != Vector2.ZERO or size != area:  # always covers the whole game
		position = Vector2.ZERO
		size = area
	_panel.size = _panel.get_combined_minimum_size()
	main.wall_view.reserve_bottom = maxf(PANEL_H, _panel.size.y) + 40.0  # keep actions above the panel
	# on the wall the panel sits on the right so it never hides your lighter (bottom left)
	var on_wall: bool = not steps.is_empty() and steps[index].screen == "wall"
	var border := float(Config.SAFE_BORDER)
	var px: float = (size.x - _panel.size.x) * 0.5
	if on_wall:  # right side, clear of the Back button
		var back_w: float = main.back_btn.size.x
		px = size.x - _panel.size.x - border * 2.0 - back_w
	_panel.position = Vector2(px, size.y - _panel.size.y - border)
	queue_redraw()


func _draw() -> void:
	if steps.is_empty():
		return
	var s: Dictionary = steps[index]
	if s.get("nodim", false) or (touring and s.has("practice")):
		return  # the whole wall stays visible
	var dim := Color(0, 0, 0, 0.55)
	var full := Rect2(Vector2.ZERO, size)
	if not s.has("target"):
		draw_rect(full, dim)
		return
	var hole: Rect2 = s.target.call()
	hole.position -= global_position
	hole = hole.intersection(full)
	# dim everything around the spotlight
	draw_rect(Rect2(0, 0, size.x, hole.position.y), dim)
	draw_rect(Rect2(0, hole.end.y, size.x, size.y - hole.end.y), dim)
	draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), dim)
	draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), dim)
	# chunky pulsing frame
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var g := 3.0
	draw_rect(hole.grow(g * 2), Config.TEXT_OUTLINE_COLOR, false, g * 2)
	draw_rect(hole.grow(g * (1 + pulse)), Config.ACCENT, false, g)
