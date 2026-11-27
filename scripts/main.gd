extends Control
## Builds the whole game screen in code.
##   top bar     : coins, Shop, Backpack (ores & gems), Settings
##   main screen : the rock (middle), Your Rocks (right), arrow on the left -> mining wall
##   wall screen : the mining wall (slides in from the left), Back button on the right
## Game logic lives in the Game autoload; numbers live in Config.

const UI_DIR := "res://assets/ui/"
const SKIN_DIR := "res://assets/ui/skin/"

var coin_label: Label
var ticket_label: Label
var ticket_icon: Control
var shop_title: Label
var shop_tab := "rocks"
var tab_rocks: Button
var tab_dwarf: Button
var tab_caves: Button
var rock_page: VBoxContainer
var dwarf_page: VBoxContainer
var cave_page: VBoxContainer
var cave_list: VBoxContainer
var ticket_info: Label
var claim_btn: Button
var upgrade_list: VBoxContainer
var slot_style: StyleBox            # dark inset box for shop cards / upgrade rows
var _dev := false
var _dev_dir := ""
var version_label: Label            # "Indev 0.1" (+ update status), bottom-left of the rock screen
var _update_status := ""                  # the demo's screenshot folder (--shot=)
var backpack_btn: Button
var shop_btn: Button
var settings_btn: Button
var help_btn: Button
var mine_btn: Button
var rocks_panel: Control
var rock_stack: Control
var tutorial: Tutorial
var slider: Control             # holds both screens side by side; slides left/right
var screens_area: Control
var main_screen: Control
var wall_screen: Control
var wall_view: WallView
var back_btn: Button
var on_wall := false
var settings_overlay: Control
var sound_btn: Button
var music_slider: HSlider
var sfx_slider: HSlider
var font: Font
var title_font: Font
var backpack_overlay: Control
var rock_view: RockView
var rock_title: Label
var hint_label: Label
var tab_stocks: Button              # Shop > Stock Prices (every price, sortable by profit, and a page per item)
var stock_page: VBoxContainer
var market_list: VBoxContainer
var market_detail: VBoxContainer
var market_tab := "ores"
var market_pick := ""               # the item shown on the right
var market_sort := ""               # "" = normal order, "low" = least profit first, "high" = most profit first
var sort_btn: Button
var stock_timer: Label              # Stock Prices: time until prices change
var tab_m_ores: Button
var tab_m_gems: Button
var tab_m_rocks: Button
var practice_btn: Button            # next to the Mine: play any activity, no lighter, no coins
var practice_overlay: Control
var mine_overlay: Control           # Select Mine: the Mine button's cave picker
var mine_list: VBoxContainer
var mine_claim_btn: Button
var rest_panel: PanelContainer      # the break between walls: next wall, item picks, Midas cash-out
var rest_title: Label
var rest_info: Label
var rest_offer_box: VBoxContainer
var rest_offer_row: HBoxContainer
var rest_offer_note: Label
var rest_items_row: HBoxContainer
var rest_midas_box: HBoxContainer
var rest_midas_label: Label
var rest_continue: Button
var _rest_shown := false
var _swap_pick := ""                # slots full: the offered item waiting for you to pick one to swap out
var items_hud: HBoxContainer        # on the wall: the items you hold this run
var dynamite_btn: Button
var ram_btn: Button
var ham_btn: Button                 # Great Ham: eat it for +2 lives
var wall_book_btn: Button           # the Artifact Book, on the wall too (opening it pauses the mine)
var rest_extra_box: VBoxContainer
var book_overlay: Control           # the Artifact Book (Select Mine): every artifact there is
var book_list: GridContainer
var book_tiers: VBoxContainer       # the Tier List tab
var book_info: Label
var book_scroll: ScrollContainer
var book_tabs := {}                 # tab id -> its button
var book_tab := "artifacts"
var hints_btn: Button
var tips_btn: Button                # Settings > Tips (the pop-up tips as you play)
var circles_btn: Button             # Settings > Coloured circles (tap circles each in their own colour)
var beat_btn: Button                # Settings > Beat practice (off: skip it after every wall)
var beat_okay_btn: Button           # on the wall: skips the beat practice
var _hints: Array[Control] = []     # helper texts that Settings > Hint text hides
var bag_list: VBoxContainer
var crush_btn: Button               # Crush All: every rock at once, supernova style
var _crush_fx: CrushFx
var _game_over: Control             # the "no more fuel" screen while it's up
var ore_list: VBoxContainer
var sell_all_btn: Button
var shop_overlay: Control
var shop_grid: GridContainer        # the Rock Shop's wooden shelf: one cubby per rock
var shop_clock: Label               # Philippine time (the shelf and prices follow it, the same for everyone)
var shop_timer: Label
var restock_btn: Button
var reset_confirm: ConfirmationDialog
var rebirth_confirm: ConfirmationDialog  # Upgrades > Rebirth (asks first: it wipes the game)
var leave_confirm: ConfirmationDialog   # Back on a run = cash out (asks first)
var toast_label: Label
var toast_tween: Tween
var fx_layer: Control
var flash_rect: ColorRect          # the full-screen flash when your flame reaches full blaze
var room_bg: TextureRect           # the room behind the rock (assets/ui/background.png); slides with the rock screen
var menu_bar: PanelContainer       # the top menu (coins, Shop, Market...): only on the rock screen, it slides away in the mine
var _menu_tween: Tween
var _slide_tween: Tween
var _shake := 0.0


func _ready() -> void:
	font = _make_font(Config.FONT_FILE, Config.FONT_SYSTEM_NAMES, Config.FONT_WEIGHT)
	title_font = _make_font(Config.TITLE_FONT_FILE, Config.TITLE_FONT_SYSTEM_NAMES, Config.TITLE_FONT_WEIGHT)
	theme = _make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel art stays crisp everywhere
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	Game.changed.connect(_refresh)
	Game.shop_changed.connect(_rebuild_shop)
	Game.toast.connect(show_toast)
	rock_view.hit.connect(_on_hit)
	rock_view.broken.connect(_on_broken)
	wall_view.action_done.connect(_on_action_done)
	wall_view.missed.connect(_on_missed)
	wall_view.failed.connect(_on_failed)
	wall_view.wall_down.connect(_on_wall_down)
	wall_view.life_lost.connect(_on_life_lost)
	wall_view.flooded.connect(_on_flooded)
	wall_view.full_light.connect(_on_full_light)
	wall_view.countdown_tick.connect(func():
		if not wall_view.peaceful():
			_shake = maxf(_shake, Config.COUNTDOWN_SHAKE))  # 3, 2, 1: the screen shakes a bit
	wall_view.stage_up.connect(_on_stage_up)
	wall_view.dynamite_blown.connect(func(at: Vector2):
		_shake = Config.SCREEN_SHAKE_ON_BREAK * 2.0
		Sfx.play("wall_break", 0.7)
		_float_text(wall_view.global_position + at - fx_layer.global_position + Vector2(0, -60), "KABOOM!  Dynamite", Config.SLICE_MISS_COLOR, 0.0))
	wall_view.item_popped.connect(func(text: String, at: Vector2):
		Sfx.play("drop_rare")
		_float_text(wall_view.global_position + at - fx_layer.global_position, text, Config.ACCENT, 0.0))
	Game.item_used.connect(func(_id: String, text: String):
		Sfx.play("drop_rare")
		_float_text(Vector2(size.x * 0.5, size.y * 0.42), text, Config.ACCENT, 0.3))
	Game.run_changed.connect(_refresh_run)
	wall_view.rest_ui_external = true
	Game.lucky_sale.connect(_on_lucky_sale)
	Game.market_moved.connect(_refresh)
	Game.trip_over.connect(_on_trip_over)
	Game.found_rocks.connect(_on_found_rocks)
	Game.found_ticket.connect(_on_found_ticket)
	wall_view.action_started.connect(func(k: String):
		if wall_view.practice == "":
			tutorial.tip("act_" + k, true)  # the first time each move shows up
			tutorial.tip("wick"))  # ... and then what the wick is (waits until the move's tip is closed)
	wall_view.lighter_out.connect(func(_at: Vector2):
		if wall_view.practice == "":
			tutorial.tip("relight", true))
	_refresh()
	_rebuild_shop()
	if Game.current_rock != "":
		rock_view.set_rock(Game.current_rock)
	else:
		_auto_place("")
	_update_rock_text()
	var dev := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			dev = true
			_dev = true
			_dev_shots(a.trim_prefix("--shot="))
	if "--selftest" in OS.get_cmdline_user_args():
		# the updater's check of a freshly installed pack: the whole screen got built and every music
		# track decrypted and loaded -> report success
		var music_ok: bool = Sfx._music.size() == Config.MUSIC_TRACKS.size()
		if not music_ok:
			printerr("SELFTEST: music tracks loaded %d / %d" % [Sfx._music.size(), Config.MUSIC_TRACKS.size()])
		get_tree().quit.call_deferred(Updater.SELFTEST_CODE if music_ok else 1)
		return
	if Updater.enabled():
		var updater := Updater.new()
		add_child(updater)
		updater.status_changed.connect(func(text: String):
			_update_status = text
			_update_version_label())
	if not dev and Config.SHOW_TUTORIAL:
		tutorial.tip.call_deferred("anvil")  # tips pop up as you play (the ? button has a short tour)


func _process(delta: float) -> void:
	if _dev_dir != "" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)  # demo: a minimized window stops drawing
	_layout_screens()
	version_label.visible = not on_wall
	version_label.position = Vector2(14, size.y - version_label.size.y - 8)
	wall_view.active = on_wall and not (shop_overlay.visible or backpack_overlay.visible or settings_overlay.visible or practice_overlay.visible or mine_overlay.visible or book_overlay.visible or reset_confirm.visible or leave_confirm.visible) 			and (not tutorial.visible or tutorial.in_practice())  # the tutorial freezes the wall, except while you try an action
	wall_view.active = wall_view.active and (Game.trip_active or tutorial.in_practice() or wall_view.free_practice)  # no ticket, no mining (Practice is free)
	if shop_overlay.visible and shop_tab == "stocks":
		stock_timer.text = "Prices change in %s  (PH %s)" % [_fmt_time(Game.restock_left()), Game.market_clock()]
	if shop_overlay.visible:
		shop_timer.text = "Restocks in %s" % _fmt_time(Game.restock_left())
		shop_clock.text = "Philippine time %s - everyone sees the same shelf & prices" % Game.market_clock()
		_update_tickets()
	elif mine_overlay.visible:
		_update_tickets()  # the free ticket's countdown
	# the break between walls: our panel (items, Midas) over the wall
	var want_rest: bool = on_wall and wall_view.resting and wall_view.practice == "" and not wall_view.free_practice
	if want_rest != _rest_shown:
		_rest_shown = want_rest
		rest_panel.visible = want_rest
		_swap_pick = ""
		_refresh_run()
	if on_wall and wall_view.active:  # about to lose: the whole screen trembles too
		_shake = maxf(_shake, wall_view.danger() * Config.DANGER_SCREEN_SHAKE)
		if wall_view.danger() > 0.35:
			tutorial.tip("danger", true)
		if wall_view.in_beat_practice():
			tutorial.tip("beat", true)
	if on_wall and wall_view.peaceful():
		_shake = 0.0  # Art of Peace: the screen never shakes
	# practicing the beat: the zoomed FLICK bar is all you see - the wall's buttons and floating texts fade
	# away too (and can't be clicked while they're gone), then come back when it zooms out
	var zoom := wall_view.zoom_amount()
	var shown := 1.0 - Config.BEAT_PRACTICE_DIM * zoom
	for c in [back_btn, wall_book_btn, dynamite_btn, ram_btn, ham_btn, items_hud, fx_layer]:
		(c as CanvasItem).modulate = Color(1, 1, 1, shown)
	for b in [back_btn, wall_book_btn, dynamite_btn, ram_btn, ham_btn]:
		(b as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if zoom > 0.0 else Control.MOUSE_FILTER_STOP
	# feeling the beat: "Okay" skips straight to the 3, 2, 1
	beat_okay_btn.visible = on_wall and wall_view.beat_skippable()
	if beat_okay_btn.visible:
		beat_okay_btn.size = beat_okay_btn.get_combined_minimum_size()
		beat_okay_btn.position = (wall_view.position + wall_view.beat_okay_pos() - beat_okay_btn.size * 0.5).round()
		beat_okay_btn.modulate.a = zoom
	if on_wall and wall_view.active and wall_view.practice == "" and not wall_view.free_practice:
		Game.note_time(delta / maxf(Engine.time_scale, 0.01))  # real seconds, even with Rapid Fire
	# Rapid Fire: everything in the mine runs faster (only while you're mining, not on breaks or in menus)
	var speed := Game.rapid_speed() if wall_view.active and wall_view.practice == "" and not wall_view.free_practice and not wall_view.resting and not wall_view.in_beat_practice() else 1.0
	if not is_equal_approx(Engine.time_scale, speed):
		Engine.time_scale = speed
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 40.0)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	elif position != Vector2.ZERO:
		position = Vector2.ZERO


# ================================================================== build
func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Config.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists(UI_DIR + "background.png"):  # optional art: the room behind the rock
		room_bg = TextureRect.new()
		room_bg.texture = load(UI_DIR + "background.png")
		room_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		room_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		room_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- the two screens fill the whole window, side by side inside a clipped area. The rock screen
	# keeps its content below the menu bar; the mine is the whole window (just the cave).
	screens_area = Control.new()
	screens_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	screens_area.clip_contents = true
	add_child(screens_area)

	# --- top menu bar (rock screen only: it slides up out of the way when you go down the mine).
	# Built here, added to the window after the screens so it sits on top of them.
	menu_bar = PanelContainer.new()
	var mb := StyleBoxFlat.new()
	mb.bg_color = Config.MENU_BAR_COLOR
	mb.border_color = Config.MENU_BAR_EDGE
	mb.border_width_bottom = 4
	menu_bar.add_theme_stylebox_override("panel", mb)
	menu_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var top_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		top_margin.add_theme_constant_override("margin_" + side, Config.SAFE_BORDER)
	menu_bar.add_child(top_margin)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top_margin.add_child(top)
	top.add_child(_title(GameVersion.TITLE.to_upper(), 32, Config.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	coin_label = _label("", 26, Config.ACCENT)
	top.add_child(coin_label)
	var tk := _icon(Game.ui_texture("ticket.png"), 32)
	tk.tooltip_text = "Mine tickets, all caves (Shop > Caves)"
	top.add_child(tk)
	ticket_icon = tk
	ticket_label = _label("", 26, Config.TEXT_COLOR)
	ticket_label.tooltip_text = tk.tooltip_text
	ticket_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(ticket_label)
	shop_btn = _top_button("Shop", _open_shop)
	top.add_child(shop_btn)
	backpack_btn = _icon_button("backpack", "Backpack", "Backpack: your ores & gems", _open_backpack)
	top.add_child(backpack_btn)
	settings_btn = _icon_button("settings", "Settings", "Settings", _open_settings)
	top.add_child(settings_btn)
	help_btn = _top_button("?", _open_tutorial)
	help_btn.custom_minimum_size.x = 48
	help_btn.tooltip_text = "Tutorial"
	top.add_child(help_btn)

	slider = Control.new()
	slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screens_area.add_child(slider)
	if room_bg:
		slider.add_child(room_bg)  # sized to the rock screen in _layout_screens

	# main screen: [arrow] [rock] [Your Rocks]
	main_screen = MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		main_screen.add_theme_constant_override("margin_" + side, Config.SAFE_BORDER)  # never right at the window's edge
	slider.add_child(main_screen)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	main_screen.add_child(body)
	var left_col := VBoxContainer.new()  # the Mine arrow, with Practice under it
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 10)
	body.add_child(left_col)
	mine_btn = _arrow_button("<", "Mine", _go_wall)
	left_col.add_child(mine_btn)
	practice_btn = _button("Practice", _open_practice)
	practice_btn.custom_minimum_size = Vector2(72, 52)
	practice_btn.add_theme_font_size_override("font_size", Config.font_px(16))
	practice_btn.tooltip_text = "Practice any activity: no lighter to look after, no ticket - and no coins"
	left_col.add_child(practice_btn)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(center)
	rock_title = _title("", 30, Config.TEXT_COLOR)  # under the rock, on the table (added after the holder)
	rock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(holder)
	var stack := Control.new()  # the rock (sits on the table in the room art)
	stack.custom_minimum_size = Vector2.ONE * Config.ROCK_DISPLAY_SIZE
	holder.add_child(stack)
	rock_stack = stack
	rock_view = RockView.new()
	rock_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(rock_view)
	center.add_child(rock_title)
	hint_label = _hint(_label("", 18, Config.MUTED_TEXT)) as Label
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint_label)
	crush_btn = _button("CRUSH ALL", _crush_all)
	crush_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	crush_btn.custom_minimum_size = Vector2(220, 52)
	crush_btn.add_theme_font_size_override("font_size", Config.font_px(20))
	crush_btn.tooltip_text = "Break every rock you have at once (the bag and the anvil)"
	center.add_child(crush_btn)

	var right := _panel(280)
	body.add_child(right)
	rocks_panel = right
	var rv := VBoxContainer.new()
	right.add_child(rv)
	rv.add_child(_title("Your Rocks", 24, Config.ACCENT))
	rv.add_child(_hint(_label("Click one to put it on the anvil", 14, Config.MUTED_TEXT)))
	bag_list = _scroll_list(rv)

	# wall screen: just the cave wall, the whole window. The Back button sits on it at the right; actions
	# keep clear of it (WALL_MARGINS) so it never covers a spot you need to tap.
	wall_screen = Control.new()
	wall_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider.add_child(wall_screen)
	wall_view = WallView.new()
	wall_view.font = font
	wall_view.title_font = title_font
	wall_screen.add_child(wall_view)
	back_btn = _arrow_button(">", "Back", _leave_mine)
	wall_screen.add_child(back_btn)
	beat_okay_btn = _button("Okay", func(): wall_view.skip_beat_practice())
	beat_okay_btn.custom_minimum_size = Vector2(140, 44)
	beat_okay_btn.tooltip_text = "Skip the practice (ENTER). Settings > Beat practice can always skip it."
	beat_okay_btn.visible = false
	wall_screen.add_child(beat_okay_btn)
	_build_run_ui()
	add_child(menu_bar)  # above the screens

	# --- floating fx (drop pop-ups) above everything
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

	_build_shop()
	_build_backpack()
	_build_settings()
	_build_practice()
	_build_select_mine()
	_build_book()

	toast_label = _title("", 22, Config.TEXT_COLOR)
	toast_label.add_theme_constant_override("outline_size", Config.TEXT_OUTLINE_SIZE + 3)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	version_label = _label("", 16, Config.MUTED_TEXT)
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(version_label)
	_update_version_label()

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Config.FULL_FLASH_COLOR
	flash_rect.modulate.a = 0.0
	add_child(flash_rect)

	tutorial = Tutorial.new()
	tutorial.main = self
	add_child(tutorial)

	reset_confirm = ConfirmationDialog.new()
	reset_confirm.dialog_text = "Start over? Coins, rocks, ores, upgrades and Rebirths are wiped."
	reset_confirm.confirmed.connect(_reset)
	add_child(reset_confirm)
	rebirth_confirm = ConfirmationDialog.new()
	rebirth_confirm.ok_button_text = "REBIRTH"
	rebirth_confirm.cancel_button_text = "Not yet"
	rebirth_confirm.confirmed.connect(_rebirth)
	add_child(rebirth_confirm)
	leave_confirm = ConfirmationDialog.new()
	leave_confirm.ok_button_text = "Cash out & leave"
	leave_confirm.cancel_button_text = "Keep mining"
	leave_confirm.confirmed.connect(_cash_out)
	add_child(leave_confirm)
	_update_sound_btn()


