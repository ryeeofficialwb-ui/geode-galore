extends Node
## Autoload "Game": coins, owned rocks, ores, the shop, drops and saving.
## All numbers come from Config (scripts/config.gd).

signal changed            # coins / rocks / ores changed
signal shop_changed       # shop stock re-rolled or bought from
signal toast(text: String)
signal lucky_sale(ore_id: String, extra: int)  # Fool's Gold paid extra on a sale
signal market_moved       # prices changed (timed restock)
signal trip_over          # ran out of lives: the mine ticket is used up
signal found_rocks(found: Array, rolled: int)  # clearing a stage hit the cave's stone_chance: kept these rock ids out of `rolled`
signal found_ticket(cave_id: String)  # clearing a stage found a ticket (Ticket Hungry)

const SAVE_PATH := "user://save.cfg"
const LEGACY_ORES := {"copper_ore": "copper", "iron_ore": "iron", "sandstone": "lead"}
## Tips the old (Indev 0.1 - 0.3) tutorial already explained: saves that finished it skip these.
const BASIC_TIPS := ["anvil", "backpack", "shop", "mine", "lighter", "danger", "relight", "lives",
		"act_tap", "act_zigzag", "act_slash", "act_drill", "act_pry"]

var coins := 0
var rocks := {}           # rock id -> count (in your bag)
var ores := {}            # ore id -> count
var shop: Array = []      # [{id, stock, price}]
var restock_at := 0.0     # unix time of the next restock
var current_rock := ""    # rock sitting on the anvil ("" = none)
var rocks_broken := 0
var tutorial_done := false  # stays done after Reset
var tips_seen := {}       # tip id -> true: tips that already popped up (kept through Reset)
var show_tips := true     # Settings > Tips
var stage := 1            # mining stage (checkpoint)
var lives := 0.0          # lives left in this stage (halves count: flooding the lighter costs half a life)
var stage_walls := 0      # walls broken in this stage
var walls_need := 5       # walls this stage needs (rolled WALLS_PER_STAGE_MIN..MAX when the stage starts)
var restock_buys := 0     # paid restocks since the shop last restocked by itself (each costs more)
var best_stage := 1
var market := {}          # rock / ore id -> price multiplier (supply & demand), 1.0 = normal
var tickets := {}         # cave id -> mine tickets for that cave
var cave := ""            # the cave you're in (or were in last); stage / lives / stage_walls are this cave's
var cave_progress := {}   # other caves' stage checkpoints: cave id -> {stage, lives, stage_walls, best_stage}
var last_break_saved := false  # Silktouch kept the last rock you broke
var free_ticket_at := 0.0 # unix time when the next free ticket can be claimed
var trip_active := false  # a ticket has been used and you haven't run out of lives yet
var upgrades := {}        # upgrade id -> level
var show_hints := true    # Settings > Hint text (kept through Reset)
var market_prev := {}     # the market before the last restock (for the up / down trend)

var batch := false        # dev / simulations: don't save after every change
var _tex_cache := {}


func _ready() -> void:
	randomize()
	_validate_config()
	if Config.RESET_SAVE_ON_START or not _load():
		_new_game()


func _process(_delta: float) -> void:
	if now() >= restock_at:
		restock(true)
		Sfx.play("restock")
		toast.emit("The shop restocked - the market moved!")


static func now() -> float:
	return Time.get_unix_time_from_system()


func restock_left() -> float:
	return maxf(restock_at - now(), 0.0)


# ------------------------------------------------------------------ new game / shop
func _new_game() -> void:
	coins = Config.START_COINS
	rocks = Config.START_ROCKS.duplicate()
	ores = {}
	current_rock = ""
	rocks_broken = 0
	upgrades = {}
	stage = 1
	lives = max_lives()
	stage_walls = 0
	walls_need = roll_walls()
	restock_buys = 0
	best_stage = 1
	market = {}
	market_prev = {}
	cave = first_cave()
	cave_progress = {}
	tickets = {}
	if Config.START_TICKETS > 0:
		tickets[first_cave()] = Config.START_TICKETS
	free_ticket_at = now()  # the first free ticket is ready
	trip_active = false
	restock()


