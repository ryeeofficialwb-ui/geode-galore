class_name Config
## ====================================================================================
##  GEODE GALORE - GAME SETTINGS
##  Every line marked "# configurable" is safe to change. Save the file and press Play.
##  Chances are in PERCENT (0 - 100). Times are in SECONDS. Prices are in COINS.
##
##  NOTE: starting coins / rocks only apply to a NEW save. While you are tweaking,
##  set RESET_SAVE_ON_START = true (or press "Reset" in the game) to start fresh.
## ====================================================================================


# ------------------------------------------------------------------ BREAKING ROCKS
## How many clicks a rock takes. A random number between MIN and MAX (inclusive) is picked
## for every rock. A rock in ROCKS below can override this with its own "hits_min"/"hits_max".
const HITS_MIN := 3  # configurable
const HITS_MAX := 5  # configurable

## Global luck: every drop chance is multiplied by this. 2.0 = twice as likely. (capped at 100%)
const LUCK_MULTIPLIER := 1.0  # configurable

## After a rock breaks, the next rock of the same type is placed automatically (if you own one).
const AUTO_NEXT_ROCK := true  # configurable
const NEXT_ROCK_DELAY := 0.9  # configurable  (seconds before the next rock appears)


# ------------------------------------------------------------------ CRACKS (look & feel)
## Procedural cracks are drawn into the rock's own pixels each time you hit it.
## Want hand-drawn cracks instead? Put  assets/rocks/<rock id>_crack_1.png, _crack_2.png ...
## next to the rock (same size as the rock PNG). See README.md.
const CRACK_COLOR := Color("#2E222F")  # configurable  (dark crack pixels)
const CRACK_EDGE_COLOR := Color("#7F708A")  # configurable  (light pixel beside a crack; set alpha 0 to disable)
const CRACKS_PER_HIT := 2  # configurable  (how many crack lines each hit adds)
const CRACK_LENGTH_MIN := 3  # configurable  (in rock pixels)
const CRACK_LENGTH_MAX := 7  # configurable
const CRACK_ART_STAGES := 3  # configurable  (how many hand-drawn crack images per rock, if you make them)


# ------------------------------------------------------------------ ROCK DISPLAY & JUICE
const ROCK_DISPLAY_SIZE := 288  # configurable  (on-screen size of the rock in px; art is scaled up pixel-perfect)
const SHAKE_STRENGTH := 7.0  # configurable  (px the rock jiggles per hit)
const SQUASH_AMOUNT := 0.08  # configurable  (how much the rock squishes per hit, 0 = none)
const CHIPS_PER_HIT := 7  # configurable  (little stone bits flying off each hit)
const CHIPS_ON_BREAK := 30  # configurable
const CHIP_GRAVITY := 1400.0  # configurable
const BREAK_PIECES := 4  # configurable  (rock splits into N x N chunks when it breaks; 2 = 4 chunks)
const SCREEN_SHAKE_ON_BREAK := 10.0  # configurable


# ------------------------------------------------------------------ ECONOMY
const START_COINS := 50  # configurable
## rock id -> how many you start with
const START_ROCKS := {"rock_02": 3}  # configurable


# ------------------------------------------------------------------ SHOP  (limited stock)
## The shop shows SHOP_SLOTS random rock types. Each slot has a random stock between
## STOCK_MIN and STOCK_MAX. When the timer runs out, the whole shop is re-rolled.
const SHOP_SLOTS := 4  # configurable
const STOCK_MIN := 1  # configurable
const STOCK_MAX := 5  # configurable
const RESTOCK_SECONDS := 300.0  # configurable

# ------------------------------------------------------------------ MARKET  (supply & demand)
## Every time the shop restocks on its timer (RESTOCK_SECONDS), demand shifts: every rock's shop price
## and every ore / gem's sell price moves up or down from where it was. It drifts back towards normal
## over time and can never leave MARKET_MIN..MARKET_MAX of the price in the tables below.
## (Paying to restock early gives new rocks but does NOT move the market.)
const MARKET_MIN := 0.1  # configurable  (10% of the normal price at the lowest)
const MARKET_MAX := 2.0  # configurable  (200% of the normal price at the highest)
const MARKET_SWING := 0.3  # configurable  (how far a price can jump per restock; 0 = prices never change)
const MARKET_PULL := 0.2  # configurable  (0 - 1: how strongly prices drift back to normal each restock)
## Green = good for you, red = bad. Ores & gems: a price ABOVE normal is green (you sell for more).
## Rocks: a price BELOW normal is green (cheaper to buy) and above normal is red.
const MARKET_GOOD_COLOR := Color("#91db69")  # configurable
const MARKET_BAD_COLOR := Color("#f68181")  # configurable
## Allow the same rock type in two slots at once?
const ALLOW_DUPLICATE_SLOTS := false  # configurable
## Pay to restock right now. Set to -1 to hide the button.
const INSTANT_RESTOCK_COST := 25  # configurable


# ------------------------------------------------------------------ DWARVEN SHOP  (tickets & upgrades)
## You need a TICKET to go down the mine (the mining wall). One ticket = one trip: it lasts until you
## run out of lives (then you're sent back up). Going Back to your rocks doesn't end the trip.
## Every CAVE (see CAVES below) has its own tickets. The free ticket is always for the first cave.
const TICKET_PRICE := 100  # configurable  (coins, a ticket for the first cave)
const FREE_TICKET_SECONDS := 600.0  # configurable  (a free ticket can be claimed this often: 600 = every 10 minutes)
const START_TICKETS := 0  # configurable  (first-cave tickets in a new game; it can also claim its first free ticket straight away)