## A dimmed full-screen popup with a titled panel. Returns [overlay, content VBox].
func _make_overlay(title: String, close: Callable) -> Array:
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	ov.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			close.call())  # (the mouse wheel is a "button" too: scrolling must not close the menu)
	add_child(ov)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var panel := PanelContainer.new()
	cc.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var tl := _title(title, 30, Config.ACCENT)
	head.add_child(tl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_button("Close", close))
	return [ov, v, tl]


## The shop has three tabs: rocks (limited stock, market prices), Upgrades and Caves
## (a ticket for each cave).
func _build_shop() -> void:
	var o := _make_overlay("Rock Shop", _close_overlays)
	shop_overlay = o[0]
	var v: VBoxContainer = o[1]
	shop_title = o[2]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var grp := ButtonGroup.new()
	tab_rocks = _button("Rock Shop", _show_shop_tab.bind("rocks"))
	tab_dwarf = _button("Upgrades", _show_shop_tab.bind("dwarf"))
	tab_caves = _button("Caves", _show_shop_tab.bind("caves"))
	tab_stocks = _button("Stock Prices", _show_shop_tab.bind("stocks"))
	for b in [tab_rocks, tab_dwarf, tab_caves, tab_stocks]:
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(196, 46)
		b.add_theme_color_override("font_pressed_color", Config.ACCENT)  # the open tab reads gold
		b.add_theme_color_override("font_hover_pressed_color", Config.ACCENT)
		tabs.add_child(b)

	rock_page = VBoxContainer.new()
	rock_page.add_theme_constant_override("separation", 10)
	rock_page.custom_minimum_size.x = 820
	v.add_child(rock_page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	rock_page.add_child(head)
	var times := VBoxContainer.new()
	times.add_theme_constant_override("separation", 0)
	times.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(times)
	shop_timer = _label("", 16, Config.TEXT_COLOR)
	times.add_child(shop_timer)
	shop_clock = _hint(_label("", 16, Config.MUTED_TEXT)) as Label
	times.add_child(shop_clock)
	restock_btn = _button("", _instant_restock)
	restock_btn.visible = Config.INSTANT_RESTOCK_COST >= 0
	restock_btn.add_theme_font_size_override("font_size", Config.font_px(16))
	restock_btn.custom_minimum_size = Vector2(240, 44)
	head.add_child(restock_btn)
	# the shelf: every rock in its own wooden cubby, cheapest first (click one to buy it)
	var ssc := ScrollContainer.new()
	ssc.custom_minimum_size = Vector2(820, 430)
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rock_page.add_child(ssc)
	var shelf := PanelContainer.new()
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shelf_sb := _skin("shelf", Vector4i(6, 6, 6, 6), Vector4(7, 7, 7, 7), true)
	if shelf_sb:
		shelf.add_theme_stylebox_override("panel", shelf_sb)
	ssc.add_child(shelf)
	shop_grid = GridContainer.new()
	shop_grid.columns = 6
	shop_grid.add_theme_constant_override("h_separation", 4)
	shop_grid.add_theme_constant_override("v_separation", 4)
	shop_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shelf.add_child(shop_grid)

	dwarf_page = VBoxContainer.new()
	dwarf_page.add_theme_constant_override("separation", 10)
	dwarf_page.custom_minimum_size.x = 820
	v.add_child(dwarf_page)
	dwarf_page.add_child(_title("Upgrades", 24, Config.ACCENT))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(820, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dwarf_page.add_child(sc)
	upgrade_list = VBoxContainer.new()
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_list.add_theme_constant_override("separation", 8)
	sc.add_child(upgrade_list)

	# Caves: the free ticket, then one row per cave (its tickets, buy one, go down)
	cave_page = VBoxContainer.new()
	cave_page.add_theme_constant_override("separation", 10)
	cave_page.custom_minimum_size.x = 820
	v.add_child(cave_page)
	var tcard := PanelContainer.new()
	tcard.add_theme_stylebox_override("panel", slot_style)
	cave_page.add_child(tcard)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 12)
	tcard.add_child(trow)
	trow.add_child(_icon(Game.ui_texture("ticket.png"), 56))
	var tinfo := VBoxContainer.new()
	tinfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tinfo.add_theme_constant_override("separation", 0)
	trow.add_child(tinfo)
	ticket_info = _label("", 20, Config.TEXT_COLOR)
	tinfo.add_child(ticket_info)
	var tsub := _hint(_label("One ticket = one trip down that cave, until you run out of lives. Each cave keeps its own stage.", 14, Config.MUTED_TEXT)) as Label
	tsub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tsub.custom_minimum_size.x = 380
	tinfo.add_child(tsub)
	claim_btn = _button("", _claim_ticket)
	claim_btn.custom_minimum_size = Vector2(230, 48)
	trow.add_child(claim_btn)
	var csc := ScrollContainer.new()
	csc.custom_minimum_size = Vector2(820, 360)
	csc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cave_page.add_child(csc)
	cave_list = VBoxContainer.new()
	cave_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cave_list.add_theme_constant_override("separation", 8)
	csc.add_child(cave_list)

	stock_page = VBoxContainer.new()
	stock_page.add_theme_constant_override("separation", 10)
	stock_page.custom_minimum_size.x = 820
	v.add_child(stock_page)
	_build_stock_page(stock_page)
	_show_shop_tab("rocks", false)


func _show_shop_tab(tab: String, sound := true) -> void:
	if sound and tab != shop_tab:
		Sfx.play("click")
	shop_tab = tab
	rock_page.visible = tab == "rocks"
	dwarf_page.visible = tab == "dwarf"
	cave_page.visible = tab == "caves"
	stock_page.visible = tab == "stocks"
	shop_title.text = {"rocks": "Rock Shop", "dwarf": "Upgrades", "caves": "Caves", "stocks": "Stock Prices"}.get(tab, "Shop")
	tab_rocks.set_pressed_no_signal(tab == "rocks")
	tab_dwarf.set_pressed_no_signal(tab == "dwarf")
	tab_caves.set_pressed_no_signal(tab == "caves")
	tab_stocks.set_pressed_no_signal(tab == "stocks")
	_update_tickets()
	if tab == "stocks":
		_show_market_tab(market_tab, false)


func _update_tickets() -> void:
	ticket_label.text = "x%d" % Game.ticket_count()
	if ticket_info == null:
		return
	ticket_info.text = "Mine tickets: %d" % Game.ticket_count() + ("   (on a trip in %s)" % Game.cave_name() if Game.trip_active else "")
	var left := Game.free_ticket_left()
	claim_btn.text = "Free %s ticket!" % Game.cave_name(Game.first_cave()) if left <= 0.0 else "Free ticket in %s" % _fmt_time(left)
	claim_btn.disabled = left > 0.0
	if mine_claim_btn:
		mine_claim_btn.text = claim_btn.text
		mine_claim_btn.disabled = claim_btn.disabled


## The Caves tab (and the Select Mine popup): one row per cave with its wall, perks, your tickets, Buy
## and Go down.
func _rebuild_caves() -> void:
	for list in [cave_list, mine_list]:
		if list != null:
			_fill_caves(list)


func _fill_caves(list: VBoxContainer) -> void:
	for c in list.get_children():
		c.queue_free()
	for id in Config.CAVES:
		var cv: Dictionary = Config.CAVES[id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", slot_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var tile_file: String = cv.get("tile", Config.WALL_TILE_FILE)
		var tile_tex: Texture2D = load(tile_file) if ResourceLoader.exists(tile_file) else Game.rock_texture("missing")
		row.add_child(_icon(tile_tex, 64))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var head := HBoxContainer.new()
		info.add_child(head)
		head.add_child(_label(cv.get("name", id), 20, Config.ACCENT if Game.trip_active and id == Game.cave else Config.TEXT_COLOR))
		head.add_child(_label("   Tickets: %d" % Game.ticket_count(id), 15, Config.TEXT_COLOR if Game.ticket_count(id) > 0 else Config.MUTED_TEXT))
		var fuel := float(cv.get("fuel", 1.0))
		var perks := "Coins x%s" % String.num(float(cv.get("coins", 1.0)), 2)
		if fuel < 0.999:
			perks += "   -   light fades %d%% faster" % roundi((1.0 / fuel - 1.0) * 100.0)
		perks += "   -   %s%% rock per stage" % String.num(float(cv.get("stone_chance", 0.0)), 1)
		if int(cv.get("head_start", 0)) > 0:
			perks += "   -   harder walls (+%d)" % int(cv.get("head_start", 0))
		info.add_child(_label(perks, 15, Config.TEXT_COLOR))
		var cs := Game.cave_stage(id)
		info.add_child(_label("Stage %d   (best %d)   -   heart %d+ BPM   -   %d walls" % [cs, Game.cave_best(id), roundi(Game.stage_bpm(cs, id)), Game.base_walls(cs)], 14, Config.MUTED_TEXT))
		var price := Game.ticket_price(id)
		var buy := _button("Buy ticket  %d" % price, _buy_ticket.bind(id))
		buy.custom_minimum_size = Vector2(190, 48)
		buy.disabled = Game.coins < price
		row.add_child(buy)
		var here: bool = Game.trip_active and id == Game.cave
		var go := _button("Continue" if here else "Go down", _enter_cave.bind(id))
		go.custom_minimum_size = Vector2(140, 48)
		go.disabled = not here and (Game.trip_active or Game.ticket_count(id) <= 0)
		if Game.trip_active and not here:
			go.tooltip_text = "Finish your trip in %s first (it ends when you run out of lives)" % Game.cave_name()
		row.add_child(go)
		list.add_child(card)


func _rebuild_upgrades() -> void:
	for c in upgrade_list.get_children():
		c.queue_free()
	for id in Config.UPGRADES:
		var u: Dictionary = Config.UPGRADES[id]
		var lv := Game.upgrade_level(id)
		var top := Game.upgrade_max(id)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", slot_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(_icon(Game.ui_texture("upgrades/%s.png" % id), 56))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var head := HBoxContainer.new()
		info.add_child(head)
		head.add_child(_label(u.get("name", id), 20, Config.TEXT_COLOR))
		head.add_child(_label("   Lv %d / %d" % [lv, top], 15, Config.MUTED_TEXT))
		var eff := HBoxContainer.new()
		info.add_child(eff)
		eff.add_child(_label(_upgrade_text(id, Game.upgrade_value(id)) if lv > 0 else "Not bought yet", 15,
				Config.TEXT_COLOR if lv > 0 else Config.MUTED_TEXT))
		if lv < top:
			eff.add_child(_label("  ->  " + _upgrade_text(id, Game.upgrade_value(id, lv + 1)), 15, Config.ACCENT))
		var cost := Game.upgrade_cost(id)
		var b := _button("MAXED" if lv >= top else "Upgrade  %d" % cost, _buy_upgrade.bind(id))
		b.custom_minimum_size = Vector2(180, 48)
		b.disabled = lv >= top or Game.coins < cost
		row.add_child(b)
		upgrade_list.add_child(card)
	upgrade_list.add_child(_rebirth_card())


## Rebirth: the whole game over for one more artifact slot on every run (REBIRTH_MAX times). Shows what the next
## one costs - coins and ores / gems, each green when you have enough, red when you don't.
func _rebirth_card() -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", slot_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(_icon(Game.ui_texture("upgrades/rebirth.png"), 56))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	var head := HBoxContainer.new()
	info.add_child(head)
	head.add_child(_label("Rebirth", 20, Config.ACCENT))
	head.add_child(_label("   %d / %d done   -   %d artifact slots" % [Game.rebirths, Config.REBIRTH_MAX, Game.base_slots()], 15, Config.MUTED_TEXT))
	var d := _label("Start the WHOLE game over - coins, rocks, ores, upgrades, caves and tickets are wiped - for +%d artifact slot on every run, forever." % Config.REBIRTH_SLOTS, 15, Config.TEXT_COLOR)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 520
	info.add_child(d)
	var why := Game.rebirth_blocker()
	if Game.rebirths < Config.REBIRTH_MAX:
		var c := Game.rebirth_cost()
		var need := HFlowContainer.new()
		need.add_theme_constant_override("h_separation", 12)
		need.custom_minimum_size.x = 520
		info.add_child(need)
		need.add_child(_label("%s / %s coins" % [_big(Game.coins), _big(c.coins)], 15,
				Config.MARKET_GOOD_COLOR if Game.coins >= int(c.coins) else Config.MARKET_BAD_COLOR))
		for id in c.ores:
			var have := int(Game.ores.get(id, 0))
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			var ic := _icon(Game.ore_texture(id), 24)
			ic.tooltip_text = Game.ore_name(id)
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			cell.add_child(ic)
			cell.add_child(_label("%d/%d" % [have, c.ores[id]], 15, Config.MARKET_GOOD_COLOR if have >= int(c.ores[id]) else Config.MARKET_BAD_COLOR))
			need.add_child(cell)
	var b := _button("MAXED" if Game.rebirths >= Config.REBIRTH_MAX else "Rebirth", _ask_rebirth)
	b.custom_minimum_size = Vector2(180, 48)
	b.disabled = why != ""
	b.tooltip_text = why
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return card


func _ask_rebirth() -> void:
	if Game.rebirth_blocker() != "":
		Sfx.play("error")
		return
	rebirth_confirm.dialog_text = "REBIRTH #%d?\n\nEverything is wiped: coins, rocks, ores, upgrades, caves and tickets.\nYou keep: %d artifact slots on every run, forever." % [Game.rebirths + 1, Game.base_slots() + Config.REBIRTH_SLOTS]
	rebirth_confirm.popup_centered()


func _rebirth() -> void:
	if not Game.rebirth():
		Sfx.play("error")
		return
	_close_overlays()
	rock_view.set_rock("")
	_auto_place("")
	Sfx.play("supernova")
	show_toast("REBORN!  %d artifact slots on every run" % Game.base_slots())


## 2500000 -> "2,500,000"
func _big(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "," + t.right(3) + out
		t = t.left(t.length() - 3)
	return ("-" if n < 0 else "") + t + out


## "+2.5% coins in the mine", "0.2% chance a sale pays +15%"
func _upgrade_text(id: String, v: float) -> String:
	var n := String.num(v, 2 if v < 10.0 else 1)
	if id == "fools_gold":
		return "%s%% chance a sale pays +%s%%" % [n, String.num(Config.FOOLS_GOLD_BONUS, 1)]
	if id == "pack_of_fluid":  # lives every stage, in half lives, never above MAX_LIVES
		var u: Dictionary = Config.UPGRADES[id]
		var lives := minf(Config.LIVES + floorf(v * 2.0 + 0.001) / 2.0, Config.MAX_LIVES)
		var text := "%s / %s lives every stage" % [String.num(lives, 1), String.num(Config.MAX_LIVES, 1)]
		if lives >= Config.MAX_LIVES:
			return text + "  (MAX)"
		# levels per half life (20 levels for +2 lives = 5), and the level that gives the next one
		var per_half := maxi(1, roundi(float(u.get("levels", 1)) / (float(u.get("max", 1.0)) * 2.0)))
		var lv := roundi(v / maxf(float(u.get("max", 1.0)) / float(u.get("levels", 1)), 0.0001))
		return text + "  (next half life at Lv %d)" % ((lv / per_half + 1) * per_half)
	if id in ["silktouch", "ticket_hungry"]:
		return "%s%% %s" % [n, Config.UPGRADES[id].get("text", "")]
	return "+%s%% %s" % [n, Config.UPGRADES[id].get("text", "")]


## "+40%" / "-15%" next to a price (nothing at the normal price). The sign says whether it's good for you,
## not which way the price went - colours alone were too easy to miss: + = profit, - = a loss.
## Ores sell: higher is good. Rocks you buy: cheaper is good.
func _market_tag(id: String, fs: int) -> Label:
	var m := Game.market_mult(id)
	var pct := roundi(m * 100.0)
	var rock := Config.ROCKS.has(id)
	var l := _label(_deal_text(pct - 100, rock), fs, _pct_color(pct - 100, rock))
	l.tooltip_text = "Market price: %d%% of normal  (+ = good for you, - = bad for you)" % pct
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


## How good a price change is for YOU, with a sign: "+12%" good, "-12%" bad, "" none.
## rock = true: you buy it, so a price going DOWN is the "+".
func _deal_text(delta: int, rock := false, zero := "") -> String:
	var gain := -delta if rock else delta
	if gain == 0:
		return zero
	return ("+%d%%" % gain) if gain > 0 else ("-%d%%" % -gain)


## " (+ good deal)" / " (- bad deal)" after a line of text.
func _deal_word(delta: int, rock := false) -> String:
	var gain := -delta if rock else delta
	return "" if gain == 0 else ("  (+ good deal)" if gain > 0 else "  (- bad deal)")


## Shop > Stock Prices: today's price of everything (vs normal, how it moved at the last restock and the
## profit in it), sortable from least to most profit, and a page for each ore / gem (lore, where to find
## it) and rock.
const STOCK_COLS := 58                 # width of each number column in the list (and its header)


func _build_stock_page(v: VBoxContainer) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var grp := ButtonGroup.new()
	tab_m_ores = _button("Ores", _show_market_tab.bind("ores"))
	tab_m_gems = _button("Gems", _show_market_tab.bind("gems"))
	tab_m_rocks = _button("Rocks", _show_market_tab.bind("rocks"))
	for b in [tab_m_ores, tab_m_gems, tab_m_rocks]:
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(120, 44)
		b.add_theme_color_override("font_pressed_color", Config.ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", Config.ACCENT)
		tabs.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	stock_timer = _label("", 18, Config.ACCENT)
	stock_timer.tooltip_text = "Every price moves when the shop restocks by itself (paying to restock doesn't move them)"
	stock_timer.mouse_filter = Control.MOUSE_FILTER_PASS
	stock_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tabs.add_child(stock_timer)
	sort_btn = _button("", _cycle_sort)
	sort_btn.custom_minimum_size = Vector2(260, 44)
	sort_btn.add_theme_font_size_override("font_size", Config.font_px(16))
	sort_btn.tooltip_text = "Click to change the order"
	tabs.add_child(sort_btn)
	_update_sort_btn()
	var hint := _hint(_label("+ means good for you (profit), - means bad for you (a loss). Deal = today's price vs normal, Moved = since the last restock. Profit: ores = coins above (or below) their normal price; rocks = what's inside on average minus what they cost.", 15, Config.MUTED_TEXT)) as Label
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 800
	v.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	# column names over the list (same widths as the rows below)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.custom_minimum_size.x = 480
	left.add_child(head)
	var head_pad := Control.new()
	head_pad.custom_minimum_size.x = 8 + 32
	head_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_pad)
	for col in [["Price", "Price right now"], ["Deal", "Today's price vs normal:  + = good for you (sell high / buy cheap),  - = bad for you"], ["Moved", "How the deal changed at the last restock:  + = better for you,  - = worse"], ["Profit", "Ores: coins above / below the normal price.  Rocks: worth inside (average) minus price.  + = profit,  - = a loss"]]:
		var hl := _label(col[0], 14, Config.MUTED_TEXT)
		hl.custom_minimum_size.x = STOCK_COLS
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hl.tooltip_text = col[1]
		hl.mouse_filter = Control.MOUSE_FILTER_PASS
		head.add_child(hl)
	var head_end := Control.new()
	head_end.custom_minimum_size.x = 10 + 8  # the rows' right inset + the scroll bar
	head.add_child(head_end)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(480, 360)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	market_list = VBoxContainer.new()
	market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_list.add_theme_constant_override("separation", 4)
	sc.add_child(market_list)
	var dcard := PanelContainer.new()
	dcard.add_theme_stylebox_override("panel", slot_style)
	dcard.custom_minimum_size = Vector2(328, 380)
	dcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(dcard)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dcard.add_child(dsc)
	market_detail = VBoxContainer.new()
	market_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_detail.add_theme_constant_override("separation", 6)
	dsc.add_child(market_detail)


func _show_market_tab(tab: String, sound := true) -> void:
	if sound and tab != market_tab:
		Sfx.play("click")
	if tab != market_tab:
		market_pick = ""
	market_tab = tab
	tab_m_ores.set_pressed_no_signal(tab == "ores")
	tab_m_gems.set_pressed_no_signal(tab == "gems")
	tab_m_rocks.set_pressed_no_signal(tab == "rocks")
	_rebuild_market()


## Normal order -> least profit first -> most profit first -> ...
func _cycle_sort() -> void:
	Sfx.play("click")
	market_sort = {"": "low", "low": "high"}.get(market_sort, "")
	_update_sort_btn()
	_rebuild_market()


func _update_sort_btn() -> void:
	sort_btn.text = {"low": "Sort: least -> most profit", "high": "Sort: most -> least profit"}.get(market_sort, "Sort: normal order")


func _rebuild_market() -> void:
	if market_list == null or not (shop_overlay.visible and shop_tab == "stocks"):
		return
	for c in market_list.get_children():
		c.queue_free()
	var ore := market_tab != "rocks"  # the Ores or the Gems tab
	var ids: Array = _rocks_by_price()
	if ore:  # the Ores tab: every ore; the Gems tab: every gem (cheapest first)
		ids = _ores_then_gems().filter(func(id): return Game.is_gem(id) == (market_tab == "gems"))
	if market_sort != "":
		var profit := {}
		var order := {}
		for i in ids.size():
			profit[ids[i]] = _profit(ids[i], ore)
			order[ids[i]] = i
		var low := market_sort == "low"
		ids.sort_custom(func(a, b):
			if profit[a] != profit[b]:
				return profit[a] < profit[b] if low else profit[a] > profit[b]
			return order[a] < order[b])  # ties keep the normal order
	if market_pick == "" or not ids.has(market_pick):
		market_pick = ids[0]
	for id in ids:
		market_list.add_child(_market_row(id))
	_show_market_detail(market_pick)


## Coins of profit in one: an ore sold now vs its normal price; a rock = its average worth inside at
## today's prices minus what it costs in the shop today.
func _profit(id: String, ore: bool) -> int:
	if ore:
		return Game.ore_price(id) - int(Config.ORES[id].sell_price)
	return roundi(_rock_worth(id)) - Game.rock_price(id)


## Every ore id, ores first and then gems (Config.ORES table order inside each group).
func _ores_then_gems() -> Array:
	var ores: Array = Config.ORES.keys().filter(func(id): return not Game.is_gem(id))
	return ores + Config.ORES.keys().filter(func(id): return Game.is_gem(id))


func _rocks_by_price() -> Array:
	var ids: Array = Config.ROCKS.keys()
	ids.sort_custom(func(a, b): return int(Config.ROCKS[a].price) < int(Config.ROCKS[b].price))
	return ids


## One line of the list: icon, name, price now, % of normal, last move, profit. Click it for its page.
func _market_row(id: String) -> Control:
	var ore := market_tab != "rocks"  # the Ores or the Gems tab
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.button_pressed = id == market_pick
	b.pressed.connect(func():
		Sfx.play("click")
		market_pick = id
		_rebuild_market())
	var flat := slot_style.duplicate() as StyleBox
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("hover", _box(Color("#5a3a52"), Color("#2e222f"), 3, 0, 6))
	b.add_theme_stylebox_override("pressed", _box(Color("#6e4b2f"), Config.ACCENT, 3, 0, 6))
	b.add_theme_stylebox_override("hover_pressed", _box(Color("#6e4b2f"), Config.ACCENT, 3, 0, 6))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := _icon(Game.ore_texture(id) if ore else Game.rock_icon(id), 32)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var name_l := _label(Game.ore_name(id) if ore else Game.rock_name(id), 16, Config.ORES[id].color if ore else Config.TEXT_COLOR)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_l)
	var price := Game.ore_price(id) if ore else Game.rock_price(id)
	var pl := _label("%d" % price, 16, Config.ACCENT)
	pl.custom_minimum_size.x = STOCK_COLS
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	var pct := roundi(Game.market_mult(id) * 100.0)
	var ml := _label(_deal_text(pct - 100, not ore, "0%"), 16, _pct_color(pct - 100, not ore))
	ml.custom_minimum_size.x = STOCK_COLS
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ml)
	var tr := Game.market_trend(id)
	var tl := _label(_deal_text(tr, not ore, "0%"), 16, _pct_color(tr, not ore))
	tl.custom_minimum_size.x = STOCK_COLS
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(tl)
	var pf := _profit(id, ore)
	var fl := _label(("+%d" % pf) if pf > 0 else ("%d" % pf) if pf < 0 else "0", 16, _pct_color(pf))
	fl.custom_minimum_size.x = STOCK_COLS
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(fl)
	for c in h.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Colour for a price change: green = good for you, red = bad. rock = true: you BUY it, so cheaper is good.
func _pct_color(delta: int, rock := false) -> Color:
	if delta == 0:
		return Config.MUTED_TEXT
	return Config.MARKET_GOOD_COLOR if (delta > 0) != rock else Config.MARKET_BAD_COLOR


## The page on the right.
func _show_market_detail(id: String) -> void:
	for c in market_detail.get_children():
		c.queue_free()
	var ore := market_tab != "rocks"  # the Ores or the Gems tab
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	market_detail.add_child(head)
	head.add_child(_icon(Game.ore_texture(id) if ore else Game.rock_icon(id), 80))
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(_title(Game.ore_name(id) if ore else Game.rock_name(id), 32, Config.ORES[id].color if ore else Config.ACCENT))
	var pct := roundi(Game.market_mult(id) * 100.0)
	var tr := Game.market_trend(id)
	if ore:
		var o: Dictionary = Config.ORES[id]
		hv.add_child(_label(("Gem" if Game.is_gem(id) else "Ore") + ("  -  rare" if o.get("rare", false) else ""), 16, Config.MUTED_TEXT))
		_detail_line("Sells for %d coins" % Game.ore_price(id), Config.ACCENT)
		_detail_line("Market: %d%% of the normal %d%s  (%s for you at the last restock)" % [pct, int(o.sell_price), _deal_word(pct - 100),
				_deal_text(tr, false, "no change")], _pct_color(pct - 100))
		var pf := _profit(id, true)
		_detail_line("Profit: %s coins each vs the normal price%s" % [("+%d" % pf) if pf > 0 else str(pf), _deal_word(pf)], _pct_color(pf))
		_detail_line("In your backpack: %d" % int(Game.ores.get(id, 0)), Config.TEXT_COLOR)
		var best := _best_rocks_for(id)
		_detail_line("Only found in: " + ", ".join(best), Config.TEXT_COLOR)
		market_detail.add_child(HSeparator.new())
		var lore := _label(Config.ORE_LORE.get(id, "Nobody knows much about this one yet."), 16, Config.TEXT_COLOR)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size.x = 290
		market_detail.add_child(lore)
	else:
		var r: Dictionary = Config.ROCKS[id]
		hv.add_child(_label("Rock", 16, Config.MUTED_TEXT))
		_detail_line("Shop price: %d coins" % Game.rock_price(id), Config.ACCENT)
		_detail_line("Market: %d%% of the normal %d%s  (%s for you at the last restock)" % [pct, int(r.price), _deal_word(pct - 100, true),
				_deal_text(tr, true, "no change")], _pct_color(pct - 100, true))
		_detail_line("Hits to break: %d - %d" % [int(r.get("hits_min", Config.HITS_MIN)), int(r.get("hits_max", Config.HITS_MAX))], Config.TEXT_COLOR)
		_detail_line("Drop rolls: %d" % int(r.get("rolls", 1)), Config.TEXT_COLOR)
		var parts := []
		for oid in r.get("drops", {}):
			parts.append("%s (%s%%)" % [Game.ore_name(oid), String.num(Game.drop_chance(id, oid), 1)])
		_detail_line("Can drop: " + ", ".join(parts), Config.TEXT_COLOR)
		_detail_line("In stock at a restock: %d%% of the time (up to %d)" % [roundi(float(r.get("stock_chance", 1.0)) * 100.0), int(r.get("stock_max", 1))], Config.TEXT_COLOR)
		_detail_line("Worth inside, on average: ~%d coins at today's prices" % roundi(_rock_worth(id)), Config.ACCENT)
		var pf := _profit(id, false)
		_detail_line("Profit: %s coins per rock, on average%s" % [("+%d" % pf) if pf > 0 else str(pf), _deal_word(pf)], _pct_color(pf))
		_detail_line("You own: %d" % int(Game.rocks.get(id, 0)), Config.TEXT_COLOR)


func _detail_line(text: String, col: Color) -> void:
	var l := _label(text, 16, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 290
	market_detail.add_child(l)


## The 3 rocks most likely to give this ore (your upgrades included).
func _best_rocks_for(ore_id: String) -> Array:
	var ids: Array = Config.ROCKS.keys()
	ids.sort_custom(func(a, b): return Game.drop_chance(a, ore_id) > Game.drop_chance(b, ore_id))
	var out := []
	for rid in ids.slice(0, 3):
		out.append("%s (%s%%)" % [Game.rock_name(rid), String.num(Game.drop_chance(rid, ore_id), 2)])
	return out


## What a rock's drops are worth on average at today's market prices (upgrades included).
func _rock_worth(rid: String) -> float:
	var total := 0.0
	for oid in Config.ORES:
		var a := Game.drop_amount(rid, oid)
		var n := (a.x + a.y) * 0.5
		if not Game.is_gem(oid):
			n *= 1.0 + Game.upgrade_value("rocky_riches") / 100.0
		total += Game.drop_chance(rid, oid) / 100.0 * n * Game.ore_price(oid)
	return total * int(Config.ROCKS[rid].get("rolls", 1))


func _build_backpack() -> void:
	var o := _make_overlay("Backpack", _close_overlays)
	backpack_overlay = o[0]
	var v: VBoxContainer = o[1]
	v.add_child(_label("Ores & Gems", 18, Config.MUTED_TEXT))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(460, 320)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	ore_list = VBoxContainer.new()
	ore_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ore_list.add_theme_constant_override("separation", 8)
	sc.add_child(ore_list)
	sell_all_btn = _button("", _sell_all)
	sell_all_btn.custom_minimum_size.y = 44
	v.add_child(sell_all_btn)


func _build_settings() -> void:
	var o := _make_overlay("Settings", _close_overlays)
	settings_overlay = o[0]
	var v: VBoxContainer = o[1]
	v.custom_minimum_size.x = 380
	hints_btn = _button("", _toggle_hints)
	hints_btn.custom_minimum_size.y = 44
	v.add_child(hints_btn)
	tips_btn = _button("", func():
		Game.set_show_tips(not Game.show_tips)
		Sfx.play("click"))
	tips_btn.custom_minimum_size.y = 44
	v.add_child(tips_btn)
	circles_btn = _button("", func():
		Game.set_color_circles(not Game.color_circles)
		Sfx.play("click"))
	circles_btn.custom_minimum_size.y = 44
	circles_btn.tooltip_text = "Tap circles each get their own colour (in the order they close), so they're easier to tell apart"
	v.add_child(circles_btn)
	beat_btn = _button("", func():
		Game.set_beat_practice(not Game.beat_practice)
		Sfx.play("click"))
	beat_btn.custom_minimum_size.y = 44
	beat_btn.tooltip_text = "After every wall the view zooms in on the FLICK bar so you can feel your heartbeat. Off: straight to the 3, 2, 1."
	v.add_child(beat_btn)
	sound_btn = _button("", _toggle_sound)
	sound_btn.custom_minimum_size.y = 44
	v.add_child(sound_btn)
	music_slider = _volume_row(v, "Music", Sfx.music_volume, Sfx.set_music_volume)
	sfx_slider = _volume_row(v, "Sound effects", Sfx.sfx_volume, func(x: float):
		Sfx.set_sfx_volume(x)
		Sfx.play("tap"))
	v.add_child(HSeparator.new())
	var reset_btn := _button("Reset game", func(): reset_confirm.popup_centered())
	reset_btn.custom_minimum_size.y = 40
	v.add_child(reset_btn)
	v.add_child(HSeparator.new())
	var credits := _label(GameVersion.TITLE + "  %s  -  by %s
%s
Font: BoldPixels by YukiPixels (CC BY-SA 4.0)
Music: Gambler Symphony, MeltdownTheme, Shop Theme (Thameuszin)" % [
			GameVersion.label(), GameVersion.OWNER, GameVersion.COPYRIGHT], 16, Config.MUTED_TEXT)
	v.add_child(credits)


## Practice (the button under the Mine): pick any activity and play it as long as you like. No lighter to
## look after, no ticket needed, nothing lost - and no coins.
const PRACTICE_EXTRA := {  # the lighter itself can be practiced too
	"flick": ["LIGHTER FLICKS", "Keep the flame alive: flick SPACE in the gold zone, never when it's full"],
	"relight": ["RELIGHTING", "Strike SPACE while the marker is in the gold zone"],
}


func _build_practice() -> void:
	var o := _make_overlay("Practice", _close_overlays)
	practice_overlay = o[0]
	var v: VBoxContainer = o[1]
	var info := _label("Pick anything to practice. No lighter to worry about, no ticket, no lives - and no coins.", 16, Config.MUTED_TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 800
	v.add_child(info)
	_practice_bpm_row(v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var all := {}
	for k in WallView.KIND_INFO:
		all[k] = WallView.KIND_INFO[k]
	for k in PRACTICE_EXTRA:
		all[k] = PRACTICE_EXTRA[k]
	for k in all:
		var b := Button.new()
		b.custom_minimum_size = Vector2(262, 104)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_start_practice.bind(k))
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 12
		inner.offset_right = -12
		inner.offset_top = 6
		inner.offset_bottom = -10
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 0)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		var t := _title(all[k][0], 22, Config.ACCENT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(t)
		var d := _label(all[k][1], 14, Config.TEXT_COLOR)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 236
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(d)
		grid.add_child(b)


## Practice: pick the heart rate the FLICK bar beats at (60 = resting ... 180 = the fastest it gets in the mine).
func _practice_bpm_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var l := _label("Lighter heartbeat (FLICK bar)", 17, Config.TEXT_COLOR)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = Config.HEART_REST_BPM
	sl.max_value = Config.HEART_STRESS_BPM
	sl.step = Config.PRACTICE_BPM_STEP if Config.PRACTICE_BPM_STEP > 0.0 else 1.0
	sl.scrollable = false
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.custom_minimum_size = Vector2(300, 28)
	row.add_child(sl)
	var val := _label("", 17, Config.ACCENT)
	val.custom_minimum_size.x = 150
	row.add_child(val)
	var show := func(x: float):
		var what := "resting" if x <= Config.HEART_REST_BPM else ("max" if x >= Config.HEART_STRESS_BPM else "")
		val.text = "%d BPM%s" % [roundi(x), "  (%s)" % what if what != "" else ""]
	sl.value_changed.connect(func(x: float):
		show.call(x)
		Game.set_practice_bpm(x))
	sl.set_value_no_signal(Game.practice_bpm)
	show.call(Game.practice_bpm)


func _open_practice() -> void:
	_close_overlays()
	practice_overlay.visible = true


func _start_practice(k: String) -> void:
	Sfx.play("click")
	close_overlays_silent()
	wall_view.begin_free_practice(k)
	_slide_to(true)


## "Label ........ 70%" with a slider under it. setter gets 0..1.
func _volume_row(parent: Control, text: String, value: float, setter: Callable) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := _label(text, 17, Config.TEXT_COLOR)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var pct := _label("", 17, Config.ACCENT)
	row.add_child(pct)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.scrollable = false  # the mouse wheel scrolls menus; it must never nudge a volume by accident
	sl.custom_minimum_size.y = 28
	sl.value_changed.connect(func(x: float):
		pct.text = "%d%%" % roundi(x * 100.0)
		setter.call(x))
	parent.add_child(sl)
	sl.set_value_no_signal(value)
	pct.text = "%d%%" % roundi(value * 100.0)
	sl.set_meta("pct", pct)
	return sl


# ================================================================== refresh
func _refresh() -> void:
	_apply_hints()
	coin_label.text = "%d coins" % Game.coins
	_update_crush_btn()
	# bag
	for c in bag_list.get_children():
		c.queue_free()
	if Game.rocks.is_empty():
		bag_list.add_child(_label("Empty. Buy rocks in the Shop!", 15, Config.MUTED_TEXT))
	for id in Game.rocks:
		# the icon has a fixed size and the name clips with "..." - a Button's expand_icon shrank the
		# icon to nothing to make room for a long name
		var label := "%s  x%d" % [Game.rock_name(id), Game.rocks[id]]
		var b := _button("", _place.bind(id))
		b.tooltip_text = label
		b.custom_minimum_size = Vector2(0, 56)
		var hb := HBoxContainer.new()
		hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8
		hb.offset_right = -8
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		var ic := _icon(Game.rock_icon(id), 40)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(ic)
		var nl := _label(label, 24, Config.TEXT_COLOR)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(nl)
		bag_list.add_child(b)
	# ores
	for c in ore_list.get_children():
		c.queue_free()
	var total := 0
	if Game.ores.is_empty():
		ore_list.add_child(_label("Break rocks to find ores.", 15, Config.MUTED_TEXT))
	var section := ""
	for id in _ores_then_gems():  # ores first, then gems (table order inside each)
		if not Game.ores.has(id):
			continue
		var group := "Gems" if Game.is_gem(id) else "Ores"
		if group != section:  # a heading over each group
			section = group
			var hl := _title(group, 22, Config.ACCENT)
			ore_list.add_child(hl)
		var count: int = Game.ores[id]
		var price := Game.ore_price(id)
		total += count * price
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_icon(Game.ore_texture(id), 40))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		info.add_child(_label("%s  x%d" % [Game.ore_name(id), count], 17, Config.ORES[id].color))
		var pr := HBoxContainer.new()
		pr.add_child(_label("%d coins each " % price, 13, Config.MUTED_TEXT))
		pr.add_child(_market_tag(id, 13))
		info.add_child(pr)
		row.add_child(info)
		row.add_child(_button("Sell", _sell.bind(id, 1)))
		row.add_child(_button("All", _sell.bind(id, count)))
		ore_list.add_child(row)
	var label: String = backpack_btn.get_meta("label", "")  # "" when it shows the backpack icon
	if label == "":  # the icon, with how many ores are in it in a little badge on its corner
		var badge: Label = backpack_btn.get_meta("badge")
		badge.text = str(_ore_count()) if not Game.ores.is_empty() else ""
	else:
		backpack_btn.text = ("%s (%d)" % [label, _ore_count()]) if not Game.ores.is_empty() else label
	sell_all_btn.text = "Sell Everything (+%d)" % total
	sell_all_btn.disabled = total <= 0
	_rebuild_shop()
	_rebuild_upgrades()
	_rebuild_caves()
	_update_tickets()
	_rebuild_market()
	_refresh_run()


func _rebuild_shop() -> void:
	restock_btn.text = "Restock now (%d coins)" % Game.restock_cost()
	restock_btn.tooltip_text = "Each restock you pay for costs x%s more, until the shop restocks by itself" % String.num(Config.INSTANT_RESTOCK_GROWTH, 1)
	restock_btn.disabled = Game.coins < Game.restock_cost()
	if not shop_overlay.visible:
		return  # the shelf (30 cubbies) is only rebuilt while you're looking at it (and when the shop opens)
	for c in shop_grid.get_children():
		c.queue_free()
	for i in Game.shop.size():
		shop_grid.add_child(_cubby(i, Game.shop[i]))


## One cubby on the shelf: the rock, how many are in stock, its name and a coloured price tag. Click = buy one.
func _cubby(i: int, s: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 132)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_buy.bind(i))
	var empty: bool = s.stock <= 0
	b.disabled = empty or Game.coins < s.price
	b.tooltip_text = "%s - %d coins%s" % [Game.rock_name(s.id), s.price, "  (out of stock until the next restock)" if empty else "  (%d in stock)" % s.stock]
	var sb := _skin("cubby", Vector4i(3, 3, 3, 5), Vector4(4, 4, 4, 6))
	if sb:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var one := sb.duplicate() as StyleBoxTexture
			one.modulate_color = {"hover": Color(1.25, 1.18, 1.1), "pressed": Color(0.85, 0.8, 0.75),
					"hover_pressed": Color(0.9, 0.85, 0.8), "disabled": Color(0.8, 0.75, 0.72)}.get(st, Color.WHITE)
			b.add_theme_stylebox_override(st, one)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := _icon(Game.rock_texture(s.id), 62)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color(0.35, 0.3, 0.3, 0.55) if empty else Color.WHITE
	v.add_child(ic)
	var name_l := _label(Game.rock_name(s.id), 16, Config.TEXT_COLOR if not empty else Config.MUTED_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	v.add_child(name_l)
	var tag := PanelContainer.new()  # the price sticker, coloured by how pricey the rock is
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_theme_stylebox_override("panel", _box(_tag_color(int(Config.ROCKS[s.id].price)), Config.TEXT_OUTLINE_COLOR, 2, 0, 1))
	v.add_child(tag)
	var pl := _label(str(s.price), 16, Config.TEXT_OUTLINE_COLOR)
	pl.add_theme_constant_override("outline_size", 0)
	pl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.custom_minimum_size.x = 54
	tag.add_child(pl)
	var st_l := _label("EMPTY" if empty else "x%d" % s.stock, 16, Config.SLICE_MISS_COLOR if empty else Config.ACCENT)
	st_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	st_l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	st_l.offset_right = -8
	st_l.offset_top = 4
	b.add_child(st_l)
	# profit or not: a big + or - in the top-left corner (colour too, but the sign is what you read)
	var pf := _profit(s.id, false)
	var sign_l := _label("+" if pf > 0 else "-" if pf < 0 else "=", 26, _pct_color(pf))
	sign_l.add_theme_font_override("font", title_font)
	sign_l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	sign_l.offset_left = 9
	sign_l.offset_top = -2
	b.add_child(sign_l)
	b.tooltip_text += "\n%s: %s coins per rock on average at today's prices" % [
			"PROFIT (+)" if pf > 0 else "LOSS (-)" if pf < 0 else "Breaks even", ("+%d" % pf) if pf > 0 else str(pf)]
	for c in [v, ic, name_l, tag, pl, st_l, sign_l]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Price sticker colours (like a parts organiser's labels): green cheap, blue, yellow, pink for the priciest.
func _tag_color(price: int) -> Color:
	if price < 60:
		return Color("#91db69")
	if price < 200:
		return Color("#8fd3ff")
	if price < 500:
		return Color("#fbff86")
	return Color("#f2a7c3")


func _update_rock_text() -> void:
	if rock_view.rock_id == "":
		rock_title.text = ""
		hint_label.text = "No rock on the anvil. Pick one from Your Rocks, or buy some in the Shop."
		return
	rock_title.text = Game.rock_name(rock_view.rock_id)
	hint_label.text = "Click the rock to break it!" if rock_view.hits_done == 0 else "Keep hitting!"


# ================================================================== actions
func _place(id: String) -> void:
	if rock_view.rock_id != "" and not rock_view.is_ready_to_hit():
		return  # mid-break animation
	if Game.place_rock(id):
		Sfx.play("click")
		rock_view.set_rock(id)
		_update_rock_text()


func _auto_place(prefer: String) -> void:
	if not Config.AUTO_NEXT_ROCK or Game.rocks.is_empty():
		rock_view.set_rock("")
		_update_rock_text()
		if Game.rocks.is_empty():
			tutorial.tip("mine")  # out of rocks: the mine earns coins
		return
	var id: String = prefer if Game.rocks.has(prefer) else Game.rocks.keys()[0]
	Game.place_rock(id)
	rock_view.set_rock(id)
	_update_rock_text()


func _update_crush_btn() -> void:
	var n := Game.rocks_total()
	crush_btn.visible = n >= 2
	crush_btn.text = "CRUSH ALL  (%d)" % n
	crush_btn.disabled = _crush_fx != null


## Crush All: every rock you have breaks in one go. The drops are all worked out at once (Game.crush_all),
## then the screen goes black, zooms onto the rock on the anvil, it goes supernova and you see the lot.
func _crush_all() -> void:
	if _crush_fx != null or Game.rocks_total() < 1:
		return
	if rock_view.rock_id != "" and not rock_view.is_ready_to_hit():
		return  # the last rock is still flying apart
	if rock_view.rock_id == "" or Game.current_rock == "":
		_auto_place(rock_view.rock_id)  # a rock on the anvil to zoom onto
	var rect := rock_view.screen_rect()
	var tex: Texture2D = rock_view.tex
	var res := Game.crush_all()
	var got: Dictionary = res.got
	var by_worth: Array = got.keys()
	by_worth.sort_custom(func(a, b): return got[a] * Game.ore_price(a) > got[b] * Game.ore_price(b))
	var cols: Array[Color] = []
	for id in by_worth.slice(0, 6):
		cols.append(Config.ORES[id].color)
	rock_view.set_rock("")
	hint_label.text = ""
	rock_title.text = ""
	_crush_fx = CrushFx.new()
	add_child(_crush_fx)
	_crush_fx.play(tex, rect, cols)
	_update_crush_btn()
	Sfx.play("supernova")  # its boom lands right on the burst
	_crush_fx.burst.connect(func(): _shake = Config.SCREEN_SHAKE_ON_BREAK * 2.0)
	_crush_fx.revealed.connect(_show_crush_summary.bind(res))
	_crush_fx.finished.connect(func():
		_crush_fx = null
		_auto_place("")
		_refresh())


## Everything that came out of the supernova, one tile per ore (however many rocks it was).
func _show_crush_summary(res: Dictionary) -> void:
	var got: Dictionary = res.got
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crush_fx.add_child(holder)
	var panel := _panel(0)
	holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := _title("SUPERNOVA!", 44, Config.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var sub := "Crushed %d rock%s" % [res.rocks, "" if res.rocks == 1 else "s"]
	if res.saved > 0:
		sub += "   (Silktouch saved %d: back in Your Rocks)" % res.saved
	var sl := _label(sub, 18, Config.TEXT_COLOR)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sl)
	var ids: Array = []
	for id in _ores_then_gems():  # ores, then gems - like the Backpack
		if got.has(id):
			ids.append(id)
	var cells: Array[Control] = []
	var worth := 0
	if ids.is_empty():
		var none := _label("Nothing inside... not a single ore.", 18, Config.MUTED_TEXT)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(none)
		Sfx.play("drop_none")
	else:
		var cols := clampi(ids.size(), 1, 6)
		var cell_size := Vector2(112, 112)
		var rows := ceili(ids.size() / float(cols))
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size = Vector2(cols * (cell_size.x + 8), minf(rows * (cell_size.y + 8), size.y * 0.45))
		v.add_child(sc)
		var grid := GridContainer.new()
		grid.columns = cols
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(grid)
		var rare_any := false
		for id in ids:
			var amount: int = got[id]
			worth += amount * Game.ore_price(id)
			var rare: bool = Config.ORES[id].get("rare", false)
			rare_any = rare_any or rare
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = cell_size
			cell.alignment = BoxContainer.ALIGNMENT_CENTER
			cell.add_theme_constant_override("separation", 2)
			var ic := _icon(Game.ore_texture(id), 52)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(ic)
			var al := _title("x%d" % amount, 22, Config.ORES[id].color)
			al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(al)
			var nm := _label(Game.ore_name(id), 13, Config.ACCENT if rare else Config.MUTED_TEXT)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.clip_text = true
			cell.add_child(nm)
			cell.tooltip_text = "%s x%d  (%d coins)" % [Game.ore_name(id), amount, amount * Game.ore_price(id)]
			grid.add_child(cell)
			cell.set_meta("icon", ic)
			cells.append(cell)
		# they all pop in together (staggered a touch, but never longer than 0.6 s whatever the count)
		var step := minf(0.06, 0.6 / ids.size())
		for i in cells.size():
			var cell := cells[i]
			cell.modulate.a = 0.0
			var tw := cell.create_tween()
			tw.tween_interval(i * step)
			tw.tween_property(cell, "modulate:a", 1.0, 0.18)
		Sfx.play("drop_rare" if rare_any else "drop_common")
		var wl := _label("Worth %d coins at today's prices  (in your Backpack)" % worth, 18, Config.ACCENT)
		wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wl)
	var ok := _button("Collect", func(): _close_crush(cells))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.custom_minimum_size = Vector2(180, 52)
	v.add_child(ok)
	panel.pivot_offset = panel.get_combined_minimum_size() * 0.5
	panel.scale = Vector2.ONE * 0.6
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Collect: the ores fly into the Backpack (one icon per kind, at most 12) and the black fades away.
func _close_crush(cells: Array[Control]) -> void:
	if _crush_fx == null:
		return
	Sfx.play("click")
	var target := backpack_btn.global_position - global_position + backpack_btn.size * 0.5  # on top of the black
	var k := 0
	for cell in cells.slice(0, 12):
		var src: TextureRect = cell.get_meta("icon")
		var ic := _icon(src.texture, 52)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.size = Vector2(52, 52)
		ic.position = src.global_position - global_position
		add_child(ic)
		var tw := ic.create_tween()
		tw.tween_interval(k * 0.04)
		tw.tween_property(ic, "position", target - ic.size * 0.5, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(ic, "scale", Vector2.ONE * 0.5, 0.5)
		tw.tween_callback(ic.queue_free)
		tw.tween_callback(_bump.bind(backpack_btn))
		k += 1
	_crush_fx.close()


func _on_hit(_done: int, _total: int) -> void:
	_update_rock_text()


func _on_broken(center_global: Vector2) -> void:
	var id := rock_view.rock_id
	var got := Game.break_current()
	_shake = Config.SCREEN_SHAKE_ON_BREAK
	var origin := center_global - fx_layer.global_position
	if Game.last_break_saved:  # Silktouch: it goes back in your bag (and on the anvil next)
		_float_text(origin + Vector2(0, 60), "SILKTOUCH!  The rock survived", Config.ACCENT, 0.35)
	if got.is_empty():
		_float_text(origin, "Nothing inside...", Config.MUTED_TEXT, 0.15)
		get_tree().create_timer(0.15).timeout.connect(Sfx.play.bind("drop_none"))
	else:
		var k := 0
		for ore_id in got:
			_fly_drop(ore_id, got[ore_id], origin, k * 0.18)
			k += 1
		tutorial.tip("backpack")
	hint_label.text = ""
	rock_title.text = ""
	await get_tree().create_timer(Config.NEXT_ROCK_DELAY).timeout
	if rock_view.rock_id == id and not rock_view.is_ready_to_hit():  # nobody placed another meanwhile
		_auto_place(id)


func _fly_drop(ore_id: String, amount: int, from: Vector2, delay: float) -> void:
	var rare: bool = Config.ORES[ore_id].get("rare", false)
	var ic := _icon(Game.ore_texture(ore_id), 56)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size = Vector2(56, 56)
	ic.pivot_offset = ic.size * 0.5
	ic.position = from - ic.size * 0.5
	ic.scale = Vector2.ZERO
	fx_layer.add_child(ic)
	var target := backpack_btn.global_position - fx_layer.global_position + backpack_btn.size * 0.5
	var up := from + Vector2(randf_range(-90, 90), randf_range(-150, -100))
	var tw := ic.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func():
		Sfx.play("drop_rare" if rare else "drop_common")
		_float_text(from + Vector2(0, -40), "+%d %s" % [amount, Game.ore_name(ore_id)], Config.ORES[ore_id].color, 0.0))
	tw.set_parallel()
	tw.tween_property(ic, "scale", Vector2.ONE * (1.4 if rare else 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ic, "position", up - ic.size * 0.5, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if rare:
		tw.tween_property(ic, "rotation", TAU, 0.6)
	tw.chain().tween_interval(0.45 if rare else 0.2)
	tw.chain().tween_property(ic, "position", target - ic.size * 0.5, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(ic, "scale", Vector2.ONE * 0.6, 0.45)
	tw.chain().tween_callback(ic.queue_free)
	tw.tween_callback(_bump.bind(backpack_btn))


func _float_text(at: Vector2, text: String, col: Color, delay: float) -> void:
	var l := _title(text, 28, col)
	l.add_theme_constant_override("outline_size", Config.TEXT_OUTLINE_SIZE + 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	fx_layer.add_child(l)
	l.reset_size()
	l.position = at - Vector2(l.size.x * 0.5, 0)
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(l, "position:y", l.position.y - 70, 1.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.tween_callback(l.queue_free)


func _buy(slot: int) -> void:
	if Game.buy(slot):
		Sfx.play("buy")
		if rock_view.rock_id == "":
			_auto_place(Game.shop[slot].id)
	else:
		Sfx.play("error")


func _instant_restock() -> void:
	if Game.buy_restock():
		Sfx.play("restock")
	else:
		Sfx.play("error")
		show_toast("Not enough coins!")


func _claim_ticket() -> void:
	if Game.claim_free_ticket():
		Sfx.play("buy")
		show_toast("Free ticket claimed!")
	else:
		Sfx.play("error")


func _buy_ticket(id: String) -> void:
	if Game.buy_ticket(id):
		Sfx.play("buy")
		show_toast("%s ticket bought" % Game.cave_name(id))
	else:
		Sfx.play("error")
		show_toast("Not enough coins!")


func _buy_upgrade(id: String) -> void:
	if Game.buy_upgrade(id):
		Sfx.play("buy")
		show_toast("%s  Lv %d" % [Config.UPGRADES[id].get("name", id), Game.upgrade_level(id)])
	else:
		Sfx.play("error")


## Go down a cave from the Caves tab (uses one of its tickets, unless that's the trip you're on).
func _enter_cave(id: String) -> void:
	if Game.trip_active and id != Game.cave:
		Sfx.play("error")
		show_toast("Finish your trip in %s first" % Game.cave_name())
		return
	var was_on: bool = Game.trip_active
	if not Game.start_trip(id):
		Sfx.play("error")
		show_toast("You need a %s ticket!" % Game.cave_name(id))
		return
	close_overlays_silent()
	wall_view.change_cave()
	if not was_on:
		show_toast("Ticket used - welcome to %s!" % Game.cave_name())
	_slide_to(true)


## Clearing a stage hit the cave's stone_chance: a pile of rocks, 0-3 of them made it into your bag.
func _on_found_rocks(found: Array, rolled: int) -> void:
	var at := Vector2(size.x * 0.5, size.y * 0.3)
	if found.is_empty():
		Sfx.play("drop_none")
		_float_text(at, "Found %d rocks... but none of them made it up" % rolled, Config.MUTED_TEXT, 0.6)
		return
	Sfx.play("drop_rare")
	var names := {}
	for rid in found:
		names[Game.rock_name(rid)] = int(names.get(Game.rock_name(rid), 0)) + 1
	var parts := []
	for n in names:
		parts.append(("%dx %s" % [names[n], n]) if names[n] > 1 else n)
	_float_text(at, "Found %d of %d rocks!  %s  (in Your Rocks)" % [found.size(), rolled, ", ".join(parts)], Config.ACCENT, 0.6)
	if rock_view.rock_id == "" and not on_wall:
		_auto_place(found[0])


## Ticket Hungry found a ticket when you cleared a stage.
func _on_found_ticket(cave_id: String) -> void:
	Sfx.play("buy")
	_float_text(Vector2(size.x * 0.5, size.y * 0.3 + 50), "TICKET HUNGRY!  +1 %s ticket" % Game.cave_name(cave_id), Config.ACCENT, 1.0)
	_bump(ticket_label)


## Fool's Gold paid extra on a sale.
func _on_lucky_sale(ore_id: String, extra: int) -> void:
	Sfx.play("drop_rare")
	_float_text(Vector2(size.x * 0.5, size.y * 0.35), "FOOL'S GOLD!  +%d for your %s" % [extra, Game.ore_name(ore_id)], Config.ACCENT, 0.0)


## Out of lives: the ticket is used up and you're sent back up.
func _on_trip_over() -> void:
	if _dev:
		return
	await get_tree().create_timer(Config.GAME_OVER_DELAY).timeout  # let the last moment play out first
	if Game.trip_active or _game_over != null:
		return
	if tutorial.visible:  # the tutorial is up: just go back quietly
		if on_wall:
			wall_view.reset_run()
			_go_main()
		return
	_show_game_over(Game.last_run)


## "YOU HAVE NO MORE FUEL": the run was lost. Shows what the run did (stats, best combo...), what it had and
## what was taken back. "Back to the surface" closes it and takes you to the rock.
func _show_game_over(r: Dictionary) -> void:
	if on_wall:
		wall_view.reset_run()  # the wall stops under the screen
	Sfx.play("fizzle")
	var root := Control.new()
	_game_over = root
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.01, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = -120  # past the edges, so the screen shake never shows the window behind
	dim.offset_top = -120
	dim.offset_right = 120
	dim.offset_bottom = 120
	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)
	var rows: Array[Control] = []

	var head := _title("YOU HAVE NO MORE FUEL", 52, Config.GAME_OVER_COLOR)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_constant_override("outline_size", Config.TEXT_OUTLINE_SIZE + 4)
	v.add_child(head)
	rows.append(head)
	var why := _label(str(r.get("reason", "")).strip_edges(), 18, Config.MUTED_TEXT)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = 620
	v.add_child(why)
	rows.append(why)

	# the stats
	var panel := _panel(620)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(panel)
	rows.append(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	panel.add_child(grid)
	var moves := int(r.get("moves", 0))
	var perfects := int(r.get("perfects", 0))
	var best_combo := int(r.get("best_combo", 0))
	var secs := int(r.get("time", 0.0))
	var stats := [
		["Cave", Game.cave_name(str(r.get("cave", Game.cave)))],
		["Furthest stage", "Stage %d  (started on %d)" % [int(r.get("best_stage", 1)), int(r.get("start_stage", 1))]],
		["Highest combo", "x%d  (coins x%s)" % [best_combo, _num(minf(1.0 + maxi(best_combo - 1, 0) * Config.COMBO_BONUS_PER_STEP, Config.COMBO_MAX_MULTIPLIER))]],
		["Walls broken", str(int(r.get("walls", 0)))],
		["Moves", "%d  (%d perfect, %d%%)" % [moves, perfects, roundi(100.0 * perfects / moves) if moves > 0 else 0]],
		["Coins mined", str(int(r.get("coins", 0)))],
		["Lives lost", _num(float(r.get("lives_lost", 0.0)))],
		["Time in the mine", "%d:%02d" % [secs / 60, secs % 60]],
	]
	for st in stats:
		var k := _label(st[0], 18, Config.MUTED_TEXT)
		grid.add_child(k)
		var val := _title(st[1], 20, Config.ACCENT if st[0] == "Highest combo" else Config.TEXT_COLOR)
		grid.add_child(val)

	# the loot: what it had, what was taken
	var lost: Dictionary = r.get("lost", {})
	var keep := float(lost.get("keep", 0.0))
	var lt := "Taken back: %d coins, %d ores & gems, %d rocks" % [int(lost.get("coins", 0)), int(lost.get("ores", 0)), int(lost.get("rocks", 0))]
	if int(lost.get("coins", 0)) + int(lost.get("ores", 0)) + int(lost.get("rocks", 0)) <= 0:
		lt = "The run had no loot to lose."
	var ll := _label(lt, 18, Config.SLICE_MISS_COLOR)
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ll)
	rows.append(ll)
	if keep > 0.0:
		var kl := _label("Minecart / Backpack saved %d%% of it." % roundi(keep * 100.0), 16, Config.ACCENT)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(kl)
		rows.append(kl)

	# the artifacts you went down with
	var items: Array = r.get("items", [])
	if not items.is_empty():
		var ir := HBoxContainer.new()
		ir.alignment = BoxContainer.ALIGNMENT_CENTER
		ir.add_theme_constant_override("separation", 8)
		ir.add_child(_label("Artifacts:", 16, Config.MUTED_TEXT))
		for id in items:
			if Config.ITEMS.has(id):
				ir.add_child(_item_icon(id, 40))
		v.add_child(ir)
		rows.append(ir)

	var back := _button("Back to the surface", _close_game_over)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(300, 56)
	v.add_child(back)
	rows.append(back)

	# fade in: the black first, then each row in turn
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.5)
	for i in rows.size():
		var c := rows[i]
		c.modulate.a = 0.0
		var tw := c.create_tween()
		tw.tween_interval(0.5 + i * 0.12)
		tw.tween_property(c, "modulate:a", 1.0, 0.25)


func _close_game_over() -> void:
	if _game_over == null:
		return
	Sfx.play("click")
	var g := _game_over
	_game_over = null
	if on_wall:
		_go_main()
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.3)
	tw.tween_callback(g.queue_free)
	show_toast("Get a new ticket in Shop > Caves to go down again.")


## 1.5 -> "1.5", 2.0 -> "2"
func _num(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else "%.1f" % x


func _sell(id: String, amount: int) -> void:
	var earned := Game.sell(id, amount)
	if earned > 0:
		tutorial.tip("shop")
		Sfx.play("sell")
		show_toast("+%d coins" % earned)


func _sell_all() -> void:
	var earned := Game.sell_all()
	if earned > 0:
		tutorial.tip("shop")
		Sfx.play("sell")
		show_toast("+%d coins" % earned)


func _open_shop(tab := "") -> void:
	_close_overlays()
	if tab != "":
		_show_shop_tab(tab, false)
	shop_overlay.visible = true
	_rebuild_shop()
	Sfx.play_music("shop")


func _open_backpack() -> void:
	_close_overlays()
	backpack_overlay.visible = true


func _open_settings() -> void:
	_close_overlays()
	for sl in [music_slider, sfx_slider]:
		sl.set_value_no_signal(Sfx.music_volume if sl == music_slider else Sfx.sfx_volume)
		sl.get_meta("pct").text = "%d%%" % roundi(sl.value * 100.0)
	settings_overlay.visible = true


func _close_overlays() -> void:
	Sfx.play("click")
	close_overlays_silent()


func close_overlays_silent() -> void:
	for o in [shop_overlay, backpack_overlay, settings_overlay, practice_overlay, mine_overlay, book_overlay]:
		if o:
			o.visible = false
	Sfx.play_music("mine" if on_wall else "main")  # the shop's music fades back to this screen's


func _open_tutorial() -> void:
	Sfx.play("click")
	tutorial.start()


# ================================================================== screens
## The Mine button: Select Mine pops up so you pick which cave to go down (each needs its own ticket). On a
## trip your cave's row says Continue (the others wait until the trip is over).
func _go_wall() -> void:
	_open_select_mine()  # always: on a trip your cave's row says Continue


func _build_select_mine() -> void:
	var o := _make_overlay("Select Mine", _close_overlays)
	mine_overlay = o[0]
	var v: VBoxContainer = o[1]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var info := _label("Pick a mine to go down. Each trip uses one ticket for that mine.", 16, Config.MUTED_TEXT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(info)
	var book := _icon_button("book", "Artifacts", "Artifact Book: every artifact you can find on a run", _open_book)
	top.add_child(book)
	mine_claim_btn = _button("", _claim_ticket)
	mine_claim_btn.custom_minimum_size = Vector2(230, 48)
	top.add_child(mine_claim_btn)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(820, 440)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	mine_list = VBoxContainer.new()
	mine_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mine_list.add_theme_constant_override("separation", 8)
	sc.add_child(mine_list)


## The Artifact Book: every artifact you can be offered on a run, what it does, and (on a run) which you hold.
## Three tabs: Artifacts (they last the run), Consumables (used up once they've done their thing) and the
## Tier List (Config.ITEM_TIERS - the current meta).
func _build_book() -> void:
	var o := _make_overlay("Artifact Book", _close_overlays)
	book_overlay = o[0]
	var v: VBoxContainer = o[1]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var grp := ButtonGroup.new()
	for t in [["artifacts", "Artifacts"], ["consumables", "Consumables"], ["tiers", "Tier List"]]:
		var b := _button(t[1], _show_book_tab.bind(t[0]))
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(196, 46)
		b.add_theme_color_override("font_pressed_color", Config.ACCENT)  # the open tab reads gold
		b.add_theme_color_override("font_hover_pressed_color", Config.ACCENT)
		tabs.add_child(b)
		book_tabs[t[0]] = b
	book_info = _label("", 16, Config.MUTED_TEXT)
	book_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	book_info.custom_minimum_size.x = 860
	v.add_child(book_info)
	book_scroll = ScrollContainer.new()
	book_scroll.custom_minimum_size = Vector2(880, 470)
	book_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(book_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_scroll.add_child(pages)
	book_list = GridContainer.new()
	book_list.columns = 2
	book_list.add_theme_constant_override("h_separation", 8)
	book_list.add_theme_constant_override("v_separation", 8)
	pages.add_child(book_list)
	book_tiers = VBoxContainer.new()
	book_tiers.add_theme_constant_override("separation", 6)
	book_tiers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(book_tiers)


func _open_book() -> void:
	_close_overlays()
	_show_book_tab(book_tab, false)
	book_overlay.visible = true


## Consumables: used up once they've done their thing (Config "once"), and the Pet Rock (it wanders off).
func _book_consumable(id: String) -> bool:
	return Game.is_consumable(id) or id == "pet_rock"


## An artifact's tier in Config.ITEM_TIERS ("?" = unranked).
func _tier_of(id: String) -> String:
	for t in Config.ITEM_TIERS:
		if id in Config.ITEM_TIERS[t]:
			return t
	return "?"


## Its place in the whole tier list (best = 0; unranked last).
func _tier_rank(id: String) -> int:
	var n := 0
	for t in Config.ITEM_TIERS:
		var i: int = Config.ITEM_TIERS[t].find(id)
		if i >= 0:
			return n + i
		n += Config.ITEM_TIERS[t].size()
	return n + 1000


## A tier letter on a coloured block.
func _tier_badge(t: String, s: int, fs: int) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Config.TIER_COLORS.get(t, Config.TIER_COLORS["?"])
	st.border_color = Config.TEXT_OUTLINE_COLOR
	st.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(s, s)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.tooltip_text = "Tier %s in the current meta" % t if t != "?" else "Not ranked yet"
	var l := _title(t, fs, Color.WHITE)  # white letter, dark outline (the theme's)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _show_book_tab(tab: String, sound := true) -> void:
	if sound:
		Sfx.play("click")
	book_tab = tab
	book_tabs[tab].set_pressed_no_signal(true)
	for c in book_list.get_children() + book_tiers.get_children():
		c.queue_free()
	book_list.visible = tab != "tiers"
	book_tiers.visible = tab == "tiers"
	book_scroll.scroll_vertical = 0
	match tab:
		"artifacts":
			book_info.text = "Every time you clear a stage on a run, you're offered %d artifacts: take one. You hold %d at once; they last for the run. With your slots full, taking one swaps one of yours out - that one won't show up again for %d stages. Best first (see the Tier List)." % [
					Config.ITEM_CHOICES, Game.base_slots(), Config.SWAP_COOLDOWN]
		"consumables":
			book_info.text = "Used up once they've done their thing. A used-up one isn't offered again for %d stages (or pay at a rest to bring it back sooner). Best first." % Config.CONSUMABLE_COOLDOWN
		"tiers":
			book_info.text = "The current meta: S is the best, F the worst - it changes as the game gets rebalanced. Hover an icon for what it does."
			_fill_tier_list()
			return
	var ids: Array = Config.ITEMS.keys().filter(func(id): return _book_consumable(id) == (tab == "consumables"))
	ids.sort_custom(func(a, b): return _tier_rank(a) < _tier_rank(b))
	for id in ids:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", slot_style)
		card.custom_minimum_size = Vector2(430, 0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var ic := _item_icon(id, 48)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var tag := ""
		if Game.trip_active and Game.run_items.has(id):
			tag = "   (you have it)"
		col.add_child(_label(Game.item_name(id) + tag, 20, Config.ACCENT))
		var d := _label(Config.ITEMS[id].get("book", Config.ITEMS[id].text), 16, Config.TEXT_COLOR)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 310
		col.add_child(d)
		row.add_child(_tier_badge(_tier_of(id), 34, 22))
		book_list.add_child(card)


## The Tier List tab: a row per tier, with its artifacts' icons and names in the meta's order.
func _fill_tier_list() -> void:
	var rows := {}
	for t in Config.ITEM_TIERS:
		rows[t] = Config.ITEM_TIERS[t].filter(func(id): return Config.ITEMS.has(id))
	var unranked: Array = Config.ITEMS.keys().filter(func(id): return _tier_of(id) == "?")
	if not unranked.is_empty():
		rows["?"] = unranked
	for t in rows:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", slot_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(_tier_badge(t, 72, 40))
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 6)
		row.add_child(flow)
		for id in rows[t]:
			var cell := VBoxContainer.new()
			cell.custom_minimum_size.x = 92
			cell.add_theme_constant_override("separation", 0)
			var ic := _item_icon(id, 48)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(ic)
			var nm := _label(Game.item_name(id), 12, Config.TEXT_COLOR)
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nm.custom_minimum_size.x = 92
			cell.add_child(nm)
			flow.add_child(cell)
		book_tiers.add_child(card)


func _open_select_mine() -> void:
	_close_overlays()
	_fill_caves(mine_list)
	_update_tickets()
	mine_overlay.visible = true


func _go_main() -> void:
	_slide_to(false)


## The wall's Back button. On a run, leaving the mine cashes out: the run ends and this cave starts again
## from stage 1 next time - so it asks first.
func _leave_mine() -> void:
	if not Game.trip_active or wall_view.free_practice or wall_view.practice != "":
		_go_main()
		return
	Sfx.play("click")
	leave_confirm.dialog_text = "Leave the mine and cash out?\n\nYour run ends here and its loot is yours to keep%s, and %s starts again from Stage 1 next time." % [
			" (the Midas pot of %d coins too)" % Game.run_pot if Game.run_pot > 0 else "", Game.cave_name()]
	leave_confirm.popup_centered()


func go_wall() -> void:
	_slide_to(true)


func go_main() -> void:
	_slide_to(false)


func _slide_to(wall: bool) -> void:
	if on_wall == wall:
		return
	on_wall = wall
	if not wall and wall_view.free_practice:
		wall_view.end_free_practice()  # back up: the mine is just as you left it
	if wall and Game.trip_active and not wall_view.free_practice:
		tutorial.tip("lighter")
	Sfx.play("screen_slide")
	if not shop_overlay.visible:
		Sfx.play_music("mine" if wall else "main")
	if _slide_tween:
		_slide_tween.kill()
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide_tween = tw
	tw.tween_property(slider, "position:x", screens_area.size.x if wall else 0.0, Config.SCREEN_SLIDE_TIME)
	_show_menu_bar(not wall)


## The top menu (coins, Shop, Market, Backpack, Settings) only belongs to the rock screen: in the mine you
## only see the cave. It slides up out of the window and back down.
func _show_menu_bar(on: bool, instant := false) -> void:
	if _menu_tween:
		_menu_tween.kill()
	var h := menu_bar.size.y
	if on:
		menu_bar.visible = true
	if instant:
		menu_bar.position.y = 0.0 if on else -h - 8.0
		menu_bar.visible = on
		return
	_menu_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_menu_tween.tween_property(menu_bar, "position:y", 0.0 if on else -h - 8.0, Config.SCREEN_SLIDE_TIME)
	if not on:
		_menu_tween.tween_callback(func(): menu_bar.visible = false)


## Both screens are as big as the area under the top bar; the wall one sits to the left of the main one.
func _layout_screens() -> void:
	var s := screens_area.size
	var bar_h := ceilf(menu_bar.get_combined_minimum_size().y)
	if main_screen.size != s:
		main_screen.size = s
		wall_screen.size = s
		wall_screen.position = Vector2(-s.x, 0)
		if not (_slide_tween and _slide_tween.is_running()):
			slider.position.x = s.x if on_wall else 0.0
		if wall_view.size != s:
			wall_view.position = Vector2.ZERO
			wall_view.size = s
	if main_screen.get_theme_constant("margin_top") != int(bar_h) + Config.SAFE_BORDER:
		main_screen.add_theme_constant_override("margin_top", int(bar_h) + Config.SAFE_BORDER)  # rock screen content starts under the menu
	if room_bg and (room_bg.position.y != bar_h or room_bg.size != Vector2(s.x, s.y - bar_h)):
		room_bg.position = Vector2(0, bar_h)  # the room starts under the menu bar
		room_bg.size = Vector2(s.x, s.y - bar_h)
	if menu_bar.size.x != size.x:
		menu_bar.size.x = size.x
	if not (_menu_tween and _menu_tween.is_running()):
		menu_bar.visible = not on_wall
		menu_bar.position.y = 0.0 if not on_wall else -bar_h - 8.0
	# the wall's buttons go down the right edge from the top-right corner (the lives are top-left)
	var right := s.x - Config.SAFE_BORDER
	back_btn.size = back_btn.get_combined_minimum_size()
	back_btn.position = Vector2(right - back_btn.size.x, Config.SAFE_BORDER)
	ram_btn.size = ram_btn.get_combined_minimum_size()
	ram_btn.position = Vector2(back_btn.position.x - ram_btn.size.x - 12, back_btn.position.y + (back_btn.size.y - ram_btn.size.y) * 0.5)
	wall_book_btn.size = wall_book_btn.get_combined_minimum_size()
	wall_book_btn.position = Vector2(right - wall_book_btn.size.x, back_btn.position.y + back_btn.size.y + 12)
	dynamite_btn.size = dynamite_btn.get_combined_minimum_size()
	dynamite_btn.position = Vector2(right - dynamite_btn.size.x, wall_book_btn.position.y + wall_book_btn.size.y + 12)
	ham_btn.size = ham_btn.get_combined_minimum_size()
	ham_btn.position = Vector2(right - ham_btn.size.x, dynamite_btn.position.y + (dynamite_btn.size.y + 12 if dynamite_btn.visible else 0.0))
	items_hud.position = Vector2(Config.SAFE_BORDER + 6, 200)  # under the lives and the combo
	rest_panel.size = rest_panel.get_combined_minimum_size()
	rest_panel.position = ((s - rest_panel.size) * 0.5 + Vector2(30, 10)).round()


func _on_action_done(perfect: bool, at: Vector2, combo: int, mult: float) -> void:
	var pos := wall_view.global_position + at - fx_layer.global_position
	var base := randi_range(Config.PERFECT_COINS_MIN, Config.PERFECT_COINS_MAX) if perfect else Config.GOOD_COINS
	var coins := roundi(base * _mine_mult(mult))
	if wall_view.practice != "":
		coins = 0  # practice (and the tutorial) never pays
	else:
		Game.move_done()  # Midas grows every 3 moves
		Game.note_move(perfect, combo)  # for the game over screen
		if combo > 0 and combo % Config.COMBO_MILESTONE == 0:  # every 10 in a row: a bonus
			var bonus := roundi(Config.COMBO_MILESTONE_COINS * (combo / Config.COMBO_MILESTONE) * _mine_mult(1.0))
			if bonus > 0:
				Game.mine_coins(bonus)
				Sfx.play("drop_rare")
				_float_text(pos + Vector2(0, -50), "COMBO %d!  +%d" % [combo, bonus], Config.ACCENT, 0.15)
		var drop := Game.dwarven_drop()  # Dwarven Hands
		for oid in drop:
			_float_text(pos + Vector2(0, 40), "+%d %s" % [drop[oid], Game.ore_name(oid)], Config.ORES[oid].color, 0.25)
		var found := Game.move_rocks(combo)  # Ring of Luck, Drill, Excavator, Miner's Permit, Philosopher's Stone
		if not found.is_empty():
			var paid := Game.give_rocks(found)
			var n := Game._sum(found)
			if paid > 0:
				_float_text(pos + Vector2(0, 75), "Molerats ate %d rock%s: +%d" % [n, "s" if n > 1 else "", paid], Config.ACCENT, 0.35)
			else:
				var first: String = found.keys()[0]
				_float_text(pos + Vector2(0, 75), ("+%d %s" % [n, Game.rock_name(first)]) if found.size() == 1 else "+%d rocks" % n, Config.ACCENT, 0.35)
	Game.mine_coins(coins)
	if coins > 0:
		_bump(coin_label)
	if perfect:
		Sfx.play("slice_perfect", minf(1.0 + 0.04 * (combo - 1), 1.6))
		_float_text(pos, "PERFECT!" + ("  +%d" % coins if coins > 0 else ""), Config.ACCENT, 0.0)
	else:
		Sfx.play("slice_good")
		_float_text(pos, "Good" + ("  +%d" % coins if coins > 0 else ""), Config.TEXT_COLOR, 0.0)


## The mine's coin multiplier. Normally: combo x (cave & stage coins). With Midas Touch: cave x MIDAS + combo.
## Then x every artifact that multiplies coins (Golden Apple, Draupnir, Familiar Circle, Art of Peace...).
func _mine_mult(combo_mult: float) -> float:
	var m := maxf(combo_mult, 1.0) * Game.mine_coin_mult()
	if Game.has_item("midas_touch") and Game.trip_active:
		m = Game.mine_coin_mult() * Game.midas + combo_mult
	return m * Game.artifact_coin_mult()


# ================================================================== the run (items, rests, Midas)
func _build_run_ui() -> void:
	# the items you hold, top left of the wall (under the combo)
	items_hud = HBoxContainer.new()
	items_hud.add_theme_constant_override("separation", 6)
	items_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wall_screen.add_child(items_hud)
	dynamite_btn = _button("", func(): wall_view.use_dynamite())
	dynamite_btn.custom_minimum_size = Vector2(72, 64)
	dynamite_btn.add_theme_font_size_override("font_size", Config.font_px(16))
	dynamite_btn.tooltip_text = "Dynamite (D): blow straight through this wall"
	wall_screen.add_child(dynamite_btn)
	ram_btn = _button("", func(): wall_view.use_ram())
	ram_btn.custom_minimum_size = Vector2(72, 64)
	ram_btn.add_theme_font_size_override("font_size", Config.font_px(16))
	ram_btn.tooltip_text = "Ram (R): crash through %d walls at once" % Config.RAM_WALLS
	wall_screen.add_child(ram_btn)
	ham_btn = _button("HAM", func(): wall_view.eat_ham())
	ham_btn.custom_minimum_size = Vector2(72, 64)
	ham_btn.add_theme_font_size_override("font_size", Config.font_px(16))
	ham_btn.tooltip_text = "Great Ham (H): eat it for +%d lives" % int(Config.GREAT_HAM_LIVES)
	wall_screen.add_child(ham_btn)
	wall_book_btn = _icon_button("book", "Book", "Artifact Book: what every artifact does (the mine waits while it's open)", _open_book)
	wall_screen.add_child(wall_book_btn)
	# the break between walls
	rest_panel = PanelContainer.new()
	rest_panel.visible = false
	wall_screen.add_child(rest_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	rest_panel.add_child(v)
	rest_title = _title("", 30, Config.ACCENT)
	rest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rest_title)
	rest_info = _label("", 16, Config.MUTED_TEXT)
	rest_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rest_info)
	rest_offer_box = VBoxContainer.new()
	rest_offer_box.add_theme_constant_override("separation", 6)
	v.add_child(rest_offer_box)
	rest_offer_note = _label("", 16, Config.TEXT_COLOR)
	rest_offer_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rest_offer_box.add_child(rest_offer_note)
	rest_offer_row = HBoxContainer.new()
	rest_offer_row.add_theme_constant_override("separation", 10)
	rest_offer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rest_offer_box.add_child(rest_offer_row)
	var skip := _button("Skip", func():
		Sfx.play("click")
		_swap_pick = ""
		Game.skip_offer())
	skip.add_theme_font_size_override("font_size", Config.font_px(16))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rest_offer_box.add_child(skip)
	var hold := HBoxContainer.new()
	hold.add_theme_constant_override("separation", 8)
	hold.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hold)
	rest_items_row = HBoxContainer.new()
	rest_items_row.add_theme_constant_override("separation", 6)
	hold.add_child(rest_items_row)
	rest_extra_box = VBoxContainer.new()  # Coin of Deceit, bringing used-up consumables back
	rest_extra_box.add_theme_constant_override("separation", 4)
	v.add_child(rest_extra_box)
	rest_midas_box = HBoxContainer.new()
	rest_midas_box.add_theme_constant_override("separation", 10)
	rest_midas_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(rest_midas_box)
	rest_midas_label = _label("", 16, Config.ACCENT)
	rest_midas_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rest_midas_box.add_child(rest_midas_label)
	var cash := _button("Cash out & leave", _cash_out)
	cash.add_theme_font_size_override("font_size", Config.font_px(16))
	cash.tooltip_text = "End this run and keep everything it gave you (coins, ores, rocks, a Midas pot). This cave starts again from Stage 1."
	rest_midas_box.add_child(cash)
	rest_continue = _button("Next wall  (SPACE)", func():
		wall_view.end_rest())
	rest_continue.custom_minimum_size = Vector2(300, 48)
	rest_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rest_continue)


## An item as a small square (icon, or its first letters if there's no art yet), with its name and text as a tooltip.
func _item_icon(id: String, s: int) -> Control:
	var path := UI_DIR + "items/%s.png" % id
	var c: Control
	if ResourceLoader.exists(path):
		c = _icon(load(path), s)
	else:
		var l := _label(Game.item_name(id).substr(0, 2).to_upper(), 16, Config.ACCENT)
		l.custom_minimum_size = Vector2(s, s)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c = l
	c.tooltip_text = "%s: %s" % [Game.item_name(id), Config.ITEMS[id].text]
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


## Items / Midas / Dynamite changed: the wall's items bar and the Dynamite button.
func _refresh_run() -> void:
	if items_hud == null:
		return
	for c in items_hud.get_children():
		c.queue_free()
	var run := Game.trip_active and wall_view.practice == ""
	if run:
		for i in Game.run_items.size():
			var box := PanelContainer.new()
			box.add_theme_stylebox_override("panel", slot_style)
			box.add_child(_item_icon(Game.run_items[i], 32))
			if Game._stack(i) > 1:
				box.add_child(_stack_badge(Game._stack(i)))
			items_hud.add_child(box)
	dynamite_btn.visible = run and Game.has_item("dynamite")
	dynamite_btn.text = "TNT\nx%d" % Game.dynamite
	dynamite_btn.disabled = Game.dynamite <= 0
	ram_btn.visible = run and Game.run_items.has("ram")
	ram_btn.text = "RAM\nx%d" % Game.ram_uses
	ram_btn.disabled = Game.ram_uses <= 0
	ham_btn.visible = run and Game.run_items.has("great_ham")
	if rest_panel.visible:
		_fill_rest_panel()


func _stack_badge(n: int) -> Label:
	var l := _label("x%d" % n, 16, Config.ACCENT)
	l.size_flags_horizontal = Control.SIZE_SHRINK_END
	l.size_flags_vertical = Control.SIZE_SHRINK_END
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The break's panel: what's next, the items on offer (after a stage), your items, Midas' cash-out.
func _fill_rest_panel() -> void:
	var cleared: bool = wall_view._rest_cleared
	rest_title.text = ("STAGE %d CLEARED!" % (Game.stage - 1)) if cleared else "Wall down - take a breather"
	rest_info.text = "Your light, wick and timers wait for you.   Next: Stage %d, wall %d / %d" % [
			Game.stage, mini(Game.stage_walls + 1, Game.walls_need), Game.walls_need]
	var offer: Array = Game.item_offer if Game.trip_active else []
	rest_offer_box.visible = not offer.is_empty()
	for c in rest_offer_row.get_children():
		c.queue_free()
	var full := Game.free_slots() <= 0
	if _swap_pick != "":
		rest_offer_note.text = "Your slots are full: click one of YOUR artifacts below to swap it for %s (the one you swap out won't show up for %d stages)" % [Game.item_name(_swap_pick), Config.SWAP_COOLDOWN]
	else:
		rest_offer_note.text = "Pick an artifact for this run (1 of %d)%s" % [offer.size(), "  -  slots full: you'll swap one out" if full else ""]
	for id in offer:
		rest_offer_row.add_child(_item_card(id))
	# your artifacts, in order (Copy copies the one on its right, Catto the one on its left: < > move them)
	for c in rest_items_row.get_children():
		c.queue_free()
	var head := _label("Your artifacts  %d / %d:" % [Game.run_items.size(), Game.run_slots], 16, Config.TEXT_COLOR)
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rest_items_row.add_child(head)
	for i in Game.run_items.size():
		var id: String = Game.run_items[i]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		rest_items_row.add_child(col)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 52)
		b.disabled = _swap_pick == ""  # only clickable while you're choosing what to swap out
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.offset_bottom = -4  # clear of the button's raised underside
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cc)
		var ic := _item_icon(id, 32)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(ic)
		if Game._stack(i) > 1:
			var badge := _stack_badge(Game._stack(i))
			badge.position = Vector2(30, 26)  # bottom-right corner of the 52 px button
			b.add_child(badge)
		b.tooltip_text = ic.tooltip_text
		var slot := i
		b.pressed.connect(func():
			Sfx.play("buy")
			Game.take_item(_swap_pick, slot)
			_swap_pick = "")
		col.add_child(b)
		var arrows := HBoxContainer.new()
		arrows.add_theme_constant_override("separation", 2)
		col.add_child(arrows)
		for d in [-1, 1]:
			var mv := _button("<" if d < 0 else ">", func():
				Sfx.play("click")
				Game.move_item(slot, d))
			mv.add_theme_font_size_override("font_size", Config.font_px(16))
			mv.custom_minimum_size = Vector2(25, 26)
			mv.disabled = (d < 0 and i == 0) or (d > 0 and i == Game.run_items.size() - 1)
			arrows.add_child(mv)
		if id == "draupnir":
			var sell := _button("Sell %d" % roundi(Config.DRAUPNIR_SELL * Game.reward_mult()), func():
				var got := Game.sell_draupnir(slot)
				if got > 0:
					Sfx.play("sell")
					show_toast("Sold a Draupnir: +%d coins" % got)
					_bump(coin_label))
			sell.add_theme_font_size_override("font_size", Config.font_px(16))
			col.add_child(sell)
	if Game.run_items.is_empty():
		rest_items_row.add_child(_label("none yet", 16, Config.MUTED_TEXT))
	_fill_rest_extras()
	rest_midas_box.visible = Game.trip_active
	var loot := Game.run_loot()
	var at_stake := "At stake: %d coins, %d ores & gems, %d rocks" % [loot.coins, loot.ores, loot.rocks]
	if Game.loot_keep() > 0.0:
		at_stake += "  (%d%% safe)" % roundi(Game.loot_keep() * 100.0)
	if Game.has_item("midas_touch"):
		rest_midas_label.text = "MIDAS x%s   -   %s   (lose the run and it's gone)" % [String.num(Game.midas, 2), at_stake]
	else:
		rest_midas_label.text = at_stake + "   (lose the run and it's gone)"
	wall_view.rest_hold = not offer.is_empty()
	rest_continue.disabled = wall_view.rest_hold
	rest_continue.text = "Pick or skip an artifact first" if wall_view.rest_hold else "Next wall  (SPACE)"
	rest_panel.reset_size()


## The break's extras: flip the Coin of Deceit; pay to bring used-up consumables back early.
func _fill_rest_extras() -> void:
	for c in rest_extra_box.get_children():
		c.queue_free()
	if not Game.trip_active:
		return
	if Game.has_item("coin_of_deceit"):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		rest_extra_box.add_child(row)
		var stake := Game.run_earned + Game.run_pot
		var l := _label("Coin of Deceit: heads doubles this run's %d coins, tails loses them" % stake, 16, Config.TEXT_COLOR)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var flip := _button("Flip!", func():
			var heads := Game.flip_coin()
			Sfx.play("drop_rare" if heads else "life_lost")
			show_toast("HEADS!  Doubled to %d" % (Game.run_earned + Game.run_pot) if heads else "TAILS...  This run's coins are gone"))
		flip.add_theme_font_size_override("font_size", Config.font_px(16))
		flip.disabled = stake <= 0
		row.add_child(flip)
	if Game.run_items.has("pet_rock") and Game.pet_feeds > 0:
		var prow := HBoxContainer.new()
		prow.alignment = BoxContainer.ALIGNMENT_CENTER
		prow.add_theme_constant_override("separation", 10)
		rest_extra_box.add_child(prow)
		var meal := Game.pet_rock_meal()
		var pl := _label("Pet Rock (%d feed%s left): %s" % [Game.pet_feeds, "" if Game.pet_feeds == 1 else "s",
				"eats %d rocks from your bag for +1 life" % Game._sum(meal) if not meal.is_empty() else "your bag isn't worth %d coins yet" % Config.PET_ROCK_PRICE], 16, Config.TEXT_COLOR)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		prow.add_child(pl)
		var feed := _button("Feed it", func():
			if Game.feed_pet_rock():
				Sfx.play("buy")
				show_toast("The Pet Rock munches happily:  +1 life (%s)" % _lives_text()))
		feed.add_theme_font_size_override("font_size", Config.font_px(16))
		feed.disabled = meal.is_empty() or Game.lives >= Config.MAX_LIVES
		feed.tooltip_text = "Takes the cheapest rocks in your bag until they're worth %d coins (today's prices)" % Config.PET_ROCK_PRICE
		prow.add_child(feed)
	var swapped: Array = []
	for id in Game.run_swapped:
		if Game.swap_wait(id) > 0:
			swapped.append("%s (%d)" % [Game.item_name(id), Game.swap_wait(id)])
	if not swapped.is_empty():
		var srow := _label("Swapped out, back in N stages: " + ", ".join(swapped), 16, Config.MUTED_TEXT)
		srow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rest_extra_box.add_child(srow)
	var cooling: Array = []
	for id in Game.run_used:
		if Game.consumable_wait(id) > 0:
			cooling.append("%s (%d)" % [Game.item_name(id), Game.consumable_wait(id)])
	if not cooling.is_empty():
		var row2 := HBoxContainer.new()
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_theme_constant_override("separation", 10)
		rest_extra_box.add_child(row2)
		var l2 := _label("Used up, back in N stages: " + ", ".join(cooling), 16, Config.MUTED_TEXT)
		l2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row2.add_child(l2)
		var cost := Game.unlock_cost()
		var unl := _button("Bring them back: %d" % cost, func():
			if Game.unlock_consumables():
				Sfx.play("buy")
				show_toast("Used-up artifacts can show up again"))
		unl.add_theme_font_size_override("font_size", Config.font_px(16))
		unl.tooltip_text = "Costs %d%% of the coins you've earned this run" % roundi(Config.CONSUMABLE_UNLOCK_COST * 100.0)
		row2.add_child(unl)


func _item_card(id: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 168)
	b.toggle_mode = true
	b.button_pressed = id == _swap_pick
	b.pressed.connect(func():
		if Game.free_slots() <= 0:
			Sfx.play("click")
			_swap_pick = id  # full: now pick which of yours goes
			_fill_rest_panel()
		else:
			Sfx.play("buy")
			_swap_pick = ""
			Game.take_item(id))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 8
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var ic := _item_icon(id, 40)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(ic)
	var n := _title(Game.item_name(id), 22, Config.ACCENT)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size.x = 150
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(n)
	var d := _label(Config.ITEMS[id].text, 14, Config.TEXT_COLOR)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 206
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	return b


func _cash_out() -> void:
	var got := Game.cash_out()
	Sfx.play("sell")
	wall_view.reset_run()
	_go_main()
	show_toast(("Cashed out: +%d coins!  " % got if got > 0 else "Cashed out.  ") + "%s starts again from Stage 1." % Game.cave_name())
	_bump(coin_label)


func _on_failed(reason: String, lost_combo: int, at: Vector2) -> void:
	Sfx.play("timeout")
	var pos := wall_view.global_position + at - fx_layer.global_position
	_float_text(pos, reason + ("  Combo lost" if lost_combo > 1 else ""), Config.SLICE_MISS_COLOR, 0.0)


func _on_missed(reason: String, at: Vector2) -> void:
	Sfx.play("slice_miss")
	_float_text(wall_view.global_position + at - fx_layer.global_position, reason, Config.SLICE_MISS_COLOR, 0.0)


func _on_wall_down(at: Vector2) -> void:
	Sfx.play("wall_break")
	_shake = Config.SCREEN_SHAKE_ON_BREAK
	var bonus := 0 if wall_view.practice != "" else roundi(Config.WALL_BREAK_BONUS * _mine_mult(0.0))
	Game.mine_coins(bonus)
	var pos := wall_view.global_position + at - fx_layer.global_position
	var count := "" if wall_view.practice != "" else "  (%d / %d)" % [mini(Game.stage_walls + 1, Game.walls_need), Game.walls_need]
	_float_text(pos, "Wall down!" + count + ("  +%d" % bonus if bonus > 0 else ""), Config.ACCENT, 0.0)


func _on_life_lost(stage_down: bool, at: Vector2) -> void:
	tutorial.tip("lives")
	var pos := wall_view.global_position + at - fx_layer.global_position
	_shake = Config.SCREEN_SHAKE_ON_BREAK
	if stage_down:
		Sfx.play("stage_down")
		_float_text(pos, "Out of lives!  Down to Stage %d" % Game.stage, Config.SLICE_MISS_COLOR, 0.0)
	else:
		Sfx.play("life_lost")
		var lives := _lives_text()
		_float_text(pos, "Too late! Life lost (%s)" % lives + ("  -  stage restarts" if Config.LOSS_RESTARTS_STAGE else ""), Config.SLICE_MISS_COLOR, 0.0)


## The flame reached full blaze: a quick, soft flash over the whole screen.
func _on_full_light() -> void:
	if not on_wall or wall_view.peaceful():
		return
	flash_rect.size = size
	flash_rect.modulate.a = 1.0
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "modulate:a", 0.0, Config.FULL_FLASH_TIME).set_ease(Tween.EASE_OUT)


