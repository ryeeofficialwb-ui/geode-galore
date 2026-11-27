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
## Cracks are drawn into the rock's own pixels each time you hit it.
const CRACK_COLOR := Color("#2E222F")  # configurable  (dark crack pixels)
const CRACK_EDGE_COLOR := Color("#7F708A")  # configurable  (light pixel beside a crack; set alpha 0 to disable)
const CRACKS_PER_HIT := 2  # configurable  (how many crack lines each hit adds)
const CRACK_LENGTH_MIN := 3  # configurable  (in rock pixels)
const CRACK_LENGTH_MAX := 7  # configurable


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
const START_ROCKS := {"rock_02": 3}  # configurable  (3 Pebbles, the cheapest rock)


# ------------------------------------------------------------------ SHOP  (limited stock)
## The shop is a wooden shelf with EVERY rock on it. At each restock every rock rolls its own stock
## (ROCKS: stock_chance, stock_max): cheap rocks are nearly always there, the priciest only now and then.
## The restocks follow the Philippine clock (UTC+8) and the stock and prices come from that time alone,
## so EVERYONE sees the same shelf and the same prices at the same moment (no server needed).
const RESTOCK_SECONDS := 300.0  # configurable  (restocks at :00, :05, :10 ... Philippine time)
const MARKET_TIME_OFFSET := 8 * 3600  # configurable  (seconds east of UTC: 8 h = Philippine time)
const MARKET_HISTORY := 40  # configurable  (restocks of price history worked out to get today's prices)

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
## Pay to restock right now. Set to -1 to hide the button.
const INSTANT_RESTOCK_COST := 25  # configurable
## Every paid restock makes the next one cost this many times more (25 -> 63 -> 156 -> ...). It goes back
## to INSTANT_RESTOCK_COST when the shop restocks by itself on its timer.
const INSTANT_RESTOCK_GROWTH := 2.5  # configurable


# ------------------------------------------------------------------ UPGRADES SHOP  (tickets & upgrades)
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
##   fuel          how long your light lasts compared to the first cave (1 / 1.03 = fades 3% faster). Only the
##                 Crystal Grotto has a faster light now; the other caves keep their rewards with a normal light.
##   stone_chance  % chance that clearing stage 1 finds a pile of rocks for your bag (more on later stages)
##   tiers         [lowest, highest] rock tier this cave's piles can hold (ROCK_TIERS: 1 = cheapest .. 5 = priciest)
##   head_start    the walls act as if you were this many stages further: more actions per wall and the
##                 harder move styles sooner (see ACTION_UNLOCK). The Crystal Grotto has every move from stage 1.
##   bpm           your heart rate on this cave's stage 1 (the pricier the cave, the faster): the lowest it can go
##                 there. Every stage after that raises it HEART_STAGE_BPM (see HEART_REST_BPM).
const CAVES := {  # configurable (whole table)
	"old_mine": {"name": "Old Mine", "tile": "res://assets/wall/wall_tile.png", "ticket_price": TICKET_PRICE, "coins": 1.0, "fuel": 1.0, "stone_chance": 1.0, "tiers": [1, 1], "head_start": 0, "bpm": 60},
	"shale_hollow": {"name": "Shale Hollow", "tile": "res://assets/wall/shale_hollow.png", "ticket_price": 250, "coins": 1.4, "fuel": 1.0, "stone_chance": 1.8, "tiers": [1, 2], "head_start": 1, "bpm": 65},
	"crimson_deep": {"name": "Crimson Deep", "tile": "res://assets/wall/crimson_deep.png", "ticket_price": 600, "coins": 1.9, "fuel": 1.0, "stone_chance": 2.6, "tiers": [1, 3], "head_start": 2, "bpm": 70},
	"blackrock_tunnels": {"name": "Blackrock Tunnels", "tile": "res://assets/wall/blackrock_tunnels.png", "ticket_price": 1400, "coins": 2.6, "fuel": 1.0, "stone_chance": 3.4, "tiers": [2, 4], "head_start": 3, "bpm": 75},
	"magma_veins": {"name": "Magma Veins", "tile": "res://assets/wall/magma_veins.png", "ticket_price": 3000, "coins": 3.5, "fuel": 1.0, "stone_chance": 4.2, "tiers": [3, 5], "head_start": 4, "bpm": 80},
	"crystal_grotto": {"name": "Crystal Grotto", "tile": "res://assets/wall/crystal_grotto.png", "ticket_price": 6500, "coins": 4.75, "fuel": 1.0 / 1.03, "stone_chance": 5.0, "tiers": [4, 5], "head_start": 5, "bpm": 85},
}
## Rock TIERS: every rock sorted by price and cut into this many equal groups (tier 1 = the cheapest rocks).
const ROCK_TIERS := 5  # configurable
## The pile of rocks a cleared stage can find (the cave's stone_chance), and how it grows with the stage:
##   chance  = stone_chance x (1 + STAGE_STONE_CHANCE_GROWTH x (stage - 1)), never above STAGE_STONE_CHANCE_MAX
##   pile    = STAGE_ROCK_ROLLS rocks, +1 every STAGE_ROCK_ROLLS_EVERY stages; each has STAGE_ROCK_KEEP % to make it
##   kept    = at most STAGE_ROCK_MAX, +1 every STAGE_ROCK_MAX_EVERY stages (stage 1: 0-3 of 5)
##   tiers   = each rock is from the cave's tiers; higher stages lean to its higher tiers (STAGE_TIER_SHIFT)
const STAGE_STONE_CHANCE_GROWTH := 0.15  # configurable
const STAGE_STONE_CHANCE_MAX := 60.0  # configurable  (%)
const STAGE_ROCK_ROLLS := 5  # configurable
const STAGE_ROCK_ROLLS_EVERY := 3  # configurable
const STAGE_ROCK_KEEP := 50.0  # configurable  (%)
const STAGE_ROCK_MAX := 3  # configurable
const STAGE_ROCK_MAX_EVERY := 4  # configurable
const STAGE_TIER_SHIFT := 0.35  # configurable  (per stage: how much more the cave's higher tiers weigh)
## Upgrades. Level 1 gives "first", the last level gives exactly "max"; the levels in between follow a
## smooth curve: first < max / levels makes each level add a bit MORE than the one before (the rock upgrades),
## first > max / levels a bit less.
## The ROCK ECONOMY (tools/tune_drops.py + the 5 rock upgrades - Miner's / Jeweler's Favor, Rocky Riches,
## Fool's Gold, Silktouch): a rock pays back 105% of its price on average with no upgrades, ~200% with all five
## at half their levels (~220k coins), ~400% with all five maxed (~3.6M). Change these and re-check the math.
##   name / text   shown in the shop ("text" says what the number is)
##   first / max   the bonus at level 1 / at the last level (percent)
##   levels        how many times it can be bought
##   cost          coins for level 1; every level costs cost_growth times more than the one before
##   art: assets/ui/upgrades/<id>.png (placeholders made by tools/make_ui.py)
const UPGRADES := {  # configurable (whole table)
	"miners_favor": {"name": "Miner's Favor", "text": "ore chance", "first": 0.08, "max": 80.0, "levels": 250, "cost": 40, "cost_growth": 1.022},
	"jewelers_favor": {"name": "Jeweler's Favor", "text": "gem chance", "first": 0.075, "max": 75.0, "levels": 250, "cost": 60, "cost_growth": 1.022},
	"rocky_riches": {"name": "Rocky Riches", "text": "ores per drop", "first": 0.14, "max": 140.0, "levels": 250, "cost": 50, "cost_growth": 1.022},  # max +140% = x2.4 ores (gems don't count)
	"digging_expert": {"name": "Digging Expert", "text": "coins in the mine", "first": 2.5, "max": 400.0, "levels": 250, "cost": 30, "cost_growth": 1.022},
	"fools_gold": {"name": "Fool's Gold", "text": "chance to sell for more", "first": 0.2, "max": 20.0, "levels": 250, "cost": 75, "cost_growth": 1.022},
	"heat_of_the_forge": {"name": "Heat of the Forge", "text": "light per lighter flick", "first": 0.04, "max": 10.0, "levels": 250, "cost": 60, "cost_growth": 1.022},
	## Pack of Fluid: the value is extra LIVES (not %), counted in half lives: 20 levels for +2 lives = half a life
	## every 5 levels, so 3 + 2 = 5 lives at max. Lives never go above MAX_LIVES (5) no matter what.
	"pack_of_fluid": {"name": "Pack of Fluid", "text": "lives every stage", "first": 0.1, "max": 2.0, "levels": 20, "cost": 2500, "cost_growth": 1.25},
	"silktouch": {"name": "Silktouch", "text": "chance a rock doesn't break", "first": 0.08, "max": 20.0, "levels": 250, "cost": 120, "cost_growth": 1.022},
	"ticket_hungry": {"name": "Ticket Hungry", "text": "chance of a ticket per stage cleared", "first": 0.1, "max": 3.0, "levels": 50, "cost": 150, "cost_growth": 1.08},
	## Better Rock Piles: a cleared stage's pile chance (and its STAGE_STONE_CHANCE_MAX cap) and each rock's
	## STAGE_ROCK_KEEP chance, all x (1 + this %) - never above 100%. Max +60%: keep 50% -> 80%, cap 60% -> 96%.
	"rock_piles": {"name": "Better Rock Piles", "text": "rock pile chance & size", "first": 0.3, "max": 60.0, "levels": 250, "cost": 80, "cost_growth": 1.022},
	## Strongbox: this part of a lost run's loot (coins, ores, rocks) is yours anyway (adds to Minecart / Backpack).
	"strongbox": {"name": "Strongbox", "text": "of a lost run's loot kept", "first": 0.2, "max": 20.0, "levels": 100, "cost": 150, "cost_growth": 1.05},
}
const FOOLS_GOLD_BONUS := 15.0  # configurable  (% extra a Fool's Gold sale pays)
const FOOLS_GOLD_GEMS := true  # configurable  (false = Fool's Gold only works when selling ores, not gems)
## REBIRTH (Upgrades): the whole game starts over - coins, rocks, ores, upgrades, caves and tickets are wiped -
## for REBIRTH_SLOTS more artifact slots on every run, forever. At most REBIRTH_MAX times. Each costs coins AND
## ores / gems (they're spent: the reset wipes the rest anyway); each one after the first costs REBIRTH_GROWTH x more.
## Reset (Settings) wipes Rebirths too.
const REBIRTH_MAX := 3  # configurable
const REBIRTH_SLOTS := 1  # configurable
const REBIRTH_COINS := 2500000  # configurable  (the first one; then x REBIRTH_GROWTH each time)
const REBIRTH_ORES := {"gold": 250, "silver": 400, "cryo_core": 60, "ruby": 25, "sapphire": 25, "emerald": 12, "pearl": 8, "dreamstone": 4}  # configurable
const REBIRTH_GROWTH := 3.0  # configurable