## CAVES: the mines you can go down. Each needs its own ticket and keeps its own stage (checkpoint).
## They're listed in the Shop's "Caves" tab in this order. The first one is where free tickets go.
##   name          shown in the game
##   tile          the wall tile (32 x 32, repeated over the wall). Cut from art_source/cave_sheet.png
##   ticket_price  coins for one ticket
##   coins         x coins you earn down there
##   fuel          how long your light lasts compared to the first cave (0.8 = fades 20% faster)
##   stone_chance  % chance that clearing a stage finds a rock (any rock type) for your bag
const CAVES := {  # configurable (whole table)
	"old_mine": {"name": "Old Mine", "tile": "res://assets/wall/wall_tile.png", "ticket_price": TICKET_PRICE, "coins": 1.0, "fuel": 1.0, "stone_chance": 1.0},
	"shale_hollow": {"name": "Shale Hollow", "tile": "res://assets/wall/shale_hollow.png", "ticket_price": 250, "coins": 1.4, "fuel": 0.95, "stone_chance": 1.8},
	"crimson_deep": {"name": "Crimson Deep", "tile": "res://assets/wall/crimson_deep.png", "ticket_price": 600, "coins": 1.9, "fuel": 0.9, "stone_chance": 2.6},
	"blackrock_tunnels": {"name": "Blackrock Tunnels", "tile": "res://assets/wall/blackrock_tunnels.png", "ticket_price": 1400, "coins": 2.6, "fuel": 0.85, "stone_chance": 3.4},
	"magma_veins": {"name": "Magma Veins", "tile": "res://assets/wall/magma_veins.png", "ticket_price": 3000, "coins": 3.5, "fuel": 0.8, "stone_chance": 4.2},
	"crystal_grotto": {"name": "Crystal Grotto", "tile": "res://assets/wall/crystal_grotto.png", "ticket_price": 6500, "coins": 4.75, "fuel": 0.75, "stone_chance": 5.0},
}
## Rocks found in caves: true = every rock type is as likely as any other; false = they follow shop_weight
## (cheap rocks more often).
const CAVE_STONE_ANY_EQUAL := true  # configurable
## Upgrades. Level 1 gives "first", the last level gives exactly "max"; the levels in between follow a
## smooth curve (so each level of Miner's Favor adds a bit less than the one before).
##   name / text   shown in the shop ("text" says what the number is)
##   first / max   the bonus at level 1 / at the last level (percent)
##   levels        how many times it can be bought
##   cost          coins for level 1; every level costs cost_growth times more than the one before
##   art: assets/ui/upgrades/<id>.png (placeholders made by tools/make_ui.py)
const UPGRADES := {  # configurable (whole table)
	"miners_favor": {"name": "Miner's Favor", "text": "ore chance", "first": 1.0, "max": 90.0, "levels": 250, "cost": 40, "cost_growth": 1.022},
	"jewelers_favor": {"name": "Jeweler's Favor", "text": "gem chance", "first": 1.0, "max": 90.0, "levels": 250, "cost": 60, "cost_growth": 1.022},
	"rocky_riches": {"name": "Rocky Riches", "text": "ores per drop", "first": 0.25, "max": 200.0, "levels": 250, "cost": 50, "cost_growth": 1.022},  # max +200% = x3 ores (gems don't count)
	"digging_expert": {"name": "Digging Expert", "text": "coins in the mine", "first": 2.5, "max": 400.0, "levels": 250, "cost": 30, "cost_growth": 1.022},
	"fools_gold": {"name": "Fool's Gold", "text": "chance to sell for more", "first": 0.2, "max": 20.0, "levels": 250, "cost": 75, "cost_growth": 1.022},
	"heat_of_the_forge": {"name": "Heat of the Forge", "text": "light per lighter flick", "first": 0.04, "max": 10.0, "levels": 250, "cost": 60, "cost_growth": 1.022},
	## Pack of Fluid: the value is extra LIVES (not %), counted in half lives: 20 levels for +2 lives = half a life
	## every 5 levels, so 3 + 2 = 5 lives at max. Lives never go above MAX_LIVES (5) no matter what.
	"pack_of_fluid": {"name": "Pack of Fluid", "text": "lives every stage", "first": 0.1, "max": 2.0, "levels": 20, "cost": 2500, "cost_growth": 1.25},
	"silktouch": {"name": "Silktouch", "text": "chance a rock doesn't break", "first": 0.08, "max": 20.0, "levels": 250, "cost": 120, "cost_growth": 1.022},
	"ticket_hungry": {"name": "Ticket Hungry", "text": "chance of a ticket per stage cleared", "first": 0.1, "max": 3.0, "levels": 50, "cost": 150, "cost_growth": 1.08},
}
const FOOLS_GOLD_BONUS := 15.0  # configurable  (% extra a Fool's Gold sale pays)
const FOOLS_GOLD_GEMS := true  # configurable  (false = Fool's Gold only works when selling ores, not gems)