func _on_flooded(stage_down: bool, at: Vector2) -> void:
	var pos := wall_view.global_position + at - fx_layer.global_position
	if stage_down:
		_shake = Config.SCREEN_SHAKE_ON_BREAK
		Sfx.play("stage_down")
		_float_text(pos, "Flooded your last life!  Down to Stage %d" % Game.stage, Config.SLICE_MISS_COLOR, 0.0)
	else:
		Sfx.play("life_lost", 1.3)
		_float_text(pos, "-1/2 life  (%s)" % _lives_text(), Config.SLICE_MISS_COLOR, 0.0)


func _lives_text() -> String:
	var n := str(snappedf(Game.lives, 0.5)).trim_suffix(".0")
	return "%s %s left" % [n, "life" if Game.lives == 1.0 else "lives"]


func _on_stage_up(stage: int, at: Vector2) -> void:
	tutorial.tip("lives")
	Sfx.play("stage_up")
	var pos := wall_view.global_position + at - fx_layer.global_position + Vector2(0, 50)
	_float_text(pos, "STAGE %d!  Coins x%s" % [stage, str(snappedf(Game.stage_coin_mult(), 0.01))], Config.ACCENT, 0.25)


func _toggle_sound() -> void:
	Sfx.set_muted(not Sfx.muted)
	Sfx.play("click")
	_update_sound_btn()


