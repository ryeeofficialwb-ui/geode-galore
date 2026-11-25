class_name Tutorial
extends Control
## The tutorial: a step-by-step tour of the whole game. Dims the screen around the thing being
## explained and shows a panel with Back / Next / Skip. On the mining-wall steps you can try each
## action for real (no timer). Opens on a new game (Config.SHOW_TUTORIAL) and from the "?" button.
## The texts are in _make_steps() below; edit them freely.

signal closed

const PANEL_W := 760.0
const PANEL_H := 170.0

var main                        # scripts/main.gd (set before adding the tutorial)
var steps: Array[Dictionary] = []
var index := 0
var _panel: PanelContainer
var _title: Label
var _body: Label
var _count: Label
var _status: Label
var _back: Button
var _next: Button
var _tries := 0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # you can still click the highlighted thing
	visible = false
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	if main._skinned():  # tighter padding than other panels: leaves more of the wall free for practice
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
	row.add_child(_button("Skip tutorial", close))
	_status = _label("", 16, Config.ACCENT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_status)
	_back = _button("Back", func(): _go(index - 1))
	row.add_child(_back)
	_next = _button("Next", func(): _go(index + 1))
	_next.custom_minimum_size.x = 110
	row.add_child(_next)
	main.wall_view.practiced.connect(_on_practiced)


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