# ------------------------------------------------------------------ ROCK TYPES
## id: also the file name -> assets/rocks/<id>.png
##   name        shown in the game
##   price       base shop price (coins)
##   shop_weight how often it shows up in the shop compared to others (bigger = more common, 0 = never)
##   hits_min / hits_max   (optional) override HITS_MIN / HITS_MAX for this rock
##   rolls       how many times the drops are rolled when it breaks
##   quality     0 - 1: where this rock sits between the cheapest (0) and the best (1) rocks. EVERY rock can
##               drop EVERY ore and gem; quality slides each ore's chance between its two numbers in ORES
##               ("chance": [cheapest, best]), so better rocks lean towards the valuable stuff.
##   bonus       (optional) ore id -> chance multiplier: this rock's speciality (2.0 = twice as likely)
##   drops       (optional, advanced) ore id -> {chance: %, min, max}: replaces that ore's chance and amount
##               for this rock completely.
## Every ore is rolled on its own each roll, so one rock can give several ores (or nothing).
## tools/tune_drops.py can re-balance qualities so each rock is worth about its price.
const ROCKS := {  # configurable (whole table)
	"rock_02": {"name": "Pebble", "price": 8, "shop_weight": 40, "hits_min": 2, "hits_max": 3, "rolls": 1, "quality": 0.0},
	"rock_10": {"name": "Round Stone", "price": 12, "shop_weight": 35, "rolls": 1, "quality": 0.05},
	"rock_05": {"name": "Shard Rock", "price": 15, "shop_weight": 30, "rolls": 1, "quality": 0.11, "bonus": {"peridot": 2.0}},
	"rock_04": {"name": "Lumpy Rock", "price": 18, "shop_weight": 28, "rolls": 1, "quality": 0.18, "bonus": {"jade": 1.5}},
	"rock_06": {"name": "Knobby Rock", "price": 22, "shop_weight": 24, "rolls": 1, "quality": 0.27, "bonus": {"rhodonite": 2.0}},
	"rock_07": {"name": "Crag", "price": 26, "shop_weight": 20, "rolls": 1, "quality": 0.35, "bonus": {"gold": 1.5, "topaz": 1.5}},
	"rock_09": {"name": "Rubble Pile", "price": 30, "shop_weight": 18, "rolls": 2, "quality": 0.08, "bonus": {"lead": 1.5, "copper": 1.5}},
	"rock_01": {"name": "Boulder", "price": 40, "shop_weight": 14, "hits_min": 4, "hits_max": 6, "rolls": 2, "quality": 0.23, "bonus": {"silver": 1.5}},
	"rock_03": {"name": "Big Boulder", "price": 60, "shop_weight": 8, "hits_min": 5, "hits_max": 7, "rolls": 2, "quality": 0.45, "bonus": {"sapphire": 1.5, "ruby": 1.5}},
	"rock_08": {"name": "Twin Stones", "price": 90, "shop_weight": 4, "hits_min": 5, "hits_max": 8, "rolls": 3, "quality": 0.42, "bonus": {"emerald": 3.0}},
	"rock_14": {"name": "Cobblestone", "price": 10, "shop_weight": 36, "hits_min": 2, "hits_max": 4, "rolls": 1, "quality": 0.0, "bonus": {"zinc": 2.5}},
	"rock_13": {"name": "Dome Rock", "price": 20, "shop_weight": 26, "rolls": 1, "quality": 0.17, "bonus": {"zinc": 2.0, "iron": 1.5}},
	"rock_15": {"name": "Notched Rock", "price": 24, "shop_weight": 22, "rolls": 1, "quality": 0.3, "bonus": {"zinc": 1.5, "jade": 1.5}},
	"rock_16": {"name": "Chipped Block", "price": 34, "shop_weight": 16, "rolls": 2, "quality": 0.15, "bonus": {"onyx": 2.0}},
	"rock_12": {"name": "Tall Egg", "price": 45, "shop_weight": 12, "hits_min": 4, "hits_max": 6, "rolls": 2, "quality": 0.28, "bonus": {"uranium": 2.0}},
	"rock_17": {"name": "Clump", "price": 50, "shop_weight": 11, "hits_min": 4, "hits_max": 6, "rolls": 2, "quality": 0.33, "bonus": {"uranium": 1.5, "zinc": 1.5}},
	"rock_18": {"name": "Tower Rock", "price": 70, "shop_weight": 7, "hits_min": 5, "hits_max": 7, "rolls": 3, "quality": 0.29, "bonus": {"uranium": 2.0, "onyx": 1.5}},
	"rock_19": {"name": "Saddle Rock", "price": 80, "shop_weight": 6, "hits_min": 5, "hits_max": 7, "rolls": 3, "quality": 0.36, "bonus": {"onyx": 2.0, "dreamstone": 1.5}},
	"rock_11": {"name": "Egg Boulder", "price": 110, "shop_weight": 4, "hits_min": 6, "hits_max": 8, "rolls": 3, "quality": 0.59, "bonus": {"dreamstone": 2.0}},
	"rock_20": {"name": "Wedge Rock", "price": 150, "shop_weight": 2, "hits_min": 7, "hits_max": 9, "rolls": 3, "quality": 0.83, "bonus": {"dreamstone": 2.0, "onyx": 1.5, "uranium": 1.5}},
}


# ------------------------------------------------------------------ ORE / GEM TYPES
## id: also the file name -> assets/ores/<id>.png   (cut from art_source/sheet_v2.png by tools/slice_sheets.py)
##   name        shown in the game
##   sell_price  coins you get for selling one, before the market (see MARKET_* above)
##   type        "ore" or "gem": Miner's Favor / Rocky Riches boost ores, Jeweler's Favor boosts gems
##   rare        true = sparkly sound + spin when it drops
##   color       used for the "+1 Ruby" pop-up text
##   chance      [% per roll in the cheapest rocks, % per roll in the best rocks] (see "quality" above)
##   amount      [min, max] you get when it drops
## The order here is the order in the Backpack.
const ORES := {  # configurable (whole table)
	"lead": {"name": "Lead", "sell_price": 4, "type": "ore", "rare": false, "color": Color("#a99ab5"), "chance": [32.0, 10.0], "amount": [1, 2]},
	"copper": {"name": "Copper", "sell_price": 6, "type": "ore", "rare": false, "color": Color("#e8925f"), "chance": [22.0, 12.0], "amount": [1, 1]},
	"iron": {"name": "Iron", "sell_price": 8, "type": "ore", "rare": false, "color": Color("#dcc6ba"), "chance": [15.0, 15.0], "amount": [1, 2]},
	"zinc": {"name": "Zinc", "sell_price": 11, "type": "ore", "rare": false, "color": Color("#8fd3c9"), "chance": [10.0, 14.0], "amount": [1, 2]},
	"rhodonite": {"name": "Rhodonite", "sell_price": 14, "type": "gem", "rare": false, "color": Color("#ec85a6"), "chance": [4.0, 12.0], "amount": [1, 1]},
	"rustvein": {"name": "Rustvein", "sell_price": 16, "type": "ore", "rare": false, "color": Color("#f57d4a"), "chance": [3.0, 13.0], "amount": [1, 2]},
	"stibnite": {"name": "Stibnite", "sell_price": 24, "type": "ore", "rare": false, "color": Color("#c7dcd0"), "chance": [2.0, 12.0], "amount": [1, 2]},
	"silver": {"name": "Silver", "sell_price": 20, "type": "ore", "rare": false, "color": Color("#dfe9ec"), "chance": [2.5, 16.0], "amount": [1, 1]},
	"jade": {"name": "Jade", "sell_price": 30, "type": "gem", "rare": false, "color": Color("#62cf9e"), "chance": [1.2, 11.0], "amount": [1, 1]},
	"gold": {"name": "Gold", "sell_price": 45, "type": "ore", "rare": false, "color": Color("#ffd84a"), "chance": [0.8, 12.0], "amount": [1, 1]},
	"peridot": {"name": "Peridot", "sell_price": 60, "type": "gem", "rare": true, "color": Color("#aee35c"), "chance": [0.2, 4.0], "amount": [1, 1]},
	"lapis": {"name": "Lapis", "sell_price": 120, "type": "gem", "rare": true, "color": Color("#4d9be6"), "chance": [0.1, 3.0], "amount": [1, 1]},
	"topaz": {"name": "Topaz", "sell_price": 250, "type": "gem", "rare": true, "color": Color("#ffb347"), "chance": [0.12, 3.5], "amount": [1, 1]},
	"uranium": {"name": "Uranium", "sell_price": 200, "type": "ore", "rare": true, "color": Color("#6cff5a"), "chance": [0.08, 3.0], "amount": [1, 1]},
	"amethyst": {"name": "Amethyst", "sell_price": 250, "type": "gem", "rare": true, "color": Color("#c690e6"), "chance": [0.08, 3.0], "amount": [1, 1]},
	"sapphire": {"name": "Sapphire", "sell_price": 250, "type": "gem", "rare": true , "color": Color("#6a98ff"), "chance": [0.05, 2.5], "amount": [1, 1]},
	"tourmaline": {"name": "Tourmaline", "sell_price": 200, "type": "gem", "rare": true, "color": Color("#ff8aa5"), "chance": [0.05, 2.2], "amount": [1, 1]},
	"ruby": {"name": "Ruby", "sell_price": 250, "type": "gem", "rare": true, "color": Color("#ff4a5e"), "chance": [0.04, 2.0], "amount": [1, 1]},
	"onyx": {"name": "Onyx", "sell_price": 100, "type": "gem", "rare": true, "color": Color("#b9b3cf"), "chance": [0.03, 1.8], "amount": [1, 1]},
	"obsidian": {"name": "Obsidian", "sell_price": 350, "type": "gem", "rare": true, "color": Color("#ae97ae"), "chance": [0.03, 1.6], "amount": [1, 1]},
	"emerald": {"name": "Emerald", "sell_price": 500, "type": "gem", "rare": true, "color": Color("#45e3c4"), "chance": [0.025, 1.5], "amount": [1, 1]},
	"zapperion": {"name": "Zapperion", "sell_price": 650, "type": "gem", "rare": true, "color": Color("#e2e679"), "chance": [0.02, 1.4], "amount": [1, 1]},
	"dreamstone": {"name": "Dreamstone", "sell_price": 1000, "type": "gem", "rare": true, "color": Color("#d9a6ff"), "chance": [0.015, 1.2], "amount": [1, 1]},
}


