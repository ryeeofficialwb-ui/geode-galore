# Geode Galore

Buy rocks, smash them open, sell the ores and gems inside, and go down the mines for more.

## Download & play (Windows)

### **[⬇ Download Geode Galore](https://github.com/ryeeofficialwb-ui/geode-galore/releases/latest/download/GeodeGalore-Windows.zip)**

1. Click the link above: `GeodeGalore-Windows.zip` downloads (about 13 MB).
2. Right-click the zip > **Extract All**.
3. Open the **Geode Galore** folder and double-click **GeodeGalore.exe**.

If Windows says *"Windows protected your PC"*, click **More info** > **Run anyway** (the game just isn't
signed by a big company).

**That's it - you never download it again.** Every time you open the game it checks for a new version and
updates itself (it closes and reopens once). Your save is kept. No internet? It just opens as it is.

(c) 2026 ryeeofficialwb-ui. All rights reserved. See [LICENSE](LICENSE).

---

## For the developer

(Geode Galore was called *Rich From Rocks* until Indev 0.3. Some files keep the old name - `RichFromRocks.exe` in
old installs, the update packs, the save folder - so updates and saves carry over.)

Buy rocks, smash them open (3-5 clicks, random), find ores and gems, sell them, buy better rocks.
Short on coins? Click **< Mine** on the left to go to the mining wall and earn coins with quick mining actions
(you need a **ticket** for one of the **caves**: Shop > Caves).

**Screens**
- **Top bar:** coins, your mine **tickets**, **Shop** (four tabs: **Rock Shop**, **Dwarven Shop**, **Caves** and **Stock Prices**), the **Backpack** icon (your ores & gems, sell them here; the number next to it is how many you carry), the **Settings** gear (sound on/off, music volume, sound-effect volume, hint text, tips, reset), **?** (a short tour).
- **Practice** (under the Mine arrow): pick any activity - every move, lighter flicking or relighting - and play it as long as you like. No lighter to look after, no ticket, no lives, and **no coins**. Back puts the mine back exactly as you left it.
- **Tips as you play:** no long tutorial up front. The first time something happens (your first rock, first sale, running out of rocks, your first trip down the mine, each move style the first time it shows up, your light getting low, the lighter going out, your first lost life) a short tip pops up **once**, with a spotlight on what it's about; the mine pauses while it's up. **No more tips** (or Settings > Tips) turns them off. **?** plays a short 6-step tour (you can try the lighter and a move with no timer). Old saves that finished the old tutorial only get tips for the new moves.
- **Main screen:** the rock in the middle, **Your Rocks** on the right, **< Mine** arrow on the left.
- **Shop > Stock Prices:** today's price of every ore, gem and rock, its % of normal, how it moved at the
  last restock and its **profit** (ores: coins above / below the normal price; rocks: what's inside on average minus
  the price). The **Sort** button orders the list from least to most profit (click again: most to least). Click anything for its page: what it sells for, chances, the 3 best rocks to find it in (your
  upgrades included) and its **lore** (`ORE_LORE` in `config.gd`, write your own); for rocks, what's inside is worth
  on average at today's prices.
- **Settings > Hint text:** turn off the helper texts (the rock hint, "Click one to put it on the anvil", the
  ticket and market notes, each wall action's instruction line, the "Flick SPACE..." / "Hit SPACE..." prompts).
- **Market (supply & demand):** every time the shop restocks on its timer (every 5 minutes) demand shifts: every
  rock's shop price and every ore / gem's sell price moves up or down from where it was, drifting back towards
  normal over time. A price can never go above **200%** or below **10%** of its normal price. The Shop, Market and
  Backpack colour prices **green when they're good for you** and **red when bad**: ores & gems are green above
  normal (you sell for more), rocks are green below normal (cheaper to buy). Paying to restock early gives new
  rocks but doesn't move the market, and **every paid restock costs x2.5 more** than the one before (25, 63, 156...)
  until the shop restocks by itself again (`INSTANT_RESTOCK_GROWTH`). Shop > Stock Prices shows a countdown to the
  next price change.
- **Caves** (third tab of the Shop): six caves, each with its own wall, its own **tickets** and its own **stage**
  checkpoint (`CAVES` in `config.gd`). One ticket = one **trip** down that cave, which lasts until you run out of
  lives (then you're sent back up; going Back to your rocks doesn't end it). Claim a **free Old Mine ticket every
  10 minutes**, or buy tickets (Old Mine 100 coins ... Crystal Grotto 6500). Deeper caves pay more coins but your
  light fades faster. **Clearing a stage** has a **1-5%** chance (by cave) of finding a **pile of 5 rocks** - any
  rock type - and **0-3 of them** make it into Your Rocks (`STAGE_ROCK_ROLLS`, `STAGE_ROCK_KEEP`, `STAGE_ROCK_MAX`).
  **< Mine** opens **Select Mine**: every cave with your tickets, Buy ticket and Go down (and the free ticket).
  On a trip your cave's row says **Continue**. (The ? tour's visit to the wall is free.)