func reset() -> void:
	_new_game()
	changed.emit()
	save()


# ------------------------------------------------------------------ market (supply & demand)
func market_mult(id: String) -> float:
	return float(market.get(id, 1.0))


func rock_price(id: String) -> int:
	return maxi(1, roundi(float(Config.ROCKS[id].get("price", 10)) * market_mult(id)))


func ore_price(id: String) -> int:
	return maxi(1, roundi(float(Config.ORES[id].get("sell_price", 0)) * market_mult(id)))


## Demand shifts: every price moves from where it was, drifting back towards normal, kept inside
## MARKET_MIN..MARKET_MAX.
func move_market() -> void:
	market_prev = market.duplicate()
	for id in Config.ROCKS.keys() + Config.ORES.keys():
		var m := 1.0 + (market_mult(id) - 1.0) * (1.0 - Config.MARKET_PULL) + randfn(0.0, Config.MARKET_SWING)
		market[id] = snappedf(clampf(m, Config.MARKET_MIN, Config.MARKET_MAX), 0.01)
	market_moved.emit()


## move: true on the shop's timer (the market moves too); false for a paid restock / new game.
func restock(move := false) -> void:
	if move:
		move_market()
		restock_buys = 0  # the timed restock makes paying to restock cheap again
	shop.clear()
	var pool := {}
	for id in Config.ROCKS:
		var w := float(Config.ROCKS[id].get("shop_weight", 1))
		if w > 0:
			pool[id] = w
	for i in Config.SHOP_SLOTS:
		if pool.is_empty():
			break
		var id := _weighted_pick(pool)
		if not Config.ALLOW_DUPLICATE_SLOTS:
			pool.erase(id)
		shop.append({"id": id, "stock": randi_range(Config.STOCK_MIN, Config.STOCK_MAX), "price": rock_price(id)})
	restock_at = now() + Config.RESTOCK_SECONDS
	shop_changed.emit()
	save()


## What paying to restock costs right now: x INSTANT_RESTOCK_GROWTH for every paid restock since the last
## timed one.
func restock_cost() -> int:
	return roundi(Config.INSTANT_RESTOCK_COST * pow(Config.INSTANT_RESTOCK_GROWTH, restock_buys))


func buy_restock() -> bool:
	var cost := restock_cost()
	if Config.INSTANT_RESTOCK_COST < 0 or coins < cost:
		return false
	coins -= cost
	restock_buys += 1
	restock()
	changed.emit()
	return true


func buy(slot: int) -> bool:
	if slot < 0 or slot >= shop.size():
		return false
	var s: Dictionary = shop[slot]
	if s.stock <= 0:
		toast.emit("Sold out!")
		return false
	if coins < s.price:
		toast.emit("Not enough coins!")
		return false
	coins -= s.price
	s.stock -= 1
	rocks[s.id] = rocks.get(s.id, 0) + 1
	changed.emit()
	shop_changed.emit()
	save()
	return true


# ------------------------------------------------------------------ rocks & drops
## Moves one rock from the bag onto the anvil. Returns false if you have none.
func place_rock(id: String) -> bool:
	if rocks.get(id, 0) <= 0:
		return false
	if current_rock != "":  # put the old one back in the bag
		rocks[current_rock] = rocks.get(current_rock, 0) + 1
	rocks[id] -= 1
	if rocks[id] <= 0:
		rocks.erase(id)
	current_rock = id
	changed.emit()
	save()
	return true


func hits_for(id: String) -> int:
	var r: Dictionary = Config.ROCKS.get(id, {})
	return randi_range(int(r.get("hits_min", Config.HITS_MIN)), int(r.get("hits_max", Config.HITS_MAX)))