# ------------------------------------------------------------------ ROCK TYPES
## id: also its name on the rocks texture (assets/rocks/rocks.png, packed by tools/slice_sheets.py)
##   name        shown in the game
##   price         base shop price (coins): by the rock's size, 10 for the smallest up to 1000 for the biggest
##   stock_chance  0 - 1: chance it's in stock at each restock (the pricier, the rarer)
##   stock_max     most there can be in stock (1 - stock_max when it is)
##   hits_min / hits_max   hits to break it
##   rolls         how many times the drops are rolled when it breaks
##   drops         the ONLY ores / gems this rock can give: ore id -> [% chance per roll, min, max]
## Every ore in drops is rolled on its own each roll, so one rock can give several ores (or nothing).
## tools/tune_drops.py writes this whole table: prices from the art's size, a few ores per rock, and chances
## tuned so each rock pays back its price about half the time. Re-run it after changing ore prices.
const ROCKS := {  # configurable (whole table)
	"rock_02": {"name": "Pebble", "price": 10, "stock_chance": 0.9, "stock_max": 8, "hits_min": 2, "hits_max": 4, "rolls": 1, "drops": {"lead": [41.02, 1, 2], "mudspec": [34.32, 1, 3], "copper": [29.66, 1, 1], "iron": [23.56, 1, 2]}},
	"rock_25": {"name": "Flatstone", "price": 25, "stock_chance": 0.53, "stock_max": 7, "hits_min": 3, "hits_max": 5, "rolls": 1, "drops": {"lead": [64.61, 1, 2], "iron": [37.11, 1, 2], "zinc": [28.76, 1, 2], "rustvein": [21.31, 1, 2], "jade": [12.89, 1, 1], "gold": [9.32, 1, 1]}},
	"rock_29": {"name": "Spire", "price": 60, "stock_chance": 0.31, "stock_max": 5, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"polyphite": [28.75, 1, 2], "rhodonite": [25.41, 1, 1], "rustvein": [22.84, 1, 2], "veridium": [12.21, 1, 2], "tigers_eye": [5.73, 1, 1], "hellspec": [3.81, 1, 1]}},
	"rock_05": {"name": "Shard Rock", "price": 65, "stock_chance": 0.3, "stock_max": 5, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"polyphite": [37.64, 1, 2], "stibnite": [21.62, 1, 2], "jade": [18.09, 1, 1], "veridium": [15.99, 1, 2], "white_quartz": [14.37, 1, 1]}},
	"rock_28": {"name": "Bean Rock", "price": 70, "stock_chance": 0.29, "stock_max": 5, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"polyphite": [43.58, 1, 2], "rhodonite": [38.52, 1, 1], "rustvein": [34.62, 1, 2], "peridot": [12.02, 1, 1], "onyx": [7.99, 1, 1]}},
	"rock_23": {"name": "Slate Stack", "price": 75, "stock_chance": 0.28, "stock_max": 5, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"rustvein": [28.27, 1, 2], "silver": [23.65, 1, 1], "veridium": [15.11, 1, 2], "gold": [12.36, 1, 1], "onyx": [6.53, 1, 1], "amethyst": [3.14, 1, 1]}},
	"rock_14": {"name": "Cobblestone", "price": 95, "stock_chance": 0.24, "stock_max": 5, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"rhodonite": [42.81, 1, 1], "rustvein": [38.47, 1, 2], "gold": [16.82, 1, 1], "rose_quartz": [14.33, 1, 1], "lapis": [7.68, 1, 1], "aquamarine": [5.55, 1, 1]}},
	"rock_22": {"name": "Broken Knot", "price": 95, "stock_chance": 0.24, "stock_max": 5, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"zinc": [45.45, 1, 2], "rustvein": [33.68, 1, 2], "veridium": [18.01, 1, 2], "cryo_core": [9.29, 1, 1], "lapis": [6.72, 1, 1], "sapphire": [3.74, 1, 1]}},
	"rock_24": {"name": "Anvil Rock", "price": 110, "stock_chance": 0.22, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"silver": [43.5, 1, 1], "jade": [31.45, 1, 1], "veridium": [27.8, 1, 2], "onyx": [12.0, 1, 1], "hellspec": [8.68, 1, 1]}},
	"rock_15": {"name": "Notched Rock", "price": 130, "stock_chance": 0.2, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"rustvein": [56.56, 1, 2], "veridium": [30.24, 1, 2], "rose_quartz": [21.06, 1, 1], "onyx": [13.06, 1, 1], "hellspec": [9.44, 1, 1]}},
	"rock_07": {"name": "Crag", "price": 140, "stock_chance": 0.19, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"rustvein": [64.37, 1, 2], "stibnite": [46.54, 1, 2], "jade": [38.93, 1, 1], "cryo_core": [17.76, 1, 1], "lapis": [12.84, 1, 1]}},
	"rock_20": {"name": "Wedge Rock", "price": 140, "stock_chance": 0.19, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"rustvein": [67.11, 1, 2], "silver": [56.14, 1, 1], "gold": [29.34, 1, 1], "tigers_eye": [16.85, 1, 1], "tourmaline": [8.9, 1, 1]}},
	"rock_27": {"name": "Moon Boulder", "price": 150, "stock_chance": 0.18, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"rustvein": [67.37, 1, 2], "stibnite": [48.71, 1, 2], "peridot": [23.4, 1, 1], "cryo_core": [18.59, 1, 1], "lapis": [13.44, 1, 1]}},
	"rock_19": {"name": "Saddle Rock", "price": 160, "stock_chance": 0.18, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"stibnite": [41.78, 1, 2], "white_quartz": [27.76, 1, 1], "peridot": [20.07, 1, 1], "hellspec": [9.64, 1, 1], "uranium": [7.66, 1, 1], "sapphire": [6.41, 1, 1]}},
	"rock_06": {"name": "Knobby Rock", "price": 170, "stock_chance": 0.17, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"silver": [48.43, 1, 1], "veridium": [30.95, 1, 2], "cryo_core": [15.98, 1, 1], "tourmaline": [7.68, 1, 1], "amethyst": [6.42, 1, 1], "pearl": [3.19, 1, 1]}},
	"rock_26": {"name": "Knuckle Rock", "price": 170, "stock_chance": 0.17, "stock_max": 4, "hits_min": 4, "hits_max": 6, "rolls": 2, "drops": {"silver": [52.8, 1, 1], "gold": [27.6, 1, 1], "peridot": [21.93, 1, 1], "aquamarine": [9.1, 1, 1], "amethyst": [7.0, 1, 1], "daevorium": [4.81, 1, 1]}},
	"rock_16": {"name": "Chipped Block", "price": 190, "stock_chance": 0.16, "stock_max": 4, "hits_min": 5, "hits_max": 7, "rolls": 2, "drops": {"veridium": [34.96, 1, 2], "white_quartz": [31.42, 1, 1], "tigers_eye": [16.42, 1, 1], "onyx": [15.09, 1, 1], "amethyst": [7.25, 1, 1], "emerald": [4.17, 1, 1]}},
	"rock_08": {"name": "Twin Stones", "price": 250, "stock_chance": 0.14, "stock_max": 3, "hits_min": 5, "hits_max": 7, "rolls": 2, "drops": {"rose_quartz": [32.41, 1, 1], "peridot": [30.23, 1, 1], "lapis": [17.36, 1, 1], "aquamarine": [12.55, 1, 1], "ruby": [9.65, 1, 1], "emerald": [5.54, 1, 1]}},
	"rock_04": {"name": "Lumpy Rock", "price": 250, "stock_chance": 0.14, "stock_max": 3, "hits_min": 5, "hits_max": 7, "rolls": 2, "drops": {"gold": [47.14, 1, 1], "cryo_core": [29.75, 1, 1], "tigers_eye": [27.08, 1, 1], "ruby": [11.96, 1, 1], "obsidian": [9.14, 1, 1]}},
	"rock_30": {"name": "Twisted Rock", "price": 310, "stock_chance": 0.12, "stock_max": 3, "hits_min": 5, "hits_max": 7, "rolls": 3, "drops": {"rose_quartz": [26.3, 1, 1], "peridot": [24.53, 1, 1], "hellspec": [11.79, 1, 1], "tourmaline": [9.36, 1, 1], "sapphire": [7.83, 1, 1], "pearl": [3.89, 1, 1]}},
	"rock_17": {"name": "Clump", "price": 340, "stock_chance": 0.11, "stock_max": 3, "hits_min": 5, "hits_max": 7, "rolls": 3, "drops": {"gold": [43.46, 1, 1], "rose_quartz": [37.01, 1, 1], "tigers_eye": [24.96, 1, 1], "uranium": [13.18, 1, 1], "daevorium": [7.57, 1, 1]}},
	"rock_10": {"name": "Round Stone", "price": 400, "stock_chance": 0.1, "stock_max": 2, "hits_min": 5, "hits_max": 7, "rolls": 3, "drops": {"gold": [39.04, 1, 1], "onyx": [20.61, 1, 1], "hellspec": [14.9, 1, 1], "amethyst": [9.9, 1, 1], "topaz": [9.9, 1, 1], "zapperion": [4.61, 1, 1]}},
	"rock_18": {"name": "Tower Rock", "price": 430, "stock_chance": 0.1, "stock_max": 2, "hits_min": 5, "hits_max": 7, "rolls": 3, "drops": {"lapis": [17.77, 1, 1], "tourmaline": [11.81, 1, 1], "uranium": [11.81, 1, 1], "sapphire": [9.88, 1, 1], "ruby": [9.88, 1, 1], "dreamstone": [3.26, 1, 1]}},
	"rock_11": {"name": "Egg Boulder", "price": 440, "stock_chance": 0.1, "stock_max": 2, "hits_min": 5, "hits_max": 7, "rolls": 3, "drops": {"rose_quartz": [44.21, 1, 1], "cryo_core": [32.76, 1, 1], "lapis": [23.68, 1, 1], "obsidian": [10.06, 1, 1], "zapperion": [6.13, 1, 1]}},
	"rock_01": {"name": "Boulder", "price": 500, "stock_chance": 0.09, "stock_max": 2, "hits_min": 5, "hits_max": 7, "rolls": 3, "drops": {"lapis": [19.88, 1, 1], "hellspec": [16.63, 1, 1], "amethyst": [11.05, 1, 1], "daevorium": [7.59, 1, 1], "emerald": [6.35, 1, 1], "dreamstone": [3.65, 1, 1]}},
	"rock_12": {"name": "Tall Egg", "price": 600, "stock_chance": 0.08, "stock_max": 2, "hits_min": 6, "hits_max": 8, "rolls": 3, "drops": {"aquamarine": [16.8, 1, 1], "topaz": [12.92, 1, 1], "sapphire": [12.92, 1, 1], "daevorium": [8.87, 1, 1], "emerald": [7.42, 1, 1], "dreamstone": [4.26, 1, 1]}},
	"rock_13": {"name": "Dome Rock", "price": 675, "stock_chance": 0.08, "stock_max": 2, "hits_min": 6, "hits_max": 8, "rolls": 3, "drops": {"tigers_eye": [41.86, 1, 1], "uranium": [22.1, 1, 1], "ruby": [18.49, 1, 1], "emerald": [10.62, 1, 1], "pearl": [9.18, 1, 1]}},
	"rock_03": {"name": "Big Boulder", "price": 675, "stock_chance": 0.08, "stock_max": 2, "hits_min": 6, "hits_max": 8, "rolls": 3, "drops": {"tigers_eye": [41.47, 1, 1], "tourmaline": [21.89, 1, 1], "ruby": [18.31, 1, 1], "obsidian": [13.99, 1, 1], "dreamstone": [6.04, 1, 1]}},
	"rock_21": {"name": "Split Boulder", "price": 925, "stock_chance": 0.06, "stock_max": 1, "hits_min": 6, "hits_max": 8, "rolls": 3, "drops": {"aquamarine": [31.17, 1, 1], "tourmaline": [28.65, 1, 1], "ruby": [23.97, 1, 1], "pearl": [11.9, 1, 1], "dreamstone": [7.91, 1, 1]}},
	"rock_09": {"name": "Rubble Pile", "price": 1000, "stock_chance": 0.06, "stock_max": 1, "hits_min": 6, "hits_max": 8, "rolls": 3, "drops": {"hellspec": [38.29, 1, 1], "topaz": [25.44, 1, 1], "obsidian": [19.44, 1, 1], "zapperion": [11.85, 1, 1], "dreamstone": [8.39, 1, 1]}},
}