- **Dwarven Shop** (second tab of the Shop):
  - **Upgrades** (level 1 gives exactly the first number, the last level exactly the max, a smooth curve in
    between):

    | Upgrade | Level 1 | Max (lv 250) | What it does |
    |---|---|---|---|
    | **Miner's Favor** | +1% | +90% | ore drop chance (each level adds a bit less) |
    | **Jeweler's Favor** | +1% | +90% | gem drop chance |
    | **Rocky Riches** | +0.25% | +200% (x3) | ores per drop, ores only; a fraction is a chance of one more |
    | **Digging Expert** | +2.5% | +400% | coins from the mining wall |
    | **Fool's Gold** | 0.2% | 20% | chance a sale (one Sell / All / each ore in Sell Everything) pays **+15%** |
    | **Heat of the Forge** | +0.04% | +10% | light each good lighter flick gives |
    | **Pack of Fluid** (20 levels, expensive) | +0.1 | +2 lives | extra lives every stage: half a life every 5 levels, 3 -> 5 lives at Lv 20. Lives can never go above `MAX_LIVES` (5) |
    | **Silktouch** | 0.08% | 20% | chance a rock you break doesn't break: you get its drops AND keep the rock |
    | **Ticket Hungry** (50 levels) | 0.1% | 3% | chance clearing a stage gives a ticket for a random cave |

    Costs start at 30-150 coins and grow 2.2% per level (Pack of Fluid: 2500, +25% per level; Ticket Hungry +8%);
    all in `UPGRADES` in `config.gd`.