## Breaks the rock on the anvil: rolls its drop table, adds the ores. Returns ore id -> amount.
func break_current() -> Dictionary:
	var got := {}
	var r: Dictionary = Config.ROCKS.get(current_rock, {})
	# Silktouch: a chance the rock survives - you still get its drops and it goes back in your bag
	last_break_saved = current_rock != "" and randf() * 100.0 < upgrade_value("silktouch")
	if last_break_saved:
		rocks[current_rock] = rocks.get(current_rock, 0) + 1
	for roll in int(r.get("rolls", 1)):
		for ore_id in Config.ORES:  # every rock can drop every ore / gem
			if randf() * 100.0 < drop_chance(current_rock, ore_id):
				var a := drop_amount(current_rock, ore_id)
				var n := float(randi_range(a.x, a.y))
				if not is_gem(ore_id):  # Rocky Riches: more ores per drop (a fraction is a chance of one more)
					n *= 1.0 + upgrade_value("rocky_riches") / 100.0
				got[ore_id] = got.get(ore_id, 0) + int(n) + (1 if randf() < n - int(n) else 0)
	for ore_id in got:
		ores[ore_id] = ores.get(ore_id, 0) + got[ore_id]
	current_rock = ""
	rocks_broken += 1
	changed.emit()
	save()
	return got


# ------------------------------------------------------------------ mining stages
## A wall came down. Returns true if that cleared the stage (stage up).
func wall_cleared() -> bool:
	stage_walls += 1
	var up := stage_walls >= walls_need
	var found_r: Array = []
	var rolled := 0
	var found_t := ""
	if up:
		stage += 1
		best_stage = maxi(best_stage, stage)
		lives = max_lives()
		stage_walls = 0
		walls_need = roll_walls()
		# the cave may give you a pile of rocks: 0 - STAGE_ROCK_MAX of STAGE_ROCK_ROLLS make it up ...
		if randf() * 100.0 < float(cave_info().get("stone_chance", 0.0)):
			rolled = Config.STAGE_ROCK_ROLLS
			for i in rolled:
				if found_r.size() >= Config.STAGE_ROCK_MAX:
					break
				if randf() * 100.0 < Config.STAGE_ROCK_KEEP:
					var rid := _random_rock()
					if rid != "":
						found_r.append(rid)
						rocks[rid] = rocks.get(rid, 0) + 1
		# ... and Ticket Hungry a ticket for any cave
		if randf() * 100.0 < upgrade_value("ticket_hungry"):
			found_t = Config.CAVES.keys().pick_random()
			tickets[found_t] = ticket_count(found_t) + 1
	save()
	if not found_r.is_empty() or found_t != "":
		changed.emit()
	if rolled > 0:
		found_rocks.emit(found_r, rolled)
	if found_t != "":
		found_ticket.emit(found_t)
	return up


## How many walls a new stage needs (WALLS_PER_STAGE_MIN..MAX).
func roll_walls() -> int:
	return randi_range(Config.WALLS_PER_STAGE_MIN, maxi(Config.WALLS_PER_STAGE_MIN, Config.WALLS_PER_STAGE_MAX))


## Any rock type for the caves' stone drops (CAVE_STONE_ANY_EQUAL: all equally likely, or by shop_weight).
func _random_rock() -> String:
	var pool := {}
	for id in Config.ROCKS:
		var w := 1.0 if Config.CAVE_STONE_ANY_EQUAL else float(Config.ROCKS[id].get("shop_weight", 1))
		if w > 0.0:
			pool[id] = w
	return "" if pool.is_empty() else _weighted_pick(pool)