## Lore shown when you click an ore / gem in the Market & Guide (write your own!).
const ORE_LORE := {  # configurable
	"lead": "Soft, grey and heavy for its size. Miners use it for weights and sinkers, and nobody has ever bragged about finding it.",
	"copper": "The first metal people ever worked. It turns green with age, which the dwarves call 'getting wise'.",
	"iron": "The backbone of every pickaxe in the mine. Rusts if you so much as look at it wrong.",
	"zinc": "Brown nodules with a teal heart. Mixed with copper it becomes brass, the dwarves' favourite trim.",
	"rhodonite": "A rose-pink stone streaked with black veins. Said to calm a hot-tempered miner.",
	"rustvein": "Rock shot through with veins of rusted iron. Old miners say the red is the mountain bleeding.",
	"stibnite": "Needle-sharp silver crystals of antimony. Pretty, brittle, and poisonous to lick. Don't lick it.",
	"silver": "Bright, cool and quick to tarnish. Dwarven tales say it keeps the dark things of the deep away.",
	"jade": "A tough green stone, harder to break than steel. Carvers spend a lifetime on a single piece.",
	"gold": "Soft, heavy and it never rusts. Every miner's dream, and the reason most of them started digging.",
	"peridot": "An olive-green gem born deep under the crust and carried up by volcanoes. It's even been found in meteorites.",
	"lapis": "Deep blue flecked with golden pyrite, like a night sky in stone. Ground up, it made the bluest paint in history.",
	"topaz": "A warm golden gem that glows like honey in lamplight. Legend says it can cool boiling water.",
	"uranium": "Glowing green lumps that hum faintly in your backpack. Worth a lot. Don't keep it under your pillow.",
	"amethyst": "Purple quartz. Ancient drinkers carved cups from it, sure it would keep them sober. It didn't.",
	"sapphire": "Blue corundum, second only to diamond in hardness. Kings wore it to keep envy away.",
	"tourmaline": "A pink gem that charges up when it's warmed and pulls dust towards it. Some say it pulls luck too.",
	"ruby": "Red corundum, the king of gems. Old miners swore a ruby kept close made you unbreakable.",
	"onyx": "A black gem with faint pale bands. Polished, it's dark enough to see yourself in.",
	"obsidian": "Volcanic glass that cooled too fast to crystallise. Its edge is sharper than any steel blade.",
	"emerald": "Green beryl full of tiny flaws the jewellers call its 'garden'. A flawless one is rarer than a diamond.",
	"zapperion": "A yellow-green crystal that crackles when touched. Nobody knows what it is, but lamps flicker when it's near.",
	"dreamstone": "Lavender lumps found only in the deepest walls. Sleep beside one and you'll dream of veins of gold.",
}


# ------------------------------------------------------------------ MINING WALL  (left screen)
## Click the arrow on the left of the main screen to go to the wall. The wall asks for one
## ACTION at a time (tap, zigzag, slash, drill, pry). Finish it before the timer at the top runs
## out to keep your COMBO going; a bigger combo multiplies the coins you get.
## After a random number of actions the wall crumbles and a new one drops in.
const WALL_TILE_FILE := "res://assets/wall/wall_tile.png"  # configurable  (the tile repeated over the whole wall)
const WALL_TILE_SCALE := 3  # configurable  (32px tile x 3 = 96px on screen)
const WALL_ACTIONS_MIN := 4  # configurable  (actions needed to take the wall down: random MIN..MAX)
const WALL_ACTIONS_MAX := 8  # configurable
const WALL_RESPAWN_DELAY := 1.1  # configurable  (seconds the rubble falls before a new wall)
const SCREEN_SLIDE_TIME := 0.35  # configurable  (seconds to slide between screens)
const ACTION_GAP := 0.3  # configurable  (pause in seconds between two actions)

## How often each action shows up (bigger = more often, 0 = never).
const ACTION_WEIGHTS := {  # configurable
	"tap": 25,      # tap every ring on the wall
	"zigzag": 25,   # trace a zigzag line, like pickaxe swings
	"slash": 20,    # one big, fast swipe along a long line
	"drill": 15,    # spam-click the same spot
	"pry": 15,      # hold on the wedge, let go when the gauge is in the gold zone
}
const NO_REPEAT_ACTION := true  # configurable  (true = never the same action twice in a row)

