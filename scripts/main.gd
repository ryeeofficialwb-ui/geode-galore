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
var rock_page: VBoxContainer
var dwarf_page: VBoxContainer
var ticket_info: Label
var claim_btn: Button
var buy_ticket_btn: Button
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
var market_btn: Button
var market_overlay: Control
var market_list: VBoxContainer
var market_detail: VBoxContainer
var market_tab := "ores"
var market_pick := ""               # the item shown on the right
var tab_m_ores: Button
var tab_m_rocks: Button
var hints_btn: Button
var _hints: Array[Control] = []     # helper texts that Settings > Hint text hides
var bag_list: VBoxContainer
var ore_list: VBoxContainer
var sell_all_btn: Button
var shop_overlay: Control
var shop_grid: GridContainer
var shop_timer: Label
var restock_btn: Button
var reset_confirm: ConfirmationDialog
var toast_label: Label
var toast_tween: Tween
var fx_layer: Control
var flash_rect: ColorRect          # the full-screen flash when your flame reaches full blaze
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
	wall_view.stage_up.connect(_on_stage_up)
	Game.lucky_sale.connect(_on_lucky_sale)
	Game.market_moved.connect(_refresh)
	Game.trip_over.connect(_on_trip_over)
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
	if not dev and Config.SHOW_TUTORIAL and not Game.tutorial_done:
		tutorial.start.call_deferred()