## Lose some life: 1 = didn't relight in time (the stage restarts), 0.5 = flooded the lighter.
## Returns true if that was the last of it (down a stage).
func lose_life(amount := 1.0, restart := true) -> bool:
	lives = snappedf(lives - amount, 0.5)
	if restart and Config.LOSS_RESTARTS_STAGE:
		stage_walls = 0
	var down := lives <= 0.0
	if down:
		stage = maxi(1, stage - 1)
		lives = max_lives()
		stage_walls = 0
		walls_need = roll_walls()
		if trip_active:  # out of lives: the ticket is used up
			trip_active = false
			trip_over.emit()
			changed.emit()
	save()
	return down


## How long the light lasts (and tap ring speed) compared to stage 1.
func stage_fuel_factor() -> float:
	return maxf(1.0 - (stage - 1) * Config.STAGE_FUEL_STEP, Config.STAGE_FUEL_MIN) * float(cave_info().get("fuel", 1.0))


## SPACE hits needed to relight (min, max).
func relight_range() -> Vector2i:
	var extra := (stage - 1) / maxi(Config.STAGE_RELIGHT_EVERY, 1)
	return Vector2i(Config.RELIGHT_HITS_MIN + extra, Config.RELIGHT_HITS_MAX + extra)


## How far along the mine's difficulty you are: your stage + the cave's head start. Sets how many actions
## a wall takes and which move styles you get (Config.ACTION_UNLOCK).
func skill_stage() -> int:
	return stage + int(cave_info().get("head_start", 0))


func stage_coin_mult() -> float:
	return 1.0 + (stage - 1) * Config.STAGE_COIN_BONUS


## Everything that multiplies the coins you earn in the mine: stage bonus x the cave x Digging Expert.
func mine_coin_mult() -> float:
	return stage_coin_mult() * float(cave_info().get("coins", 1.0)) * (1.0 + upgrade_value("digging_expert") / 100.0)


## Lives you get every stage: Config.LIVES + Pack of Fluid (in half lives), never above Config.MAX_LIVES.
func max_lives() -> float:
	return minf(float(Config.LIVES) + fluid_lives(), Config.MAX_LIVES)


## Pack of Fluid's extra lives, rounded down to half lives.
func fluid_lives(level := -1) -> float:
	return floorf(upgrade_value("pack_of_fluid", level) * 2.0 + 0.001) / 2.0


# ------------------------------------------------------------------ caves
func first_cave() -> String:
	return Config.CAVES.keys()[0]


func cave_info(id := "") -> Dictionary:
	return Config.CAVES.get(cave if id == "" else id, {})


func cave_name(id := "") -> String:
	return cave_info(id).get("name", id)


func ticket_price(id: String) -> int:
	return int(cave_info(id).get("ticket_price", Config.TICKET_PRICE))


## Tickets for one cave, or for all caves together ("").
func ticket_count(id := "") -> int:
	if id != "":
		return int(tickets.get(id, 0))
	var n := 0
	for k in tickets:
		n += int(tickets[k])
	return n


## The best stage you reached in a cave.
func cave_best(id: String) -> int:
	return best_stage if id == cave else int(cave_progress.get(id, {}).get("best_stage", 1))


func cave_stage(id: String) -> int:
	return stage if id == cave else int(cave_progress.get(id, {}).get("stage", 1))


## Switches the stage checkpoint over to another cave (each cave keeps its own).
func _switch_cave(id: String) -> void:
	if id == cave:
		return
	cave_progress[cave] = {"stage": stage, "lives": lives, "stage_walls": stage_walls, "walls_need": walls_need, "best_stage": best_stage}
	cave = id
	var p: Dictionary = cave_progress.get(id, {})
	cave_progress.erase(id)
	stage = maxi(1, int(p.get("stage", 1)))
	lives = clampf(float(p.get("lives", max_lives())), 0.5, max_lives())
	walls_need = _valid_walls(int(p.get("walls_need", 0)))
	stage_walls = clampi(int(p.get("stage_walls", 0)), 0, walls_need - 1)
	best_stage = maxi(stage, int(p.get("best_stage", 1)))