# ------------------------------------------------------------------ steps
## target: what gets the spotlight (global rect), or null for none.
## screen: "main" (rocks) or "wall".  practice: wall action to try on this step.
func _make_steps() -> void:
	var m = main
	var wall_hud := func() -> Rect2:
		var wv: Control = m.wall_view
		var w := minf(520.0, wv.size.x - 420.0)
		return Rect2(wv.global_position + Vector2((wv.size.x - w) * 0.5 - 40, 14), Vector2(w + 80, 118))
	var wick_box := func() -> Rect2:
		var wv: Control = m.wall_view
		var g: Rect2 = wv.wick_gauge_rect()
		return Rect2(wv.global_position + g.position, g.size).grow(18)
	var stage_hud := func() -> Rect2:
		var wv: Control = m.wall_view
		return Rect2(wv.global_position + Vector2(wv.size.x * 0.5 - 230, 8), Vector2(wv.size.x * 0.5 + 220, 128))  # stage line + lives
	steps = [
		{"title": "Welcome to " + GameVersion.TITLE + "!", "screen": "main",
			"text": "Buy rocks, smash them open, sell the ores and gems inside, then buy better rocks. This tour shows you everything. You can open it again any time with the ? button at the top."},
		{"title": "The anvil", "screen": "main", "target": func(): return m.rock_stack.get_global_rect().grow(16),
			"text": "Click the rock to hit it. Each hit cracks it a bit more; after a few hits (cheap rocks 2-3, big ones up to 8) it breaks open. Go on, give it a whack!"},
		{"title": "What's inside", "screen": "main", "target": func(): return m.backpack_btn.get_global_rect().grow(6),
			"text": "Ores and gems fly out of a broken rock into your Backpack. Some rocks are empty. Gems are rare: they spin and sparkle when they drop."},
		{"title": "Your Rocks", "screen": "main", "target": func(): return m.rocks_panel.get_global_rect().grow(6),
			"text": "Every rock you own is listed here. Click one to put it on the anvil. When a rock breaks, the next one of the same kind is placed for you."},
		{"title": "Selling", "screen": "main", "target": func(): return m.backpack_btn.get_global_rect().grow(6),
			"text": "Open the Backpack to sell your ores and gems for coins: one at a time, a whole stack with All, or everything at once."},
		{"title": "The Shop", "screen": "main", "target": func(): return m.shop_btn.get_global_rect().merge(m.coin_label.get_global_rect()).grow(6),
			"text": "Spend your coins in the Shop. It has a few kinds of rocks with limited stock and restocks every %d minutes with new rocks. Every restock the MARKET moves too: rock prices and what ores and gems sell for go up and down (from 10%% to 200%% of normal). Green is always good for you: sell ores and gems when they're green, buy rocks when they're green (cheap). The Market button lists today's price of everything, and tells you about every ore and gem." % int(Config.RESTOCK_SECONDS / 60.0)},
		{"title": "The Dwarven Shop", "screen": "main", "target": func(): return m.shop_btn.get_global_rect().merge(m.ticket_icon.get_global_rect()).grow(6),
			"text": "The Shop's second tab is the Dwarven Shop: buy UPGRADES there (better ore and gem chances, more ores, more mine coins, lucky sales, more lives...). The third tab is CAVES: every cave needs its own TICKET. There's a free %s ticket every %d minutes, or buy one for %d coins; deeper caves pay more. Your tickets are shown next to your coins." % [Game.cave_name(Game.first_cave()), int(Config.FREE_TICKET_SECONDS / 60.0), Config.TICKET_PRICE]},
		{"title": "Out of coins?", "screen": "main", "target": func(): return m.mine_btn.get_global_rect().grow(6),
			"text": "The Mine arrow takes you to the mining wall, where you earn coins with quick actions. Going down costs a ticket, and the trip lasts until you run out of lives. This tour is free though - let's go there now."},
		{"title": "It's dark down here", "screen": "wall", "practice": "flick",
			"text": "You hold your lighter like a torch. While it's lit the whole wall is lit, but the flame slowly fades and the wall gets darker: that's your TIMER. A flick of SPACE (or a tap on the lighter) only adds a little light, and only if it's TIMED: the FLICK bar next to the lighter charges up - flick when it reaches the gold zone. Too soon (spamming) or too late fails and burns some wick. Every action has its own tempo: some slow, some very fast. When it's back to full it flashes and burns steady for a few seconds: flick it THEN and you flood it, half a life gone! Try it: let it dim, then flick it back up."},
		{"title": "Mind the wick", "screen": "wall", "target": wick_box,
			"text": "That's your WICK. Flicking alone won't keep you alive: while an action waits on you the wick burns down, and the light can't be flicked back above it, so the wall keeps getting darker. Only FINISHING an action refills it; sloppy motions burn some off. If it burns out, the lighter dies. When you're close to losing, the lighter starts to shake."},
		{"title": "The mining wall", "screen": "wall", "target": wall_hud,
			"text": "The wall asks for one action at a time. Clean work is PERFECT and pays coins. Keep finishing actions to build a COMBO: each step adds +%d%% coins. Keep flicking your lighter while you work: if the light dies, the combo dies with it. After a few actions the wall crumbles and a new one drops in." % roundi(Config.COMBO_BONUS_PER_STEP * 100)},
		{"title": "TAP!", "screen": "wall", "practice": "tap",
			"text": "Circles pop up, each with a ring closing in on it. Tap a circle right when its ring touches it. Rings close at different speeds, so tap whichever ring closes FIRST, not the circle that showed up first. Too early or too late misses it."},
		{"title": "ZIGZAG!", "screen": "wall", "practice": "zigzag",
			"text": "Press on the glowing dot and drag along the zigzag: you crack the wall as you go. Pass through every corner (the small rings); cutting straight across won't work. Stay close to the line for PERFECT."},
		{"title": "SLASH!", "screen": "wall", "practice": "slash",
			"text": "Press on the glowing dot and swipe the whole line in one fast move. Once you start, you have under %s seconds to reach the arrow." % str(Config.SLASH_SWIPE_TIME)},
		{"title": "DRILL!", "screen": "wall", "practice": "drill",
			"text": "Click the same spot over and over until the counter hits 0. Clicks outside the ring don't count and spoil PERFECT."},
		{"title": "PRY!", "screen": "wall", "practice": "pry",
			"text": "Press and HOLD on the wedge. The gauge fills up; let go while it's in the gold zone. Hold too long and the wedge snaps."},
		{"title": "Lighter's out!", "screen": "wall", "practice": "relight",
			"text": "If the flame burns out (or you lose your combo) the lighter goes out. Strike SPACE (or tap the lighter) while the marker is in the GOLD zone: each good strike drops the bar, but the marker speeds up and the zone shrinks. Mistime it and the bar goes back up. Empty the bar in %d seconds or lose a life. It's hard!" % int(Config.RELIGHT_TIME)},
		{"title": "Stages & lives", "screen": "wall", "target": stage_hud,
			"text": "Each stage gives you %d lives (flooding costs half of one). Break %d walls to clear it and go up a stage: every stage pays +%d%% coins but your light fades faster and relighting takes more strikes. Lose a life and the stage starts over from its first wall (your stage is a checkpoint). Lose all %d before clearing it and you drop down a stage." % [Config.LIVES, Config.WALLS_PER_STAGE, roundi(Config.STAGE_COIN_BONUS * 100), Config.LIVES]},
		{"title": "Heading back", "screen": "wall", "target": func(): return m.back_btn.get_global_rect().grow(6),
			"text": "Back takes you to your rocks (the wall waits for you). Each screen has its own music. From now on the lighter really burns, so be quick!"},
		{"title": "You're ready!", "screen": "main", "target": func(): return m.settings_btn.get_global_rect().merge(m.help_btn.get_global_rect()).grow(6),
			"text": "Settings has sound, music and effect volume, and Reset to start over. Press ? to see this tour again. Now go get rich!"},
	]