# --- combo
## (Actions have no timer of their own any more: your lighter's light is the timer, see LIGHT_DURATION.)
const COMBO_BONUS_PER_STEP := 0.25  # configurable  (each combo step adds +25% coins: x1, x1.25, x1.5 ...)
const COMBO_MAX_MULTIPLIER := 5.0  # configurable  (coin multiplier never goes above this)
const COMBO_NEEDS_PERFECT := false  # configurable  (true = a non-perfect action also resets the combo)
const MISS_BREAKS_COMBO := false  # configurable  (true = any miss resets the combo, not just the timer)

# --- the lighter  (art in assets/lighter/, cut by tools/make_lighter.py)
## It's dark in the mine. You hold the lighter on the left like a torch. While it's lit the whole
## wall is lit, but the flame slowly fades (the wall gets darker in steps - that's your timer, there's
## no bar). Every flick of SPACE (or tap on the lighter) only adds a little light back, so keep flicking
## while you work. When it reaches full it flashes and burns steady for 3-10 s - flick it then and you
## FLOOD it: half a life gone. Flicks can't go above the WICK though (see below): finish the actions.
## If the light fades all the way you lose your combo and the lighter goes OUT.
## (Losing the combo another way - missing every circle - also puts it out.) Relight it:
## a marker sweeps back and forth along a track - hit SPACE while it's in the gold zone. Every good
## strike lowers the bar, but the marker gets faster and the zone smaller; a mistimed strike pushes
## the bar back up. Empty the bar within RELIGHT_TIME seconds or you lose a life.
const LIGHTER_DIR := "res://assets/lighter/"  # configurable  (lighter_0.png = closed ... lighter_N.png = open, flame.png)
const LIGHTER_SCALE := 5  # configurable  (art pixels -> screen pixels; 5 = big, close to you)
const LIGHTER_POS := Vector2(334, 180)  # configurable  (bottom of the flame: px from the LEFT edge, px up from the BOTTOM)
const LIGHTER_SWAY := Vector2(14, 12)  # configurable  (px the lighter leans towards your mouse; 0 = never moves)
const LIGHTER_GLOW_RADIUS := 300.0  # configurable  (px of extra light around the lighter itself)
const LIGHT_DURATION := 18.0  # configurable  (seconds for a full flame to fade out completely, at stage 1)
const LIGHT_STEPS := 6  # configurable  (the light fades in this many visible steps)
const RECHARGE_MIN := 3.0  # configurable  (% of light one flick adds back: random MIN..MAX - so you keep flicking)
const RECHARGE_MAX := 5.0  # configurable
const FLOOD_AT := 1.0  # configurable  (flicking during the steady full blaze floods it)
## TIMED FLICKS: the FLICK bar next to the lighter charges up; a flick only adds light while the bar is
## in its gold zone (near the top). Spam it (too soon) or wait too long (too late) and the flick fails:
## no light, and it burns FLICK_FAIL_WICK_COST of your wick. Every minigame has its own tempo, so some
## let you take your time (more light) and some are too fast to flick well (finish the action quickly).
##   kind -> [seconds for the bar to fill, size of the gold zone (part of the bar)]   ("" = between actions)
const FLICK_TEMPO := {  # configurable
	"": [0.9, 0.24],
	"tap": [0.5, 0.26],      # fast
	"zigzag": [1.1, 0.22],   # steady
	"slash": [0.36, 0.3],    # very fast
	"drill": [0.65, 0.24],   # quick
	"pry": [1.5, 0.18],      # slow, narrow zone
}
const FLICK_ZONE_END := 0.94  # configurable  (the gold zone ends here on the bar; above it is "too late")
## A slow bar means fewer flicks, so each good flick gives more light: hitting every flick brings the light
## back FLICK_GAIN times as fast as it fades, whatever the tempo (but never less than RECHARGE_MIN..MAX %).
const FLICK_GAIN := 1.8  # configurable  (1.0 = perfect flicking only just keeps up; higher = easier)
const FLICK_FAIL_WICK_COST := 0.06  # configurable  (wick a mistimed flick burns)
const FLICK_STAGE_SPEEDUP := 0.5  # configurable  (0 = same tempo every stage, 1 = speeds up as much as the light fades)
const FLICK_BAR_HEIGHT := 150.0  # configurable  (px)
const FLICK_BAR_GAP := 20.0  # configurable  (px between the lighter and the bar)
## The WICK: the most light your flicks can bring back. While an action is waiting on you it burns
## down (over WICK_TIME seconds from full to nothing), so flicking alone isn't enough: the wall gets
## darker and darker and when the wick is gone the lighter dies (combo lost). FINISHING an action is
## the only thing that restores it; sloppy motions (off the line, missed circle, stray click) burn some.
const WICK_TIME := 12.0  # configurable  (seconds an unfinished action takes to burn the whole wick, at stage 1)
const MISS_WICK_COST := 0.12  # configurable  (wick each miss burns off)
const WICK_GAUGE := true  # configurable  (show the wick next to the lighter)
const WICK_GAUGE_HEIGHT := 185.0  # configurable  (px)
const WICK_GAUGE_MARGIN := Vector2(26, 26)  # configurable  (px from the bottom-right corner of the screen)
## About to lose: the lighter trembles harder the closer you are.
const DANGER_AT := 0.3  # configurable  (it starts trembling when the wick or the light drops below this)
const DANGER_RELIGHT_SECONDS := 2.0  # configurable  (... or in the last this-many seconds of the relight countdown)
const DANGER_SHAKE := 18.0  # configurable  (px the lighter trembles at most; 0 = never)
const DANGER_SCREEN_SHAKE := 5.0  # configurable  (px the whole screen trembles at most when you're about to lose; 0 = never)
## ... and a red border throbs in from the screen edges like a heartbeat (faster when it's closer).
const STRESS_COLOR := Color("#e83b3b")  # configurable
const STRESS_ALPHA := 0.45  # configurable  (how strong the red border gets at worst; 0 = off)
const STRESS_WIDTH := 140.0  # configurable  (px it reaches in from the edges at worst)
const STRESS_BANDS := 5  # configurable  (steps it fades in, pixel-art style)
const LIGHT_HOLD_MIN := 3.0  # configurable  (once the flame reaches full it burns steady for MIN..MAX seconds at random,
const LIGHT_HOLD_MAX := 10.0  # configurable   then starts dying again; flicking during that time floods it)
const FULL_SHAKE := 0.6  # configurable  (how hard the lighter jolts when the flame reaches full; 0 = none)
const FULL_FLASH_COLOR := Color(1.0, 0.85, 0.55, 0.35)  # configurable  (the soft full-screen flash at full blaze; alpha = strength, 0 = none)
const FULL_FLASH_TIME := 0.35  # configurable  (seconds the flash takes to fade)
const FLAME_FPS := 11.0  # configurable  (speed of the flame animation: assets/lighter/flame_0.png ... flame_7.png)
const FLAME_MIN_SIZE := 0.3  # configurable  (the flame shrinks to this size as the light dies; 1 = never shrinks)
const FLAME_SINK := 3.0  # configurable  (art pixels the bottom of the flame sits down inside the chimney)
const FLOOD_LIFE_COST := 0.5  # configurable  (lives a flood costs: half a life)
const LIGHTER_KEY := KEY_SPACE  # configurable  (key to flick the lighter; clicking / tapping the lighter works too - that's how phones do it)
const START_FLICKS_MIN := 3  # configurable  (flicks before the flame catches when you light it up: random MIN..MAX)
const START_FLICKS_MAX := 5  # configurable
const WALL_MARGINS := Vector4(140, 150, 90, 110)  # configurable  (px kept free at the wall's left, top, right, bottom: HUD, wick gauge, edges; the Back button has its own strip)
const LIGHTER_LID_TIME := 0.18  # configurable  (seconds for the lid to open / close)
const LIGHT_SOFT_EDGE := 0.45  # configurable  (part of the radius that fades out in steps; 0 = hard edge)
const LIGHT_BANDS := 4  # configurable  (steps in the fade - it's pixel art, so no smooth gradient)
const LIGHT_PIXEL := 6  # configurable  (px per light "pixel")
const LIGHT_FLICKER := 0.04  # configurable  (how much the light wobbles)
const LIGHT_TINT := Color(1.0, 0.6, 0.2, 0.07)  # configurable  (warm glow inside the light; alpha 0 = none)
const WALL_DARKNESS := 0.96  # configurable  (how dark the wall gets with no light: 0 = no darkness, 1 = pitch black)
const LIGHT_CURVE := 1.6  # configurable  (above 1 = the wall darkens sooner as the light drops; 1 = evenly)
const GLOW_MIN := 0.3  # configurable  (the glow round the lighter shrinks to this much as the light dies)
const RELIGHT_TIME := 5.0  # configurable  (seconds to relight before you lose a life)
const RELIGHT_HITS_MIN := 4  # configurable  (good strikes needed to empty the bar: random MIN..MAX, at stage 1)
const RELIGHT_HITS_MAX := 4  # configurable
const RELIGHT_SPEED := 1.3  # configurable  (track lengths per second the marker moves at first)
const RELIGHT_SPEED_UP := 1.3  # configurable  (marker gets this many times faster after every good strike)
const RELIGHT_ZONE := 0.2  # configurable  (gold zone size at first, part of the track: 0.2 = 20%)
const RELIGHT_ZONE_SHRINK := 0.8  # configurable  (zone shrinks to 80% after every good strike)
const RELIGHT_ZONE_MIN := 0.06  # configurable
const RELIGHT_MISS_PENALTY := 1  # configurable  (a mistimed strike pushes the bar back up this many steps)