## A saved walls-per-stage, or a fresh roll if it's missing / outside WALLS_PER_STAGE_MIN..MAX.
func _valid_walls(n: int) -> int:
	return n if n >= Config.WALLS_PER_STAGE_MIN and n <= Config.WALLS_PER_STAGE_MAX else roll_walls()


# ------------------------------------------------------------------ tickets
func free_ticket_left() -> float:
	return maxf(free_ticket_at - now(), 0.0)


func claim_free_ticket() -> bool:
	if free_ticket_left() > 0.0:
		return false
	tickets[first_cave()] = ticket_count(first_cave()) + 1
	free_ticket_at = now() + Config.FREE_TICKET_SECONDS
	changed.emit()
	save()
	return true


func buy_ticket(id := "") -> bool:
	if id == "":
		id = first_cave()
	if not Config.CAVES.has(id) or coins < ticket_price(id):
		return false
	coins -= ticket_price(id)
	tickets[id] = ticket_count(id) + 1
	changed.emit()
	save()
	return true


## Going down the mine: uses a ticket for that cave unless a trip is already going. false = no ticket.
## id "" = the cave you were in last if you have a ticket for it, else any cave you have a ticket for.
func start_trip(id := "") -> bool:
	if trip_active:
		return true
	if id == "":
		id = cave if ticket_count(cave) > 0 else ""
		for k in Config.CAVES:
			if id == "" and ticket_count(k) > 0:
				id = k
	if id == "" or ticket_count(id) <= 0:
		return false
	tickets[id] = ticket_count(id) - 1
	if tickets[id] <= 0:
		tickets.erase(id)
	_switch_cave(id)
	trip_active = true
	changed.emit()
	save()
	return true


# ------------------------------------------------------------------ upgrades
func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_max(id: String) -> int:
	return int(Config.UPGRADES[id].get("levels", 1))


## The bonus (percent) an upgrade gives at a level (default: the level you have). Level 1 = "first",
## the last level = "max", a smooth power curve in between.
func upgrade_value(id: String, level := -1) -> float:
	if not Config.UPGRADES.has(id):
		return 0.0
	var u: Dictionary = Config.UPGRADES[id]
	var n := mini(upgrade_level(id) if level < 0 else level, upgrade_max(id))
	if n <= 0:
		return 0.0
	var top := float(u.get("max", 0.0))
	var first := float(u.get("first", top))
	var levels := upgrade_max(id)
	if levels <= 1 or first <= 0.0 or top <= 0.0:
		return top
	var p := log(first / top) / log(1.0 / levels)
	return top * pow(float(n) / levels, p)


func upgrade_cost(id: String) -> int:
	var u: Dictionary = Config.UPGRADES[id]
	return roundi(float(u.get("cost", 10)) * pow(float(u.get("cost_growth", 1.0)), upgrade_level(id)))


func buy_upgrade(id: String) -> bool:
	if upgrade_level(id) >= upgrade_max(id) or coins < upgrade_cost(id):
		return false
	coins -= upgrade_cost(id)
	var before := max_lives()
	upgrades[id] = upgrade_level(id) + 1
	lives += max_lives() - before  # Pack of Fluid tops you up straight away
	changed.emit()
	save()
	return true


func is_gem(ore_id: String) -> bool:
	return Config.ORES.get(ore_id, {}).get("type", "ore") == "gem"


func set_show_hints(on: bool) -> void:
	show_hints = on
	changed.emit()
	save()


## How a price moved at the last restock, in % (+12 = up 12%).
func market_trend(id: String) -> int:
	var before := float(market_prev.get(id, 1.0))
	return roundi((market_mult(id) / maxf(before, 0.01) - 1.0) * 100.0)


func tip_seen(id: String) -> bool:
	return tips_seen.has(id)


func mark_tip(id: String) -> void:
	if id != "" and not tips_seen.has(id):
		tips_seen[id] = true
		save()