# ------------------------------------------------------------------ ORE / GEM TYPES
## id: also its name on the ores & gems texture (assets/ores/ores.png, packed by tools/slice_sheets.py)
##   name        shown in the game
##   sell_price  coins you get for selling one, before the market (see MARKET_* above)
##   type        "ore" or "gem": Miner's Favor / Rocky Riches boost ores, Jeweler's Favor boosts gems
##   rare        true = sparkly sound + spin when it drops
##   color       used for the "+1 Ruby" pop-up text
##   amount      [min, max] you get when it drops
## Sorted: all the ORES first, then all the GEMS, each cheapest first (Backpack, Stock Prices and crush results
## list them in this order). Add a new one in its section, at its price.
const ORES := {  # configurable (whole table)
	# ---------------- ORES (17): Miner's Favor + Rocky Riches boost these ----------------
	"lead": {"name": "Lead", "sell_price": 4, "type": "ore", "rare": false, "color": Color("#a99ab5"), "amount": [1, 2]},
	"mudspec": {"name": "Mudspec", "sell_price": 5, "type": "ore", "rare": false, "color": Color("#b08a66"), "amount": [1, 3]},
	"copper": {"name": "Copper", "sell_price": 6, "type": "ore", "rare": false, "color": Color("#e8925f"), "amount": [1, 1]},
	"iron": {"name": "Iron", "sell_price": 8, "type": "ore", "rare": false, "color": Color("#dcc6ba"), "amount": [1, 2]},
	"zinc": {"name": "Zinc", "sell_price": 11, "type": "ore", "rare": false, "color": Color("#8fd3c9"), "amount": [1, 2]},
	"polyphite": {"name": "Polyphite", "sell_price": 12, "type": "ore", "rare": false, "color": Color("#b3b864"), "amount": [1, 2]},
	"rhodonite": {"name": "Rhodonite", "sell_price": 14, "type": "ore", "rare": false, "color": Color("#ec85a6"), "amount": [1, 1]},
	"rustvein": {"name": "Rustvein", "sell_price": 16, "type": "ore", "rare": false, "color": Color("#f57d4a"), "amount": [1, 2]},
	"silver": {"name": "Silver", "sell_price": 20, "type": "ore", "rare": false, "color": Color("#dfe9ec"), "amount": [1, 1]},
	"stibnite": {"name": "Stibnite", "sell_price": 24, "type": "ore", "rare": false, "color": Color("#c7dcd0"), "amount": [1, 2]},
	"veridium": {"name": "Veridium", "sell_price": 35, "type": "ore", "rare": false, "color": Color("#4fd16b"), "amount": [1, 2]},
	"gold": {"name": "Gold", "sell_price": 45, "type": "ore", "rare": false, "color": Color("#ffd84a"), "amount": [1, 1]},
	"cryo_core": {"name": "Cryo-core", "sell_price": 80, "type": "ore", "rare": true, "color": Color("#9eeaff"), "amount": [1, 1]},
	"hellspec": {"name": "Hellspec", "sell_price": 150, "type": "ore", "rare": true, "color": Color("#e0503c"), "amount": [1, 1]},
	"uranium": {"name": "Uranium", "sell_price": 200, "type": "ore", "rare": true, "color": Color("#6cff5a"), "amount": [1, 1]},
	"daevorium": {"name": "Daevorium", "sell_price": 400, "type": "ore", "rare": true, "color": Color("#ff3d6b"), "amount": [1, 1]},
	"dreamstone": {"name": "Dreamstone", "sell_price": 1000, "type": "ore", "rare": true, "color": Color("#d9a6ff"), "amount": [1, 1]},
	# ---------------- GEMS (17): Jeweler's Favor boosts these ----------------
	"jade": {"name": "Jade", "sell_price": 30, "type": "gem", "rare": false, "color": Color("#62cf9e"), "amount": [1, 1]},
	"white_quartz": {"name": "White Quartz", "sell_price": 40, "type": "gem", "rare": false, "color": Color("#e6eef0"), "amount": [1, 1]},
	"rose_quartz": {"name": "Rose Quartz", "sell_price": 55, "type": "gem", "rare": false, "color": Color("#f2a7c3"), "amount": [1, 1]},
	"peridot": {"name": "Peridot", "sell_price": 60, "type": "gem", "rare": true, "color": Color("#aee35c"), "amount": [1, 1]},
	"tigers_eye": {"name": "Tiger's Eye", "sell_price": 90, "type": "gem", "rare": true, "color": Color("#e0913a"), "amount": [1, 1]},
	"onyx": {"name": "Onyx", "sell_price": 100, "type": "gem", "rare": true, "color": Color("#b9b3cf"), "amount": [1, 1]},
	"lapis": {"name": "Lapis", "sell_price": 120, "type": "gem", "rare": true, "color": Color("#4d9be6"), "amount": [1, 1]},
	"aquamarine": {"name": "Aquamarine", "sell_price": 180, "type": "gem", "rare": true, "color": Color("#6fe3dc"), "amount": [1, 1]},
	"tourmaline": {"name": "Tourmaline", "sell_price": 200, "type": "gem", "rare": true, "color": Color("#ff8aa5"), "amount": [1, 1]},
	"amethyst": {"name": "Amethyst", "sell_price": 250, "type": "gem", "rare": true, "color": Color("#c690e6"), "amount": [1, 1]},
	"ruby": {"name": "Ruby", "sell_price": 250, "type": "gem", "rare": true, "color": Color("#ff4a5e"), "amount": [1, 1]},
	"sapphire": {"name": "Sapphire", "sell_price": 250, "type": "gem", "rare": true , "color": Color("#6a98ff"), "amount": [1, 1]},
	"topaz": {"name": "Topaz", "sell_price": 250, "type": "gem", "rare": true, "color": Color("#ffb347"), "amount": [1, 1]},
	"obsidian": {"name": "Obsidian", "sell_price": 350, "type": "gem", "rare": true, "color": Color("#ae97ae"), "amount": [1, 1]},
	"emerald": {"name": "Emerald", "sell_price": 500, "type": "gem", "rare": true, "color": Color("#45e3c4"), "amount": [1, 1]},
	"pearl": {"name": "Pearl", "sell_price": 600, "type": "gem", "rare": true, "color": Color("#f6f2ec"), "amount": [1, 1]},
	"zapperion": {"name": "Zapperion", "sell_price": 650, "type": "gem", "rare": true, "color": Color("#e2e679"), "amount": [1, 1]},
}