# ------------------------------------------------------------------ flow
func start() -> void:
	_make_steps()
	main.close_overlays_silent()
	visible = true
	main.wall_view.reserve_bottom = PANEL_H + 40.0
	_go(0)


func close() -> void:
	if not visible:
		return
	visible = false
	main.wall_view.reserve_bottom = 0.0
	if main.wall_view.practice != "":
		main.wall_view.set_practice("")
	if main.on_wall and not Game.trip_active:
		main.go_main()  # the tour was free; the real mine needs a ticket
	Game.set_tutorial_done()
	closed.emit()


func _go(i: int) -> void:
	if i >= steps.size():
		close()
		main.go_main()
		return
	index = clampi(i, 0, steps.size() - 1)
	var s: Dictionary = steps[index]
	_title.text = s.title
	_body.text = s.text
	_count.text = "%d / %d" % [index + 1, steps.size()]
	_back.disabled = index == 0
	_next.text = "Let's go!" if index == steps.size() - 1 else "Next"
	_tries = 0
	_status.text = "Try it! (no timer)" if s.has("practice") else ""
	if s.screen == "wall":
		main.go_wall()
	else:
		main.go_main()
	var want: String = s.get("practice", "")
	if main.wall_view.practice != want:
		main.wall_view.set_practice(want)
	if s.screen == "wall" and want == "":
		main.wall_view.ensure_lit()


func _on_practiced(_kind: String) -> void:
	if not visible:
		return
	_tries += 1
	_status.text = "Nice! Again, or press Next" if _tries == 1 else "Done x%d - press Next when ready" % _tries
	if _kind == "flick":
		_status.text = "Keep flicking... (don't overfill it!)" if _tries < 12 else "You've got it - press Next"
	if _kind == "relight":
		_status.text = "Lit! It'll go out again - practise or press Next"


func practicing() -> bool:
	return visible and steps.size() > 0 and steps[index].has("practice")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				close()
			KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER:
				_go(index + 1)
			KEY_LEFT:
				_go(index - 1)
			_:
				return  # other keys (SPACE for the lighter) go through
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
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
	var px := size.x - _panel.size.x - 16 if on_wall else (size.x - _panel.size.x) * 0.5
	_panel.position = Vector2(px, size.y - _panel.size.y - 16)
	queue_redraw()


func _draw() -> void:
	if steps.is_empty():
		return
	var s: Dictionary = steps[index]
	if s.has("practice") or s.get("nodim", false):
		return  # the whole wall stays visible so you can try it
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