func set_show_tips(on: bool) -> void:
	show_tips = on
	changed.emit()
	save()


func set_tutorial_done() -> void:
	tutorial_done = true
	save()


## % chance (per roll) that this rock gives this ore: the ore's chance slid between "cheapest" and
## "best" by the rock's quality, times the rock's bonus for it, times LUCK. A rock's own "drops" entry wins.
func drop_chance(rock_id: String, ore_id: String) -> float:
	var r: Dictionary = Config.ROCKS.get(rock_id, {})
	var o: Dictionary = Config.ORES.get(ore_id, {})
	var chance := 0.0
	if r.get("drops", {}).has(ore_id):
		chance = float(r.drops[ore_id].get("chance", 0.0))
	else:
		var c: Array = o.get("chance", [0.0, 0.0])
		chance = lerpf(float(c[0]), float(c[1]), clampf(float(r.get("quality", 0.0)), 0.0, 1.0))
		chance *= float(r.get("bonus", {}).get(ore_id, 1.0))
	chance *= 1.0 + upgrade_value("jewelers_favor" if is_gem(ore_id) else "miners_favor") / 100.0
	return minf(chance * Config.LUCK_MULTIPLIER, 100.0)


func drop_amount(rock_id: String, ore_id: String) -> Vector2i:
	var r: Dictionary = Config.ROCKS.get(rock_id, {})
	if r.get("drops", {}).has(ore_id):
		var d: Dictionary = r.drops[ore_id]
		return Vector2i(int(d.get("min", 1)), int(d.get("max", 1)))
	var a: Array = Config.ORES.get(ore_id, {}).get("amount", [1, 1])
	return Vector2i(int(a[0]), int(a[1]))


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	coins += amount
	changed.emit()
	save()


func sell(ore_id: String, amount: int) -> int:
	amount = mini(amount, ores.get(ore_id, 0))
	if amount <= 0:
		return 0
	var earned: int = amount * ore_price(ore_id)
	# Fool's Gold: a chance the buyer pays over the odds for this lot
	if (Config.FOOLS_GOLD_GEMS or not is_gem(ore_id)) and randf() * 100.0 < upgrade_value("fools_gold"):
		var extra := maxi(1, roundi(earned * Config.FOOLS_GOLD_BONUS / 100.0))
		earned += extra
		lucky_sale.emit(ore_id, extra)
	ores[ore_id] -= amount
	if ores[ore_id] <= 0:
		ores.erase(ore_id)
	coins += earned
	changed.emit()
	save()
	return earned


func sell_all() -> int:
	var total := 0
	for ore_id in ores.keys():
		total += sell(ore_id, ores[ore_id])
	return total


func _weighted_pick(pool: Dictionary) -> String:
	var total := 0.0
	for k in pool:
		total += pool[k]
	var r := randf() * total
	for k in pool:
		r -= pool[k]
		if r <= 0.0:
			return k
	return pool.keys().back()


# ------------------------------------------------------------------ art lookup
func rock_name(id: String) -> String:
	return Config.ROCKS.get(id, {}).get("name", id)


func ore_name(id: String) -> String:
	return Config.ORES.get(id, {}).get("name", id)


## All rocks live in ONE texture (assets/rocks/rocks.png) and all ores & gems in another (assets/ores/ores.png),
## sorted by price; scripts/sprite_atlas.gd (made by tools/slice_sheets.py) says where each one is.
const SHEET_ROCKS := "res://assets/rocks/rocks.png"
const SHEET_ORES := "res://assets/ores/ores.png"
const Atlas := preload("res://scripts/sprite_atlas.gd")


func rock_texture(id: String) -> Texture2D:
	return _sheet_texture(SHEET_ROCKS, Atlas.ROCKS, id)