## Lore shown when you click an ore / gem in Shop > Stock Prices (write your own!).
const ORE_LORE := {  # configurable
	# ---- ores ----
	"lead": "Soft, grey and heavy for its size. Miners use it for weights and sinkers, and nobody has ever bragged about finding it.",
	"mudspec": "Brown, crumbly and streaked with darker bands. Mostly dried mud with a speck of metal - miners sell it by the sackful.",
	"copper": "The first metal people ever worked. It turns green with age, which the dwarves call 'getting wise'.",
	"iron": "The backbone of every pickaxe in the mine. Rusts if you so much as look at it wrong.",
	"zinc": "Brown nodules with a teal heart. Mixed with copper it becomes brass, the dwarves' favourite trim.",
	"polyphite": "Olive lumps that grow in clusters, like the rock is sprouting. Smiths grind it into a green flux.",
	"rhodonite": "A rose-pink stone streaked with black veins. Said to calm a hot-tempered miner.",
	"rustvein": "Rock shot through with veins of rusted iron. Old miners say the red is the mountain bleeding.",
	"silver": "Bright, cool and quick to tarnish. Dwarven tales say it keeps the dark things of the deep away.",
	"stibnite": "Needle-sharp silver crystals of antimony. Pretty, brittle, and poisonous to lick. Don't lick it.",
	"veridium": "Spiky green crystals that hum in the dark. Dwarves set them in their helmets to see in the deep.",
	"gold": "Soft, heavy and it never rusts. Every miner's dream, and the reason most of them started digging.",
	"cryo_core": "Ice-blue cores, cold enough to frost your gloves. They never melt, even in a forge.",
	"hellspec": "Red shards from near the magma. They stay warm for years; drop one in a bucket and it boils.",
	"uranium": "Glowing green lumps that hum faintly in your backpack. Worth a lot. Don't keep it under your pillow.",
	"daevorium": "Deep crimson crystals with a light inside. Old miners won't sleep in a tunnel that has some.",
	"dreamstone": "Lavender lumps found only in the deepest walls. Sleep beside one and you'll dream of veins of gold.",
	# ---- gems ----
	"jade": "A tough green stone, harder to break than steel. Carvers spend a lifetime on a single piece.",
	"white_quartz": "Clear white quartz, as common in the deep as sand on a beach - but a clean one still sparkles.",
	"rose_quartz": "Soft pink quartz. Miners carry a piece for luck and give the best ones away.",
	"peridot": "An olive-green gem born deep under the crust and carried up by volcanoes. It's even been found in meteorites.",
	"tigers_eye": "Golden-brown bands that shimmer as you turn it, like an eye looking back at you.",
	"onyx": "A black gem with faint pale bands. Polished, it's dark enough to see yourself in.",
	"lapis": "Deep blue flecked with golden pyrite, like a night sky in stone. Ground up, it made the bluest paint in history.",
	"aquamarine": "Sea-blue beryl. Sailors say it keeps you calm in a storm; miners say it keeps the water out.",
	"tourmaline": "A pink gem that charges up when it's warmed and pulls dust towards it. Some say it pulls luck too.",
	"amethyst": "Purple quartz. Ancient drinkers carved cups from it, sure it would keep them sober. It didn't.",
	"ruby": "Red corundum, the king of gems. Old miners swore a ruby kept close made you unbreakable.",
	"sapphire": "Blue corundum, second only to diamond in hardness. Kings wore it to keep envy away.",
	"topaz": "A warm golden gem that glows like honey in lamplight. Legend says it can cool boiling water.",
	"obsidian": "Volcanic glass that cooled too fast to crystallise. Its edge is sharper than any steel blade.",
	"emerald": "Green beryl full of tiny flaws the jewellers call its 'garden'. A flawless one is rarer than a diamond.",
	"pearl": "A perfect white pearl, somehow grown in stone. Nobody can explain it, and everybody wants one.",
	"zapperion": "A yellow-green crystal that crackles when touched. Nobody knows what it is, but lamps flicker when it's near.",
}