func _process(delta: float) -> void:
	if _dev_dir != "" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)  # demo: a minimized window stops drawing
	_layout_screens()
	version_label.visible = not on_wall
	version_label.position = Vector2(14, size.y - version_label.size.y - 8)
	wall_view.active = on_wall and not (shop_overlay.visible or backpack_overlay.visible or settings_overlay.visible or market_overlay.visible or reset_confirm.visible) 			and (not tutorial.visible or tutorial.practicing())  # the tutorial freezes the wall, except while you try an action
	wall_view.active = wall_view.active and (Game.trip_active or tutorial.practicing())  # no ticket, no mining
	if shop_overlay.visible:
		shop_timer.text = "Restocks in %s" % _fmt_time(Game.restock_left()) + ("  -  the market moves every restock" if Game.show_hints else "")
		_update_tickets()
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
	if ResourceLoader.exists(UI_DIR + "background.png"):  # optional art
		var bgt := TextureRect.new()
		bgt.texture = load(UI_DIR + "background.png")
		bgt.set_anchors_preset(Control.PRESET_FULL_RECT)
		bgt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bgt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(bgt)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)

	# --- top bar (stays put on both screens)
	var top_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		top_margin.add_theme_constant_override("margin_" + side, 12)
	col.add_child(top_margin)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top_margin.add_child(top)
	top.add_child(_title("RICH FROM ROCKS", 32, Config.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	if ResourceLoader.exists(UI_DIR + "coin.png"):
		top.add_child(_icon(load(UI_DIR + "coin.png"), 32))
	coin_label = _label("", 26, Config.ACCENT)
	top.add_child(coin_label)
	var tk := _icon(Game.ui_texture("ticket.png"), 32)
	tk.tooltip_text = "Mine tickets (Dwarven Shop)"
	top.add_child(tk)
	ticket_icon = tk
	ticket_label = _label("", 26, Config.TEXT_COLOR)
	ticket_label.tooltip_text = tk.tooltip_text
	ticket_label.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_child(ticket_label)
	shop_btn = _top_button("Shop", "shop", _open_shop)
	top.add_child(shop_btn)
	market_btn = _top_button("Market", "market", _open_market)
	market_btn.tooltip_text = "Market prices & guide to every ore, gem and rock"
	top.add_child(market_btn)
	backpack_btn = _top_button("Backpack", "backpack", _open_backpack)
	top.add_child(backpack_btn)
	settings_btn = _top_button("Settings", "settings", _open_settings)
	top.add_child(settings_btn)
	help_btn = _top_button("?", "help", _open_tutorial)
	help_btn.custom_minimum_size.x = 48
	help_btn.tooltip_text = "Tutorial"
	top.add_child(help_btn)

	# --- the two screens, side by side inside a clipped area
	screens_area = Control.new()
	screens_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screens_area.clip_contents = true
	col.add_child(screens_area)
	slider = Control.new()
	screens_area.add_child(slider)

	# main screen: [arrow] [rock] [Your Rocks]
	main_screen = MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		main_screen.add_theme_constant_override("margin_" + side, 12)
	slider.add_child(main_screen)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	main_screen.add_child(body)
	mine_btn = _arrow_button("<", "Mine", _go_wall)
	body.add_child(mine_btn)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(center)
	rock_title = _title("", 30, Config.TEXT_COLOR)
	rock_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(rock_title)
	var holder := CenterContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(holder)
	var stack := Control.new()  # pedestal (optional art) behind the rock
	stack.custom_minimum_size = Vector2.ONE * Config.ROCK_DISPLAY_SIZE
	holder.add_child(stack)
	rock_stack = stack
	if ResourceLoader.exists(UI_DIR + "pedestal.png"):
		var ped := TextureRect.new()
		ped.texture = load(UI_DIR + "pedestal.png")
		ped.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ped.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ped.size = Vector2(Config.ROCK_DISPLAY_SIZE, Config.ROCK_DISPLAY_SIZE * 0.35)
		ped.position = Vector2(0, Config.ROCK_DISPLAY_SIZE * 0.85)
		ped.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(ped)
	rock_view = RockView.new()
	rock_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.add_child(rock_view)
	hint_label = _hint(_label("", 18, Config.MUTED_TEXT)) as Label
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(hint_label)

	var right := _panel(280)
	body.add_child(right)
	rocks_panel = right
	var rv := VBoxContainer.new()
	right.add_child(rv)
	rv.add_child(_title("Your Rocks", 24, Config.ACCENT))
	rv.add_child(_hint(_label("Click one to put it on the anvil", 14, Config.MUTED_TEXT)))
	bag_list = _scroll_list(rv)

	# wall screen: the wall fills it, Back button on the right
	wall_screen = Control.new()
	slider.add_child(wall_screen)
	wall_view = WallView.new()
	wall_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall_view.font = font
	wall_view.title_font = title_font
	wall_screen.add_child(wall_view)
	back_btn = _arrow_button(">", "Back", _go_main)
	wall_screen.add_child(back_btn)

	# --- floating fx (drop pop-ups) above everything
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

	_build_shop()
	_build_market()
	_build_backpack()
	_build_settings()

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
	reset_confirm.dialog_text = "Start over? Coins, rocks and ores are wiped."
	reset_confirm.confirmed.connect(_reset)
	add_child(reset_confirm)
	_update_sound_btn()


## A dimmed full-screen popup with a titled panel. Returns [overlay, content VBox].
func _make_overlay(title: String, close: Callable) -> Array:
	var ov := ColorRect.new()
	ov.color = Color(0, 0, 0, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	ov.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: close.call())
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


## The shop has two tabs: rocks (limited stock, market prices) and the Dwarven Shop (tickets + upgrades).
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
	tab_dwarf = _button("Dwarven Shop", _show_shop_tab.bind("dwarf"))
	for b in [tab_rocks, tab_dwarf]:
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(190, 46)
		b.add_theme_color_override("font_pressed_color", Config.ACCENT)  # the open tab reads gold
		b.add_theme_color_override("font_hover_pressed_color", Config.ACCENT)
		tabs.add_child(b)

	rock_page = VBoxContainer.new()
	rock_page.add_theme_constant_override("separation", 10)
	rock_page.custom_minimum_size.x = 820
	v.add_child(rock_page)
	shop_timer = _label("", 16, Config.MUTED_TEXT)
	rock_page.add_child(shop_timer)
	shop_grid = GridContainer.new()
	shop_grid.columns = mini(Config.SHOP_SLOTS, 4)
	shop_grid.add_theme_constant_override("h_separation", 10)
	shop_grid.add_theme_constant_override("v_separation", 10)
	shop_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rock_page.add_child(shop_grid)
	restock_btn = _button("", _instant_restock)
	restock_btn.visible = Config.INSTANT_RESTOCK_COST >= 0
	rock_page.add_child(restock_btn)

	dwarf_page = VBoxContainer.new()
	dwarf_page.add_theme_constant_override("separation", 10)
	dwarf_page.custom_minimum_size.x = 820
	v.add_child(dwarf_page)
	var tcard := PanelContainer.new()
	tcard.add_theme_stylebox_override("panel", slot_style)
	dwarf_page.add_child(tcard)
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
	var tsub := _hint(_label("One ticket = one trip down the mine, until you run out of lives.", 14, Config.MUTED_TEXT))
	tinfo.add_child(tsub)
	claim_btn = _button("", _claim_ticket)
	claim_btn.custom_minimum_size = Vector2(190, 48)
	trow.add_child(claim_btn)
	buy_ticket_btn = _button("", _buy_ticket)
	buy_ticket_btn.custom_minimum_size = Vector2(170, 48)
	trow.add_child(buy_ticket_btn)
	dwarf_page.add_child(_title("Upgrades", 24, Config.ACCENT))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(820, 330)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dwarf_page.add_child(sc)
	upgrade_list = VBoxContainer.new()
	upgrade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_list.add_theme_constant_override("separation", 8)
	sc.add_child(upgrade_list)
	_show_shop_tab("rocks", false)


func _show_shop_tab(tab: String, sound := true) -> void:
	if sound and tab != shop_tab:
		Sfx.play("click")
	shop_tab = tab
	rock_page.visible = tab == "rocks"
	dwarf_page.visible = tab == "dwarf"
	shop_title.text = "Rock Shop" if tab == "rocks" else "Dwarven Shop"
	tab_rocks.set_pressed_no_signal(tab == "rocks")
	tab_dwarf.set_pressed_no_signal(tab == "dwarf")
	_update_tickets()


func _update_tickets() -> void:
	ticket_label.text = "x%d" % Game.tickets
	if ticket_info == null:
		return
	ticket_info.text = "Mine tickets: %d" % Game.tickets + ("   (you're on a trip)" if Game.trip_active else "")
	var left := Game.free_ticket_left()
	claim_btn.text = "Claim free ticket!" if left <= 0.0 else "Free ticket in %s" % _fmt_time(left)
	claim_btn.disabled = left > 0.0
	buy_ticket_btn.text = "Buy ticket  %d" % Config.TICKET_PRICE
	buy_ticket_btn.disabled = Game.coins < Config.TICKET_PRICE


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


## "+2.5% coins in the mine", "0.2% chance a sale pays +15%"
func _upgrade_text(id: String, v: float) -> String:
	var n := String.num(v, 2 if v < 10.0 else 1)
	if id == "fools_gold":
		return "%s%% chance a sale pays +%s%%" % [n, String.num(Config.FOOLS_GOLD_BONUS, 1)]
	return "+%s%% %s" % [n, Config.UPGRADES[id].get("text", "")]


## "(140%)" in green / "(60%)" in red next to a price, or nothing at the normal price.
func _market_tag(id: String, fs: int) -> Label:
	var m := Game.market_mult(id)
	var pct := roundi(m * 100.0)
	var l := _label("" if pct == 100 else "(%d%%)" % pct, fs,
			Config.MARKET_UP_COLOR if pct > 100 else Config.MARKET_DOWN_COLOR)
	l.tooltip_text = "Market price: %d%% of normal" % pct
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


## Market & Guide: today's price of everything (vs normal, and how it moved at the last restock), and
## a page for each ore / gem (lore, where to find it) and rock.
func _build_market() -> void:
	var o := _make_overlay("Market & Guide", _close_overlays)
	market_overlay = o[0]
	var v: VBoxContainer = o[1]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	var grp := ButtonGroup.new()
	tab_m_ores = _button("Ores & Gems", _show_market_tab.bind("ores"))
	tab_m_rocks = _button("Rocks", _show_market_tab.bind("rocks"))
	for b in [tab_m_ores, tab_m_rocks]:
		b.toggle_mode = true
		b.button_group = grp
		b.custom_minimum_size = Vector2(190, 46)
		b.add_theme_color_override("font_pressed_color", Config.ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", Config.ACCENT)
		tabs.add_child(b)
	v.add_child(_hint(_label("Prices change at every shop restock. Click anything to read about it.", 16, Config.MUTED_TEXT)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(500, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	market_list = VBoxContainer.new()
	market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_list.add_theme_constant_override("separation", 4)
	sc.add_child(market_list)
	var dcard := PanelContainer.new()
	dcard.add_theme_stylebox_override("panel", slot_style)
	dcard.custom_minimum_size = Vector2(400, 430)
	row.add_child(dcard)
	var dsc := ScrollContainer.new()
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dcard.add_child(dsc)
	market_detail = VBoxContainer.new()
	market_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_detail.add_theme_constant_override("separation", 6)
	dsc.add_child(market_detail)


func _open_market() -> void:
	_close_overlays()
	market_overlay.visible = true
	_show_market_tab(market_tab, false)


func _show_market_tab(tab: String, sound := true) -> void:
	if sound and tab != market_tab:
		Sfx.play("click")
	if tab != market_tab:
		market_pick = ""
	market_tab = tab
	tab_m_ores.set_pressed_no_signal(tab == "ores")
	tab_m_rocks.set_pressed_no_signal(tab == "rocks")
	_rebuild_market()


func _rebuild_market() -> void:
	if market_list == null or not market_overlay.visible:
		return
	for c in market_list.get_children():
		c.queue_free()
	var ids: Array = Config.ORES.keys() if market_tab == "ores" else _rocks_by_price()
	if market_pick == "" or not ids.has(market_pick):
		market_pick = ids[0]
	for id in ids:
		market_list.add_child(_market_row(id))
	_show_market_detail(market_pick)


func _rocks_by_price() -> Array:
	var ids: Array = Config.ROCKS.keys()
	ids.sort_custom(func(a, b): return int(Config.ROCKS[a].price) < int(Config.ROCKS[b].price))
	return ids


## One line of the list: icon, name, price now, % of normal, last move. Click it for its page.
func _market_row(id: String) -> Control:
	var ore := market_tab == "ores"
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
	pl.custom_minimum_size.x = 64
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	var pct := roundi(Game.market_mult(id) * 100.0)
	var ml := _label("%d%%" % pct, 16, _pct_color(pct - 100))
	ml.custom_minimum_size.x = 64
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(ml)
	var tr := Game.market_trend(id)
	var tl := _label(("+%d%%" % tr) if tr > 0 else ("%d%%" % tr) if tr < 0 else "-", 16, _pct_color(tr))
	tl.custom_minimum_size.x = 64
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tl.tooltip_text = "Change at the last restock"
	h.add_child(tl)
	for c in h.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _pct_color(delta: int) -> Color:
	return Config.MARKET_UP_COLOR if delta > 0 else Config.MARKET_DOWN_COLOR if delta < 0 else Config.MUTED_TEXT


## The page on the right.
func _show_market_detail(id: String) -> void:
	for c in market_detail.get_children():
		c.queue_free()
	var ore := market_tab == "ores"
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
		_detail_line("Market: %d%% of the normal %d  (%s at the last restock)" % [pct, int(o.sell_price),
				("+%d%%" % tr) if tr > 0 else ("%d%%" % tr) if tr < 0 else "no change"], _pct_color(pct - 100))
		_detail_line("In your backpack: %d" % int(Game.ores.get(id, 0)), Config.TEXT_COLOR)
		var ch: Array = o.get("chance", [0, 0])
		_detail_line("Chance per roll: %s%% in the cheapest rocks, up to %s%% in the best" % [String.num(float(ch[0]), 3), String.num(float(ch[1]), 2)], Config.TEXT_COLOR)
		var best := _best_rocks_for(id)
		_detail_line("Best found in: " + ", ".join(best), Config.TEXT_COLOR)
		market_detail.add_child(HSeparator.new())
		var lore := _label(Config.ORE_LORE.get(id, "Nobody knows much about this one yet."), 16, Config.TEXT_COLOR)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size.x = 350
		market_detail.add_child(lore)
	else:
		var r: Dictionary = Config.ROCKS[id]
		hv.add_child(_label("Rock", 16, Config.MUTED_TEXT))
		_detail_line("Shop price: %d coins" % Game.rock_price(id), Config.ACCENT)
		_detail_line("Market: %d%% of the normal %d  (%s at the last restock)" % [pct, int(r.price),
				("+%d%%" % tr) if tr > 0 else ("%d%%" % tr) if tr < 0 else "no change"], _pct_color(pct - 100))
		_detail_line("Hits to break: %d - %d" % [int(r.get("hits_min", Config.HITS_MIN)), int(r.get("hits_max", Config.HITS_MAX))], Config.TEXT_COLOR)
		_detail_line("Drop rolls: %d" % int(r.get("rolls", 1)), Config.TEXT_COLOR)
		var bonus: Dictionary = r.get("bonus", {})
		if not bonus.is_empty():
			var parts := []
			for oid in bonus:
				parts.append("%s x%s" % [Game.ore_name(oid), String.num(float(bonus[oid]), 1)])
			_detail_line("Speciality: " + ", ".join(parts), Config.TEXT_COLOR)
		_detail_line("Worth inside, on average: ~%d coins at today's prices" % roundi(_rock_worth(id)), Config.ACCENT)
		_detail_line("You own: %d" % int(Game.rocks.get(id, 0)), Config.TEXT_COLOR)


func _detail_line(text: String, col: Color) -> void:
	var l := _label(text, 16, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 350
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
	var credits := _label("Rich From Rocks  %s  -  by %s
%s
Font: BoldPixels by YukiPixels (CC BY-SA 4.0)
Music: Gambler Symphony, MeltdownTheme, Shop Theme (Thameuszin)" % [
			GameVersion.label(), GameVersion.OWNER, GameVersion.COPYRIGHT], 16, Config.MUTED_TEXT)
	v.add_child(credits)


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
	# bag
	for c in bag_list.get_children():
		c.queue_free()
	if Game.rocks.is_empty():
		bag_list.add_child(_label("Empty. Buy rocks in the Shop!", 15, Config.MUTED_TEXT))
	for id in Game.rocks:
		var b := _button("%s  x%d" % [Game.rock_name(id), Game.rocks[id]], _place.bind(id))
		b.icon = Game.rock_icon(id)
		b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		bag_list.add_child(b)
	# ores
	for c in ore_list.get_children():
		c.queue_free()
	var total := 0
	if Game.ores.is_empty():
		ore_list.add_child(_label("Break rocks to find ores.", 15, Config.MUTED_TEXT))
	for id in Config.ORES:  # keep table order
		if not Game.ores.has(id):
			continue
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
	backpack_btn.text = ("Backpack (%d)" % _ore_count()) if not Game.ores.is_empty() else "Backpack"
	sell_all_btn.text = "Sell Everything (+%d)" % total
	sell_all_btn.disabled = total <= 0
	restock_btn.text = "Restock now (%d coins)" % Config.INSTANT_RESTOCK_COST
	restock_btn.disabled = Game.coins < Config.INSTANT_RESTOCK_COST
	_rebuild_shop()
	_rebuild_upgrades()
	_update_tickets()
	_rebuild_market()


func _rebuild_shop() -> void:
	for c in shop_grid.get_children():
		c.queue_free()
	for i in Game.shop.size():
		var s: Dictionary = Game.shop[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", slot_style)
		card.custom_minimum_size.x = 190
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(v)
		var ic := _icon(Game.rock_texture(s.id), 96)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var name_l := _label(Game.rock_name(s.id), 18, Config.TEXT_COLOR)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_l)
		var stock_l := _label("%d left" % s.stock if s.stock > 0 else "SOLD OUT", 14,
				Config.MUTED_TEXT if s.stock > 0 else Color("#ff6b6b"))
		stock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(stock_l)
		var mk := _market_tag(s.id, 14)
		if mk.text == "":
			mk.text = "normal price"
			mk.add_theme_color_override("font_color", Config.MUTED_TEXT)
		mk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mk)
		var b := _button("Buy  %d" % s.price, _buy.bind(i))
		b.custom_minimum_size = Vector2(150, 40)
		b.disabled = s.stock <= 0 or Game.coins < s.price
		v.add_child(b)
		shop_grid.add_child(card)


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
		return
	var id: String = prefer if Game.rocks.has(prefer) else Game.rocks.keys()[0]
	Game.place_rock(id)
	rock_view.set_rock(id)
	_update_rock_text()


func _on_hit(_done: int, _total: int) -> void:
	_update_rock_text()


func _on_broken(center_global: Vector2) -> void:
	var id := rock_view.rock_id
	var got := Game.break_current()
	_shake = Config.SCREEN_SHAKE_ON_BREAK
	var origin := center_global - fx_layer.global_position
	if got.is_empty():
		_float_text(origin, "Nothing inside...", Config.MUTED_TEXT, 0.15)
		get_tree().create_timer(0.15).timeout.connect(Sfx.play.bind("drop_none"))
	else:
		var k := 0
		for ore_id in got:
			_fly_drop(ore_id, got[ore_id], origin, k * 0.18)
			k += 1
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


func _buy_ticket() -> void:
	if Game.buy_ticket():
		Sfx.play("buy")
		show_toast("Ticket bought")
	else:
		Sfx.play("error")
		show_toast("Not enough coins!")


func _buy_upgrade(id: String) -> void:
	if Game.buy_upgrade(id):
		Sfx.play("buy")
		show_toast("%s  Lv %d" % [Config.UPGRADES[id].get("name", id), Game.upgrade_level(id)])
	else:
		Sfx.play("error")


## Fool's Gold paid extra on a sale.
func _on_lucky_sale(ore_id: String, extra: int) -> void:
	Sfx.play("drop_rare")
	_float_text(Vector2(size.x * 0.5, size.y * 0.35), "FOOL'S GOLD!  +%d for your %s" % [extra, Game.ore_name(ore_id)], Config.ACCENT, 0.0)


## Out of lives: the ticket is used up and you're sent back up.
func _on_trip_over() -> void:
	if _dev:
		return
	await get_tree().create_timer(1.8).timeout
	if on_wall and not tutorial.visible and not Game.trip_active:
		_go_main()
		show_toast("Out of lives - your trip is over. Get a new ticket in the Dwarven Shop.")


func _sell(id: String, amount: int) -> void:
	var earned := Game.sell(id, amount)
	if earned > 0:
		Sfx.play("sell")
		show_toast("+%d coins" % earned)


func _sell_all() -> void:
	var earned := Game.sell_all()
	if earned > 0:
		Sfx.play("sell")
		show_toast("+%d coins" % earned)


func _open_shop(tab := "") -> void:
	_close_overlays()
	_rebuild_shop()
	if tab != "":
		_show_shop_tab(tab, false)
	shop_overlay.visible = true
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
	for o in [shop_overlay, backpack_overlay, settings_overlay, market_overlay]:
		if o:
			o.visible = false
	Sfx.play_music("mine" if on_wall else "main")  # the shop's music fades back to this screen's


func _open_tutorial() -> void:
	Sfx.play("click")
	tutorial.start()


# ================================================================== screens
## The Mine button: needs a ticket unless you're already on a trip.
func _go_wall() -> void:
	if not Game.trip_active:
		if not Game.start_trip():
			Sfx.play("error")
			_open_shop("dwarf")
			show_toast("You need a ticket to go down the mine!")
			return
		show_toast("Ticket used - good luck down there!")
	_slide_to(true)


func _go_main() -> void:
	_slide_to(false)


func go_wall() -> void:
	_slide_to(true)


func go_main() -> void:
	_slide_to(false)


func _slide_to(wall: bool) -> void:
	if on_wall == wall:
		return
	on_wall = wall
	Sfx.play("screen_slide")
	if not shop_overlay.visible:
		Sfx.play_music("mine" if wall else "main")
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(slider, "position:x", screens_area.size.x if wall else 0.0, Config.SCREEN_SLIDE_TIME)


## Both screens are as big as the area under the top bar; the wall one sits to the left of the main one.
func _layout_screens() -> void:
	var s := screens_area.size
	if main_screen.size != s:
		main_screen.size = s
		wall_screen.size = s
		wall_screen.position = Vector2(-s.x, 0)
		slider.position.x = s.x if on_wall else 0.0
	back_btn.size = back_btn.get_combined_minimum_size()
	back_btn.position = Vector2(s.x - back_btn.size.x - 12, (s.y - back_btn.size.y) * 0.5)


func _on_action_done(perfect: bool, at: Vector2, combo: int, mult: float) -> void:
	var pos := wall_view.global_position + at - fx_layer.global_position
	var base := randi_range(Config.PERFECT_COINS_MIN, Config.PERFECT_COINS_MAX) if perfect else Config.GOOD_COINS
	var coins := roundi(base * mult * Game.mine_coin_mult())
	Game.add_coins(coins)
	if coins > 0:
		_bump(coin_label)
	if perfect:
		Sfx.play("slice_perfect", minf(1.0 + 0.04 * (combo - 1), 1.6))
		_float_text(pos, "PERFECT!  +%d" % coins, Config.ACCENT, 0.0)
	else:
		Sfx.play("slice_good")
		_float_text(pos, "Good" + ("  +%d" % coins if coins > 0 else ""), Config.TEXT_COLOR, 0.0)


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
	var bonus := roundi(Config.WALL_BREAK_BONUS * Game.mine_coin_mult())
	Game.add_coins(bonus)
	var pos := wall_view.global_position + at - fx_layer.global_position
	var count := "" if wall_view.practice != "" else "  (%d / %d)" % [mini(Game.stage_walls + 1, Config.WALLS_PER_STAGE), Config.WALLS_PER_STAGE]
	_float_text(pos, "Wall down!" + count + ("  +%d" % bonus if bonus > 0 else ""), Config.ACCENT, 0.0)


func _on_life_lost(stage_down: bool, at: Vector2) -> void:
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
	if not on_wall:
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
func _top_button(text: String, icon_name: String, cb: Callable) -> Button:
	var b := _button(text, cb)
	b.custom_minimum_size = Vector2(110, 44)
	var path := UI_DIR + icon_name + ".png"
	if ResourceLoader.exists(path):
		b.icon = load(path)
		b.expand_icon = true
	return b


## Tall arrow button at the screen edge (optional art: assets/ui/arrow_left.png / arrow_right.png).
func _arrow_button(arrow: String, text: String, cb: Callable) -> Button:
	var left := arrow == "<"
	var b := _button(("%s\n%s" % [arrow, text]) if left else ("%s\n%s" % [text, arrow]), cb)
	b.custom_minimum_size = Vector2(72, 120)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", Config.font_px(20))
	var path := UI_DIR + ("arrow_left.png" if left else "arrow_right.png")
	if ResourceLoader.exists(path):
		b.icon = load(path)
		b.text = text
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
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
	# --- market, tickets, upgrades
	Game.move_market()
	print("market after one move: ", Game.market.values().slice(0, 8))
	var lo := 9.0
	var hi := 0.0
	var at_min := 0
	var at_max := 0
	var n_items := 0
	for i in 300:
		Game.move_market()
		for k in Game.market:
			lo = minf(lo, Game.market[k])
			hi = maxf(hi, Game.market[k])
			at_min += 1 if Game.market[k] <= Config.MARKET_MIN else 0
			at_max += 1 if Game.market[k] >= Config.MARKET_MAX else 0
			n_items += 1
	print("market over 300 restocks: min %.2f max %.2f, at the floor %.1f%%, at the cap %.1f%%" % [lo, hi, 100.0 * at_min / n_items, 100.0 * at_max / n_items])
	Game.restock(true)
	print("tickets %d, trip %s, can start without one: %s" % [Game.tickets, Game.trip_active, Game.start_trip()])
	print("claim free: %s, claim again: %s, free ticket in %.0fs" % [Game.claim_free_ticket(), Game.claim_free_ticket(), Game.free_ticket_left()])
	print("buy ticket: %s (coins %d), tickets %d" % [Game.buy_ticket(), Game.coins, Game.tickets])
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
	_open_market()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5c_market.png")
	market_pick = "lapis"
	_rebuild_market()
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5d_market_lapis.png")
	_show_market_tab("rocks")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(dir + "/5e_market_rocks.png")
	print("market rows: ores %d, rocks %d" % [Config.ORES.size(), market_list.get_child_count()])
	_show_market_tab("ores", false)
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
	Game.tickets = 3
	_go_wall()
	print("went down the mine: trip %s, tickets left %d" % [Game.trip_active, Game.tickets])
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
	for w in Config.WALLS_PER_STAGE:
		await get_tree().create_timer(0.7).timeout
		wall_view.ensure_lit()
		wall_view.new_action("drill")
		wall_view.actions_left = 1
		wall_view.dev_do()
		await get_tree().create_timer(1.6).timeout
	shot.call("19_stage_up")
	print("after %d walls: stage %d, lives %d, walls %d" % [Config.WALLS_PER_STAGE, Game.stage, Game.lives, Game.stage_walls])
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
	Game.tickets = 0
	_go_wall()  # no ticket -> Dwarven Shop
	await get_tree().create_timer(0.4).timeout
	shot.call("u_need_ticket")
	print("mine without a ticket: on the wall %s, shop open %s on %s" % [on_wall, shop_overlay.visible, shop_tab])

	Game.reset()
	Game.tutorial_done = false
	Game.save()
	get_tree().quit()