- **Mining wall (left screen):** it's dark in the mine. You hold a big **lighter** at the bottom left like a torch.
  While it's lit the **whole wall is lit**, but the flame slowly fades and the wall gets darker in steps: **the light
  level is your timer** (there's no bar). Every flick of **SPACE** (or click / tap on the lighter) only adds **3-5%**
  light back, so you keep flicking while you do the actions, and the **flame shrinks** as the light dies. When it
  reaches **full blaze** the lighter jolts, the screen flashes, and it burns steady for a random **3-10 seconds**
  before it starts dying again. Flick it during that steady blaze and you **flood** it: **half a life** gone.

  **The wick (why flicking alone isn't enough):** flicks can only bring the light back up to your **wick**. While an
  action is waiting on you, the wick burns down (full to nothing in 12 s at stage 1), so the wall keeps getting
  darker however much you flick ("Wick's burnt down - finish it!"). **Only finishing an action restores the wick**,
  and every sloppy motion (off the line, a missed circle, a stray click) burns a chunk of it. If the wick burns
  out, the lighter dies and your combo goes with it. The **WICK** gauge in the bottom-right corner shows how much is left
  (a braided wick burning down with an ember on top; its frame flashes red when it's nearly gone).

  **Timed flicks:** a flick only adds light if it's **timed**. The **FLICK** bar next to the lighter charges up from the
  bottom; flick when it reaches the **gold zone** near the top ("FLICK!"). Too soon (spamming) or too late fails:
  no light, a red flash, and it **burns some wick** (`FLICK_FAIL_WICK_COST`). Every minigame charges the bar at its
  own tempo (`FLICK_TEMPO`): pry is slow (1.5 s, the easiest to flick well), zigzag steady, drill and tap quick,
  slash very fast (0.36 s, about a 0.1 s window). A slow bar gives fewer flicks, so each good flick gives more light:
  timed perfectly, flicking brings the light back 1.8x as fast as it fades at any tempo (`FLICK_GAIN`), and never
  less than 3-5% a flick. So you choose: take your time on a slow one and flick up lots of
  light, or rush the fast ones because flicking there is hard - and relighting is harder. Later stages speed the
  bar up a bit (`FLICK_STAGE_SPEEDUP`). While the flame is at full blaze the bar shows FULL (flicking floods it).

  **About to lose?** The lighter starts to tremble (hard) and a red border throbs in from the screen edges like a heartbeat when the wick or the light drops below 30%, or in the last 2
  seconds of the relight countdown, and shakes harder the closer you get. If the light fades all the way, your combo is lost and the lighter goes out.
  When you arrive (and after losing a life) the lighter is shut: flick it a few times (3-5) until the flame catches.
  **On phones there's no SPACE: tap the lighter.** On PC both work. The wall asks for one action at a time:
  | Action | What you do |
  |---|---|
  | **TAP!** (stage 6+) | circles pop up, each with a ring closing in on it; tap each circle the moment its ring touches it. Rings close at different speeds, so tap whichever closes **first** (too early / too late misses that circle). A dotted line points from the circle closing now to the next one |
  | **ZIGZAG!** (stage 2+) | press the glowing dot and crack along the zigzag, passing **every corner** (cutting straight across doesn't work) |
  | **SLASH!** (from stage 1: the first move) | one big, fast swipe along a long line (you have under a second once you press) |
  | **DRILL!** (stage 3+) | spam-click the same spot until the counter hits 0 |
  | **PRY!** (stage 4+) | hold on the wedge; a gauge fills; let go while it's in the **gold zone** (too long and it snaps). Every pry is different: the gauge starts anywhere round the ring, goes either way (the arrow), at its own speed, and may **speed up**, **slow down** or **stutter** (written under the wedge; `PRY_STYLES`) |
  | **TRACK!** (stage 6+) | a moving drill: keep clicking the circle as it drifts around the wall |
  | **SWIRL!** (stage 5+) | trace the spiral from the glowing dot on the outside into the middle (no cutting across) |
  | **SLASH IT ALL!** (stage 6+) | one huge, very fast swipe right across the wall, edge to edge |
  | **SPIN!** (stage 6+) | hold the button and spin your cursor round the circle, fast (like an osu! spinner); finish within the time shown |

  **Scaling difficulty:** the further you get, the more actions each wall takes (+1 every 2 stages, up to +6) and
  the more move styles show up: stages 1-5 add one each (Slash, Zigzag, Drill, Pry, Swirl), stage 6 brings in
  the rest (Track, Slash It All, Spin and Tap). The stage numbers are `ACTION_UNLOCK`. Pricier caves have a **head start**
  (Shale Hollow +1 ... Crystal Grotto +5), so you meet every move sooner there - the Crystal Grotto has them all
  from stage 1. Finishing a move makes the WICK gauge flash REFILLED!, and while it burns it says "Finish the move
  to refill it" (Settings > Hint text). In the mine you only see the cave: the top menu slides away, and nothing you have to hit ever
  comes within 16 px of the window's edges (`SAFE_BORDER`).

  Everything you do leaves pixel-art cracks in the wall, on the wall tile's own pixel grid.
  Clean work = **PERFECT** (1-3 coins). Every finished action raises your **COMBO**; each combo step
  gives +25% coins (x1, x1.25, x1.5 ... up to x5). After a random number of actions the wall crumbles and a new one
  drops in. **Back >** on the right returns to the rocks (the wall waits). Each screen has its own music.

  **Lighter out:** when the light dies (or you miss every circle) you lose the combo and the lighter goes out with it.
  To relight it, a marker sweeps back and forth along a track: strike **SPACE** while it's in the **gold zone**.
  Every good strike drops the bar on the right one step, but the marker gets 30% faster and the zone 20% smaller.
  A mistimed strike pushes the bar back up. Empty the bar (4 strikes at stage 1) within **5 seconds** or you
  **lose a life** and the stage starts over on its first wall. It's meant to be hard: roughly 1 save in 4-6 for a
  sharp player, and much less once later stages add strikes.

  **Stages:** each stage gives you **3 lives** (shown as lighters, top right; a half-dark lighter = half a life).
  Not relighting in time costs a whole life and restarts the stage; flooding costs half a life and doesn't. Break
  **3-5 walls** (rolled for each stage, shown at the top: `WALLS_PER_STAGE_MIN` / `_MAX`) to clear the stage and go up. After every wall (and every stage cleared) you get a **break**: nothing
  burns down until you click or press SPACE for the next wall (`REST_BETWEEN_WALLS`). Your stage is a checkpoint, but lose all 3 lives before clearing it and you
  **drop down a stage**. Every stage up pays **+25% coins**
  from the wall, but the light fades 7% faster (and tap rings close faster), and relighting takes one more strike every 2 stages.
  Stage, lives and progress are shown at the top of the wall and are saved.

**Run it:** open the folder in Godot 4.7 and press **Play** (F5).
**Play it:** download `RichFromRocks-Indev-0.1-windows.zip` from the GitHub Releases, unzip, run `RichFromRocks.exe`.
It updates itself (see "Versions & auto-update" below).

---

## 1. Changing the game: `scripts/config.gd`

All settings live in **one file**: [`scripts/config.gd`](scripts/config.gd).
Every line you can change ends with `# configurable`. Save the file and press Play.

| Section | What you can change |
|---|---|
| Breaking rocks | `HITS_MIN` / `HITS_MAX` (default 3-5), `LUCK_MULTIPLIER`, auto-place the next rock |
| Cracks | crack color, highlight color, cracks per hit, crack length |
| Display & juice | rock size on screen, shake, squash, chips, number of break chunks, screen shake |
| Economy | starting coins, starting rocks |
| Lighter | the wick gauge (`WICK_GAUGE`, `WICK_GAUGE_HEIGHT`, `WICK_GAUGE_MARGIN`), trembling when you're about to lose (`DANGER_AT`, `DANGER_RELIGHT_SECONDS`, `DANGER_SHAKE`), how fast the wick burns while an action waits (`WICK_TIME`) and what a miss costs (`MISS_WICK_COST`), how dark it gets (`WALL_DARKNESS`, `LIGHT_CURVE`, `GLOW_MIN`), flicks to light it up (`START_FLICKS_MIN/MAX`), light per flick (`RECHARGE_MIN/MAX`, %), how long full blaze lasts (`LIGHT_HOLD_MIN/MAX`), the jolt and screen flash at full (`FULL_SHAKE`, `FULL_FLASH_COLOR`, `FULL_FLASH_TIME`), flame speed / smallest size (`FLAME_FPS`, `FLAME_MIN_SIZE`), when it floods (`FLOOD_AT`) and what that costs (`FLOOD_LIFE_COST`), size (`LIGHTER_SCALE`), where it's held (`LIGHTER_POS`), how much it leans towards the mouse (`LIGHTER_SWAY`), the key (`LIGHTER_KEY`), lid speed, its own glow, **how long the light lasts** (`LIGHT_DURATION`), how many steps it fades in (`LIGHT_STEPS`), pixel size / flicker / warm tint, how dark it gets (`WALL_DARKNESS`). Actions never appear under the lighter |
| Relighting | time limit, strikes needed, marker speed and speed-up per strike, gold-zone size / shrink / minimum, how far a miss pushes the bar back (`RELIGHT_...`) |
| Stages & lives | `LIVES`, `WALLS_PER_STAGE`, whether a lost life restarts the stage, and how much each stage changes fuel, light, relight hits and coins (`STAGE_...`) |
| Mining wall | tile + tile size, free space at the edges (`WALL_MARGINS`: keeps actions off the HUD, the Back button and the screen edges), actions per wall, how often each action shows up (`ACTION_WEIGHTS`), **combo** bonus and cap, coins, and per action: circle count/size, how fast rings close (`TAP_APPROACH_MIN/MAX`), gap between them, perfect/good timing windows, zigzag turns/width/strictness/corner radius, slash length/swipe time, drill clicks, pry speed and gold-zone size, crack look (thickness, jaggedness, side-cracks, crackle sound), colors |
| Tips | `SHOW_TUTORIAL` (the tip texts are in `_tips()` in `scripts/tutorial.gd`, the ? tour is `TOUR`) |
| Shop (limited stock) | `SHOP_SLOTS`, `STOCK_MIN` / `STOCK_MAX`, `RESTOCK_SECONDS`, duplicate slots, instant-restock cost |
| Market | lowest / highest price (`MARKET_MIN` / `MARKET_MAX`, 10% / 200%), how far prices jump each restock (`MARKET_SWING`), how fast they drift back to normal (`MARKET_PULL`), the green / red colours |
| Dwarven Shop & caves | `TICKET_PRICE`, `FREE_TICKET_SECONDS`, `START_TICKETS`, the `CAVES` table (name, wall tile, ticket price, coins, fuel, stone chance), `CAVE_STONE_ANY_EQUAL`, the `UPGRADES` table (name, first / max bonus, levels, cost, cost growth), `FOOLS_GOLD_BONUS`, `FOOLS_GOLD_GEMS` |
| `ROCKS` table | name, price, how often it's in the shop, its own hit count, rolls, **quality** (how good its drops are) and **bonus** (its speciality) |
| `ORES` table | name, sell price, **type** (`"ore"` or `"gem"`: which upgrades boost it), rare (sparkle sound), text color, chances, amount |
| Audio | volume and pitch variation per sound, music track per screen, fade time, starting music / sound-effect volume |
| Colors / UI | font + drop shadow + crisp pixel sizes, the pixel skin (`UI_PIXEL_SCALE`, `UI_SKIN_BUTTON_MARGINS`, `UI_SKIN_PANEL_MARGINS`), background, text, text outline, accent, fonts, font size |
| Save | turn saving off, or wipe the save every time you press Play |

**How drop chances work: every rock can drop every ore and gem.** Each ore in `ORES` has two chances,
`"chance": [cheapest, best]` (% per roll in the cheapest rocks and in the best rocks), and an `amount`.
Each rock has a `quality` from 0 to 1 that slides between the two, so a Pebble can (very rarely) give
Dreamstone, but a Wedge Rock is far more likely to. A rock's `bonus` multiplies a few ores' chances (its
speciality, e.g. Cobblestone `"zinc": 2.5`). When a rock breaks it's rolled `rolls` times; on each roll every
ore is rolled on its own, so one rock can give several ores, or nothing. `LUCK_MULTIPLIER` multiplies every chance.
(Advanced: a rock's own `"drops": {"ruby": {"chance": 5, "min": 1, "max": 1}}` replaces that ore's numbers for it.)

**Balancing:** `py -3.12 tools/tune_drops.py` reads `ORES` and `ROCKS` from `config.gd` and prints, for every
rock, what it's worth on average (normal prices, no upgrades) and how often it's empty. The rocks are worth
about 1.4 - 2x their price (`VALUE_RATIO = 1.6` in the script). `tune_drops.py rock_31 --write` re-picks the
quality (and rolls, if it must) of just the rocks you name so they hit that; nothing else changes.
New ores make every rock a bit richer (every rock can drop every ore), so give new ones small chances: Indev 0.3's
11 new ores / gems made the old rocks about 12% richer.

> Starting coins / rocks only apply to a **new** save. Press **Reset** in the game, or set
> `RESET_SAVE_ON_START = true` while you're tuning.

### Add a new rock
1. Draw it in a free cell of `art_source/sheet_v3.png` and write `"rock_31"` in that cell of `GRID` in
   `tools/slice_sheets.py`.
2. Copy one entry in `ROCKS` in `config.gd`, change the id to `"rock_31"` and set its price / bonus, then run
   `py -3.12 tools/slice_sheets.py` (it packs it into `assets/rocks/rocks.png`, in price order).
3. `py -3.12 tools/tune_drops.py rock_31 --write` sets its quality to match the other rocks.

### Add a new ore / gem
1. Draw it in a free cell of `art_source/sheet_v3.png`, write `"diamond"` in that cell of `GRID` in `tools/slice_sheets.py`, add it to `ORES` (step 2) and run the script: it packs it into `assets/ores/ores.png`.
2. Add `"diamond": {...}` to `ORES` (every rock can drop it; give a rock `"bonus": {"diamond": 2.0}` to make it its speciality),
   plus a line of lore in `ORE_LORE`.

If an image is missing the game shows a **pink checkerboard** instead of crashing, so you can see what still needs art.

---

## 2. Everything you can replace

All art is scaled up with crisp, pixel-perfect filtering, so draw at the small size.
Replace a file with **the same name** and Godot picks it up next time you press Play.

### Rocks: `assets/rocks/rocks.png` (one texture, packed from your sheet)
All 30 rocks are in **one texture**, cheapest first (left to right, 10 a row, 32x32 cells). `scripts/sprite_atlas.gd`
says where each one is; both are made by `tools/slice_sheets.py`, so redraw `art_source/sheet_v3.png` and re-run it
rather than editing them by hand. (The names below are the rocks' ids.)
| File | Name in game | Price | Speciality |
|---|---|---|---|
| `rock_01.png` | Boulder | 40 | Silver |
| `rock_02.png` | Pebble (you start with 3) | 8 |  |
| `rock_03.png` | Big Boulder | 60 | Sapphire, Ruby |
| `rock_04.png` | Lumpy Rock | 18 | Jade |
| `rock_05.png` | Shard Rock | 15 | Peridot |
| `rock_06.png` | Knobby Rock | 22 | Rhodonite |
| `rock_07.png` | Crag | 26 | Gold, Topaz |
| `rock_08.png` | Twin Stones | 90 | Emerald |
| `rock_09.png` | Rubble Pile | 30 | Lead, Copper |
| `rock_10.png` | Round Stone | 12 |  |
| `rock_11.png` | Egg Boulder | 110 | Dreamstone |
| `rock_12.png` | Tall Egg | 45 | Uranium |
| `rock_13.png` | Dome Rock | 20 | Zinc, Iron |
| `rock_14.png` | Cobblestone | 10 | Zinc |
| `rock_15.png` | Notched Rock | 24 | Zinc, Jade |
| `rock_16.png` | Chipped Block | 34 | Onyx |
| `rock_17.png` | Clump | 50 | Uranium, Zinc |
| `rock_18.png` | Tower Rock | 70 | Uranium, Onyx |
| `rock_19.png` | Saddle Rock | 80 | Onyx, Dreamstone |
| `rock_20.png` | Wedge Rock | 150 | Dreamstone, Onyx, Uranium |
| `rock_21.png` | Split Boulder | 55 | Veridium |
| `rock_22.png` | Broken Knot | 28 | Mudspec, Polyphite |
| `rock_23.png` | Slate Stack | 32 | Polyphite, White Quartz |
| `rock_24.png` | Anvil Rock | 65 | Hellspec |
| `rock_25.png` | Flatstone | 14 | Mudspec |
| `rock_26.png` | Knuckle Rock | 38 | Rose Quartz |
| `rock_27.png` | Moon Boulder | 85 | Pearl, White Quartz |
| `rock_28.png` | Bean Rock | 24 | Tiger's Eye |
| `rock_29.png` | Spire | 120 | Cryo-core, Aquamarine |
| `rock_30.png` | Twisted Rock | 175 | Daevorium, Hellspec |

Every rock can drop every ore and gem; the speciality just makes those more likely (see "How drop chances work").

Keep the rocks on the same canvas size (32x32). A small rock on a 32x32 canvas stays small on screen and a big one stays big; the empty border is cropped automatically.

### Ores & gems: `assets/ores/ores.png` (one texture, packed from your sheet)
All ores (cheapest first), then all gems (cheapest first), in **one texture** - same tool, same atlas script.
| Ores | Sells for | | Gems | Sells for |
|---|---|---|---|---|
| `lead.png` Lead | 4 | | `rhodonite.png` Rhodonite | 14 |
| `mudspec.png` Mudspec | 5 | | `jade.png` Jade | 30 |
| `copper.png` Copper | 6 | | `white_quartz.png` White Quartz | 40 |
| `iron.png` Iron | 8 | | `rose_quartz.png` Rose Quartz | 55 |
| `zinc.png` Zinc | 11 | | `peridot.png` Peridot | 60 |
| `polyphite.png` Polyphite | 12 | | `tigers_eye.png` Tiger's Eye | 90 |
| `rustvein.png` Rustvein | 16 | | `lapis.png` Lapis | 120 |
| `stibnite.png` Stibnite | 24 | | `aquamarine.png` Aquamarine | 180 |
| `silver.png` Silver | 20 | | `topaz.png` Topaz | 250 |
| `veridium.png` Veridium | 35 | | `amethyst.png` Amethyst | 250 |
| `gold.png` Gold | 45 | | `sapphire.png` Sapphire | 250 |
| `cryo_core.png` Cryo-core | 80 | | `tourmaline.png` Tourmaline | 200 |
| `hellspec.png` Hellspec | 150 | | `ruby.png` Ruby | 250 |
| `uranium.png` Uranium | 200 | | `onyx.png` Onyx | 100 |
| `daevorium.png` Daevorium | 400 | | `obsidian.png` Obsidian | 350 |
|  |  | | `emerald.png` Emerald | 500 |
|  |  | | `pearl.png` Pearl | 600 |
|  |  | | `zapperion.png` Zapperion | 650 |
|  |  | | `dreamstone.png` Dreamstone | 1000 |

(The real prices are `sell_price` in `ORES`; then the market moves them.) For the upgrades, the left column are
**ores** (Miner's Favor, Rocky Riches) and the right column **gems** (Jeweler's Favor): the `type` column in `ORES`.
The round orange gem in `sheet_v3.png` (row 6) was the old Topaz art; Topaz is the orange triangle now.


### Lighter: `assets/lighter/` (cut from your sheet)
| File | What it is |
|---|---|
| `lighter_0.png` ... `lighter_5.png` | the lid animation: 0 = closed, 5 = fully open. Opening plays 0 to 5, closing 5 to 0. 0 and 5 are yours; 1-4 are in-betweens made by swinging your lid around its hinge |
| `flame_0.png` ... `flame_7.png` | your animated flame (8 frames, made by `tools/make_flame.py` from `art_source/flame_v2.png`; the Aseprite file is `art_source/flame_anim/flame_v3.aseprite`). It plays at `FLAME_FPS` and shrinks as the light dies (`FLAME_MIN_SIZE`). Its bottom (the blue gas) sits `FLAME_SINK` px down in the chimney. More or fewer frames work too |

All frames are on one 84x80 canvas so the lighter doesn't jump. Redraw any in-between by hand and keep the file name;
add more frames (`lighter_6.png` ...) and the animation uses them too (the last one must be fully open).
To re-cut everything from `art_source/lighter_sheet.png`: `py -3.12 tools/make_lighter.py` (this overwrites hand edits to the frames).
The flame's base is expected at (64.5, 30) on the canvas (`FLAME_ANCHOR` in `wall_view.gd`).

### UI art
**The pixel skin** (buttons, menus, the sunken boxes inside them, slider knob) is drawn by `tools/make_ui.py`
in the Resurrect 64 colours, as tiny 1x art in `assets/ui/skin/`, and scaled up 2x in the game (`UI_PIXEL_SCALE`):
chunky orange-wood keys with a bevel and an underside (lighter on hover, pushed in when pressed, slate when
disabled), menus with a wooden plank frame, iron corner brackets and a dark slate inside, and sunken plum slots for
list rows / shop cards. They're 9-sliced: the corners never stretch, the frame's plank grain repeats. Redraw the
PNGs freely (keep the border sizes, or change `UI_SKIN_*_MARGINS`); delete them to get flat boxes back.

| File | What it is |
|---|---|
| `assets/ui/upgrades/miners_favor.png` ... | the 9 upgrade icons: **PLACEHOLDERS** (16x16: pickaxe, gem, ore heap, shovel + coin, nugget, flame, fluid can, rock on a cushion, bitten ticket). Same name = replaced |
| `assets/ui/ticket.png` | the mine ticket icon (placeholder, 16x16) |
| `assets/ui/skin/*.png` | the pixel skin (see above) |

Other art:

| File | What it is |
|---|---|
| `assets/ui/background.png` | full-screen background behind the rock (the table; 320x180 = 1280x720 at 4x). Source: your Aseprite `Table_Background.aseprite` |
| `icon.png`, `icon.ico` | the app icon: the Pebble (made by `tools/make_icon.py`) |
| fonts | **BoldPixels** by YukiPixels (`assets/fonts/BoldPixels.ttf`, CC BY-SA 4.0: free for commercial use, keep the credit; it's in Settings and `BoldPixels-LICENSE.txt`). Drawn with hard pixel edges (`FONT_PIXELATED`), a dark outline and a **drop shadow** (`TEXT_SHADOW_COLOR`, `TEXT_SHADOW_OFFSET`). It's only crisp at 16, 32, 48 px, so every text size is rounded to those (`FONT_PIXEL_SIZE`); buttons use 32 (`BUTTON_FONT_SIZE`). Another font: put it in `assets/fonts/` and set `FONT_FILE` / `TITLE_FONT_FILE` (set `FONT_PIXEL_SIZE = 0` for a non-pixel font) |

### Sprite sheets: `art_source/`
Every rock, ore and gem is drawn on `art_source/sheet_v3.png` (rocks rows 1-3, ores rows 4-5, gems rows 6-7).
The game uses two packed textures made from it (`assets/rocks/rocks.png`, `assets/ores/ores.png`, sorted by price,
with `scripts/sprite_atlas.gd`). If you redraw the sheet or change prices, re-pack it with:
```
py -3.12 tools/slice_sheets.py
```
(32x32 cells; what each cell is, is written in `GRID` in the script).
Don't edit the packed textures by hand: the next run overwrites them.

### Audio: `assets/audio/`
The music is yours (see below); every other sound is a synthesized PLACEHOLDER made by
`tools/make_sounds.py`. Drop in your own file with the same name.
**.wav, .ogg or .mp3** all work (if more than one exists, .ogg is used first, then .wav, then .mp3).

| File | When it plays |
|---|---|
| `hit` | each click on the rock |
| `break` | the rock breaks apart |
| `drop_common` | a normal ore pops out |
| `drop_rare` | a rare ore pops out (`"rare": true`) |
| `drop_none` | the rock was empty |
| `buy` | you buy a rock |
| `sell` | you sell ores |
| `click` | buttons, placing a rock |
| `error` | not enough coins / sold out |
| `restock` | the shop restocks |
| `slice_perfect` | any PERFECT action on the wall (plays higher as your combo grows) |
| `slice_good` | an action finished but not perfect |
| `slice_miss` | off the line, let go too early, missed a circle... |
| `tap` | tapping a circle |
| `crack` | crackle while you crack a zigzag / slash into the wall |
| `drill` | each drill click (gets higher as the hole gets deeper) |
| `pry` | the wedge pops out |
| `timeout` | the timer ran out / every circle missed, combo lost |
| `wall_break` | the wall crumbles |
| `screen_slide` | moving between the rock screen and the wall |
| `lid` | the lighter lid flips open / shut |
| `flick` | a well-timed SPACE strike (sparks) |
| `misfire` | a mistimed strike (bar goes back up) |
| `ignite` | the flame catches |
| `fizzle` | the lighter goes out |
| `life_lost` | you didn't relight in time |
| `stage_up` / `stage_down` | you cleared a stage / ran out of lives |
| music `rocks` | the rock screen: **Gambler Symphony** |
| music `mine` | the mining wall: **MeltdownTheme** |
| music `shop` | while the Shop is open: **Shop Theme** (Thameuszin) |

The tracks cross-fade when you switch screens or open / close the Shop (`MUSIC_TRACKS` in `config.gd`).

**Music is tiny and locked.** `py -3.12 tools/make_music.py` takes your originals from `art_source/music/`, makes
them mono, 22 kHz OGG Vorbis at quality 0 (about 30 kbps) and loudness-matched (58.6 MB of WAV/MP3 -> 1.5 MB), then
**encrypts** each into `assets/audio/music/<key>.dat`. The game decrypts them in memory as they play, so the game
files hold no playable music to copy out, and the music is gitignored, so it's never in the public GitHub repo
(only inside the game). To change a track: put it in `art_source/music/`, edit `TRACKS` at the top of the script,
run it. (Nothing in a game is truly uncrackable: someone determined could still pull the key out of the game, but
nobody can just grab the files.) The old tracks are kept in `art_source/music_old/`.

Volume and pitch variation for each sound are in `SOUNDS` in `config.gd`. To regenerate the placeholders: `py tools/make_sounds.py`
(it skips any sound you've already replaced; add `--force` to overwrite all).

---

## 3. Versions & auto-update

The game is **Indev 0.1** (`scripts/game_version.gd`; shown bottom-left on the rock screen and in Settings).
It lives at **github.com/ryeeofficialwb-ui/rich-from-rocks** (public: players' games download updates from it
without logging in).

**How players get updates:** when the game starts it asks GitHub for the latest release. If it's newer it
downloads the update pack, checks its SHA-256, closes, swaps the pack in, **self-tests** the new version and
starts it; if the new version doesn't start, it puts the old one back and never tries that update again.
Offline or anything wrong: it just plays the version it has. Saves are in AppData, so updates never touch
them. (Never runs in the editor, the screenshot demo, or with `--no-update`.) Code: `scripts/updater.gd`.

**Publishing an update** (you): bump the number, one command:
```
py -3.12 tools/publish_update.py 0.2 "What changed"
```
It sets the version, exports the pack, **tests it with the real release engine** (nothing goes out if the game
doesn't start), commits, tags `v0.2`, pushes, and creates the GitHub Release with the pack. Everyone's game
updates the next time it starts. Add `--full` to also attach the complete Windows download (needed for new
players only when Godot itself changes; the 0.1 zip keeps working because it updates itself).
Needs Godot 4.7.2 with its export templates (the Steam version has them) and `gh` logged in.

**Lightweight:** the Windows download uses a **slim engine** (`tools/engine/bin/richfromrocks_template_release.x86_64.exe`:
Godot 4.7.2 built without 3D, physics, navigation, XR, Vulkan/D3D12 and unused modules - Seed Splicer's build,
same version). The exe is 30 MB instead of 109 MB and the zip about 13 MB instead of 39 MB; the game pack itself
is ~2 MB. Every update is tested on both the slim engine and the official one (0.1 players have the official
one). Rebuilding the slim engine needs the Godot source + Visual Studio: `tools/engine/build_template.ps1`.

## 4. License

**All rights reserved** (see [`LICENSE`](LICENSE)): Geode Galore belongs to ryeeofficialwb-ui. Anyone may play the
official releases and make videos of it with credit, but nobody may copy, reupload, sell, modify, or claim the game or
its art as theirs. The owner's name is in the game (Settings, the corner of the rock screen) and in the exe's
file details. The fonts, music and Godot Engine keep their own licenses.

## 5. Files

```
scripts/config.gd      <- ALL SETTINGS (edit this)
scripts/game_state.gd  coins, bag, ores, shop, market, tickets, upgrades, drop rolls, saving (autoload "Game")
scripts/sfx.gd         sounds + music (autoload "Sfx")
scripts/rock_view.gd   the clickable rock: cracks, chips, breaking apart
scripts/darkness.gdshader  the dark: whole-wall light level in steps + the glow around the lighter
scripts/wall_view.gd   the mining wall: tap / zigzag / slash / drill / pry actions, timer + combo, pixel cracks, crumbling
scripts/tutorial.gd    tips as you play (spotlight + one short tip each) and the short ? tour
scripts/game_version.gd  the version (Indev 0.1) and the GitHub repo updates come from
scripts/updater.gd     auto-update: checks GitHub Releases, downloads + verifies + installs the new pack
scripts/main.gd        builds the screens, top bar, shop / backpack / settings popups, drop animations
scenes/main.tscn       main scene
tools/slice_sheets.py  packs the art_source sheet into rocks.png / ores.png (+ scripts/sprite_atlas.gd)
tools/make_sounds.py   makes the placeholder sounds
tools/tune_drops.py    balances rock quality from the ORES / ROCKS tables (see Balancing)
tools/make_flame.py    makes the 8-frame flame flicker (sway, colour bands, breathing gas, tongues that break off)
tools/make_lighter.py  cuts the lighter sheet into frames + flame, makes the lid in-between frames
tools/make_music.py    compresses + encrypts your soundtracks (tools/encrypt_music.gd does the encrypting)
tools/engine/          the slim engine build profile (the built exe in bin/ is gitignored)
tools/publish_update.py  publishes an update (export, self-test, commit, tag, push, GitHub Release)
tools/make_ui.py       pixel UI skin, placeholder upgrade / ticket icons, the 3 new ore icons
```

Save file: `%APPDATA%\Godot\app_userdata\Rich From Rocks\save.cfg` (delete it, or press Reset, to start over).

Dev: `godot --path . -- --shot=C:/some/folder` plays a short demo and saves screenshots there.