# ------------------------------------------------------------------ RUN ITEMS  (the roguelike part)
## ARTIFACTS. A RUN is one trip down a cave (one ticket, until you run out of lives or cash out - leaving the mine
## with Back cashes out too, and that cave starts again from stage 1). Everything a run gives you (coins, ores,
## rocks) is AT STAKE until you cash out: lose the run and it's all taken back (Minecart / Backpack save some). Every time you clear a stage you're
## offered ITEM_CHOICES random artifacts at the rest: take one (or skip). You hold ITEM_SLOTS at once; when
## they're full, taking a new one swaps out one you have. They only last for that run. Their ORDER matters
## (Copy copies the one on its right, Catto the one on its left).
const ITEM_SLOTS := 4  # configurable
const ITEM_CHOICES := 3  # configurable
## id -> name, text (shown on the card), once (true = used up after it does its thing)
##   book: (optional) a longer text for the Artifact Book only (the offers and tooltips use the short "text")
const ITEMS := {  # configurable (names & texts)
	"torch": {"name": "Torch", "once": true,
		"text": "No flicking for a whole stage: the light looks after itself. Burns out when the stage ends."},
	"stronger_fluids": {"name": "Stronger Fluids",
		"text": "Three good flicks light the lighter to full blaze."},
	"extra_wick": {"name": "Extra Wick",
		"text": "A second wick that burns first: your light stays put until it's gone, then the normal wick takes over."},
	"defibrillator": {"name": "Defibrillator", "once": true,
		"text": "Run out of lives and you're revived with 3 lives on the same stage. One use."},
	"midas_touch": {"name": "Midas Touch",
		"text": "Coins x (cave x MIDAS + combo). MIDAS grows: +0.25 every 3 moves, +1 a wall, +3 a stage (max 250x). Coins go in a pot: cash out at a rest, or lose it all if the run ends."},
	"beginners_luck": {"name": "Beginner's Luck",
		"text": "Every move is slower and more forgiving, with bigger targets."},
	"dynamite": {"name": "Dynamite",
		"text": "Press D (or the button) to blow straight through the wall - even with your lighter out. 2 charges, +1 every stage."},
	"dwarven_hands": {"name": "Dwarven Hands",
		"text": "Every move you finish can shake loose an ore or gem: rarer on higher stages, more of them the more walls you break."},
	"greed": {"name": "Greed",
		"text": "Does absolutely nothing. (Rumour says it pairs with Is Good.)"},
	"is_good": {"name": "Is Good",
		"text": "Does absolutely nothing. (Rumour says it pairs with Greed.)"},
	"ladder": {"name": "Ladder", "once": true,
		"text": "Run out of lives and you just climb back one stage - the run goes on. One use."},
	"hard_as_nails": {"name": "Hard as Nails",
		"text": "Flooding the lighter has a 50% chance to cost you nothing."},
	"adrenaline_shot": {"name": "Adrenaline Shot",
		"text": "Every time you'd lose a life: 50/50 that you don't."},
	"little_light": {"name": "Little Light",
		"text": "A tiny flame flicks your lighter for you, right in the gold zone. But mess up ANY move and it burns your hand: you drop the lighter and the run is OVER."},
	"cats_eyes": {"name": "Cat's Eyes",
		"text": "You see the whole wall in the dark: no flicking, the lighter's useless. But every move you mess up, the cat plays with your wick: -25% of it. Run out of wick and you lose a life."},
	"copy": {"name": "Copy",
		"text": "Copies the artifact on its RIGHT: that one counts twice. (Not Catto.)"},
	"catto": {"name": "Catto",
		"text": "Swats the artifact on its LEFT so it works twice as hard: that one counts twice. (Not Copy.)"},
	"drunk": {"name": "Drunk",
		"text": "The lighter's gold zone is bigger and your wick lasts longer... but every move gets harder."},
	"ring_of_luck": {"name": "Ring of Luck",
		"text": "1 in 4 moves you finish digs up a random rock (any rock in the game)."},
	"hand_drill": {"name": "Drill",
		"text": "1 in 8 moves you finish digs up a random rock."},
	"excavator": {"name": "Excavator",
		"text": "1 in 2 moves you finish digs up a random rock."},
	"miners_permit": {"name": "Miner's Permit",
		"text": "EVERY move you finish digs up a random rock."},
	"deaths_gambit": {"name": "Death's Gambit",
		"text": "Everything is twice as hard - but EVERYTHING pays x10: coins, ores, rocks, artifacts."},
	"mushroom_of_might": {"name": "Mushroom of Might",
		"text": "Stages only need 2-3 walls instead of 3-5."},
	"wall_breaker": {"name": "Wall Breaker",
		"text": "Every stage needs 2 fewer walls (never less than 1)."},
	"gilded_umbrella": {"name": "Gilded Umbrella",
		"text": "Gems fall from the cave roof: some break, the rest are yours. 1 in 4 hit you and knock your lighter out of your hand: click it within 3 s and relight it, or the run is OVER."},
	"molerats": {"name": "Molerats",
		"text": "They eat every rock you'd find - and pay you 1.5x what each one is worth."},
	"draupnir": {"name": "Draupnir", "stack": 2,
		"text": "x2.5 coins. Every wall I make another of me (2 share a slot). Sell me for 500 at a rest - if I've no room left, I knock your lighter out of your hand!"},
	"diamond_pick": {"name": "Diamond Pick",
		"text": "Only Slash and Tap moves show up - every other move is gone."},
	"familiar_circle": {"name": "Familiar Circle",
		"text": "Only the rhythm moves: circles, the moving circle and spinners. WARNING: HARD. x20 coins."},
	"dice_of_dwarves": {"name": "Dice of Dwarves",
		"text": "Rolls 2 dice every stage - good or very bad (every roll is in the Artifact Book). Your lighter going out costs a life: no relighting.",
		"book": "Rolls 2 dice every stage you clear:\n  2   every rock in the game!\n  3-4   walls need half the moves next stage\n  5-6   a free Extra Wick next stage\n  7-8   a random rock\n  9-10   1-100 coins\n  11   skip a stage\n  12   the run is OVER\nWhile you hold it, your lighter going out costs a life straight away - no relighting."},
	"coin_of_deceit": {"name": "Coin of Deceit",
		"text": "At any rest, flip it: heads doubles the coins you've earned this run, tails loses them. As often as you dare."},
	"ram": {"name": "Ram", "once": true,
		"text": "Press R (or the button) to ram through 3 walls at once. 2 uses, then it's gone."},
	"golden_apple": {"name": "Golden Apple",
		"text": "x2.5 coins."},
	"standard_gloves": {"name": "Standard Gloves",
		"text": "Your lighter gives 20% more light: flicks add more and it lasts longer."},
	"art_of_peace": {"name": "Art of Peace",
		"text": "No screen shaking, flashing or red edges bother you. x2 coins."},
	"philosophers_stone": {"name": "Philosopher's Stone",
		"text": "Every move you finish turns into Pebbles: as many as your combo, up to 10."},
	"sapphires_clover": {"name": "Sapphires Clover",
		"text": "Every stage you clear doubles ALL your rewards - and makes the mine 50% harder. Forever."},
	"minecart": {"name": "Minecart",
		"text": "Lose the run and you still take home 25% of its loot (coins, ores, rocks)."},
	"backpack": {"name": "Backpack",
		"text": "Lose the run and you still take home 30% of its loot (coins, ores, rocks)."},
	"great_ham": {"name": "Great Ham", "once": true,
		"text": "Press H (or the button) to eat it: +2 lives (never above your stage's lives)."},
	"fireflies": {"name": "Fireflies",
		"text": "1 in 7 moves, the fireflies finish it for you."},
	"miners_hat": {"name": "Miner's Hat",
		"text": "A lamp on your head lights up the wall around your cursor, even in the dark. (You still need to flick the lighter.)"},
	"mandrake": {"name": "Mandrake",
		"text": "SCREAMS every time it gets darker. Annoying - but +20% coins and rocks."},
	"spike_boots": {"name": "Spike Boots",
		"text": "Every move you finish counts twice: walls come down in half the moves."},
	"rapid_fire": {"name": "Rapid Fire",
		"text": "Everything in the mine runs 3x faster. Every reward x3."},
	"blackboard": {"name": "Blackboard",
		"text": "Every move turns into the alphabet: trace the letters to crack them into the wall (lift your pen whenever you like). 1 letter, then 2, 3, up to 4 - against the clock.",
		"book": "Every move turns into writing the alphabet - no other moves show up. Trace each letter to crack it into the wall; you can let go and carry on whenever you like, any stroke in any order. Off the letter while pressing is a stray. Its timer is your wick: 1 letter on the first stages, then 2, 3 and at most 4. The clock gets faster every stage, and each time a letter is added it resets to something more forgiving - but never quite as slow as before."},
	"pet_rock": {"name": "Pet Rock",
		"text": "At a rest, feed it 1000 coins' worth of rocks from your bag for +1 life. After 3 feeds it wanders off."},
}
## Used-up artifacts (once: true, and Ram / Pet Rock once they're spent) aren't offered again for CONSUMABLE_COOLDOWN
## stages, unless you pay CONSUMABLE_UNLOCK_COST of the coins you've earned this run (at a rest) to bring them back.
const CONSUMABLE_COOLDOWN := 5  # configurable  (stages)
const CONSUMABLE_UNLOCK_COST := 0.5  # configurable  (part of this run's coins)
## An artifact you swap out (slots full, you take a new one in its place) isn't offered again for this many
## stages. Paying to bring used-up ones back doesn't bring these back.
const SWAP_COOLDOWN := 5  # configurable  (stages)
const CATS_EYES_MISS_WICK := 0.25  # configurable  (part of the whole wick each messed-up move burns: 0.25 = 4 in a row and it's gone)
const PHILOSOPHERS_MAX := 10  # configurable  (most Pebbles one move can give, in all - extra stones and reward multipliers don't raise it)
const CLOVER_REWARD := 2.0  # configurable  (rewards x this for every stage cleared while you hold it)
const CLOVER_HARDER := 1.5  # configurable  (the mine x this much harder for every stage cleared: faster light / wick, stricter moves)
const MINECART_KEEP := 0.25  # configurable  (part of the run's loot you keep if the run is lost)
const BACKPACK_KEEP := 0.30  # configurable
const GREAT_HAM_LIVES := 2.0  # configurable
const GREAT_HAM_KEY := KEY_H  # configurable
const FIREFLIES_CHANCE := 100.0 / 7.0  # configurable  (% of moves they finish for you)
const MINERS_HAT_RADIUS := 170.0  # configurable  (px of light around your cursor)
const MANDRAKE_BONUS := 1.2  # configurable  (coins and rocks x this)
const SPIKE_BOOTS_COUNT := 2  # configurable  (each finished move counts this many times)
const RAPID_FIRE_SPEED := 3.0  # configurable  (the mine runs this many times faster)
const RAPID_FIRE_REWARD := 3.0  # configurable
const PET_ROCK_PRICE := 1000  # configurable  (coins' worth of rocks (at today's shop prices) for one life)
const PET_ROCK_FEEDS := 3  # configurable  (then it's gone)
## Dice of Dwarves: what a 9-10 pays (random coins, x rewards)
const DICE_COINS := Vector2i(1, 100)  # configurable
const DRUNK_FLICK_ZONE := 1.6  # configurable  (the FLICK bar's gold zone this much bigger)
const DRUNK_WICK := 1.5  # configurable  (wick lasts this much longer)
const DRUNK_HARDER := 0.8  # configurable  (moves: tolerances / time x this)
const ROCK_ARTIFACTS := {"ring_of_luck": 25.0, "hand_drill": 12.5, "excavator": 50.0, "miners_permit": 100.0}  # configurable  (% per move)
const GAMBIT_HARDER := 2.0  # configurable  (Death's Gambit: light and wick burn this many times faster, moves this much stricter)
const GAMBIT_REWARD := 10.0  # configurable
const MUSHROOM_WALLS := Vector2i(2, 3)  # configurable
const WALL_BREAKER_WALLS := 2  # configurable  (Wall Breaker: walls each stage needs, minus this - never below 1)
const UMBRELLA_EVERY := Vector2(5.0, 9.0)  # configurable  (seconds between falling gems)
const UMBRELLA_HIT_CHANCE := 25.0  # configurable  (%)
const UMBRELLA_BREAK_CHANCE := 50.0  # configurable  (% a gem that misses you shatters)
const DROPPED_LIGHTER_TIME := 3.0  # configurable  (seconds to pick your lighter back up)
const MOLERATS_PAY := 1.5  # configurable
const DRAUPNIR_SELL := 500  # configurable
const DRAUPNIR_COINS := 2.5  # configurable  (x coins while you hold any Draupnir)
const DIAMOND_PICK_MOVES := ["slash", "tap"]  # configurable
const FAMILIAR_MOVES := ["tap", "track", "spin"]  # configurable
const FAMILIAR_COINS := 20.0  # configurable
const FAMILIAR_HARDER := 0.75  # configurable
const RAM_USES := 2  # configurable
const RAM_WALLS := 3  # configurable
const RAM_KEY := KEY_R  # configurable
const GOLDEN_APPLE_COINS := 2.5  # configurable
const STANDARD_GLOVES_LIGHT := 1.2  # configurable
const ART_OF_PEACE_COINS := 2.0  # configurable
## Greed + Is Good in the same run: both vanish and you get one more item slot for the rest of the run
## (and they stop showing up).
const GREED_IS_GOOD_SLOTS := 1  # configurable
const MIDAS_MAX := 250.0  # configurable
const MIDAS_PER_3_MOVES := 0.25  # configurable
const MIDAS_PER_WALL := 1.0  # configurable
const MIDAS_PER_STAGE := 3.0  # configurable
const DYNAMITE_MAX := 2  # configurable
const DYNAMITE_KEY := KEY_D  # configurable
const HARD_AS_NAILS_CHANCE := 50.0  # configurable  (%)
const ADRENALINE_CHANCE := 50.0  # configurable  (%)
const STRONGER_FLUIDS_GAIN := 0.34  # configurable  (each good flick adds at least this much light: 0.34 = full in 3)
const BEGINNERS_LUCK_EASE := 1.35  # configurable  (moves this much slower; hit areas and line tolerance this much bigger)
const DWARVEN_HANDS_CHANCE := 60.0  # configurable  (% per finished move)
## BLACKBOARD: every move becomes writing the alphabet (nothing else shows up): the letters are guide lines on the
## wall, and tracing one cracks it into the wall like any other move (no board shows up). You can
## lift the pen whenever you like and carry on (any stroke, any order, either way). Going off the letter while
## you press is a stray (the pen lifts, some wick). The move's timer is the wick: it burns down over the letters'
## time. Letters per move grow with your stage (stage + the cave's head start): BLACKBOARD_STAGES_PER_LETTER
## stages of 1 letter, then 2, 3, up to BLACKBOARD_MAX_LETTERS. Within a letter count the time per letter shrinks
## every stage (x BLACKBOARD_SPEEDUP); a new letter count resets it to more forgiving, but every reset starts
## a bit faster than the last (x BLACKBOARD_NEW_LETTER). With 3 / 3.5 / 0.85 / 0.85:
##   stage 1-3: 1 letter 3.5, 3.0, 2.5 s   -  4-6: 2 letters 6.0, 5.1, 4.3 s  -  7-9: 3 letters 7.6, 6.5, 5.5 s
##   10+: 4 letters 8.6, 7.3, 6.2, 5.3 s ... never under BLACKBOARD_LETTER_TIME_MIN a letter.
const BLACKBOARD_STAGES_PER_LETTER := 3  # configurable
const BLACKBOARD_MAX_LETTERS := 4  # configurable
const BLACKBOARD_LETTER_TIME := 3.5  # configurable  (seconds per letter at stage 1)
const BLACKBOARD_SPEEDUP := 0.85  # configurable  (time per letter x this every stage with the same letter count)
const BLACKBOARD_NEW_LETTER := 0.85  # configurable  (each new letter count starts this much faster per letter than the last one did)
const BLACKBOARD_LETTER_TIME_MIN := 1.1  # configurable  (seconds per letter, at the very fastest)
const BLACKBOARD_PERFECT_PART := 0.6  # configurable  (done within this part of the time with no strays = PERFECT)
const BLACKBOARD_HIT_RADIUS := 24.0  # configurable  (px round your pen that cracks the letter in (x the stage's move size))
const BLACKBOARD_OK_TOLERANCE := 58.0  # configurable  (px off the letter while pressing = a stray (x the move size))
const BLACKBOARD_FINISH := 0.9  # configurable  (part of each letter you must trace)
const BLACKBOARD_LETTER_HEIGHT := 230.0  # configurable  (px, the biggest a letter gets; smaller when 4 don't fit)
const BLACKBOARD_LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"  # configurable  (the letters it picks from)
## The Artifact Book's Tier List: the current META. Re-rank whenever the balance changes - move an id to
## another tier (best tier first; within a tier, best first). Artifacts in no tier show up as "?" (unranked).
const ITEM_TIERS := {  # configurable
	"S": ["midas_touch", "deaths_gambit", "sapphires_clover"],
	"A": ["miners_permit", "dwarven_hands", "draupnir", "golden_apple", "art_of_peace", "adrenaline_shot",
		"spike_boots", "wall_breaker", "dynamite"],
	"B": ["copy", "catto", "excavator", "rapid_fire", "familiar_circle", "ram", "defibrillator",
		"mushroom_of_might", "fireflies", "beginners_luck"],
	"C": ["blackboard", "diamond_pick", "molerats", "ring_of_luck", "backpack", "extra_wick", "stronger_fluids", "great_ham",
		"ladder", "pet_rock", "cats_eyes", "gilded_umbrella"],
	"D": ["standard_gloves", "torch", "dice_of_dwarves", "drunk", "minecart", "miners_hat", "hard_as_nails",
		"philosophers_stone"],
	"F": ["mandrake", "hand_drill", "little_light", "coin_of_deceit", "is_good", "greed"],
}
const TIER_COLORS := {  # configurable
	"S": Color("#e83b3b"), "A": Color("#f79617"), "B": Color("#f9c22b"), "C": Color("#91db69"),
	"D": Color("#4d9be6"), "F": Color("#9babb2"), "?": Color("#625565"),
}


