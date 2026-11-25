# Rich From Rocks  (Indev 0.2)

(c) 2026 ryeeofficialwb-ui. All rights reserved. See [LICENSE](LICENSE).

Buy rocks, smash them open (3-5 clicks, random), find ores and gems, sell them, buy better rocks.
Short on coins? Click **< Mine** on the left to go to the mining wall and earn coins with quick mining actions
(you need a **ticket** from the Dwarven Shop).

**Screens**
- **Top bar:** coins, your mine **tickets**, **Shop** (two tabs: **Rock Shop** and **Dwarven Shop**), **Backpack** (your ores & gems, sell them here), **Settings** (sound on/off, music volume, sound-effect volume, reset), **?** (the tutorial).
- **Tutorial:** opens by itself on a new game (and once for old saves), and any time from **?**. It spotlights each part of the game and lets you try every wall action with no timer. Skip with **Skip tutorial** or Esc; arrow keys / Enter step through it.
- **Main screen:** the rock in the middle, **Your Rocks** on the right, **< Mine** arrow on the left.
- **Market & Guide** (top bar): today's price of every ore, gem and rock, its % of normal and how it moved at the
  last restock. Click anything for its page: what it sells for, chances, the 3 best rocks to find it in (your
  upgrades included) and its **lore** (`ORE_LORE` in `config.gd`, write your own); for rocks, what's inside is worth
  on average at today's prices.