# --- stages & lives
## Every stage gives you LIVES lives. Break WALLS_PER_STAGE walls to clear it and go up a stage.
## Losing a life (lighter not relit in time) restarts the stage from its first wall - your stage
## is a checkpoint. Lose all your lives before clearing it and you drop down a stage.
const LIVES := 3  # configurable
const MAX_LIVES := 5.0  # configurable  (hard cap: you can NEVER have more lives than this, Pack of Fluid included)
const WALLS_PER_STAGE := 5  # configurable
const LOSS_RESTARTS_STAGE := true  # configurable  (false = losing a life keeps the walls you already broke this stage)
## Each stage up, things get harder - and pay more:
const STAGE_FUEL_STEP := 0.07  # configurable  (light fades 7% faster each stage; tap rings close 7% faster too)
const STAGE_FUEL_MIN := 0.45  # configurable  (never below 45% of stage 1)
const STAGE_RELIGHT_EVERY := 2  # configurable  (one more good strike needed to relight every N stages)
const STAGE_COIN_BONUS := 0.25  # configurable  (+25% coins from the wall for every stage above 1)

# --- coins
const PERFECT_COINS_MIN := 1  # configurable  (coins for a PERFECT action: random MIN..MAX, then x combo)
const PERFECT_COINS_MAX := 3  # configurable
const GOOD_COINS := 0  # configurable  (coins for an action that was finished but not perfect, x combo)
const WALL_BREAK_BONUS := 0  # configurable  (extra coins when the wall comes down)

# --- tap  (closing circles: tap each circle right when its ring closes in on it)
## Circles pop up one after another. Each has a ring that shrinks onto it; tap the circle the moment
## the ring touches it. Some rings close fast, some slow, so they don't close in the order they appear:
## watch the rings and tap whichever closes first. (Tap actions are timed by their circles, not ACTION_TIME.)
const TAP_COUNT_MIN := 3  # configurable  (circles: random MIN..MAX)
const TAP_COUNT_MAX := 6  # configurable
const TAP_RADIUS := 38.0  # configurable  (px, size of a circle)
const TAP_APPROACH_MIN := 0.65  # configurable  (seconds a FAST ring takes to close)
const TAP_APPROACH_MAX := 1.8  # configurable  (seconds a SLOW ring takes to close)
const TAP_APPROACH_SIZE := 3.0  # configurable  (the ring starts this many times bigger than the circle)
const TAP_GAP_MIN := 0.3  # configurable  (seconds between one ring closing and the next: random MIN..MAX)
const TAP_GAP_MAX := 0.65  # configurable
const TAP_PERFECT_WINDOW := 0.1  # configurable  (tap within +/- this many seconds of the ring closing = PERFECT)
const TAP_GOOD_WINDOW := 0.22  # configurable  (within this = Good; later and the circle is missed)
const TAP_EARLY_IGNORE := 0.45  # configurable  (taps MORE than this early are ignored ("Wait for it!"); between this and GOOD = "Too early!", circle missed)