# ------------------------------------------------------------------ MINING WALL  (left screen)
## Click the arrow on the left of the main screen to go to the wall. The wall asks for one
## ACTION at a time (tap, zigzag, slash, drill, pry). Finish it before the timer at the top runs
## out to keep your COMBO going; a bigger combo multiplies the coins you get.
## After a random number of actions the wall crumbles and a new one drops in.
const WALL_TILE_FILE := "res://assets/wall/wall_tile.png"  # configurable  (the tile repeated over the whole wall)
const WALL_TILE_SCALE := 3  # configurable  (32px tile x 3 = 96px on screen)
## Actions a wall needs: random MIN..MAX. The MAX grows by one every WALL_ACTIONS_MAX_EVERY stages (your stage +
## the cave's head_start), forever: stages 1-3 = 3-5, 4-6 = 3-6, 7-9 = 3-7, 10-12 = 3-8 ...
const WALL_ACTIONS_MIN := 3  # configurable
const WALL_ACTIONS_MAX := 5  # configurable  (the most on stages 1..WALL_ACTIONS_MAX_EVERY)
const WALL_ACTIONS_MAX_EVERY := 3  # configurable  (stages per +1 to the most; 0 = never grows)
## Nothing you have to tap, trace or click ever comes closer than this to the window's edges
## (buttons, circles, lines, the menu). The lighter is held from below, so it may run off the bottom.
const SAFE_BORDER := 16  # configurable  (px)
const WALL_RESPAWN_DELAY := 1.1  # configurable  (seconds the rubble falls before a new wall)
## After every wall (and every stage cleared) you get a break: nothing burns down until you click or
## press SPACE for the next wall.
const REST_BETWEEN_WALLS := true  # configurable
const SCREEN_SLIDE_TIME := 0.35  # configurable  (seconds to slide between screens)
const ACTION_GAP := 0.3  # configurable  (pause in seconds between two actions)

## How often each action shows up (bigger = more often, 0 = never).
const ACTION_WEIGHTS := {  # configurable
	"tap": 25,      # tap every ring on the wall
	"zigzag": 25,   # trace a zigzag line, like pickaxe swings
	"slash": 20,    # one big, fast swipe along a long line
	"drill": 15,    # spam-click the same spot
	"pry": 15,      # hold on the wedge, let go when the gauge is in the gold zone
	"track": 15,    # keep clicking a circle that drifts around the wall (a moving drill)
	"swirl": 15,    # trace a spiral from the outside in
	"bigslash": 12, # one huge, very fast swipe right across the wall
	"spin": 12,     # hold and spin your cursor round a circle, fast (like an osu! spinner)
	"nail": 14,     # Nail & Hammer: nails pop up all over the wall ("!" on both sides) - hammer every one, fast
}
## ("letters" - writing the alphabet - never shows up on its own: only the Blackboard artifact turns every move into it.)
## Which stage each move style starts showing up at (your stage + the cave's head_start, see CAVES).
## Stages 1-5 add one move each (stage 1 is only Slash); stage 6 brings in all the rest, Tap included
## (the circles are the hardest, so they're saved for later / the harder caves).
const ACTION_UNLOCK := {  # configurable
	"slash": 1, "zigzag": 2, "drill": 3, "pry": 4, "swirl": 5,
	"track": 6, "bigslash": 6, "spin": 6, "tap": 6, "nail": 4,
}
const NO_REPEAT_ACTION := true  # configurable  (true = never the same action twice in a row)