func _toggle_hints() -> void:
	Game.set_show_hints(not Game.show_hints)
	Sfx.play("click")


## Registers a helper text that Settings > Hint text can hide.
func _hint(c: Control) -> Control:
	_hints.append(c)
	c.visible = Game.show_hints
	return c


func _apply_hints() -> void:
	for c in _hints:
		if is_instance_valid(c):
			c.visible = Game.show_hints
	if hints_btn:
		hints_btn.text = "Hint text: On  (click to hide)" if Game.show_hints else "Hint text: Off  (click to show)"
	if tips_btn:
		tips_btn.text = "Tips: On  (click to turn off)" if Game.show_tips else "Tips: Off  (click to turn on)"
	if beat_btn:
		beat_btn.text = "Beat practice: On  (click to skip it)" if Game.beat_practice else "Beat practice: Off  (click to turn on)"
	if circles_btn:
		circles_btn.text = "Coloured circles: On  (click to turn off)" if Game.color_circles else "Coloured circles: Off  (click to turn on)"


func _update_sound_btn() -> void:
	sound_btn.text = "Sound: Off  (click to turn on)" if Sfx.muted else "Sound: On  (click to mute)"


func _reset() -> void:
	_close_overlays()
	Game.reset()
	rock_view.set_rock("")
	_auto_place("")
	show_toast("New game started")


