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
signal item_used(id: String, text: String)  # a run item just did something (main shows the text)
signal run_changed        # items, Midas or its pot changed
signal lighter_knocked(text: String)  # an artifact knocked the lighter out of your hand (the wall handles it)

const SAVE_PATH := "user://save.cfg"
const LEGACY_ORES := {"copper_ore": "copper", "iron_ore": "iron", "sandstone": "lead"}
## Tips the old (Indev 0.1 - 0.3) tutorial already explained: saves that finished it skip these.
const BASIC_TIPS := ["anvil", "backpack", "shop", "mine", "lighter", "danger", "relight", "lives",
		"act_tap", "act_zigzag", "act_slash", "act_drill", "act_pry"]

var coins := 0
var rocks := {}           # rock id -> count (in your bag)
var ores := {}            # ore id -> count
var shop: Array = []      # the shelf: every rock, cheapest first: [{id, stock, price}]
var shop_window := -1     # which restock (Philippine-time slot) the shelf and prices belong to
var shop_bought := {}     # rock id -> how many YOU bought off this shelf (the shelf itself is the same for everyone)
var restock_at := 0.0     # unix time of the next restock
var current_rock := ""    # rock sitting on the anvil ("" = none)
var rocks_broken := 0
var tutorial_done := false  # stays done after Reset
var tips_seen := {}       # tip id -> true: tips that already popped up (kept through Reset)
var show_tips := true     # Settings > Tips
var color_circles := true # Settings > Coloured circles (each tap circle in its own colour)
var beat_practice := true # Settings > Beat practice (off: straight to the 3, 2, 1 after every wall)
var practice_bpm := 60.0  # Practice: the heart rate (FLICK bar tempo) you picked for practicing
var stage := 1            # mining stage (checkpoint)
var lives := 0.0          # lives left in this stage (halves count: flooding the lighter costs half a life)
var stage_walls := 0      # walls broken in this stage
var walls_need := 3       # walls this stage needs (base_walls() when the stage starts, artifacts can change it)
var restock_buys := 0     # paid restocks since the shop last restocked by itself (each costs more)
var best_stage := 1
var market := {}          # rock / ore id -> price multiplier (supply & demand), 1.0 = normal
var tickets := {}         # cave id -> mine tickets for that cave
var cave := ""            # the cave you're in (or were in last); stage / lives / stage_walls are this cave's
var cave_progress := {}   # other caves' stage checkpoints: cave id -> {stage, lives, stage_walls, best_stage}
var last_break_saved := false  # Silktouch kept the last rock you broke
var free_ticket_at := 0.0 # unix time when the next free ticket can be claimed
var trip_active := false  # a ticket has been used and you haven't run out of lives yet
# --- the run (one trip): its items (Config.ITEMS), Midas Touch and its pot
var run_items: Array = []  # item ids you hold this run
var run_slots := 4         # item slots this run (Greed is Good adds one)
var run_greed_done := false  # Greed + Is Good already paired up this run
var item_offer: Array = [] # items offered at this rest (pick one or skip)
var dynamite := 0          # Dynamite charges
var midas := 1.0           # Midas Touch multiplier
var midas_moves := 0       # moves finished since Midas was picked (every 3 add MIDAS_PER_3_MOVES)
var run_pot := 0           # with Midas, the mine's coins wait here until you cash out
var run_stacks: Array = [] # how many share each slot (same order as run_items; only Draupnir stacks, up to 2)
var run_earned := 0        # coins the mine paid you this run (Coin of Deceit's stake, the unlock cost; at stake until you cash out)
var run_ores := {}         # ore id -> how many the run gave you (at stake: a lost run takes them back)
var run_rocks := {}        # rock id -> how many the run gave you (at stake too)
var run_used := {}         # consumable id -> run_stages when it was used up (it can't be offered for a while)
var run_stages := 0        # stages cleared this run
var ram_uses := 0          # Ram uses left
var run_swapped := {}      # artifact id -> run_stages when you swapped it out (it can't be offered for SWAP_COOLDOWN stages)
var clover_stages := 0        # Sapphires Clover: stages cleared while holding it (rewards and difficulty grow with it)
var dice_half_stage := -1  # Dice of Dwarves rolled 3-4: walls need half the moves on this stage
var dice_wick_stage := -1  # Dice of Dwarves rolled 5-6: a free Extra Wick on this stage
var pet_feeds := 0         # Pet Rock: feeds left before it wanders off
var run_stats := {}        # this run so far, for the game over screen (see _new_stats)
var last_run := {}         # the run that was just lost: its stats, what it had and what was taken (game over screen)
var upgrades := {}        # upgrade id -> level
var rebirths := 0         # Rebirths done (each: +REBIRTH_SLOTS artifact slots on every run; survives Rebirth, not Reset)
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
		refresh_shop()
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
	shop_window = -1
	shop_bought = {}
	cave = first_cave()
	cave_progress = {}
	tickets = {}
	if Config.START_TICKETS > 0:
		tickets[first_cave()] = Config.START_TICKETS
	free_ticket_at = now()  # the first free ticket is ready
	trip_active = false
	_clear_run()
	refresh_shop()


## Reset: a brand new game - Rebirths too.
func reset() -> void:
	rebirths = 0
	_new_game()
	changed.emit()
	save()


# ------------------------------------------------------------------ rebirth
## Artifact slots every run starts with: ITEM_SLOTS + REBIRTH_SLOTS for each Rebirth.
func base_slots() -> int:
	return Config.ITEM_SLOTS + rebirths * Config.REBIRTH_SLOTS


## What the next Rebirth costs: {"coins": n, "ores": {ore id: n}} - REBIRTH_GROWTH x more for each one done.
func rebirth_cost() -> Dictionary:
	var k := pow(Config.REBIRTH_GROWTH, rebirths)
	var o := {}
	for id in Config.REBIRTH_ORES:
		o[id] = roundi(int(Config.REBIRTH_ORES[id]) * k)
	return {"coins": roundi(Config.REBIRTH_COINS * k), "ores": o}


## "" = you can Rebirth now, else why not.
func rebirth_blocker() -> String:
	if rebirths >= Config.REBIRTH_MAX:
		return "All %d Rebirths done" % Config.REBIRTH_MAX
	if trip_active:
		return "Finish your run first"
	var c := rebirth_cost()
	if coins < int(c.coins):
		return "Not enough coins"
	for id in c.ores:
		if int(ores.get(id, 0)) < int(c.ores[id]):
			return "Not enough %s" % ore_name(id)
	return ""


## Rebirth: pay for it, then the whole game starts over (coins, rocks, ores, upgrades, caves, tickets) with one
## more artifact slot on every run. Settings, tips and the tutorial stay done.
func rebirth() -> bool:
	if rebirth_blocker() != "":
		return false
	rebirths += 1
	_new_game()
	changed.emit()
	save()
	return true


# ------------------------------------------------------------------ market (supply & demand)
func market_mult(id: String) -> float:
	return float(market.get(id, 1.0))