# --- combo
## (Actions have no timer of their own any more: your lighter's light is the timer, see LIGHT_DURATION.)
const COMBO_BONUS_PER_STEP := 0.5  # configurable  (each combo step adds +50% coins: x1, x1.5, x2 ... x5.5 at combo 10)
const COMBO_MAX_MULTIPLIER := 20.0  # configurable  (coin multiplier never goes above this: reached at combo 39)
## Every COMBO_MILESTONE in a row (10, 20, 30...) pays a bonus: COMBO_MILESTONE_COINS x (combo / COMBO_MILESTONE),
## times the mine's coin multipliers (cave, stage, Digging Expert, artifacts). Combo 10: 25, combo 20: 50 ...
const COMBO_MILESTONE := 10  # configurable
const COMBO_MILESTONE_COINS := 25  # configurable
const COMBO_NEEDS_PERFECT := false  # configurable  (true = a non-perfect action also resets the combo)
const COMBO_LOST_PER_FAIL := 1  # configurable  (combo each fail - a miss, a mistimed flick, a flood - knocks off; the light dying still loses it all)
const FLICK_FAIL_LOSES_COMBO := true  # configurable  (a mistimed flick (too soon / too late) or flooding the lighter costs combo too)

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
const LIGHTER_DIR := "res://assets/lighter/"  # configurable  (lighter_0.png = closed ... lighter_N.png = open, flame_0.png ... = the flame)
const LIGHTER_SCALE := 5  # configurable  (art pixels -> screen pixels; 5 = big, close to you)
const LIGHTER_POS := Vector2(334, 180)  # configurable  (bottom of the flame: px from the LEFT edge, px up from the BOTTOM)
const LIGHTER_SWAY := Vector2(14, 12)  # configurable  (px the lighter leans towards your mouse; 0 = never moves)
const TORCH_RAISE := 90.0  # configurable  (Torch artifact: px the torch - and its light - sits higher than the lighter)
const LIGHTER_GLOW_RADIUS := 300.0  # configurable  (px of extra light around the lighter itself)
const LIGHT_DURATION := 18.0  # configurable  (seconds for a full flame to fade out completely, at stage 1)
const LIGHT_STEPS := 6  # configurable  (the light fades in this many visible steps)
const RECHARGE_MIN := 3.0  # configurable  (% of light one flick adds back: random MIN..MAX - so you keep flicking)
const RECHARGE_MAX := 5.0  # configurable
const FLOOD_AT := 1.0  # configurable  (flicking during the steady full blaze floods it)
## TIMED FLICKS: the FLICK bar next to the lighter fills once per HEARTBEAT; a flick only adds light while
## the bar is in its gold zone (near the top). Spam it (too soon, or twice in one beat) or wait too long
## (too late) and the flick fails: no light, and it burns FLICK_FAIL_WICK_COST of your wick.
## The beat is your miner's heart rate (beats per minute), and it changes as you play:
##   every mistake (a miss, a stray click, a failed move, a mistimed flick, a flood) = +HEART_MISTAKE_BPM,
##   plus up to HEART_PANIC_BPM more the lower your wick is (about to lose = your heart spikes);
##   every HEART_CALM_FLICKS good flicks of the lighter = -HEART_CALM_BPM (striking it keeps you calm).
## It never drops below the stage's floor: the cave's "bpm" (CAVES) on stage 1, +HEART_STAGE_BPM every stage
## after that (Old Mine: 60, 65, 70 ...), and never goes over HEART_STRESS_BPM. It carries over between walls
## and stages (a new stage only lifts it to the new floor); a new run starts on the floor.
const HEART_REST_BPM := 60.0  # configurable  (a resting heart: the slowest the bar ever goes - 1 beat a second; also the Practice slider's lowest)
const HEART_STRESS_BPM := 180.0  # configurable  (a heart under stress: the fastest it ever goes)
const HEART_STAGE_BPM := 5.0  # configurable  (how much each stage raises the floor: stage 1 = the cave's bpm, stage 2 = +5 ...)
const HEART_MISTAKE_BPM := 1.0  # configurable  (beats per minute every mistake adds, with a full wick)
const HEART_PANIC_BPM := 2.0  # configurable  (extra a mistake adds as the wick burns down: + this x how much wick is gone; 0 = always just HEART_MISTAKE_BPM)
const HEART_CALM_FLICKS := 2  # configurable  (good flicks it takes ...)
const HEART_CALM_BPM := 1.0  # configurable  (... to calm your heart by this much)
const PRACTICE_BPM_STEP := 5.0  # configurable  (the Practice screen's heart rate slider moves in steps of this)
const FLICK_ZONE_CALM := 0.34  # configurable  (size of the gold zone (part of the bar) at a resting heart ...)
const FLICK_ZONE_STRESS := 0.24  # configurable  (... and at a heart under stress: a slower beat gets a bigger zone)
const FLICK_BEAT_SHAKE := 3.0  # configurable  (px the FLICK bar jolts on every heartbeat, more at a racing heart; 0 = never)
## After every wall (when you leave the break) the next wall drops in and the view zooms in on the FLICK
## bar for BEAT_PRACTICE_TIME seconds so you can feel your heartbeat (flicks don't count). It ends with a
## fast 3, 2, 1 (BEAT_COUNTDOWN numbers, BEAT_COUNTDOWN_STEP seconds each) with a screen flash each; after 1
## the moves start.
const BEAT_PRACTICE_TIME := 3.0  # configurable  (seconds in all, the countdown included: 2 s to feel the beat + the 1 s countdown; 0 = straight back to the game)
const BEAT_PRACTICE_ZOOM := 1.7  # configurable  (how big the FLICK bar gets while you practice)
const BEAT_PRACTICE_DIM := 1.0  # configurable  (how dark the whole game goes while you practice; 1 = all black, only the zoomed FLICK bar is on screen)
const BEAT_COUNTDOWN := 3  # configurable  (3, 2, 1; 0 = no countdown)
const BEAT_COUNTDOWN_STEP := 1.0 / 3.0  # configurable  (seconds each number of the countdown is up: 1/3 = the whole 3, 2, 1 in one second; 1 = a calm second each)
const BEAT_ZOOM_TIME := 0.18  # configurable  (seconds the zoom in to the FLICK bar, and back out, takes)
## An "Okay" button (or ENTER) skips the practice straight to the 3, 2, 1. Settings > Beat practice: Off
## always skips it (you still get the countdown and see your new BPM).
const COUNTDOWN_SHAKE := 6.0  # configurable  (px the screen shakes on each number; 0 = none)
const COUNTDOWN_RED := 0.6  # configurable  (how strong the red stress edges come in on each number; 0 = none)
## DEEP FOCUS: this many PERFECT moves in a row turns your flame blue. Anything less than PERFECT (or any
## fail: a miss, a mistimed flick, a flood) breaks the streak and the flame goes back to normal.
const DEEP_FOCUS_PERFECTS := 5  # configurable
const DEEP_FOCUS_COLOR := Color("#7fc8ff")  # configurable  (the "DEEP FOCUS!" text; the flame itself is your flame art turned blue)
const FLICK_ZONE_END := 0.94  # configurable  (the gold zone ends here on the bar; above it is "too late")
## A slow bar means fewer flicks, so each good flick gives more light: hitting every flick brings the light
## back FLICK_GAIN times as fast as it fades, whatever the tempo (but never less than RECHARGE_MIN..MAX %).
const FLICK_GAIN := 1.8  # configurable  (1.0 = perfect flicking only just keeps up; higher = easier)
const FLICK_FAIL_WICK_COST := 0.06  # configurable  (wick a mistimed flick burns)
const FLICK_BAR_HEIGHT := 200.0  # configurable  (px)
const FLICK_BAR_POS := Vector2(30, 205)  # configurable  (the bar's bottom-left corner: px from the LEFT edge, px up from the BOTTOM - above the lighter)
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
## A new stage starts (after its 3, 2, 1): the flame flares up BLUE and huge to hype you up, then settles back.
const STAGE_HYPE_TIME := 1.8  # configurable  (seconds the whole flare takes; 0 = off)
const STAGE_HYPE_SCALE := 2.4  # configurable  (how many times bigger the flame gets at its peak)
const FLOOD_LIFE_COST := 0.5  # configurable  (lives a flood costs: half a life)
const LIGHTER_KEY := KEY_SPACE  # configurable  (key to flick the lighter; clicking / tapping the lighter works too - that's how phones do it)
const START_FLICKS_MIN := 3  # configurable  (flicks before the flame catches when you light it up: random MIN..MAX)
const START_FLICKS_MAX := 5  # configurable
const WALL_MARGINS := Vector4(140, 150, 120, 110)  # configurable  (px kept free at the wall's left, top, right, bottom: HUD, the Back button, wick gauge, edges)
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
## Every stage gives you LIVES lives. Break its walls to clear it and go up a stage: WALLS_PER_STAGE on the first
## stages, one more every WALLS_PER_STAGE_EVERY stages (stages 1-5 = 3 walls, 6-10 = 4, 11-15 = 5 ...).
## Losing a life (lighter not relit in time) restarts the stage from its first wall - your stage
## is a checkpoint. Lose all your lives before clearing it and you drop down a stage.
const LIVES := 3  # configurable
const MAX_LIVES := 5.0  # configurable  (hard cap: you can NEVER have more lives than this, Pack of Fluid included)
const WALLS_PER_STAGE := 3  # configurable  (walls stage 1 needs)
const WALLS_PER_STAGE_EVERY := 5  # configurable  (one more wall every this many stages; 0 = never more)
const LOSS_RESTARTS_STAGE := true  # configurable  (false = losing a life keeps the walls you already broke this stage)
## Each stage up, things get harder - and pay more:
const STAGE_FUEL_STEP := 0.07  # configurable  (light fades 7% faster each stage; tap rings close 7% faster too)
const STAGE_FUEL_MIN := 0.45  # configurable  (never below 45% of stage 1)
const STAGE_RELIGHT_EVERY := 2  # configurable  (one more good strike needed to relight every N stages)
const STAGE_COIN_BONUS := 0.25  # configurable  (+25% coins from the wall for every stage above 1)

# --- coins
const PERFECT_COINS_MIN := 3  # configurable  (coins for a PERFECT action: random MIN..MAX, then x combo)
const PERFECT_COINS_MAX := 6  # configurable
const GOOD_COINS := 1  # configurable  (coins for an action that was finished but not perfect, x combo)
const WALL_BREAK_BONUS := 0  # configurable  (extra coins when the wall comes down)

# --- tap  (closing circles: tap each circle right when its ring closes in on it)
## Circles pop up one after another. Each has a ring that shrinks onto it; tap the circle the moment
## the ring touches it. Some rings close fast, some slow, so they don't close in the order they appear:
## watch the rings and tap whichever closes first. (Tap actions are timed by their circles, not ACTION_TIME.)
const TAP_COUNT_MIN := 3  # configurable  (circles: random MIN..MAX)
const TAP_COUNT_MAX := 6  # configurable
## MOVE SIZE: circles and lines start big and forgiving, and shrink the deeper a run goes. Every circle's
## size (and how close a click must be) and every line's wiggle room (the *_TOLERANCE values, corner rings,
## start dots) is x this. Stage 1 = MOVE_SIZE_START; each stage takes MOVE_SIZE_STEP off (smoothly, wall by
## wall) until MOVE_SIZE_MIN. With 1.35 / 0.05 / 0.75: x1.35 at stage 1, normal (x1) at stage 8, smallest at 13.
const MOVE_SIZE_START := 1.35  # configurable  (practice and the tour always use this)
const MOVE_SIZE_STEP := 0.05  # configurable  (taken off for every stage you go down)
const MOVE_SIZE_MIN := 0.75  # configurable  (the smallest / strictest it gets)
const TAP_RADIUS := 38.0  # configurable  (px, size of a circle)
const TAP_APPROACH_MIN := 0.65  # configurable  (seconds a FAST ring takes to close)
const TAP_APPROACH_MAX := 1.8  # configurable  (seconds a SLOW ring takes to close)
const TAP_APPROACH_SIZE := 3.0  # configurable  (the ring starts this many times bigger than the circle)
const TAP_GAP_MIN := 0.3  # configurable  (seconds between one ring closing and the next: random MIN..MAX)
const TAP_GAP_MAX := 0.65  # configurable
const TAP_PERFECT_WINDOW := 0.1  # configurable  (tap within +/- this many seconds of the ring closing = PERFECT)
const TAP_GOOD_WINDOW := 0.22  # configurable  (within this = Good; later and the circle is missed)
const TAP_NEXT_LINE := true  # configurable  (lines from circle to circle in the order they close: long dashes to the NEXT one, dots after that)
const TAP_SPACING := 4.5  # configurable  (circles stay at least this many radii apart, so their closing rings and lines don't pile up)
const TAP_SPAWN_GAP := 0.15  # configurable  (seconds: each circle appears at least this long after the one before it, so the first to show is the first to tap)
## Settings > Coloured circles: each tap circle gets its own colour, in the order they close.
const TAP_COLORS := [Color("#ffd166"), Color("#5ec8ff"), Color("#ff6b9a"), Color("#7bd65a"), Color("#c08cff"), Color("#ff9a3c")]  # configurable
const TAP_EARLY_IGNORE := 0.45  # configurable  (taps MORE than this early are ignored ("Wait for it!"); between this and GOOD = "Too early!", circle missed)