func _update_version_label() -> void:
	version_label.text = "%s   %s" % [GameVersion.label(), GameVersion.COPYRIGHT] + ("   -   " + _update_status if _update_status != "" else "")
	version_label.reset_size()


func show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.reset_size()
	toast_label.position = Vector2((size.x - toast_label.size.x) * 0.5, size.y - toast_label.size.y - 40)
	if toast_tween:
		toast_tween.kill()
	toast_label.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


# ================================================================== helpers
func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", Config.font_px(fs))
	l.add_theme_color_override("font_color", col)
	return l


## A label in the big title font.
func _title(text: String, fs: int, col: Color) -> Label:
	var l := _label(text, fs, col)
	l.add_theme_font_override("font", title_font)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


## Top-bar button. If assets/ui/<icon_name>.png exists it is shown as the button's icon.
func _top_button(text: String, cb: Callable) -> Button:
	var b := _button(text, cb)
	b.custom_minimum_size = Vector2(110, 44)
	return b


## Top-bar icon button (assets/ui/icons/<icon_name>.png, drawn by tools/make_ui.py). Falls back to the
## word if the icon is missing.
func _icon_button(icon_name: String, fallback: String, tip: String, cb: Callable) -> Button:
	var b := _button("", cb)
	b.tooltip_text = tip
	var path := UI_DIR + "icons/%s.png" % icon_name
	if ResourceLoader.exists(path):
		# the icon is a picture ON the button (not Button.icon: that one gets squeezed out by any text)
		b.custom_minimum_size = Vector2(60, 44)
		var pic := TextureRect.new()
		pic.texture = load(path)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 8
		pic.offset_top = 4
		pic.offset_right = -8
		pic.offset_bottom = -10  # clear of the button's raised underside
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(pic)
		var badge := _label("", 16, Config.ACCENT)  # a count in the corner (the Backpack's ores)
		badge.add_theme_constant_override("outline_size", Config.TEXT_OUTLINE_SIZE + 2)
		badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
		badge.offset_right = 2
		badge.offset_bottom = 6
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
		b.set_meta("badge", badge)
		b.set_meta("label", "")
	else:
		b.text = fallback
		b.custom_minimum_size = Vector2(110, 44)
		b.set_meta("label", fallback)
	return b