## The rock art with its empty border cropped off (for small icons in lists / the shop).
func rock_icon(id: String) -> Texture2D:
	var key := "icon:" + id
	if not _tex_cache.has(key):
		# Copy the used pixels into a new square image (transparent padding). A square region that
		# ran past the PNG's edge used to smear the edge row (the pebble's long shadow).
		var src := rock_texture(id).get_image()
		src.convert(Image.FORMAT_RGBA8)
		var used := src.get_used_rect()
		var side := maxi(maxi(used.size.x, used.size.y), 1)
		var sq := Image.create(side, side, false, Image.FORMAT_RGBA8)
		sq.blit_rect(src, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
		_tex_cache[key] = ImageTexture.create_from_image(sq)
	return _tex_cache[key]


func ore_texture(id: String) -> Texture2D:
	return _sheet_texture(SHEET_ORES, Atlas.ORES, id)


## One picture cut out of a sheet (an AtlasTexture: no copy, just the region). Not on the sheet = the
## pink checkerboard.
func _sheet_texture(sheet: String, regions: Dictionary, id: String) -> Texture2D:
	var key := sheet + ":" + id
	if _tex_cache.has(key):
		return _tex_cache[key]
	if not regions.has(id) or not ResourceLoader.exists(sheet):
		return _texture(key)  # (missing: checkerboard)
	var at := AtlasTexture.new()
	at.atlas = load(sheet)
	at.region = regions[id]
	at.filter_clip = true  # never bleed into the next picture on the sheet
	_tex_cache[key] = at
	return at


## assets/ui/<rel> (upgrade icons, ticket...); missing art shows the pink checkerboard.
func ui_texture(rel: String) -> Texture2D:
	return _texture("res://assets/ui/" + rel)


## Loads a PNG; a missing file becomes a pink checkerboard so you can see what still needs art.
func _texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D
	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_warning("Missing art: " + path)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, Color("#ff00ff") if (x / 4 + y / 4) % 2 == 0 else Color("#300030"))
		tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


func _validate_config() -> void:
	for id in Config.ROCKS:
		for key in ["drops", "bonus"]:
			for ore_id in Config.ROCKS[id].get(key, {}):
				if not Config.ORES.has(ore_id):
					push_error("Config: rock '%s' %s has unknown ore '%s' (add it to ORES)" % [id, key, ore_id])
	for id in Config.START_ROCKS:
		if not Config.ROCKS.has(id):
			push_error("Config: START_ROCKS has unknown rock '%s'" % id)


# ------------------------------------------------------------------ save / load
func save() -> void:
	if not Config.SAVE_ENABLED or batch:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("game", "coins", coins)
	cfg.set_value("game", "rocks", rocks)
	cfg.set_value("game", "ores", ores)
	cfg.set_value("game", "shop", shop)
	cfg.set_value("game", "restock_at", restock_at)
	cfg.set_value("game", "current_rock", current_rock)
	cfg.set_value("game", "rocks_broken", rocks_broken)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.set_value("mine", "stage", stage)
	cfg.set_value("mine", "lives", lives)
	cfg.set_value("mine", "stage_walls", stage_walls)
	cfg.set_value("mine", "walls_need", walls_need)
	cfg.set_value("game", "restock_buys", restock_buys)
	cfg.set_value("mine", "best_stage", best_stage)
	cfg.set_value("mine", "cave", cave)
	cfg.set_value("mine", "caves", cave_progress)
	cfg.set_value("market", "prices", market)
	cfg.set_value("dwarves", "tickets", tickets)
	cfg.set_value("dwarves", "free_ticket_at", free_ticket_at)
	cfg.set_value("dwarves", "trip_active", trip_active)
	cfg.set_value("dwarves", "upgrades", upgrades)
	cfg.set_value("prefs", "show_hints", show_hints)
	cfg.set_value("prefs", "tips_seen", tips_seen)
	cfg.set_value("prefs", "show_tips", show_tips)
	cfg.set_value("market", "prev", market_prev)
	cfg.save(SAVE_PATH)