- **Settings > Hint text:** turn off the helper texts (the rock hint, "Click one to put it on the anvil", the
  ticket and market notes, each wall action's instruction line, the "Flick SPACE..." / "Hit SPACE..." prompts).
- **Market (supply & demand):** every time the shop restocks on its timer (every 5 minutes) demand shifts: every
  rock's shop price and every ore / gem's sell price moves up or down from where it was, drifting back towards
  normal over time. A price can never go above **200%** or below **10%** of its normal price. The Shop and Backpack
  show the market price in **green** (above normal) or **red** (below). Paying to restock early gives new rocks
  but doesn't move the market.
- **Dwarven Shop** (second tab of the Shop):
  - **Tickets:** going down the mine costs a ticket. One ticket = one **trip**, which lasts until you run out of
    lives (then you're sent back up; going Back to your rocks doesn't end it). Claim a **free ticket every 10
    minutes**, or buy one for **100 coins**. Your ticket count is in the top bar. Without one, **< Mine** opens
    the Dwarven Shop. (The tutorial's tour of the wall is free.)
  - **Upgrades** (250 levels each; level 1 gives exactly the first number, level 250 exactly the max, a smooth
    curve in between):

    | Upgrade | Level 1 | Max (lv 250) | What it does |
    |---|---|---|---|
    | **Miner's Favor** | +1% | +90% | ore drop chance (each level adds a bit less) |
    | **Jeweler's Favor** | +1% | +90% | gem drop chance |
    | **Rocky Riches** | +0.25% | +200% (x3) | ores per drop, ores only; a fraction is a chance of one more |
    | **Digging Expert** | +2.5% | +400% | coins from the mining wall |
    | **Fool's Gold** | 0.2% | 20% | chance a sale (one Sell / All / each ore in Sell Everything) pays **+15%** |

    Costs start at 30-75 coins and grow 2.2% per level (all in `UPGRADES` in `config.gd`).
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

  **About to lose?** The lighter starts to tremble when the wick or the light drops below 25%, or in the last 2
  seconds of the relight countdown, and shakes harder the closer you get. If the light fades all the way, your combo is lost and the lighter goes out.
  When you arrive (and after losing a life) the lighter is shut: flick it a few times (3-5) until the flame catches.
  **On phones there's no SPACE: tap the lighter.** On PC both work. The wall asks for one action at a time:
  | Action | What you do |
  |---|---|
  | **TAP!** | circles pop up, each with a ring closing in on it; tap each circle the moment its ring touches it. Rings close at different speeds, so tap whichever closes **first** (too early / too late misses that circle) |
  | **ZIGZAG!** | press the glowing dot and crack along the zigzag, passing **every corner** (cutting straight across doesn't work) |
  | **SLASH!** | one big, fast swipe along a long line (you have under a second once you press) |
  | **DRILL!** | spam-click the same spot until the counter hits 0 |
  | **PRY!** | hold on the wedge; a gauge fills; let go while it's in the **gold zone** (too long and it snaps) |

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
  **5 walls** to clear the stage and go up. Your stage is a checkpoint, but lose all 3 lives before clearing it and you
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
| Tutorial | `SHOW_TUTORIAL` (texts are in `_make_steps()` in `scripts/tutorial.gd`) |
| Shop (limited stock) | `SHOP_SLOTS`, `STOCK_MIN` / `STOCK_MAX`, `RESTOCK_SECONDS`, duplicate slots, instant-restock cost |
| Market | lowest / highest price (`MARKET_MIN` / `MARKET_MAX`, 10% / 200%), how far prices jump each restock (`MARKET_SWING`), how fast they drift back to normal (`MARKET_PULL`), the green / red colours |
| Dwarven Shop | `TICKET_PRICE`, `FREE_TICKET_SECONDS`, `START_TICKETS`, the `UPGRADES` table (name, first / max bonus, levels, cost, cost growth), `FOOLS_GOLD_BONUS`, `FOOLS_GOLD_GEMS` |
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

**Balancing:** `py -3.12 tools/tune_drops.py` prints, for every rock, what it's worth on average and how
often it's empty; with `--write` it re-picks each rock's `quality` so it's worth about 90% of its price
(edit `ORE_CURVE` / `BONUS` / `VALUE_RATIO` at the top of the script first). Since gem prices went up
(Topaz 250, Emerald 500, Dreamstone 1000...), the rocks are currently worth MORE than they cost (roughly Pebble 11
for 8, Crag 44 for 26, Big Boulder 100 for 60, Wedge Rock 290 for 150), before the market moves. Running
`tune_drops.py --write` would bring them back to ~90% (it lowers each rock's quality; it keeps your prices).

> Starting coins / rocks only apply to a **new** save. Press **Reset** in the game, or set
> `RESET_SAVE_ON_START = true` while you're tuning.

### Add a new rock
1. Draw it in a free cell of `art_source/sheet_v2.png` and write `"rock_21"` in that cell of `GRID` in
   `tools/slice_sheets.py`, then run it (or just save `assets/rocks/rock_21.png`, 32x32).
2. Copy one entry in `ROCKS` in `config.gd`, change the id to `"rock_21"` and set its numbers.

### Add a new ore / gem
1. Save the art as `assets/ores/diamond.png` (or draw it in a free cell of `art_source/sheet_v2.png`, write `"diamond"` in that cell of `GRID` in `tools/slice_sheets.py` and run it).
2. Add `"diamond": {...}` to `ORES`, then add `"diamond"` to the `drops` of the rocks that can contain it.

If an image is missing the game shows a **pink checkerboard** instead of crashing, so you can see what still needs art.

---

## 2. Everything you can replace

All art is scaled up with crisp, pixel-perfect filtering, so draw at the small size.
Replace a file with **the same name** and Godot picks it up next time you press Play.

### Rocks: `assets/rocks/` (cut from your sheet)
| File | Name in game |
|---|---|
| `rock_01.png` | Boulder |
| `rock_02.png` | Pebble (you start with 3) |
| `rock_03.png` | Big Boulder |
| `rock_04.png` | Lumpy Rock |
| `rock_05.png` | Shard Rock |
| `rock_06.png` | Knobby Rock |
| `rock_07.png` | Crag |
| `rock_08.png` | Twin Stones |
| `rock_09.png` | Rubble Pile |
| `rock_10.png` | Round Stone |
| `rock_11.png` | Egg Boulder (speciality: Dreamstone) |
| `rock_12.png` | Tall Egg (Uranium) |
| `rock_13.png` | Dome Rock (Zinc, iron) |
| `rock_14.png` | Cobblestone (Zinc) |
| `rock_15.png` | Notched Rock (Zinc, jade) |
| `rock_16.png` | Chipped Block (Onyx) |
| `rock_17.png` | Clump (Uranium, Zinc) |
| `rock_18.png` | Tower Rock (Uranium, Onyx) |
| `rock_19.png` | Saddle Rock (Onyx, Dreamstone) |
| `rock_20.png` | Wedge Rock (Dreamstone, Onyx, Uranium; very rare in the shop) |

Every rock can drop every ore and gem; the speciality just makes those more likely (see "How drop chances work").

Keep the rocks on the same canvas size (32x32). A small rock on a 32x32 canvas stays small on screen and a big one stays big; the empty border is cropped automatically.

### Hand-drawn cracks (optional)
By default cracks are generated into the rock's own pixels on each hit. To draw them yourself, add
`assets/rocks/<rock id>_crack_1.png`, `_crack_2.png`, `_crack_3.png` (same size as the rock PNG, the
full rock with cracks drawn on). Stage 1 shows early, stage 3 just before it breaks. You can make them for
just some rocks; the others keep the generated cracks. The number of stages is `CRACK_ART_STAGES`.

### Ores & gems: `assets/ores/` (cut from your sheet)
| Ores | Sells for | | Gems (rare) | Sells for |
|---|---|---|---|---|
| `lead.png` Lead | 4 | | `peridot.png` Peridot | 60 |
| `copper.png` Copper | 6 | | `topaz.png` Topaz | 80 |
| `iron.png` Iron | 8 | | `uranium.png` **Uranium** (glowing green lumps) | 90 |
| `zinc.png` **Zinc** (brown nodules, teal centres) | 11 | | `amethyst.png` Amethyst | 100 |
| `rhodonite.png` Rhodonite | 14 | | `sapphire.png` Sapphire | 120 |
| `silver.png` Silver | 20 | | `ruby.png` Ruby | 150 |
| `jade.png` Jade | 30 | | `onyx.png` **Onyx** (black gem) | 175 |
| `gold.png` Gold | 45 | | `emerald.png` Emerald | 200 |
| `rustvein.png` **Rustvein** (rusty red chunks, yours) | 16 | | `tourmaline.png` **Tourmaline** (pink gem, yours) | 200 |
| `stibnite.png` **Stibnite** (silver-grey crystals, yours) | 24 | | `zapperion.png` **Zapperion** (yellow-green crystal, yours) | 650 |
| | | | `lapis.png` **Lapis** (blue with gold flecks, yours) | 120 |
| | | | `obsidian.png` **Obsidian** (dark volcanic glass, yours) | 350 |
| | | | `dreamstone.png` **Dreamstone** (lavender lumps) | 300 |

(The sell prices above are the old ones; the real ones are `sell_price` in `ORES`, then the market moves them.)
For the upgrades, **ores** are Lead, Copper, Iron, Zinc, Rustvein, Stibnite, Silver, Gold and Uranium; everything else is a
**gem** (the `type` column in `ORES`). Rustvein / Tourmaline / Zapperion are cut from `art_source/rustvein.png` and
`art_source/new_gems.png` by `tools/make_ui.py`, and Lapis / Stibnite / Obsidian from `art_source/new_ores_2.png`.

Every rock can drop every one of these. Cheap rocks mostly give lead / copper / iron / zinc with a tiny chance of
anything; pricier rocks lean towards silver, gold, jade and gems. All prices and chances are in `ORES` / `ROCKS`.

### Mining wall: `assets/wall/`
| File | What it is |
|---|---|
| `wall_tile.png` | the 32x32 tile repeated over the whole wall (yours; the original is also in `art_source/`). Make it tile seamlessly. Size on screen = `WALL_TILE_SCALE` |

When the wall crumbles, every tile splits into 4 chunks that fall away, so the tile art is used for the rubble too.

### Lighter: `assets/lighter/` (cut from your sheet)
| File | What it is |
|---|---|
| `lighter_0.png` ... `lighter_5.png` | the lid animation: 0 = closed, 5 = fully open. Opening plays 0 to 5, closing 5 to 0. 0 and 5 are yours; 1-4 are in-betweens made by swinging your lid around its hinge |
| `flame_0.png` ... `flame_7.png` | your animated flame (8 frames, made by `tools/make_flame.py` from `art_source/flame_v2.png`; the Aseprite file is `art_source/flame_anim/flame_v3.aseprite`). It plays at `FLAME_FPS` and shrinks as the light dies (`FLAME_MIN_SIZE`). Its bottom (the blue gas) sits `FLAME_SINK` px down in the chimney. More or fewer frames work too |
| `flame.png` | the old single flame, only used if there are no `flame_N.png` frames |

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
PNGs freely (keep the border sizes, or change `UI_SKIN_*_MARGINS`); delete them to get flat boxes back. Your first
panels are kept in `art_source/ui/ui_panels.png` (not used).

| File | What it is |
|---|---|
| `assets/ui/upgrades/miners_favor.png` ... | the 5 upgrade icons: **PLACEHOLDERS** (16x16: pickaxe, gem, ore heap, shovel + coin, nugget). Same name = replaced |
| `assets/ui/ticket.png` | the mine ticket icon (placeholder, 16x16) |
| `assets/ui/skin/*.png` | the pixel skin (see above) |

Optional (none are made yet):

| File | What it does if it exists |
|---|---|
| `assets/ui/shop.png`, `backpack.png`, `settings.png` | icon on that top-bar button |
| `assets/ui/arrow_left.png`, `arrow_right.png` | icon on the "Mine" / "Back" screen arrows |
| `assets/ui/coin.png` | coin icon next to your coins |
| `assets/ui/background.png` | full-screen background (covers the plain color) |
| `assets/ui/pedestal.png` | anvil / stand drawn under the rock |
| `icon.svg` | the game's window/app icon |
| fonts | **BoldPixels** by YukiPixels (`assets/fonts/BoldPixels.ttf`, CC BY-SA 4.0: free for commercial use, keep the credit; it's in Settings and `BoldPixels-LICENSE.txt`). Drawn with hard pixel edges (`FONT_PIXELATED`), a dark outline and a **drop shadow** (`TEXT_SHADOW_COLOR`, `TEXT_SHADOW_OFFSET`). It's only crisp at 16, 32, 48 px, so every text size is rounded to those (`FONT_PIXEL_SIZE`); buttons use 32 (`BUTTON_FONT_SIZE`). Another font: put it in `assets/fonts/` and set `FONT_FILE` / `TITLE_FONT_FILE` (set `FONT_PIXEL_SIZE = 0` for a non-pixel font) |

### Sprite sheets: `art_source/`
Everything is cut from `art_source/sheet_v2.png` (rocks rows 1-2, ores row 3, gems row 5). The older
`rock_sheet.png` / `ore_sheet.png` / `ore_sheet_old.png` are kept for reference only. If you redraw the sheet, re-cut it with:
```
py -3.12 tools/slice_sheets.py
```
(32x32 cells; what each cell is, is written in `GRID` in the script).
You can also skip the sheets and just edit the single PNGs.

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

**All rights reserved** (see [`LICENSE`](LICENSE)): Rich From Rocks belongs to ryeeofficialwb-ui. Anyone may play the
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
scripts/tutorial.gd    the tutorial (spotlight + steps + practice mode on the wall)
scripts/game_version.gd  the version (Indev 0.1) and the GitHub repo updates come from
scripts/updater.gd     auto-update: checks GitHub Releases, downloads + verifies + installs the new pack
scripts/main.gd        builds the screens, top bar, shop / backpack / settings popups, drop animations
scenes/main.tscn       main scene
tools/slice_sheets.py  cuts art_source sheets into single PNGs
tools/make_sounds.py   makes the placeholder sounds
tools/tune_drops.py    balances rock quality so each rock is worth about its price
tools/make_flame.py    makes the 8-frame flame flicker (sway, colour bands, breathing gas, tongues that break off)
tools/make_lighter.py  cuts the lighter sheet into frames + flame, makes the lid in-between frames
tools/make_music.py    compresses + encrypts your soundtracks (tools/encrypt_music.gd does the encrypting)
tools/engine/          the slim engine build profile (the built exe in bin/ is gitignored)
tools/publish_update.py  publishes an update (export, self-test, commit, tag, push, GitHub Release)
tools/make_ui.py       pixel UI skin, placeholder upgrade / ticket icons, the 3 new ore icons
rock.gd / rock_generator.gd / *.tscn   your procedural rock generator from before (not used by the game, left as is)
```

Save file: `%APPDATA%\Godot\app_userdata\Rich From Rocks\save.cfg` (delete it, or press Reset, to start over).

Dev: `godot --path . -- --shot=C:/some/folder` plays a short demo and saves screenshots there.