# --- zigzag (careful tracing) and slash (one fast swipe)
const SLICE_START_RADIUS := 40.0  # configurable  (how close to the start dot you must press)
const SLICE_FINISH := 0.93  # configurable  (how much of the line you must trace, 0.93 = 93%)
const ZIGZAG_CORNERS_MIN := 4  # configurable  (number of sharp turns)
const ZIGZAG_CORNERS_MAX := 8  # configurable
const ZIGZAG_LENGTH_MIN := 320.0  # configurable  (px, start to end)
const ZIGZAG_LENGTH_MAX := 620.0  # configurable
const ZIGZAG_WIDTH := 80.0  # configurable  (px the zigzag swings to each side)
const ZIGZAG_PERFECT_TOLERANCE := 16.0  # configurable  (px you may stray and still be PERFECT)
const ZIGZAG_OK_TOLERANCE := 40.0  # configurable  (px; stray further and it's a MISS)
const ZIGZAG_CORNER_RADIUS := 34.0  # configurable  (px; you must pass this close to EVERY corner - no straight-line shortcuts)
const ZIGZAG_LOOKAHEAD := 45.0  # configurable  (px of line ahead of you that counts; small = you can't skip ahead)
const SLASH_LENGTH_MIN := 480.0  # configurable  (px)
const SLASH_LENGTH_MAX := 860.0  # configurable
const SLASH_CURVE_CHANCE := 45.0  # configurable  (% of slashes that are curved)
const SLASH_CURVE_AMOUNT := 0.3  # configurable  (how bendy curved slashes are)
const SLASH_SWIPE_TIME := 0.9  # configurable  (seconds you have from pressing to finishing the swipe)
const SLASH_PERFECT_TOLERANCE := 26.0  # configurable
const SLASH_OK_TOLERANCE := 60.0  # configurable
const SLASH_LOOKAHEAD := 90.0  # configurable  (px of line ahead of you that counts)

# --- the crack you make (pixel art, drawn on the wall tile's own pixel grid)
const CRACK_PIXEL := 0  # configurable  (screen px per crack pixel; 0 = same as the wall art = WALL_TILE_SCALE)
const ZIGZAG_CRACK_WIDTH := 2  # configurable  (thickness in pixels)
const SLASH_CRACK_WIDTH := 3  # configurable
const CRACK_JAGGEDNESS := 2  # configurable  (pixels the crack may wander off the line; 0 = follows it exactly)
const CRACK_BRANCH_CHANCE := 40.0  # configurable  (% chance every ~50px that a little side-crack splits off)
const CRACK_BRANCH_LENGTH_MIN := 3  # configurable  (side-crack length in pixels)
const CRACK_BRANCH_LENGTH_MAX := 8  # configurable
const CRACK_SOUND_EVERY := 28.0  # configurable  (px of crack between two crackle sounds + chips; 0 = silent)

# --- drill
const DRILL_CLICKS_MIN := 8  # configurable  (clicks needed: random MIN..MAX)
const DRILL_CLICKS_MAX := 15  # configurable
const DRILL_RADIUS := 55.0  # configurable  (px; clicks further away don't count and spoil PERFECT)

# --- pry
const PRY_RADIUS := 55.0  # configurable  (px, where you must press)
const PRY_FILL_TIME := 1.4  # configurable  (seconds for the gauge to fill up; at full it snaps = miss)
const PRY_ZONE_MIN := 0.5  # configurable  (gold zone starts somewhere between MIN and MAX of the gauge)
const PRY_ZONE_MAX := 0.75  # configurable
const PRY_ZONE_SIZE := 0.16  # configurable  (size of the gold zone = PERFECT)
const PRY_GOOD_MARGIN := 0.1  # configurable  (just outside the gold zone still counts, but not perfect)

# --- colours
const SLICE_GUIDE_COLOR := Color("#ffd166")  # configurable  (lines, rings and gauges to follow)
const SLICE_TRAIL_COLOR := Color("#fff4d6")  # configurable  (the line you draw / what you've done)
const SLICE_MISS_COLOR := Color("#ff4a5e")  # configurable
const CUT_COLOR := Color("#2E222F")  # configurable  (cracks and holes left in the wall)
const CUT_EDGE_COLOR := Color("#7F708A")  # configurable  (light pixel under a crack; alpha 0 = none)
const TIMER_COLORS := [Color("#7bd65a"), Color("#ffd166"), Color("#ff4a5e")]  # configurable  (relight countdown: full -> half -> empty)


# ------------------------------------------------------------------ AUDIO
## Volume in dB for each sound (0 = file's own volume, -6 = about half, -80 = silent)
## and how much the pitch randomly varies (0.1 = +/-10%) so repeated sounds don't get boring.
## The sound files live in assets/audio/<name>.wav (or .ogg / .mp3). See README.md.
const SOUNDS := {  # configurable
	"hit": {"db": -4.0, "pitch_var": 0.12},
	"break": {"db": -2.0, "pitch_var": 0.08},
	"drop_common": {"db": -8.0, "pitch_var": 0.06},
	"drop_rare": {"db": -4.0, "pitch_var": 0.0},
	"drop_none": {"db": -10.0, "pitch_var": 0.0},
	"buy": {"db": -6.0, "pitch_var": 0.04},
	"sell": {"db": -6.0, "pitch_var": 0.04},
	"click": {"db": -10.0, "pitch_var": 0.05},
	"error": {"db": -10.0, "pitch_var": 0.0},
	"restock": {"db": -6.0, "pitch_var": 0.0},
	"slice_perfect": {"db": -5.0, "pitch_var": 0.05},  # any PERFECT action (pitch rises with combo)
	"slice_good": {"db": -7.0, "pitch_var": 0.08},  # an action finished but not perfect
	"slice_miss": {"db": -9.0, "pitch_var": 0.0},
	"wall_break": {"db": -2.0, "pitch_var": 0.06},
	"screen_slide": {"db": -12.0, "pitch_var": 0.05},
	"tap": {"db": -6.0, "pitch_var": 0.12},  # tapping a circle
	"crack": {"db": -11.0, "pitch_var": 0.25},  # crackle while you crack a zigzag / slash into the wall
	"drill": {"db": -8.0, "pitch_var": 0.05},  # each drill click (pitch rises as it goes deeper)
	"pry": {"db": -4.0, "pitch_var": 0.06},  # the wedge pops out
	"timeout": {"db": -6.0, "pitch_var": 0.0},  # fuel ran out / every circle missed, combo lost
	"lid": {"db": -6.0, "pitch_var": 0.08},  # lighter lid flips open / shut
	"flick": {"db": -6.0, "pitch_var": 0.1},  # a well-timed strike on the flint wheel (sparks)
	"misfire": {"db": -5.0, "pitch_var": 0.05},  # a mistimed strike (bar goes back up)
	"ignite": {"db": -5.0, "pitch_var": 0.05},  # the flame catches
	"fizzle": {"db": -6.0, "pitch_var": 0.05},  # the lighter goes out
	"life_lost": {"db": -4.0, "pitch_var": 0.0},  # didn't relight in time
	"stage_up": {"db": -3.0, "pitch_var": 0.0},
	"stage_down": {"db": -4.0, "pitch_var": 0.0},
}
## Music: one track per screen (+ the Shop), they cross-fade when you switch.
## key -> {file: assets/audio/music/<file>.dat (your tracks, compressed + locked by tools/make_music.py)
##         or a plain assets/audio/<file>.ogg/.wav/.mp3, db: loudness}
const MUSIC_TRACKS := {  # configurable
	"main": {"file": "rocks", "db": -12.0},  # rock-breaking screen: Gambler Symphony
	"mine": {"file": "mine", "db": -12.0},  # mining wall: MeltdownTheme
	"shop": {"file": "shop", "db": -12.0},  # while the Shop is open: Shop Theme (Thameuszin)
}
const MUSIC_FADE_TIME := 0.8  # configurable  (seconds to cross-fade between tracks)
const MUSIC_VOLUME := 0.7  # configurable  (0 - 1, starting music volume; players change it in Settings)
const SFX_VOLUME := 0.8  # configurable  (0 - 1, starting sound-effect volume)