# --- zigzag (careful tracing) and slash (one fast swipe)
const SLICE_START_RADIUS := 40.0  # configurable  (how close to the start dot you must press)
const SLICE_FINISH := 0.93  # configurable  (how much of the line you must trace, 0.93 = 93%)
const ZIGZAG_CORNERS_MIN := 3  # configurable  (number of turns: MIN..MAX on the easy stages ...)
const ZIGZAG_CORNERS_MAX := 7  # configurable
const ZIGZAG_CORNERS_PER_STAGE := 0.5  # configurable  (... the most goes up by this every stage ...)
const ZIGZAG_CORNERS_CAP := 11  # configurable  (... up to this many turns)
const ZIGZAG_LENGTH_MIN := 220.0  # configurable  (px, start to end: short ...)
const ZIGZAG_LENGTH_MAX := 780.0  # configurable  (... to long)
const ZIGZAG_STEP_MIN := 55.0  # configurable  (px of length each turn needs at least, so many turns make a longer zigzag)
const ZIGZAG_WIDTH := 80.0  # configurable  (px the zigzag swings to each side ...)
const ZIGZAG_WIDTH_VARY := Vector2(0.6, 1.4)  # configurable  (... times a random MIN..MAX: narrow to wide)
const ZIGZAG_CURVE_CHANCE := 35.0  # configurable  (% of zigzags bent into an arch)
const ZIGZAG_ROUND_CHANCE := 30.0  # configurable  (% of zigzags with smooth, rounded turns instead of sharp ones)
const ZIGZAG_MIN_GAP := 36.0  # configurable  (px legs of a zigzag must stay apart, so they never stack on each other)
const ZIGZAG_MIN_ANGLE := 30.0  # configurable  (degrees; the sharpest a turn may be, so its two legs don't overlap)
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

# --- swirl (trace a spiral from the glowing dot on the outside to the middle)
const SWIRL_TURNS_MIN := 1.5  # configurable  (times round)
const SWIRL_TURNS_MAX := 2.5  # configurable
const SWIRL_RADIUS_MIN := 110.0  # configurable  (px, size of the outer loop)
const SWIRL_RADIUS_MAX := 180.0  # configurable
const SWIRL_INNER_RADIUS := 24.0  # configurable  (px, where it ends in the middle)
const SWIRL_PERFECT_TOLERANCE := 16.0  # configurable  (px you may stray and still be PERFECT)
const SWIRL_OK_TOLERANCE := 38.0  # configurable  (px; stray further and it's a MISS)
const SWIRL_LOOKAHEAD := 45.0  # configurable  (px of line ahead of you that counts)
const SWIRL_CRACK_WIDTH := 2  # configurable

# --- big slash (one huge, fast swipe right across the wall, edge to edge)
const BIGSLASH_SWIPE_TIME := 0.7  # configurable  (seconds from pressing to finishing)
const BIGSLASH_CURVE := 0.25  # configurable  (how bendy it can be, part of the wall's height)
const BIGSLASH_PERFECT_TOLERANCE := 34.0  # configurable
const BIGSLASH_OK_TOLERANCE := 80.0  # configurable
const BIGSLASH_LOOKAHEAD := 140.0  # configurable

# --- spin (hold the mouse button and spin round the circle, both ways count; wiggling back doesn't)
const SPIN_TURNS_MIN := 3.0  # configurable  (turns needed: random MIN..MAX, in half turns)
const SPIN_TURNS_MAX := 5.0  # configurable
const SPIN_TIME := 3.5  # configurable  (seconds from your first press; too slow = miss, try again. Shorter on later stages)
const SPIN_PERFECT_PART := 0.6  # configurable  (finish within this part of SPIN_TIME = PERFECT)
const SPIN_RADIUS := 110.0  # configurable  (px, the circle drawn on the wall)
const SPIN_CHUNK_SIZE := 0.9  # configurable  (the chunk that comes out of the wall when you finish a spin, part of SPIN_RADIUS)
## The wall breaks up as you go: every finished move runs cracks in from its edges (more, longer and thicker
## the closer it is to coming down), and from WALL_CHUNKS_FROM of the way chunks start falling out.
const WALL_DAMAGE_CRACKS := 2.0  # configurable  (extra cracks per move by the end)
const WALL_CHUNKS_FROM := 0.45  # configurable  (part of the wall's moves done before chunks fall out; above 1 = never)
const SPIN_DEAD_ZONE := 25.0  # configurable  (px; right in the middle it can't tell which way you turn)

# --- track (a moving drill: keep clicking the circle as it drifts around)
const TRACK_RADIUS := 52.0  # configurable  (px)
const TRACK_CLICKS_MIN := 8  # configurable
const TRACK_CLICKS_MAX := 14  # configurable
const TRACK_SPEED := 170.0  # configurable  (about how many px per second it drifts at stage 1; faster later)
const TRACK_MISS_WICK_COST := 0.05  # configurable  (wick a click that misses it burns; small, it's hard to follow)

# --- nail (Nail & Hammer: a grid of nails pops up all over the wall with "!" flashing on both sides of the
## screen. Click every nail - any order - as fast as you can. The clock starts at your first hit; run out of time
## and the nails pop back up (start again). A click that hits no nail is a stray: no PERFECT, some wick.)
const NAIL_LAYOUTS := [Vector2i(3, 3), Vector2i(5, 3), Vector2i(7, 1)]  # configurable  (columns x rows: 3x3, 5x3 or a line of 7, one at random)
const NAIL_RADIUS := 30.0  # configurable  (px, how close a click must be to a nail head (x the stage's move size))
const NAIL_TIME_BASE := 0.8  # configurable  (seconds you get on top of the time per nail)
const NAIL_TIME_PER_NAIL := 0.5  # configurable  (seconds per nail after the first, at stage 1; less on later stages, like the tap rings)
const NAIL_TIME_PER_NAIL_MIN := 0.34  # configurable  (never less than this per nail)
const NAIL_WICK_SPARE := 2.5  # configurable  (the wick always lasts the nails' clock + this many seconds: time to reach the first one, one restart)
const NAIL_PERFECT_PART := 0.65  # configurable  (all of them within this part of the time, no stray clicks = PERFECT)
const NAIL_ALERT_SIZE := 72  # configurable  (font px of the "!" on both sides of the screen; 0 = none)

# --- drill
const DRILL_CLICKS_MIN := 8  # configurable  (clicks needed: random MIN..MAX)
const DRILL_CLICKS_MAX := 15  # configurable
const DRILL_RADIUS := 55.0  # configurable  (px; clicks further away don't count and spoil PERFECT)

# --- pry
const PRY_RADIUS := 55.0  # configurable  (px, where you must press)
const PRY_FILL_TIME := 1.4  # configurable  (seconds for the gauge to fill up; at full it snaps = miss)
const PRY_ZONE_MIN := 0.3  # configurable  (gold zone starts somewhere between MIN and MAX of the gauge)
const PRY_ZONE_MAX := 0.78  # configurable
const PRY_ZONE_SIZE_MIN := 0.12  # configurable  (size of the gold zone = PERFECT: random MIN..MAX)
const PRY_ZONE_SIZE_MAX := 0.18  # configurable
const PRY_GOOD_MARGIN := 0.1  # configurable  (just outside the gold zone still counts, but not perfect)
## Every pry is a bit different, so it's never the same spot on the ring:
const PRY_RANDOM_START := true  # configurable  (the gauge starts anywhere round the ring, not always at the top)
const PRY_REVERSE_CHANCE := 0.5  # configurable  (chance it fills anticlockwise)
const PRY_SPEED_MIN := 0.75  # configurable  (fill time x MIN..MAX: some pries are quick, some slow)
const PRY_SPEED_MAX := 1.3  # configurable
## How the gauge moves (bigger = more often, 0 = never). The style is shown under the wedge.
const PRY_STYLES := {  # configurable
	"steady": 40,    # the same speed all the way round
	"speedup": 20,   # starts slow, gets faster
	"slowdown": 20,  # starts fast, slows down
	"stutter": 20,   # jumps forward in bursts, with little stops in between
}

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
	"scream": {"db": -8.0, "pitch_var": 0.15},  # Mandrake: every time the light steps darker
	"supernova": {"db": -2.0, "pitch_var": 0.0},  # Crush All: charge up, implode, boom (the boom is 1.75 s in)
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
const GAME_OVER_COLOR := Color("#ff6a3d")  # configurable  ("YOU HAVE NO MORE FUEL")
const GAME_OVER_DELAY := 1.2  # configurable  (seconds after the run is lost before the game over screen comes up)
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
const SHOW_TUTORIAL := true  # configurable  (short tips pop up as you play, once each; the "?" button always has a short tour)


# ------------------------------------------------------------------ SAVE
const SAVE_ENABLED := true  # configurable
const RESET_SAVE_ON_START := false  # configurable  (true = always start a fresh game; handy while tuning)