func _load() -> bool:
	if not Config.SAVE_ENABLED:
		return false
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	coins = cfg.get_value("game", "coins", Config.START_COINS)
	rocks = _known(cfg.get_value("game", "rocks", {}), Config.ROCKS)
	var old_ores: Dictionary = cfg.get_value("game", "ores", {})
	for old_id in LEGACY_ORES:  # ores renamed in an update keep their count
		if old_ores.has(old_id):
			var new_id: String = LEGACY_ORES[old_id]
			old_ores[new_id] = int(old_ores.get(new_id, 0)) + int(old_ores[old_id])
			old_ores.erase(old_id)
	ores = _known(old_ores, Config.ORES)
	shop = cfg.get_value("game", "shop", []).filter(func(s): return Config.ROCKS.has(s.get("id", "")))
	restock_at = cfg.get_value("game", "restock_at", 0.0)
	current_rock = cfg.get_value("game", "current_rock", "")
	if not Config.ROCKS.has(current_rock):
		current_rock = ""
	rocks_broken = cfg.get_value("game", "rocks_broken", 0)
	tutorial_done = cfg.get_value("game", "tutorial_done", false)
	upgrades = {}  # (loaded first: Pack of Fluid sets how many lives you can have)
	var up: Dictionary = cfg.get_value("dwarves", "upgrades", {})
	for id in up:
		if Config.UPGRADES.has(id):
			upgrades[id] = clampi(int(up[id]), 0, upgrade_max(id))
	cave = cfg.get_value("mine", "cave", first_cave())
	if not Config.CAVES.has(cave):
		cave = first_cave()
	cave_progress = {}
	var cp: Dictionary = cfg.get_value("mine", "caves", {})
	for id in cp:
		if Config.CAVES.has(id) and id != cave and cp[id] is Dictionary:
			cave_progress[id] = cp[id]
	stage = maxi(1, cfg.get_value("mine", "stage", 1))
	lives = clampf(snappedf(float(cfg.get_value("mine", "lives", max_lives())), 0.5), 0.5, max_lives())
	walls_need = _valid_walls(int(cfg.get_value("mine", "walls_need", 0)))
	stage_walls = clampi(cfg.get_value("mine", "stage_walls", 0), 0, walls_need - 1)
	restock_buys = maxi(0, int(cfg.get_value("game", "restock_buys", 0)))
	best_stage = maxi(stage, cfg.get_value("mine", "best_stage", 1))
	market = {}
	var mk: Dictionary = cfg.get_value("market", "prices", {})
	for id in mk:
		if Config.ROCKS.has(id) or Config.ORES.has(id):
			market[id] = clampf(float(mk[id]), Config.MARKET_MIN, Config.MARKET_MAX)
	show_hints = cfg.get_value("prefs", "show_hints", true)
	show_tips = cfg.get_value("prefs", "show_tips", true)
	tips_seen = {}
	var ts = cfg.get_value("prefs", "tips_seen", null)
	if ts is Dictionary:
		tips_seen = ts
	elif tutorial_done:  # a save from the old tutorial: it already explained the basics
		for id in BASIC_TIPS:
			tips_seen[id] = true
	market_prev = cfg.get_value("market", "prev", {})
	var tk = cfg.get_value("dwarves", "tickets", Config.START_TICKETS)
	if tk is Dictionary:
		tickets = _known(tk, Config.CAVES)
	else:  # saves from before caves: a plain number = tickets for the first cave
		tickets = {}
		if int(tk) > 0:
			tickets[first_cave()] = int(tk)
	free_ticket_at = minf(float(cfg.get_value("dwarves", "free_ticket_at", 0.0)), now() + Config.FREE_TICKET_SECONDS)
	trip_active = cfg.get_value("dwarves", "trip_active", false)
	return true


## Drops entries you removed from Config so an old save can't crash the game.
func _known(d: Dictionary, table: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if table.has(k) and int(d[k]) > 0:
			out[k] = int(d[k])
	return out