# ------------------------------------------------------------------ COLORS / UI
## Pixel-art skin: buttons, menus and the sunken boxes inside them are 9-sliced from assets/ui/skin/*.png
## (drawn by tools/make_ui.py). Margins are in art pixels: left, top, right, bottom - the corners never
## stretch. Delete the files to get flat boxes back.
const UI_PIXEL_SCALE := 2  # configurable  (screen px per art pixel of the skin: 2 = chunky)
const UI_SKIN_BUTTON_MARGINS := Vector4i(3, 3, 3, 5)  # configurable
const UI_SKIN_PRESSED_MARGINS := Vector4i(3, 6, 3, 3)  # configurable  (pressed buttons sit 3 art px lower)
const UI_SKIN_PANEL_MARGINS := Vector4i(10, 10, 10, 10)  # configurable
const UI_SKIN_SLOT_MARGINS := Vector4i(3, 3, 3, 3)  # configurable
const BG_COLOR := Color("#1c140f")  # configurable  (behind everything)
const MENU_BAR_COLOR := Color("#2b1d14")  # configurable  (the top menu bar and the Back strip on the mine screen)
const MENU_BAR_EDGE := Color("#6e4b2f")  # configurable  (line under the menu bar)
const PANEL_COLOR := Color("#3a281c")  # configurable  (dark wood panels)
const PANEL_BORDER := Color("#6e4b2f")  # configurable
const BUTTON_COLOR := Color("#7c5534")  # configurable
const BUTTON_HOVER := Color("#9a6b41")  # configurable
const BUTTON_EDGE := Color("#24170f")  # configurable  (the dark bottom edge that makes buttons look chunky)
const TEXT_COLOR := Color("#f6e7c8")  # configurable
const MUTED_TEXT := Color("#c4a982")  # configurable
const ACCENT := Color("#ffc94a")  # configurable  (coins, highlights)
const TEXT_OUTLINE_COLOR := Color("#1a0f08")  # configurable  (dark outline around all text)
const TEXT_OUTLINE_SIZE := 4  # configurable  (0 = no outline)
## Drop shadow under all text (labels, buttons, the wall's texts) so it stands out.
const TEXT_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.6)  # configurable  (alpha 0 = no shadow)
const TEXT_SHADOW_OFFSET := Vector2i(3, 3)  # configurable  (px right, px down)
## Fonts. Put a .ttf/.otf in assets/fonts/ and write its path here to use it.
## Left empty (""), the game uses the first of the system fonts listed below that is installed.
## The font is BoldPixels by YukiPixels (CC BY-SA 4.0: keep the credit in Settings).
const FONT_FILE := "res://assets/fonts/BoldPixels.ttf"  # configurable  (body text)
const FONT_SYSTEM_NAMES := ["Rockwell", "Georgia", "serif"]  # configurable
const FONT_WEIGHT := 700  # configurable  (400 = regular, 700 = bold)
const TITLE_FONT_FILE := "res://assets/fonts/BoldPixels.ttf"  # configurable  (big titles, PERFECT!, combo)
const TITLE_FONT_SYSTEM_NAMES := ["Rockwell", "Georgia", "serif"]  # configurable
const TITLE_FONT_WEIGHT := 800  # configurable  (800 = extra bold)
const FONT_SIZE := 16  # configurable
## Pixel fonts are only crisp at whole multiples of their pixel size (BoldPixels: 16, 32, 48 ...).
## Every text size in the game is rounded to the nearest multiple of this. 0 = sizes are used as written.
const FONT_PIXEL_SIZE := 16  # configurable
const BUTTON_FONT_SIZE := 32  # configurable  (text on buttons: 32 = 2x, the same as the button art)
const FONT_PIXELATED := true  # configurable  (true = no smoothing: hard pixel edges, for pixel fonts)


## A text size rounded to the font's crisp sizes (see FONT_PIXEL_SIZE).
static func font_px(fs: int) -> int:
	if FONT_PIXEL_SIZE <= 0:
		return fs
	return maxi(FONT_PIXEL_SIZE, roundi(float(fs) / FONT_PIXEL_SIZE + 0.25) * FONT_PIXEL_SIZE)  # 20+ -> 32, 36+ -> 48


# ------------------------------------------------------------------ TUTORIAL
const SHOW_TUTORIAL := true  # configurable  (show the tutorial when a new game starts; the "?" button always opens it)


# ------------------------------------------------------------------ SAVE
const SAVE_ENABLED := true  # configurable
const RESET_SAVE_ON_START := false  # configurable  (true = always start a fresh game; handy while tuning)