## Tall arrow button at the screen edge.
func _arrow_button(arrow: String, text: String, cb: Callable) -> Button:
	var left := arrow == "<"
	var b := _button(("%s\n%s" % [arrow, text]) if left else ("%s\n%s" % [text, arrow]), cb)
	b.custom_minimum_size = Vector2(72, 120)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", Config.font_px(20))
	return b


func _bump(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 1.12, 0.06)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12)


func _ore_count() -> int:
	var n := 0
	for id in Game.ores:
		n += Game.ores[id]
	return n


func _icon(tex: Texture2D, s: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(s, s)
	return t


func _panel(w: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size.x = w
	return p


func _scroll_list(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return v


func _fmt_time(sec: float) -> String:
	var s := int(ceil(sec))
	return "%d:%02d" % [s / 60, s % 60]


func _box(bg: Color, border: Color, bw: int, radius: int, pad := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0 if _skinned() else radius)  # pixel look: square corners, no smoothing
	sb.anti_aliasing = not _skinned()
	sb.set_content_margin_all(pad)
	return sb


func _skinned() -> bool:
	return ResourceLoader.exists(SKIN_DIR + "button.png")


## A 9-sliced pixel-art box from assets/ui/skin/<file>.png (null if the file is missing).
## m = texture margins in art pixels (left, top, right, bottom), pad = content margins in art pixels.
func _skin(file: String, m: Vector4i, pad: Vector4, tile := false) -> StyleBox:
	var path := SKIN_DIR + file + ".png"
	if not ResourceLoader.exists(path):
		return null
	var s := maxi(Config.UI_PIXEL_SCALE, 1)
	var tex: Texture2D = load(path)
	if s > 1:
		var img := tex.get_image()
		img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	if tile:  # the frame's plank grain repeats instead of stretching
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.texture_margin_left = m.x * s
	sb.texture_margin_top = m.y * s
	sb.texture_margin_right = m.z * s
	sb.texture_margin_bottom = m.w * s
	sb.content_margin_left = pad.x * s
	sb.content_margin_top = pad.y * s
	sb.content_margin_right = pad.z * s
	sb.content_margin_bottom = pad.w * s
	return sb


## A font file from Config, or (if empty / missing) the first installed system font from the list.
func _make_font(file: String, names: Array, weight: int) -> Font:
	if file != "" and ResourceLoader.exists(file):
		var ff: FontFile = (load(file) as FontFile).duplicate()
		if Config.FONT_PIXELATED:  # hard pixel edges
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ff.multichannel_signed_distance_field = false
		return ff
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	return f


## Chunky "wooden" box: a thicker dark bottom edge makes it look raised.
func _chunky(bg: Color, edge: Color, bottom: int, pad := 8, top_pad := -1) -> StyleBoxFlat:
	var sb := _box(bg, edge, 2, 6, pad)
	sb.border_width_bottom = bottom
	if top_pad >= 0:
		sb.content_margin_top = top_pad
	return sb


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = Config.font_px(Config.FONT_SIZE)
	for type in ["Label", "Button"]:
		t.set_color("font_outline_color", type, Config.TEXT_OUTLINE_COLOR)
		t.set_constant("outline_size", type, Config.TEXT_OUTLINE_SIZE)
		# drop shadow: the outlined letters again, offset and dark, underneath
		t.set_color("font_shadow_color", type, Config.TEXT_SHADOW_COLOR)
		t.set_constant("shadow_offset_x", type, Config.TEXT_SHADOW_OFFSET.x)
		t.set_constant("shadow_offset_y", type, Config.TEXT_SHADOW_OFFSET.y)
		t.set_constant("shadow_outline_size", type, Config.TEXT_OUTLINE_SIZE)
	t.set_stylebox("panel", "PanelContainer", _chunky(Config.PANEL_COLOR, Config.PANEL_BORDER, 6, 12))
	t.set_stylebox("normal", "Button", _chunky(Config.BUTTON_COLOR, Config.BUTTON_EDGE, 6, 8, 6))
	t.set_stylebox("hover", "Button", _chunky(Config.BUTTON_HOVER, Config.BUTTON_EDGE, 6, 8, 6))
	t.set_stylebox("pressed", "Button", _chunky(Config.BUTTON_COLOR.darkened(0.15), Config.BUTTON_EDGE, 2, 8, 10))
	t.set_stylebox("hover_pressed", "Button", _chunky(Config.BUTTON_HOVER.darkened(0.15), Config.BUTTON_EDGE, 2, 8, 10))
	t.set_stylebox("disabled", "Button", _chunky(Config.PANEL_BORDER.darkened(0.25), Config.BUTTON_EDGE, 4, 8, 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Config.TEXT_COLOR)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Config.TEXT_COLOR)
	t.set_color("font_disabled_color", "Button", Config.MUTED_TEXT.darkened(0.3))
	t.set_color("font_color", "Label", Config.TEXT_COLOR)
	var track := _box(Config.BUTTON_EDGE, Config.PANEL_BORDER, 2, 6, 4)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", _box(Config.ACCENT.darkened(0.15), Config.BUTTON_EDGE, 0, 6, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Config.ACCENT, Config.BUTTON_EDGE, 0, 6, 4))
	slot_style = _box(Color("#3e3546"), Color("#2e222f"), 3, 6, 10)
	if not _skinned():
		return t
	# ---- pixel-art skin (assets/ui/skin/, drawn by tools/make_ui.py); pads are in art px
	var bm := Config.UI_SKIN_BUTTON_MARGINS
	var bpad := Vector4(5, 2, 5, 5)          # text sits on the face, above the underside
	t.set_stylebox("normal", "Button", _skin("button", bm, bpad))
	t.set_stylebox("hover", "Button", _skin("button_hover", bm, bpad))
	var down := Vector4(5, 5, 5, 2)          # pressed: the key and its text sink 3 art px
	t.set_stylebox("pressed", "Button", _skin("button_pressed", Config.UI_SKIN_PRESSED_MARGINS, down))
	t.set_stylebox("hover_pressed", "Button", _skin("button_pressed", Config.UI_SKIN_PRESSED_MARGINS, down))
	t.set_stylebox("disabled", "Button", _skin("button_disabled", bm, bpad))
	var pm := Config.UI_SKIN_PANEL_MARGINS
	var panel := _skin("panel", pm, Vector4(9, 9, 9, 9), true)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "TooltipPanel", _skin("panel", pm, Vector4(7, 6, 7, 6), true))
	t.set_stylebox("panel", "AcceptDialog", panel)
	t.set_stylebox("embedded_border", "Window", _skin("panel", pm, Vector4(9, 18, 9, 9), true))
	t.set_stylebox("embedded_unfocused_border", "Window", _skin("panel", pm, Vector4(9, 18, 9, 9), true))
	var slot := _skin("slot", Config.UI_SKIN_SLOT_MARGINS, Vector4(5, 5, 5, 5))
	if slot:
		slot_style = slot
	# sliders and scroll bars: square pixel boxes in the same colours
	var outline := Color("#2e222f")
	var px := maxi(Config.UI_PIXEL_SCALE, 1)
	t.set_stylebox("slider", "HSlider", _box(Color("#45293f"), outline, px * 2, 0, 4))
	t.set_stylebox("grabber_area", "HSlider", _box(Color("#cd683d"), outline, px * 2, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("#e6904e"), outline, px * 2, 0, 4))
	if ResourceLoader.exists(SKIN_DIR + "grabber.png"):
		var img: Image = (load(SKIN_DIR + "grabber.png") as Texture2D).get_image()
		img.resize(img.get_width() * px, img.get_height() * px, Image.INTERPOLATE_NEAREST)
		var knob := ImageTexture.create_from_image(img)
		for k in ["grabber", "grabber_highlight", "grabber_disabled"]:
			t.set_icon(k, "HSlider", knob)
	t.set_stylebox("scroll", "VScrollBar", _box(Color("#45293f"), outline, px, 0, 3))
	t.set_stylebox("grabber", "VScrollBar", _box(Color("#cd683d"), outline, px, 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", _box(Color("#e6904e"), outline, px, 0, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", _box(Color("#9e4539"), outline, px, 0, 3))
	t.set_color("font_disabled_color", "Button", Color("#9babb2"))
	t.set_font_size("font_size", "Button", Config.font_px(Config.BUTTON_FONT_SIZE))
	t.set_constant("scrollbar_h_separation", "ScrollContainer", 6)
	return t


# ================================================================== dev: screenshots
## godot --path . -- --shot=<folder>   plays a little demo and saves screenshots (for testing).
func _dev_shots(dir: String) -> void:
	_dev_dir = dir
	Game.reset()
	Game.coins = 500
	_auto_place("")
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/1_start.png")
	var c := rock_view.size * 0.5 + Vector2(0, 30)
	for i in rock_view.hits_total - 1:
		rock_view.do_hit(c + Vector2(randf_range(-40, 40), randf_range(-30, 30)))
		await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/2_cracked.png")
	rock_view.do_hit(c)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/3_break.png")
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/4_after.png")
	print("music tracks loaded: %s, playing %s" % [Sfx._music.keys(), Sfx.current_music])
	_open_shop("rocks")
	print("music with the shop open: %s" % Sfx.current_music)
	_close_overlays()
	print("music after closing it: %s" % Sfx.current_music)
	# --- market (the same for everyone: worked out from the Philippine-time restock number), tickets, upgrades
	var w0 := Game.market_window()
	print("restock #%d, Philippine time %s, next in %.0fs, same prices worked out twice: %s" % [w0, Game.market_clock(),
			Game.restock_left(), Game.market_for(w0) == Game.market_for(w0)])
	var lo := 9.0
	var hi := 0.0
	var at_min := 0
	var at_max := 0
	var n_items := 0
	for i in 150:
		var mk := Game.market_for(w0 + i)
		for k in mk:
			lo = minf(lo, mk[k])
			hi = maxf(hi, mk[k])
			at_min += 1 if mk[k] <= Config.MARKET_MIN else 0
			at_max += 1 if mk[k] >= Config.MARKET_MAX else 0
			n_items += 1
	print("market over 150 restocks: min %.2f max %.2f, at the floor %.1f%%, at the cap %.1f%%" % [lo, hi, 100.0 * at_min / n_items, 100.0 * at_max / n_items])
	var in_stock := 0
	for s in Game.shop:
		in_stock += 1 if s.stock > 0 else 0
	print("shelf: %d rocks, %d in stock now, cheapest %s %d, priciest %s %d" % [Game.shop.size(), in_stock,
			Game.shop[0].id, Game.shop[0].price, Game.shop[-1].id, Game.shop[-1].price])
	Game.refresh_shop()
	print("tickets %d, trip %s, can start without one: %s" % [Game.ticket_count(), Game.trip_active, Game.start_trip()])
	print("claim free: %s, claim again: %s, free ticket in %.0fs" % [Game.claim_free_ticket(), Game.claim_free_ticket(), Game.free_ticket_left()])
	print("buy ticket: %s (coins %d), tickets %d" % [Game.buy_ticket(), Game.coins, Game.ticket_count()])
	for uid in Config.UPGRADES:
		print("%s: lv1 %.3f  lv2 %.3f  lv125 %.2f  lv250 %.2f  cost lv1 %d  cost lv250 %d" % [uid, Game.upgrade_value(uid, 1),
				Game.upgrade_value(uid, 2), Game.upgrade_value(uid, 125), Game.upgrade_value(uid, 250),
				Game.upgrade_cost(uid), roundi(Config.UPGRADES[uid].cost * pow(Config.UPGRADES[uid].cost_growth, 249))])
	var gold_before := Game.drop_chance("rock_07", "gold")
	var ruby_before := Game.drop_chance("rock_07", "ruby")
	Game.upgrades = {"miners_favor": 125, "jewelers_favor": 3, "rocky_riches": 250, "digging_expert": 40, "fools_gold": 250}
	print("crag gold chance %.2f -> %.2f, ruby %.3f -> %.3f, mine coins x%.2f" % [gold_before, Game.drop_chance("rock_07", "gold"),
			ruby_before, Game.drop_chance("rock_07", "ruby"), Game.mine_coin_mult()])
	Game.batch = true
	Game.set_block_signals(true)
	var ores_got := 0
	var gems_got := 0
	for i in 3000:
		Game.current_rock = "rock_02"
		var got := Game.break_current()
		for k in got:
			if Game.is_gem(k):
				gems_got += got[k]
			else:
				ores_got += got[k]
	Game.upgrades.erase("rocky_riches")
	var ores_plain := 0
	for i in 3000:
		Game.current_rock = "rock_02"
		var got := Game.break_current()
		for k in got:
			if not Game.is_gem(k):
				ores_plain += got[k]
	print("pebble ores per break: %.2f without Rocky Riches, %.2f at max (gems %.3f)" % [ores_plain / 3000.0, ores_got / 3000.0, gems_got / 3000.0])
	var lucky := 0
	for i in 2000:
		Game.ores["lead"] = 1
		if Game.sell("lead", 1) > Game.ore_price("lead"):
			lucky += 1
	Game.set_block_signals(false)
	Game.batch = false
	print("Fool's Gold at max: %d lucky sales out of 2000" % lucky)
	Game.ores = {"lead": 12, "rustvein": 5, "gold": 2, "tourmaline": 1, "zapperion": 1, "dreamstone": 1}
	Game.upgrades = {"miners_favor": 12, "jewelers_favor": 3, "digging_expert": 40}
	Game.coins = 500
	Game.changed.emit()
	_open_shop("rocks")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5_shop.png")
	_open_shop("dwarf")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5b_dwarf.png")
	Game.tickets = {Game.first_cave(): 2, "magma_veins": 1}
	Game.changed.emit()
	_open_shop("caves")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5b2_caves.png")
	Game.tickets = {}
	_open_shop("stocks")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5c_market.png")
	_show_market_tab("gems", false)  # Lapis is a gem: it's on the Gems tab
	market_pick = "lapis"
	_rebuild_market()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5d_market_lapis.png")
	_show_market_tab("rocks")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5e_market_rocks.png")
	print("market rows: ores %d, rocks %d" % [Config.ORES.size(), market_list.get_child_count()])
	_cycle_sort()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5e2_market_sorted.png")
	var profits := []
	for id in _rocks_by_price():
		profits.append(_profit(id, false))
	profits.sort()
	print("rock profits, least to most: ", profits)
	market_sort = ""
	_update_sort_btn()
	_show_market_tab("ores", false)
	_close_overlays()
	_open_practice()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5g_practice.png")
	_close_overlays()
	Game.set_show_hints(false)
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5f_no_hints.png")
	print("hints off: hint label visible %s" % hint_label.visible)
	Game.set_show_hints(true)
	_open_backpack()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/6_backpack.png")
	_open_settings()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/7_settings.png")
	_close_overlays()
	var shot0 := func(name: String): get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")
	Game.tickets = {Game.first_cave(): 3}
	_go_wall()
	await get_tree().create_timer(0.3).timeout
	shot0.call("7b_select_mine")
	_enter_cave(Game.first_cave())
	print("went down the mine: trip %s, tickets left %d" % [Game.trip_active, Game.ticket_count()])
	var shot := func(name: String): get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")
	await get_tree().create_timer(1.0).timeout
	wall_view.dev_mouse = wall_view.size * 0.5
	await get_tree().process_frame
	shot.call("8_wall_off")  # closed lighter, "press SPACE"
	var flicks := 0
	while wall_view.light_state == "off" and flicks < 20:
		wall_view.flick()
		flicks += 1
		if flicks == 2:
			await get_tree().create_timer(0.25).timeout
			shot.call("8b_flicking")
	print("flicks to light it up: ", flicks)
	await get_tree().create_timer(0.5).timeout
	wall_view.actions_left = 99
	var n := 9
	for k in ["tap", "zigzag", "slash", "drill", "pry"]:
		wall_view.new_action(k)
		wall_view.dev_mouse = wall_view._action_center() + Vector2(-60, -20)
		await get_tree().create_timer(0.6).timeout
		if k in ["zigzag", "slash", "pry"]:
			wall_view.dev_do(false, 0.5)  # half-way
		await get_tree().process_frame
		shot.call("%d_%s" % [n, k])
		if k == "pry":
			wall_view._fill = (wall_view._zone.x + wall_view._zone.y) * 0.5
			wall_view.release(wall_view._spot)
		else:
			wall_view.dev_do(k == "slash")  # one sloppy -> "Good"
		await get_tree().create_timer(0.12).timeout
		shot.call("%d_%s_done" % [n, k])
		n += 1
		await get_tree().create_timer(0.4).timeout
	# low fuel
	wall_view.new_action("drill")
	wall_view.dev_mouse = wall_view._spot + Vector2(-40, -10)
	wall_view._hold = 0.0
	wall_view.light = 0.3
	await get_tree().create_timer(0.1).timeout
	shot.call("14_low_fuel")
	# fuel runs out -> lighter out -> relight with SPACE
	wall_view._hold = 0.0
	wall_view.light = 0.002
	await get_tree().create_timer(0.5).timeout
	shot.call("15_lighter_out")
	print("state after fuel ran out: ", wall_view.light_state, "  need ", wall_view.relight_need, " hits")
	for i in wall_view.relight_need - 1:
		wall_view.dev_relight_hit()
	wall_view._meter = fmod(wall_view._zone_c + 0.5, 1.0)
	wall_view.flick()  # a mistimed strike: bar back up one
	print("after %d good strikes + 1 miss: %d / %d, speed %.2f, zone %.2f" % [wall_view.relight_need - 1, wall_view.relight_hits, wall_view.relight_need, wall_view._meter_speed, wall_view._zone_w])
	await get_tree().create_timer(0.1).timeout
	shot.call("16_relighting")
	while wall_view.light_state == "out":
		wall_view.dev_relight_hit()
	await get_tree().create_timer(0.7).timeout
	shot.call("17_relit")
	print("state after relight: ", wall_view.light_state, "  action: ", wall_view.kind)
	wall_view.light = 0.5
	wall_view.dev_flick()
	print("one timed flick at 0.50: light %.2f" % wall_view.light)
	# spam / late flicks fail and burn wick; each minigame has its own tempo
	wall_view._hold = 0.0
	wall_view.light = 0.5
	wall_view.wick = 1.0
	wall_view._fm = 0.05
	wall_view.flick()
	print("spam flick (bar at 0.05): light %.2f, wick %.2f" % [wall_view.light, wall_view.wick])
	wall_view._fm = 0.99
	wall_view.flick()
	print("late flick (bar at 0.99): light %.2f, wick %.2f" % [wall_view.light, wall_view.wick])
	var tempos := []
	for k in ["tap", "zigzag", "slash", "drill", "pry"]:
		wall_view.new_action(k)
		var tp: Vector2 = wall_view.flick_tempo()
		tempos.append("%s %.2fs (zone %d ms)" % [k, tp.x, roundi(tp.x * tp.y * 1000.0)])
	print("flick tempos: ", ", ".join(tempos))
	# perfect flicking must out-gain the fade at every tempo and stage
	var stage_keep := Game.stage
	for st in [1, 5, 10]:
		Game.stage = st
		var rates := []
		for k in ["", "tap", "zigzag", "slash", "drill", "pry"]:
			if k != "":
				wall_view.new_action(k)
			else:
				wall_view.kind = ""
			var gain := 0.0
			for i in 200:
				gain += wall_view.flick_gain()
			var per_sec := gain / 200.0 / wall_view.flick_tempo().x
			var fade := 1.0 / (Config.LIGHT_DURATION * Game.stage_fuel_factor())
			rates.append("%s %+.1f%%/s (%.1f%%/flick)" % [k if k != "" else "idle", (per_sec - fade) * 100.0, gain / 2.0])
		print("stage %d, net light with perfect flicks: %s" % [st, ", ".join(rates)])
	Game.stage = stage_keep
	wall_view.new_action("drill")
	await get_tree().create_timer(0.3).timeout
	shot.call("17e_flick_bar")
	var n_fl := 0
	wall_view.light = 0.3
	wall_view.wick = 1.0
	wall_view._hold = 0.0
	while wall_view.light < 1.0 and n_fl < 200:
		wall_view.dev_flick()
		n_fl += 1
	print("flicks from 0.30 to full: %d, then it stays full for %.1fs" % [n_fl, wall_view._hold])
	await get_tree().create_timer(0.08).timeout
	shot.call("17a_full_flash")
	var holds := []
	for i in 400:
		wall_view.ensure_lit()
		holds.append(wall_view._hold)
	print("full-blaze hold over 400 tries: min %.1fs, max %.1fs" % [holds.min(), holds.max()])
	wall_view._hold = 0.0
	wall_view.light = 0.3
	await get_tree().create_timer(0.1).timeout
	shot.call("17c_low_flame")
	wall_view.ensure_lit()
	var lives_before := Game.lives
	wall_view.flick()
	print("flick when full: flooded, lives %.1f -> %.1f, light %.2f" % [lives_before, Game.lives, wall_view.light])
	await get_tree().create_timer(0.15).timeout
	shot.call("17b_flooded")
	Game.lives = Config.LIVES
	# clicking / tapping the lighter works like SPACE
	wall_view.light = 0.5
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = wall_view._lighter_origin() + Vector2(60, 50) * Config.LIGHTER_SCALE
	var z: Vector2 = wall_view.flick_zone()
	wall_view._fm = (z.x + z.y) * 0.5
	wall_view._gui_input(click)
	print("tap on the lighter at 0.50: light %.2f" % wall_view.light)
	# the wick: burns while an action waits, caps the light, only finishing restores it
	wall_view.ensure_lit()
	wall_view._hold = 0.0
	wall_view.new_action("drill")
	await get_tree().create_timer(2.0).timeout
	print("wick after 2s with an action waiting: %.2f (light %.2f)" % [wall_view.wick, wall_view.light])
	wall_view.wick = 0.4
	wall_view.light = 0.38
	for i in 10:
		wall_view.dev_flick()
	print("10 flicks with the wick at 0.40: light %.2f" % wall_view.light)
	wall_view.press(wall_view._spot + Vector2(500, 0))
	print("after a stray click: wick %.2f" % wall_view.wick)
	await get_tree().create_timer(0.1).timeout
	wall_view.wick = 0.12
	await get_tree().create_timer(0.1).timeout
	shot.call("17d_wick_low")
	print("danger with the wick at 0.12: %.2f" % wall_view.danger())
	wall_view.dev_do()
	print("after finishing the action: wick %.2f" % wall_view.wick)
	wall_view.new_action("drill")
	wall_view.wick = 0.01
	await get_tree().create_timer(0.4).timeout
	print("wick burnt out: lighter %s" % wall_view.light_state)
	while wall_view.light_state == "out":
		wall_view.dev_relight_hit()
	# not relit in time -> life lost x3 -> stage down; then 5 walls -> stage up
	Game.stage = 3
	Game.lives = Config.LIVES
	Game.stage_walls = 2
	for i in Config.LIVES:
		wall_view.ensure_lit()
		wall_view._go_out()
		wall_view.relight_left = 0.01
		await get_tree().create_timer(0.8).timeout
		print("after loss %d: stage %d, lives %d, walls %d, lighter %s, trip %s" % [i + 1, Game.stage, Game.lives, Game.stage_walls, wall_view.light_state, Game.trip_active])
		if i == 0:
			await get_tree().create_timer(0.6).timeout
			shot.call("18_life_lost")
	await get_tree().create_timer(0.8).timeout
	Game.start_trip()  # a new ticket for the next part of the demo
	while wall_view.light_state == "off":
		wall_view.flick()  # "off" -> lit after a few flicks
	var need := Game.walls_need
	for w in need:
		await get_tree().create_timer(0.7).timeout
		wall_view.ensure_lit()
		wall_view.new_action("drill")
		wall_view.actions_left = 1
		wall_view.dev_do()
		await get_tree().create_timer(1.6).timeout
		if w == need - 1:
			shot.call("19_stage_up")  # the break after the stage is cleared
		wall_view.end_rest()
	print("after %d walls: stage %d, lives %d, walls %d (next stage needs %d)" % [need, Game.stage, Game.lives, Game.stage_walls, Game.walls_need])
	print("coins after wall: ", Game.coins)
	await get_tree().create_timer(0.6).timeout
	wall_view.ensure_lit()

	# every rock can drop every ore / gem: simulate breaks with the real drop code
	for rid in ["rock_02", "rock_07", "rock_03", "rock_20"]:
		var seen := {}
		var worth := 0.0
		var n_sim := 20000
		for i in n_sim:
			for roll in int(Config.ROCKS[rid].get("rolls", 1)):
				for ore_id in Config.ORES:
					if randf() * 100.0 < Game.drop_chance(rid, ore_id):
						var am := Game.drop_amount(rid, ore_id)
						seen[ore_id] = seen.get(ore_id, 0) + 1
						worth += randi_range(am.x, am.y) * int(Config.ORES[ore_id].sell_price)
		print("%s %s (price %d): worth ~%.1f per rock, %d / %d ores seen in %d breaks, dreamstone x%d, emerald x%d" % [rid,
				Game.rock_name(rid), Config.ROCKS[rid].price, worth / n_sim, seen.size(), Config.ORES.size(), n_sim,
				seen.get("dreamstone", 0), seen.get("emerald", 0)])

	# tap circles must always be clickable
	var back_r := Rect2(back_btn.global_position - wall_view.global_position, back_btn.size)
	print("taps, normal: ", wall_view.dev_check_taps(400, [back_r]))
	tutorial.start()
	tutorial._go(10)
	await get_tree().create_timer(0.4).timeout
	var panel_r := Rect2(tutorial._panel.global_position - wall_view.global_position, tutorial._panel.size)
	print("tutorial panel rect ", panel_r, "  reserve ", wall_view.reserve_bottom)
	print("taps, tutorial: ", wall_view.dev_check_taps(400, [back_r, panel_r]))
	tutorial.close()
	wall_view.ensure_lit()

	# zigzag shortcut check: a straight line from start to end must never work
	var cheats := 0
	for i in 30:
		wall_view.actions_left = 99
		wall_view.new_action("zigzag")
		if wall_view.dev_shortcut():
			cheats += 1
	print("zigzag straight-line shortcuts that worked: %d / 30" % cheats)
	var ok := 0
	for i in 30:
		wall_view.new_action("zigzag")
		wall_view.dev_do()
		if wall_view.kind != "zigzag":
			ok += 1
	print("zigzags traced properly that finished: %d / 30" % ok)

	# tutorial
	await get_tree().create_timer(0.8).timeout
	tutorial.start()
	await get_tree().create_timer(0.6).timeout
	shot.call("t1_welcome")
	tutorial._go(1)
	await get_tree().create_timer(0.6).timeout
	shot.call("t2_anvil")
	tutorial._go(6)
	await get_tree().create_timer(0.4).timeout
	shot.call("t2b_dwarves")
	tutorial._go(8)
	await get_tree().create_timer(0.8).timeout
	shot.call("t3_dark")
	tutorial._go(9)
	await get_tree().create_timer(0.3).timeout
	shot.call("t4_wall")
	tutorial._go(10)
	wall_view.dev_mouse = Vector2(400, 300)
	await get_tree().create_timer(1.3).timeout
	shot.call("t5_tap")
	tutorial._go(15)
	await get_tree().create_timer(0.6).timeout
	shot.call("t6_relight")
	wall_view.dev_relight_hit()
	await get_tree().create_timer(0.3).timeout
	shot.call("t6b_relight_hit")
	tutorial._go(16)
	await get_tree().create_timer(0.3).timeout
	shot.call("t7_stages")
	tutorial._go(18)
	await get_tree().create_timer(0.6).timeout
	shot.call("t8_done")
	tutorial.close()

	# out of lives on a trip: sent back up
	_dev = false
	go_wall()
	Game.trip_active = true
	await get_tree().create_timer(0.6).timeout
	Game.lose_life(Config.LIVES)
	await get_tree().create_timer(2.6).timeout
	shot.call("u_trip_over")
	print("after running out of lives: trip %s, on the wall %s" % [Game.trip_active, on_wall])
	Game.tickets = {}
	_go_wall()  # no ticket -> Select Mine (Go down greyed out)
	await get_tree().create_timer(0.4).timeout
	shot.call("u_need_ticket")
	print("mine without a ticket: on the wall %s, select mine open %s" % [on_wall, mine_overlay.visible])

	Game.reset()
	Game.tutorial_done = false
	Game.save()
	get_tree().quit()