func rock_price(id: String) -> int:
	return maxi(1, roundi(float(Config.ROCKS[id].get("price", 10)) * market_mult(id)))


func ore_price(id: String) -> int:
	return maxi(1, roundi(float(Config.ORES[id].get("sell_price", 0)) * market_mult(id)))


# ------------------------------------------------------------------ the global shelf & market
## Restocks happen on the Philippine clock (Config.MARKET_TIME_OFFSET) every RESTOCK_SECONDS, and each one
## is numbered. The prices and the shelf's stock are worked out from that number alone (a fixed random seed),
## so every player sees exactly the same prices and stock at the same moment, without a server.
func market_window(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	return floori((t + Config.MARKET_TIME_OFFSET) / Config.RESTOCK_SECONDS)


func window_start(w: int) -> float:
	return w * Config.RESTOCK_SECONDS - Config.MARKET_TIME_OFFSET


## The Philippine time right now as "2:35 PM".
func market_clock() -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(now()) + Config.MARKET_TIME_OFFSET)
	var h: int = d.hour % 12
	return "%d:%02d %s" % [12 if h == 0 else h, d.minute, "AM" if d.hour < 12 else "PM"]


## A random number generator everyone gets the same numbers from, for restock w (and stream `salt`).
static func _shared_rng(w: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = w * 2654435761 + salt * 40503 + 12345
	return r


## Every price for restock w: demand shifts each restock and drifts back towards normal, kept inside
## MARKET_MIN..MARKET_MAX. Worked out from MARKET_HISTORY restocks back (older ones no longer matter).
func market_for(w: int) -> Dictionary:
	var m := {}
	var ids: Array = Config.ROCKS.keys() + Config.ORES.keys()
	for k in range(w - Config.MARKET_HISTORY + 1, w + 1):
		var r := _shared_rng(k, 1)
		for id in ids:
			var x := 1.0 + (float(m.get(id, 1.0)) - 1.0) * (1.0 - Config.MARKET_PULL) + r.randfn(0.0, Config.MARKET_SWING)
			m[id] = snappedf(clampf(x, Config.MARKET_MIN, Config.MARKET_MAX), 0.01)
	return m


## Catches the shelf and prices up with the clock (on start, and at every restock).
func refresh_shop() -> void:
	var w := market_window()
	if w != shop_window:
		shop_window = w
		restock_buys = 0  # the timed restock makes paying to restock cheap again
		shop_bought = {}
		market_prev = market_for(w - 1)
		market = market_for(w)
		market_moved.emit()
	restock_at = window_start(w + 1)
	_build_shelf()
	save()


## Every rock on the shelf, cheapest first, each with this restock's stock (minus what you bought).
## Paying to restock rolls a new shelf - the same new shelf for everyone who pays the same number of times.
func _build_shelf() -> void:
	shop.clear()
	var r := _shared_rng(shop_window, 2 + restock_buys)
	for id in rocks_by_price():
		var c: Dictionary = Config.ROCKS[id]
		var roll := r.randf()
		var qty := r.randi_range(1, maxi(1, int(c.get("stock_max", 1))))
		var have := qty if roll < float(c.get("stock_chance", 1.0)) else 0
		shop.append({"id": id, "stock": maxi(0, have - int(shop_bought.get(id, 0))), "price": rock_price(id)})
	shop_changed.emit()


func rocks_by_price() -> Array:
	var ids: Array = Config.ROCKS.keys()
	ids.sort_custom(func(a, b):
		var pa := int(Config.ROCKS[a].price)
		var pb := int(Config.ROCKS[b].price)
		return pa < pb or (pa == pb and String(a) < String(b)))
	return ids


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
	shop_bought = {}
	_build_shelf()
	save()
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
	shop_bought[s.id] = int(shop_bought.get(s.id, 0)) + 1
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
	_roll_rock(current_rock, r, got)
	for ore_id in got:
		ores[ore_id] = ores.get(ore_id, 0) + got[ore_id]
	current_rock = ""
	rocks_broken += 1
	changed.emit()
	save()
	return got


## Rolls one rock's drop table into `got` (ore id -> amount).
func _roll_rock(id: String, r: Dictionary, got: Dictionary) -> void:
	var riches := 1.0 + upgrade_value("rocky_riches") / 100.0
	for roll in int(r.get("rolls", 1)):
		for ore_id in r.get("drops", {}):  # only this rock's own ores / gems
			if randf() * 100.0 < drop_chance(id, ore_id):
				var a := drop_amount(id, ore_id)
				var n := float(randi_range(a.x, a.y))
				if not is_gem(ore_id):  # Rocky Riches: more ores per drop (a fraction is a chance of one more)
					n *= riches
				got[ore_id] = got.get(ore_id, 0) + int(n) + (1 if randf() < n - int(n) else 0)


func rocks_total() -> int:
	return _sum(rocks) + (1 if current_rock != "" else 0)


## Crush All: breaks every rock you have (the bag and the anvil) in one go. All the drops are worked
## out here at once and saved once, so it doesn't matter how many rocks there are.
## Silktouch still works: the rocks it saves go back in your bag (they aren't crushed again this time).
## Returns {"got": ore id -> amount, "rocks": how many broke, "saved": Silktouch saves, "kinds": rock id -> count}.
func crush_all() -> Dictionary:
	var all := rocks.duplicate()
	if current_rock != "":
		all[current_rock] = int(all.get(current_rock, 0)) + 1
	var got := {}
	var broke := 0
	var saved := {}
	var silk := upgrade_value("silktouch")
	for id in all:
		var r: Dictionary = Config.ROCKS.get(id, {})
		var count := int(all[id])
		for i in count:
			_roll_rock(id, r, got)
			if randf() * 100.0 < silk:
				saved[id] = int(saved.get(id, 0)) + 1
		broke += count
	for ore_id in got:
		ores[ore_id] = ores.get(ore_id, 0) + got[ore_id]
	rocks = saved
	current_rock = ""
	rocks_broken += broke
	changed.emit()
	save()
	return {"got": got, "rocks": broke, "saved": _sum(saved), "kinds": all}


# ------------------------------------------------------------------ mining stages
## A wall came down. Returns true if that cleared the stage (stage up).
func wall_cleared() -> bool:
	stage_walls += 1
	_stat("walls", 1)
	midas_add(Config.MIDAS_PER_WALL)
	if trip_active:
		draupnir_grow()  # Draupnir makes another of itself every wall
	var up := stage_walls >= walls_need
	var found_r: Array = []
	var rolled := 0
	var found_t := ""
	var dice := ""
	var dice_end := false
	var hot := ""
	if up:
		stage += 1
		best_stage = maxi(best_stage, stage)
		lives = max_lives()
		stage_walls = 0
		walls_need = roll_walls()
		# artifacts: the Torch burns out, Dynamite gets a charge, Midas jumps, the Dice roll, new ones are offered
		if trip_active:
			run_stages += 1
			run_stats["best_stage"] = maxi(int(run_stats.get("best_stage", stage)), stage)
		if has_item("torch"):
			use_up("torch")
		if has_item("dynamite"):
			dynamite = mini(dynamite + item_count("dynamite"), Config.DYNAMITE_MAX * item_count("dynamite"))
		midas_add(Config.MIDAS_PER_STAGE)
		if trip_active:
			if has_item("sapphires_clover"):
				clover_stages += 1
				hot = "SAPPHIRES CLOVER!  Rewards x%s - but the mine is x%s harder" % [_short(clover_reward()), _short(clover_harder())]
			for k in item_count("dice_of_dwarves"):
				var r := roll_dice()
				dice = r if dice == "" else dice + "\n" + r
				if r.ends_with(DICE_END_TEXT):
					dice_end = true
					break
			roll_offer()
		# the cave may give you a pile of rocks from its tiers; bigger, likelier and richer on later stages ...
		# (Better Rock Piles: the pile chance, its cap and each rock's keep chance all x (1 + its %), never above 100%)
		var piles := 1.0 + upgrade_value("rock_piles") / 100.0
		var chance := minf(float(cave_info().get("stone_chance", 0.0)) * (1.0 + Config.STAGE_STONE_CHANCE_GROWTH * (stage - 2)) * piles,
				minf(Config.STAGE_STONE_CHANCE_MAX * piles, 100.0))
		if randf() * 100.0 < chance:
			var cleared := stage - 1
			rolled = Config.STAGE_ROCK_ROLLS + (cleared - 1) / maxi(Config.STAGE_ROCK_ROLLS_EVERY, 1)
			var keep_max := Config.STAGE_ROCK_MAX + (cleared - 1) / maxi(Config.STAGE_ROCK_MAX_EVERY, 1)
			for i in rolled:
				if found_r.size() >= keep_max:
					break
				if randf() * 100.0 < minf(Config.STAGE_ROCK_KEEP * piles, 100.0):
					found_r.append(_cave_rock(cleared))
		# ... and Ticket Hungry a ticket for any cave
		if randf() * 100.0 < upgrade_value("ticket_hungry"):
			found_t = Config.CAVES.keys().pick_random()
			tickets[found_t] = ticket_count(found_t) + 1
	var paid := 0
	if not found_r.is_empty():
		var pile := {}
		for rid in found_r:
			pile[rid] = int(pile.get(rid, 0)) + roundi(reward_mult())
		paid = give_rocks(pile)
	save()
	if not found_r.is_empty() or found_t != "":
		changed.emit()
	if paid > 0:
		item_used.emit("molerats", "MOLERATS ate the pile of %d rocks:  +%d coins" % [found_r.size(), paid])
	elif rolled > 0:
		found_rocks.emit(found_r, rolled)
	if found_t != "":
		found_ticket.emit(found_t)
	if hot != "":
		item_used.emit("sapphires_clover", hot)
	if dice != "":
		item_used.emit("dice_of_dwarves", dice)
	if dice_end:
		fail_run("DICE OF DWARVES rolled 12 - the run is over!")
	return up


## How many walls a new stage needs (base_walls(); Mushroom of Might: MUSHROOM_WALLS;
## Wall Breaker: WALL_BREAKER_WALLS fewer, never below 1).
func roll_walls() -> int:
	var n := base_walls()
	if has_item("mushroom_of_might"):
		n = randi_range(Config.MUSHROOM_WALLS.x, Config.MUSHROOM_WALLS.y)
	if has_item("wall_breaker"):
		n -= Config.WALL_BREAKER_WALLS
	return maxi(n, 1)


## Walls a stage needs before artifacts: WALLS_PER_STAGE, one more every WALLS_PER_STAGE_EVERY stages
## (stages 1-5 = 3, 6-10 = 4, 11-15 = 5 ...).
func base_walls(at_stage := -1) -> int:
	var s := stage if at_stage < 1 else at_stage
	var more := (s - 1) / Config.WALLS_PER_STAGE_EVERY if Config.WALLS_PER_STAGE_EVERY > 0 else 0
	return maxi(Config.WALLS_PER_STAGE + more, 1)


## The lowest your heart rate (FLICK bar BPM) can go on a stage of a cave: the cave's "bpm" on stage 1
## (Old Mine 60, pricier caves +5 each) and HEART_STAGE_BPM more every stage after that, up to HEART_STRESS_BPM.
## Mistakes push your heart above it; good flicks calm it back down to it (see WallView.heart_bpm).
func stage_bpm(at_stage := -1, cave_id := "") -> float:
	var s := stage if at_stage < 1 else at_stage
	var start := float(cave_info(cave_id).get("bpm", Config.HEART_REST_BPM))
	var b := start + Config.HEART_STAGE_BPM * maxf(s - 1, 0)
	return clampf(b, Config.HEART_REST_BPM, Config.HEART_STRESS_BPM)


## Any rock in the game, all equally likely (the artifacts that dig rocks up).
func _random_rock() -> String:
	return Config.ROCKS.keys().pick_random()


## A rock's tier: every rock sorted by price and cut into ROCK_TIERS groups (1 = the cheapest).
func rock_tier(id: String) -> int:
	var ids := rocks_by_price()
	return 1 + ids.find(id) * Config.ROCK_TIERS / maxi(ids.size(), 1)


## A rock from this cave's tiers (CAVES "tiers"); the further the stage, the more its higher tiers weigh.
func _cave_rock(at_stage: int) -> String:
	var t: Array = cave_info().get("tiers", [1, Config.ROCK_TIERS])
	var pool := {}
	for id in Config.ROCKS:
		var tier := rock_tier(id)
		if tier >= int(t[0]) and tier <= int(t[1]):
			pool[id] = 1.0 + Config.STAGE_TIER_SHIFT * (at_stage - 1) * (tier - int(t[0]))
	return _random_rock() if pool.is_empty() else _weighted_pick(pool)


## Lose some life: 1 = didn't relight in time (the stage restarts), 0.5 = flooded the lighter.
## Returns true if that was the last of it (down a stage).
func lose_life(amount := 1.0, restart := true) -> bool:
	if amount >= 1.0 and has_item("adrenaline_shot") and randf() * 100.0 < Config.ADRENALINE_CHANCE:
		item_used.emit("adrenaline_shot", "ADRENALINE SHOT!  No life lost")
		save()
		return false
	lives = snappedf(lives - amount, 0.5)
	_stat("lives_lost", amount)
	if restart and Config.LOSS_RESTARTS_STAGE:
		stage_walls = 0
	var down := lives <= 0.0
	if down and has_item("defibrillator"):  # revived on the same stage
		use_up("defibrillator")
		lives = minf(float(Config.LIVES), max_lives())
		stage_walls = 0
		item_used.emit("defibrillator", "DEFIBRILLATOR!  Back with %d lives on Stage %d" % [int(lives), stage])
		save()
		return false
	if down:
		stage = maxi(1, stage - 1)
		lives = max_lives()
		stage_walls = 0
		walls_need = roll_walls()
		if has_item("torch"):
			use_up("torch")
		if has_item("ladder"):  # just back a stage: the run goes on
			use_up("ladder")
			item_used.emit("ladder", "LADDER!  Down to Stage %d - the run goes on" % stage)
		elif trip_active:  # out of lives: the ticket is used up and the run's loot goes with it (minus Minecart / Backpack)
			var before := run_loot()
			var loot := _lose_loot()
			_end_summary("You ran out of lives.", before, loot)
			trip_active = false
			_clear_run()
			var lt := _loot_text(loot)
			if lt != "":
				item_used.emit("", "Out of lives - " + lt)
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


## A saved walls-per-stage, or a fresh roll if it's missing / more than this stage can need (artifacts can
## take it below base_walls(), Mushroom of Might up to MUSHROOM_WALLS).
func _valid_walls(n: int) -> int:
	return n if n >= 1 and n <= maxi(base_walls(), Config.MUSHROOM_WALLS.y) else roll_walls()


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
	_clear_run()  # a new run: no items yet
	changed.emit()
	save()
	return true


# ------------------------------------------------------------------ artifacts (Config.ITEMS)
## How strongly an artifact works: 1 for each you hold (a Draupnir slot holds up to 2), +1 more for a Copy
## on its LEFT (Copy copies the one on its right) and for a Catto on its RIGHT (Catto swats the one on its
## left). Copy can't copy Catto and Catto can't swat Copy.
func item_count(id: String) -> int:
	var n := 0
	for i in run_items.size():
		var it: String = run_items[i]
		if it == id:
			n += _stack(i)
		elif it == "copy" and id != "catto" and i + 1 < run_items.size() and run_items[i + 1] == id:
			n += _stack(i + 1)
		elif it == "catto" and id != "copy" and i > 0 and run_items[i - 1] == id:
			n += _stack(i - 1)
	return n


func has_item(id: String) -> bool:
	return item_count(id) > 0


func _stack(i: int) -> int:
	return int(run_stacks[i]) if i < run_stacks.size() else 1


func item_name(id: String) -> String:
	return Config.ITEMS.get(id, {}).get("name", id)


## Used up after it does its thing (and can't be offered again for a while)?
func is_consumable(id: String) -> bool:
	return bool(Config.ITEMS.get(id, {}).get("once", false))


## Stages until a used-up consumable can be offered again (0 = it can).
func consumable_wait(id: String) -> int:
	if not run_used.has(id):
		return 0
	return maxi(0, Config.CONSUMABLE_COOLDOWN - (run_stages - int(run_used[id])))


## Stages until an artifact you swapped out can be offered again (0 = it can).
func swap_wait(id: String) -> int:
	if not run_swapped.has(id):
		return 0
	return maxi(0, Config.SWAP_COOLDOWN - (run_stages - int(run_swapped[id])))


## Paying to bring the used-up consumables back early: CONSUMABLE_UNLOCK_COST of this run's coins.
func unlock_cost() -> int:
	return ceili((run_earned + run_pot) * Config.CONSUMABLE_UNLOCK_COST)


func unlock_consumables() -> bool:
	if run_used.is_empty():
		return false
	var from_earned := ceili(run_earned * Config.CONSUMABLE_UNLOCK_COST)
	var from_pot := ceili(run_pot * Config.CONSUMABLE_UNLOCK_COST)
	coins = maxi(0, coins - from_earned)
	run_earned -= from_earned
	run_pot -= from_pot
	run_used = {}
	changed.emit()
	run_changed.emit()
	save()
	return true


func _clear_run() -> void:
	run_items = []
	run_stacks = []
	run_slots = base_slots()
	run_greed_done = false
	item_offer = []
	dynamite = 0
	ram_uses = 0
	midas = 1.0
	midas_moves = 0
	run_pot = 0
	run_earned = 0
	run_ores = {}
	run_rocks = {}
	run_used = {}
	run_swapped = {}
	run_stages = 0
	clover_stages = 0
	dice_half_stage = -1
	dice_wick_stage = -1
	pet_feeds = 0
	run_stats = _new_stats()
	run_changed.emit()


func _new_stats() -> Dictionary:
	return {"start_stage": stage, "best_stage": stage, "walls": 0, "moves": 0, "perfects": 0, "best_combo": 0,
			"lives_lost": 0.0, "time": 0.0, "coins": 0}


func _stat(key: String, add: float) -> void:
	if not trip_active:
		return
	if run_stats.is_empty():
		run_stats = _new_stats()
	run_stats[key] = run_stats.get(key, 0) + add


## A move was finished on a run (main calls this): counts it, and the best combo.
func note_move(perfect: bool, combo: int) -> void:
	if not trip_active:
		return
	_stat("moves", 1)
	if perfect:
		_stat("perfects", 1)
	run_stats["best_combo"] = maxi(int(run_stats.get("best_combo", 0)), combo)


## Time spent mining this run (main adds it every frame you're on the wall; saved with everything else).
func note_time(delta: float) -> void:
	if trip_active and not run_stats.is_empty():
		run_stats["time"] = float(run_stats.get("time", 0.0)) + delta


## The run was just lost: keeps everything the game over screen shows. `before` is run_loot() from before the
## loot was taken, `lost` what _lose_loot() took.
func _end_summary(reason: String, before: Dictionary, lost: Dictionary) -> void:
	last_run = run_stats.duplicate()
	last_run["reason"] = reason
	last_run["cave"] = cave
	last_run["loot"] = before
	last_run["lost"] = lost
	last_run["items"] = run_items.duplicate()


## Rolls ITEM_CHOICES different artifacts to offer: none you already hold, no used-up consumable still
## cooling down, and Greed / Is Good stop showing up once they've paired.
func roll_offer() -> void:
	var pool: Array = []
	for id in Config.ITEMS:
		if run_items.has(id) or (run_greed_done and id in ["greed", "is_good"]) or consumable_wait(id) > 0 or swap_wait(id) > 0:
			continue
		pool.append(id)
	pool.shuffle()
	item_offer = pool.slice(0, Config.ITEM_CHOICES)
	run_changed.emit()


func free_slots() -> int:
	return run_slots - run_items.size()


## Takes an offered artifact (swapping out slot `drop` if your slots are full). Returns false if it can't.
func take_item(id: String, drop := -1) -> bool:
	if not item_offer.has(id):
		return false
	if free_slots() <= 0:
		if drop < 0 or drop >= run_items.size():
			return false
		var old: String = run_items[drop]
		run_items.remove_at(drop)
		run_stacks.remove_at(drop)
		if not run_items.has(old):  # swapped out: it won't be offered again for SWAP_COOLDOWN stages
			run_swapped[old] = run_stages
	run_items.append(id)
	run_stacks.append(1)
	item_offer = []
	match id:
		"dynamite":
			dynamite = Config.DYNAMITE_MAX
		"midas_touch":
			midas = 1.0
			midas_moves = 0
		"ram":
			ram_uses = Config.RAM_USES
		"mushroom_of_might":
			walls_need = clampi(walls_need, stage_walls + 1, maxi(Config.MUSHROOM_WALLS.y, stage_walls + 1))
		"wall_breaker":  # the stage you're on gets easier straight away too
			walls_need = maxi(walls_need - Config.WALL_BREAKER_WALLS, stage_walls + 1)
		"sapphires_clover":
			clover_stages = 0
		"pet_rock":
			pet_feeds = Config.PET_ROCK_FEEDS
	if run_items.has("greed") and run_items.has("is_good"):  # Greed is Good: both go, one more slot for the run
		_remove_slot(run_items.find("greed"))
		_remove_slot(run_items.find("is_good"))
		run_slots += Config.GREED_IS_GOOD_SLOTS
		run_greed_done = true
		item_used.emit("greed", "GREED IS GOOD!  +1 artifact slot this run")
	run_changed.emit()
	save()
	return true


func _remove_slot(i: int) -> void:
	if i >= 0 and i < run_items.size():
		run_items.remove_at(i)
		run_stacks.remove_at(i)


func skip_offer() -> void:
	item_offer = []
	run_changed.emit()
	save()


## A consumable did its thing: it's gone (and isn't offered again for CONSUMABLE_COOLDOWN stages).
func use_up(id: String) -> void:
	_remove_slot(run_items.find(id))
	if is_consumable(id):
		run_used[id] = run_stages
	run_changed.emit()


## Moves an artifact one slot left (-1) or right (+1): order matters for Copy and Catto.
func move_item(i: int, dir: int) -> void:
	var j := i + dir
	if i < 0 or j < 0 or i >= run_items.size() or j >= run_items.size():
		return
	var a = run_items[i]
	run_items[i] = run_items[j]
	run_items[j] = a
	var s = run_stacks[i]
	run_stacks[i] = run_stacks[j]
	run_stacks[j] = s
	run_changed.emit()
	save()


# --- Draupnir: one more every wall; 2 share a slot; sell for DRAUPNIR_SELL; no room = it knocks your lighter
## Returns false if there was no room (the overflow knocks your lighter out of your hand).
func draupnir_grow() -> bool:
	if not run_items.has("draupnir"):
		return true
	var add := 2 if item_count("draupnir") > _real_count("draupnir") else 1  # a Copy / Catto on it makes one more
	var cap := int(Config.ITEMS.draupnir.get("stack", 2))
	for k in add:
		var placed := false
		for i in run_items.size():
			if run_items[i] == "draupnir" and _stack(i) < cap:
				run_stacks[i] = _stack(i) + 1
				placed = true
				break
		if not placed and free_slots() > 0:
			run_items.append("draupnir")
			run_stacks.append(1)
			placed = true
		if not placed:
			run_changed.emit()
			lighter_knocked.emit("DRAUPNIR OVERFLOWED!  Your lighter's knocked out of your hand")
			return false
	run_changed.emit()
	return true


func _real_count(id: String) -> int:
	var n := 0
	for i in run_items.size():
		if run_items[i] == id:
			n += _stack(i)
	return n


func sell_draupnir(i: int) -> int:
	if i < 0 or i >= run_items.size() or run_items[i] != "draupnir":
		return 0
	run_stacks[i] = _stack(i) - 1
	if run_stacks[i] <= 0:
		_remove_slot(i)
	var got := roundi(Config.DRAUPNIR_SELL * reward_mult())
	coins += got
	if trip_active:
		run_earned += got
	changed.emit()
	run_changed.emit()
	save()
	return got


## Midas Touch: the coin multiplier = cave & stage coins x MIDAS + combo.
func midas_add(amount: float) -> void:
	if has_item("midas_touch"):
		midas = minf(midas + amount, Config.MIDAS_MAX)
		run_changed.emit()


## A move was finished on the wall (not in practice): Midas grows every 3 moves.
func move_done() -> void:
	if has_item("midas_touch"):
		midas_moves += 1
		if midas_moves % 3 == 0:
			midas_add(Config.MIDAS_PER_3_MOVES)


## Coins from the mine: with Midas they wait in the run's pot. They count as this run's coins (Coin of Deceit,
## unlocking consumables).
func mine_coins(amount: int) -> void:
	if amount <= 0:
		return
	_stat("coins", amount)
	if has_item("midas_touch") and trip_active:
		run_pot += amount
		run_changed.emit()
		save()
	else:
		if trip_active:
			run_earned += amount
		add_coins(amount)


## Rewards on everything (coins, ores, rocks, Draupnir sales): Death's Gambit x10, Sapphires Clover x2 per stage
## cleared, Rapid Fire x3.
func reward_mult() -> float:
	if not trip_active:
		return 1.0
	return pow(Config.GAMBIT_REWARD, item_count("deaths_gambit")) * clover_reward() * pow(Config.RAPID_FIRE_REWARD, item_count("rapid_fire"))


## Sapphires Clover: rewards x CLOVER_REWARD for every stage cleared while you hold it (a Copy / Catto on it: again).
func clover_reward() -> float:
	return pow(Config.CLOVER_REWARD, clover_stages * item_count("sapphires_clover"))


## Sapphires Clover: the mine x CLOVER_HARDER harder for every stage cleared while you hold it.
func clover_harder() -> float:
	return pow(Config.CLOVER_HARDER, clover_stages * item_count("sapphires_clover"))


## Rapid Fire: how many times faster the mine runs.
func rapid_speed() -> float:
	return pow(Config.RAPID_FIRE_SPEED, item_count("rapid_fire")) if trip_active else 1.0


## The free Extra Wick: the artifact, or the Dice's 5-6 for this stage.
func has_extra_wick() -> bool:
	return trip_active and (has_item("extra_wick") or dice_wick_stage == stage)


## Dice of Dwarves' 3-4: walls on this stage need half the moves.
func half_walls() -> bool:
	return trip_active and dice_half_stage == stage


static func _short(v: float) -> String:
	return str(snappedf(v, 0.01)).trim_suffix(".0") if v < 1000.0 else str(roundi(v))


## Every artifact that multiplies the mine's coins: Golden Apple, Draupnir, Familiar Circle, Art of Peace,
## Mandrake and the rewards on everything (Death's Gambit, Sapphires Clover, Rapid Fire).
func artifact_coin_mult() -> float:
	if not trip_active:
		return 1.0
	var m := pow(Config.GOLDEN_APPLE_COINS, item_count("golden_apple"))
	if has_item("draupnir"):
		m *= Config.DRAUPNIR_COINS  # however many Draupnirs you hold
	m *= pow(Config.FAMILIAR_COINS, item_count("familiar_circle"))
	m *= pow(Config.ART_OF_PEACE_COINS, item_count("art_of_peace"))
	m *= pow(Config.MANDRAKE_BONUS, item_count("mandrake"))
	m *= reward_mult()
	return m


## Cash out (at a rest, or by leaving the mine with Back): the run's loot (and the pot) is yours for good, the
## run ends, and this cave starts again from stage 1 next time.
func cash_out() -> int:
	var got := run_pot
	coins += run_pot
	run_pot = 0
	trip_active = false
	stage = 1
	lives = max_lives()
	stage_walls = 0
	_clear_run()
	walls_need = roll_walls()
	changed.emit()
	save()
	return got


## The run is over right now (Little Light, a dropped lighter, the Dice's 12...): like running out of lives,
## minus the stage drop. The run's loot is lost (minus Minecart / Backpack).
func fail_run(reason: String) -> void:
	if not trip_active:
		return
	var before := run_loot()
	var loot := _lose_loot()
	_end_summary(reason, before, loot)
	trip_active = false
	lives = max_lives()
	stage_walls = 0
	_clear_run()
	var lt := _loot_text(loot)
	item_used.emit("", reason + ("\n" + lt if lt != "" else ""))
	trip_over.emit()
	changed.emit()
	save()


## The part of the run's loot Minecart / Backpack / the Strongbox upgrade save if the run is lost (they add up,
## never above all of it).
func loot_keep() -> float:
	return clampf(Config.MINECART_KEEP * item_count("minecart") + Config.BACKPACK_KEEP * item_count("backpack")
			+ upgrade_value("strongbox") / 100.0, 0.0, 1.0)


## The run was lost: everything it gave you is taken back - its coins (and a Midas pot), ores and rocks - except
## the part Minecart / Backpack save. Only what you still have can be taken (rocks the Pet Rock ate are gone).
## Returns what was lost, for the pop-up: {coins, ores, rocks, keep}.
func _lose_loot() -> Dictionary:
	var keep := loot_keep()
	var lose := 1.0 - keep
	var lost_coins := mini(roundi(run_earned * lose), coins)
	coins -= lost_coins
	var pot_lost := roundi(run_pot * lose)
	coins += run_pot - pot_lost
	lost_coins += pot_lost
	var lost_ores := 0
	for oid in run_ores:
		var n := mini(roundi(int(run_ores[oid]) * lose), int(ores.get(oid, 0)))
		if n > 0:
			ores[oid] = int(ores[oid]) - n
			if ores[oid] <= 0:
				ores.erase(oid)
			lost_ores += n
	var lost_rocks := 0
	for rid in run_rocks:
		var n := mini(roundi(int(run_rocks[rid]) * lose), int(rocks.get(rid, 0)))
		if n > 0:
			rocks[rid] = int(rocks[rid]) - n
			if rocks[rid] <= 0:
				rocks.erase(rid)
			lost_rocks += n
	run_pot = 0
	run_earned = 0
	run_ores = {}
	run_rocks = {}
	return {"coins": lost_coins, "ores": lost_ores, "rocks": lost_rocks, "keep": keep}


## What the run's loot is worth right now, for the break's panel: {coins, ores, rocks}.
func run_loot() -> Dictionary:
	var o := 0
	for k in run_ores:
		o += int(run_ores[k])
	var r := 0
	for k in run_rocks:
		r += int(run_rocks[k])
	return {"coins": run_earned + run_pot, "ores": o, "rocks": r}


func _loot_text(l: Dictionary) -> String:
	if int(l.coins) + int(l.ores) + int(l.rocks) <= 0:
		return ""
	var parts: Array = []
	if int(l.coins) > 0:
		parts.append("%d coins" % l.coins)
	if int(l.ores) > 0:
		parts.append("%d ores & gems" % l.ores)
	if int(l.rocks) > 0:
		parts.append("%d rocks" % l.rocks)
	var t := "the run's loot is lost: " + ", ".join(parts)
	if float(l.keep) > 0.0:
		t += "  (you saved %d%%)" % roundi(float(l.keep) * 100.0)
	return t


## Great Ham: +GREAT_HAM_LIVES lives (never above this stage's lives), then it's gone. Returns the lives gained.
func eat_ham() -> float:
	if not trip_active or not run_items.has("great_ham") or lives >= max_lives():
		return 0.0
	var before := lives
	lives = minf(lives + Config.GREAT_HAM_LIVES, max_lives())
	use_up("great_ham")
	changed.emit()
	save()
	return lives - before


## Pet Rock: the rocks from your bag it would eat for one life (cheapest first, until they're worth
## PET_ROCK_PRICE at today's prices). Empty = your bag isn't worth that much.
func pet_rock_meal() -> Dictionary:
	var meal := {}
	var worth := 0
	for rid in rocks_by_price():
		var have := int(rocks.get(rid, 0))
		while have > 0 and worth < Config.PET_ROCK_PRICE:
			meal[rid] = int(meal.get(rid, 0)) + 1
			worth += rock_price(rid)
			have -= 1
		if worth >= Config.PET_ROCK_PRICE:
			return meal
	return {}


## Pet Rock: eats the meal for +1 life (never above MAX_LIVES). After PET_ROCK_FEEDS feeds it's gone.
func feed_pet_rock() -> bool:
	if not trip_active or not run_items.has("pet_rock") or pet_feeds <= 0 or lives >= Config.MAX_LIVES:
		return false
	var meal := pet_rock_meal()
	if meal.is_empty():
		return false
	for rid in meal:
		rocks[rid] = int(rocks[rid]) - int(meal[rid])
		if rocks[rid] <= 0:
			rocks.erase(rid)
		if run_rocks.has(rid):  # eaten rocks can't be taken back again if the run is lost
			run_rocks[rid] = maxi(0, int(run_rocks[rid]) - int(meal[rid]))
	lives = minf(lives + 1.0, Config.MAX_LIVES)
	pet_feeds -= 1
	if pet_feeds <= 0:
		use_up("pet_rock")
		run_used["pet_rock"] = run_stages
	changed.emit()
	run_changed.emit()
	save()
	return true


## Dynamite: uses a charge. Returns false if there's none.
func use_dynamite() -> bool:
	if not has_item("dynamite") or dynamite <= 0:
		return false
	dynamite -= 1
	run_changed.emit()
	save()
	return true


## Ram: one use breaks RAM_WALLS walls (this one included). After RAM_USES it's gone.
func use_ram() -> bool:
	if not run_items.has("ram") or ram_uses <= 0:
		return false
	ram_uses -= 1
	stage_walls = mini(stage_walls + Config.RAM_WALLS - 1, walls_need - 1)  # the crash itself breaks the last one
	if ram_uses <= 0:
		use_up("ram")
	run_changed.emit()
	save()
	return true


## Coin of Deceit: heads doubles this run's coins (and a Midas pot), tails loses them. Returns true on heads.
func flip_coin() -> bool:
	var heads := randf() < 0.5
	if heads:
		coins += run_earned
		run_earned *= 2
		run_pot *= 2
	else:
		coins = maxi(0, coins - run_earned)
		run_earned = 0
		run_pot = 0
	changed.emit()
	run_changed.emit()
	save()
	return heads


## Dwarven Hands: a finished move may shake loose an ore / gem. Higher stages lean to the rarer ones;
## the more walls you've broken this stage, the more you get. Returns ore id -> amount (or empty).
func dwarven_drop() -> Dictionary:
	var hands := item_count("dwarven_hands")
	if hands <= 0 or randf() * 100.0 >= Config.DWARVEN_HANDS_CHANCE:
		return {}
	var k := clampf(1.3 - 0.08 * (stage - 1), 0.3, 1.3)
	var pool := {}
	for oid in Config.ORES:
		pool[oid] = 1.0 / pow(float(Config.ORES[oid].sell_price), k)
	var oid := _weighted_pick(pool)
	var n := roundi((1 + stage_walls) * hands * reward_mult())
	gain_ore(oid, n)
	changed.emit()
	save()
	return {oid: n}


## Rocks a finished move digs up: Ring of Luck / Drill / Excavator / Miner's Permit (any rock), and the
## Philosopher's Stone (Pebbles = your combo, never more than PHILOSOPHERS_MAX a move - however many stones
## you hold or what multiplies your rewards). Returns rock id -> amount (Molerats may eat them: see give_rocks).
func move_rocks(combo: int) -> Dictionary:
	var got := {}
	for art in Config.ROCK_ARTIFACTS:
		for k in item_count(art):
			if randf() * 100.0 < float(Config.ROCK_ARTIFACTS[art]):
				var rid := _random_rock()
				got[rid] = int(got.get(rid, 0)) + 1
	if not got.is_empty() and reward_mult() > 1.0:
		for rid in got:
			got[rid] = roundi(got[rid] * reward_mult())
	if has_item("philosophers_stone"):
		var stones := mini(roundi(item_count("philosophers_stone") * maxi(combo, 1) * maxf(reward_mult(), 1.0)), Config.PHILOSOPHERS_MAX)
		got["rock_02"] = int(got.get("rock_02", 0)) + stones
	return got


## Rocks you found go in your bag - unless you have Molerats: they eat them and pay MOLERATS_PAY x what
## they're worth (each Molerats x that again). Returns the coins they paid (0 = the rocks are in your bag).
func give_rocks(found: Dictionary) -> int:
	if found.is_empty():
		return 0
	if has_item("mandrake"):  # +20% rocks (the odd fraction is a chance at one more)
		var m := pow(Config.MANDRAKE_BONUS, item_count("mandrake"))
		for rid in found:
			var f := float(found[rid]) * m
			found[rid] = floori(f) + (1 if randf() < f - floorf(f) else 0)
	if has_item("molerats"):
		var worth := 0
		for rid in found:
			worth += rock_price(rid) * int(found[rid])
		var paid := roundi(worth * pow(Config.MOLERATS_PAY, item_count("molerats")))
		coins += paid
		if trip_active:
			run_earned += paid
		changed.emit()
		save()
		return paid
	for rid in found:
		rocks[rid] = int(rocks.get(rid, 0)) + int(found[rid])
		if trip_active:
			run_rocks[rid] = int(run_rocks.get(rid, 0)) + int(found[rid])
	changed.emit()
	save()
	return 0


## Ores the mine gives you (on a run they're at stake until you cash out).
func gain_ore(oid: String, n: int) -> void:
	if n <= 0:
		return
	ores[oid] = int(ores.get(oid, 0)) + n
	if trip_active:
		run_ores[oid] = int(run_ores.get(oid, 0)) + n


## Dice of Dwarves, rolled at every stage cleared (Game.stage is already the next stage):
## 2 every rock, 3-4 half-move walls next stage, 5-6 a free Extra Wick next stage, 7-8 a random rock,
## 9-10 DICE_COINS coins, 11 skip a stage, 12 the run is over (wall_cleared ends it). Returns the pop-up text.
const DICE_END_TEXT := "The run is OVER!"


func roll_dice() -> String:
	var a := randi_range(1, 6)
	var b := randi_range(1, 6)
	var t := a + b
	var head := "DICE OF DWARVES: %d + %d = %d!  " % [a, b, t]
	if t == 2:
		var all := {}
		for rid in Config.ROCKS:
			all[rid] = roundi(reward_mult())
		var paid := give_rocks(all)
		return head + ("Snake eyes - every rock in the game!" if paid == 0 else "Snake eyes - every rock, the Molerats paid %d" % paid)
	if t <= 4:
		dice_half_stage = stage
		return head + "Walls need half the moves this stage!"
	if t <= 6:
		dice_wick_stage = stage
		return head + "A free Extra Wick this stage!"
	if t <= 8:
		var rid := _random_rock()
		var got := {rid: roundi(reward_mult())}
		var paid := give_rocks(got)
		return head + ("+%d %s" % [_sum(got), rock_name(rid)] if paid == 0 else "A rock - the Molerats paid %d" % paid)
	if t <= 10:
		var c := roundi(randi_range(Config.DICE_COINS.x, Config.DICE_COINS.y) * reward_mult())
		mine_coins(c)
		return head + "+%d coins!" % c
	if t == 11:
		stage += 1
		best_stage = maxi(best_stage, stage)
		run_stages += 1
		stage_walls = 0
		walls_need = roll_walls()
		return head + "Skipped ahead to Stage %d!" % stage
	return head + DICE_END_TEXT


func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


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


func set_practice_bpm(v: float) -> void:
	practice_bpm = clampf(v, Config.HEART_REST_BPM, Config.HEART_STRESS_BPM)
	save()


func set_beat_practice(on: bool) -> void:
	beat_practice = on
	changed.emit()
	save()


func set_color_circles(on: bool) -> void:
	color_circles = on
	changed.emit()
	save()


## Artifacts that were renamed: old saves still hold the old id.
const RENAMED_ITEMS := {"hot_hands": "sapphires_clover"}


func _renamed_item(id) -> Variant:
	return RENAMED_ITEMS.get(id, id)


func set_tutorial_done() -> void:
	tutorial_done = true
	save()


## % chance (per roll) that this rock gives this ore: its "drops" entry (0 if it's not one of this rock's
## ores), times your Favor upgrade, times LUCK.
func drop_chance(rock_id: String, ore_id: String) -> float:
	var d: Array = Config.ROCKS.get(rock_id, {}).get("drops", {}).get(ore_id, [])
	if d.is_empty():
		return 0.0
	var chance := float(d[0]) * (1.0 + upgrade_value("jewelers_favor" if is_gem(ore_id) else "miners_favor") / 100.0)
	return minf(chance * Config.LUCK_MULTIPLIER, 100.0)


func drop_amount(rock_id: String, ore_id: String) -> Vector2i:
	var d: Array = Config.ROCKS.get(rock_id, {}).get("drops", {}).get(ore_id, [])
	return Vector2i(int(d[1]), int(d[2])) if d.size() >= 3 else Vector2i(1, 1)


## The rocks that can give this ore.
func rocks_with(ore_id: String) -> Array:
	return rocks_by_price().filter(func(rid): return Config.ROCKS[rid].get("drops", {}).has(ore_id))


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
		for ore_id in Config.ROCKS[id].get("drops", {}):
			if not Config.ORES.has(ore_id):
				push_error("Config: rock '%s' drops an unknown ore '%s' (add it to ORES)" % [id, ore_id])
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
	cfg.set_value("game", "shop_window", shop_window)
	cfg.set_value("game", "shop_bought", shop_bought)
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
	cfg.set_value("dwarves", "tickets", tickets)
	cfg.set_value("dwarves", "free_ticket_at", free_ticket_at)
	cfg.set_value("dwarves", "trip_active", trip_active)
	cfg.set_value("run", "items", run_items)
	cfg.set_value("run", "slots", run_slots)
	cfg.set_value("dwarves", "rebirths", rebirths)
	cfg.set_value("run", "greed_done", run_greed_done)
	cfg.set_value("run", "offer", item_offer)
	cfg.set_value("run", "dynamite", dynamite)
	cfg.set_value("run", "midas", midas)
	cfg.set_value("run", "midas_moves", midas_moves)
	cfg.set_value("run", "pot", run_pot)
	cfg.set_value("run", "stacks", run_stacks)
	cfg.set_value("run", "earned", run_earned)
	cfg.set_value("run", "used", run_used)
	cfg.set_value("run", "stages", run_stages)
	cfg.set_value("run", "ram", ram_uses)
	cfg.set_value("run", "swapped", run_swapped)
	cfg.set_value("run", "loot_ores", run_ores)
	cfg.set_value("run", "loot_rocks", run_rocks)
	cfg.set_value("run", "clover_stages", clover_stages)
	cfg.set_value("run", "dice_half_stage", dice_half_stage)
	cfg.set_value("run", "dice_wick_stage", dice_wick_stage)
	cfg.set_value("run", "pet_feeds", pet_feeds)
	cfg.set_value("run", "stats", run_stats)
	cfg.set_value("dwarves", "upgrades", upgrades)
	cfg.set_value("prefs", "show_hints", show_hints)
	cfg.set_value("prefs", "tips_seen", tips_seen)
	cfg.set_value("prefs", "show_tips", show_tips)
	cfg.set_value("prefs", "color_circles", color_circles)
	cfg.set_value("prefs", "beat_practice", beat_practice)
	cfg.set_value("prefs", "practice_bpm", practice_bpm)
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
	shop_window = int(cfg.get_value("game", "shop_window", -1))
	shop_bought = cfg.get_value("game", "shop_bought", {})
	restock_at = cfg.get_value("game", "restock_at", 0.0)
	current_rock = cfg.get_value("game", "current_rock", "")
	if not Config.ROCKS.has(current_rock):
		current_rock = ""
	rocks_broken = cfg.get_value("game", "rocks_broken", 0)
	tutorial_done = cfg.get_value("game", "tutorial_done", false)
	upgrades = {}  # (loaded first: Pack of Fluid sets how many lives you can have)
	rebirths = clampi(int(cfg.get_value("dwarves", "rebirths", 0)), 0, Config.REBIRTH_MAX)
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
	show_hints = cfg.get_value("prefs", "show_hints", true)
	show_tips = cfg.get_value("prefs", "show_tips", true)
	color_circles = cfg.get_value("prefs", "color_circles", true)
	beat_practice = cfg.get_value("prefs", "beat_practice", true)
	practice_bpm = clampf(float(cfg.get_value("prefs", "practice_bpm", Config.HEART_REST_BPM)), Config.HEART_REST_BPM, Config.HEART_STRESS_BPM)
	tips_seen = {}
	var ts = cfg.get_value("prefs", "tips_seen", null)
	if ts is Dictionary:
		tips_seen = ts
	elif tutorial_done:  # a save from the old tutorial: it already explained the basics
		for id in BASIC_TIPS:
			tips_seen[id] = true
	var tk = cfg.get_value("dwarves", "tickets", Config.START_TICKETS)
	if tk is Dictionary:
		tickets = _known(tk, Config.CAVES)
	else:  # saves from before caves: a plain number = tickets for the first cave
		tickets = {}
		if int(tk) > 0:
			tickets[first_cave()] = int(tk)
	free_ticket_at = minf(float(cfg.get_value("dwarves", "free_ticket_at", 0.0)), now() + Config.FREE_TICKET_SECONDS)
	trip_active = cfg.get_value("dwarves", "trip_active", false)
	var items_in: Array = Array(cfg.get_value("run", "items", [])).map(_renamed_item)
	var stacks_in: Array = cfg.get_value("run", "stacks", [])
	run_items = []
	run_stacks = []
	for i in items_in.size():
		if Config.ITEMS.has(items_in[i]):
			run_items.append(items_in[i])
			run_stacks.append(clampi(int(stacks_in[i]) if i < stacks_in.size() else 1, 1, int(Config.ITEMS[items_in[i]].get("stack", 1))))
	run_earned = maxi(0, int(cfg.get_value("run", "earned", 0)))
	run_used = cfg.get_value("run", "used", {})
	run_stages = int(cfg.get_value("run", "stages", 0))
	ram_uses = int(cfg.get_value("run", "ram", 0))
	run_swapped = {}
	var sw: Dictionary = cfg.get_value("run", "swapped", {})
	for k in sw:
		run_swapped[_renamed_item(k)] = sw[k]
	run_ores = _known(cfg.get_value("run", "loot_ores", {}), Config.ORES)
	run_rocks = _known(cfg.get_value("run", "loot_rocks", {}), Config.ROCKS)
	clover_stages = maxi(0, int(cfg.get_value("run", "clover_stages", cfg.get_value("run", "hot_stages", 0))))  # (0.7.1 and older: "hot_stages")
	dice_half_stage = int(cfg.get_value("run", "dice_half_stage", -1))
	dice_wick_stage = int(cfg.get_value("run", "dice_wick_stage", -1))
	pet_feeds = clampi(int(cfg.get_value("run", "pet_feeds", 0)), 0, Config.PET_ROCK_FEEDS)
	var st = cfg.get_value("run", "stats", {})
	run_stats = st if st is Dictionary and not st.is_empty() else _new_stats()
	run_slots = maxi(base_slots(), int(cfg.get_value("run", "slots", base_slots())))
	run_greed_done = cfg.get_value("run", "greed_done", false)
	item_offer = Array(cfg.get_value("run", "offer", [])).map(_renamed_item).filter(func(i): return Config.ITEMS.has(i))
	dynamite = clampi(int(cfg.get_value("run", "dynamite", 0)), 0, Config.DYNAMITE_MAX)
	midas = clampf(float(cfg.get_value("run", "midas", 1.0)), 1.0, Config.MIDAS_MAX)
	midas_moves = int(cfg.get_value("run", "midas_moves", 0))
	run_pot = maxi(0, int(cfg.get_value("run", "pot", 0)))
	# prices and the shelf come from the clock, the same for everyone (saved ones aren't used)
	var keep_window := shop_window
	shop_window = -1
	refresh_shop()
	if shop_window == keep_window:  # same restock as when you last played: keep what you bought / paid for
		restock_buys = maxi(0, int(cfg.get_value("game", "restock_buys", 0)))
		shop_bought = cfg.get_value("game", "shop_bought", {})
		_build_shelf()
	return true


## Drops entries you removed from Config so an old save can't crash the game.
func _known(d: Dictionary, table: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		if table.has(k) and int(d[k]) > 0:
			out[k] = int(d[k])
	return out
