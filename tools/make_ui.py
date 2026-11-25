"""Builds the pixel-art UI skin, the upgrade / ticket icons and the caves' wall tiles.

    py -3.12 tools/make_ui.py

The skin (buttons, menus, slots, slider knob) is drawn in code below (make_skin) in the Resurrect 64
colours. (Rocks, ores and gems are cut from art_source/sheet_v3.png by tools/slice_sheets.py.)
From YOUR art:
  art_source/cave_sheet.png     the cave walls, 32 x 32 each, left to right (see CAVE_TILES below)
Writes:
  assets/ui/skin/button.png (+ _hover, _pressed, _disabled), panel.png (menus), slot.png (sunken boxes),
  grabber.png (slider knob) - tiny (16 px) art, scaled up by UI_PIXEL_SCALE in the game
  assets/ui/upgrades/<upgrade id>.png and assets/ui/ticket.png - PLACEHOLDERS (16 x 16), replace freely
  assets/ui/icons/backpack.png, settings.png - the top bar's icon buttons (16 x 16)
  assets/wall/<cave id>.png (the caves' wall tiles, Config.CAVES)
  art_source/ui/preview.png - everything side by side, 6x, to look at
The game reads the 9-slice margins from Config (UI_SKIN_*): the corners never stretch, so a redrawn
skin just needs the same border sizes - or change those numbers.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SKIN = ROOT / "assets/ui/skin"
UPG = ROOT / "assets/ui/upgrades"

# your panels' colours (Resurrect 64 palette)
OUTLINE = (46, 34, 47)
FACE = (171, 148, 122)
STRIPE = (150, 108, 108)
SCREW = (127, 112, 138)
SCREW_DARK = (98, 85, 101)


def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def stamp(img, grid, pal, at=(0, 0)):
    px = img.load()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != "." and ch in pal:
                X, Y = at[0] + x, at[1] + y
                if 0 <= X < img.width and 0 <= Y < img.height:
                    px[X, Y] = _rgb(pal[ch]) + (255,)


PAL = {
    "K": "#2e222f", "g": "#3e3546", "G": "#625565", "m": "#7f708a", "M": "#9babb2", "l": "#c7dcd0",
    "w": "#ffffff", "t": "#ab947a", "s": "#966c6c", "n": "#9e4539", "O": "#cd683d", "o": "#f79617",
    "y": "#f9c22b", "Y": "#fbff86", "b": "#4d9be6", "B": "#8fd3ff", "r": "#e83b3b", "R": "#ae2334",
    "e": "#1ebc73", "E": "#91db69", "a": "#a2a947", "A": "#d5e04b",
}

ICONS = {
    # Miner's Favor: a pickaxe with a sparkle
    "miners_favor": [
        "................",
        "...KKKKKKKKKK...",
        ".KKMMMMMMMMMMKK.",
        "KMMllllllllllMMK",
        "KMKKKKMMMMKKKKMK",
        "KK...KMMMMK...KK",
        "K....KKOOKK....K",
        "......KOnK......",
        "......KOnK......",
        "..Y...KOnK......",
        ".YwY..KOnK......",
        "..Y...KOnK......",
        "......KOnK......",
        "......KOnK......",
        "......KKKK......",
        "................",
    ],
    # Jeweler's Favor: a cut gem with a sparkle
    "jewelers_favor": [
        ".............Y..",
        "............YwY.",
        "....KKKKKKKK.Y..",
        "...KBwBBBbbbK...",
        "..KBwBBBBbbbbK..",
        ".KKKKKKKKKKKKKK.",
        ".KBBBBBBbbbbbbK.",
        "..KBBBBBbbbbbK..",
        "...KBBBBbbbbK...",
        "....KBBBbbbK....",
        ".....KBBbbK.....",
        "......KBbK......",
        ".......KK.......",
        "................",
        "................",
        "................",
    ],
    # Rocky Riches: a heap of ore lumps (drawn below), plus a "+"
    "rocky_riches": None,
    # Heat of the Forge: a roaring flame over the forge
    "heat_of_the_forge": [
        "................",
        ".......KK.......",
        "......KoOK......",
        "......KooK......",
        ".....KoyoOK.....",
        "....KOoyyoK.....",
        "....KoyYyoOK....",
        "...KOoyYYyoK....",
        "...KoyYwwYyoK...",
        "...KoyYwwYyoK...",
        "...KOoyYYyoOK...",
        "....KOoyyoOK....",
        ".....KKOOKK.....",
        "...KnnnnnnnnK...",
        "...KKKKKKKKKK...",
        "................",
    ],
    # Pack of Fluid: a can of lighter fluid and a drop
    "pack_of_fluid": [
        "................",
        "..........KK....",
        ".........KMMK...",
        "........KMK.....",
        "...KKKKKKK......",
        "..KBBBBBBBK.....",
        "..KBbbbbbbK.....",
        "..KbwBbbbbK.....",
        "..KbBbbbbbK.....",
        "..KbbbbbbbK..b..",
        "..KbbbbbbbK.bBb.",
        "..KbbbbbbbK.bwb.",
        "..KbbbbbbbK..b..",
        "..KKKKKKKKK.....",
        "................",
        "................",
    ],
    # Silktouch: a rock resting safe on a soft cushion
    "silktouch": [
        "............Y...",
        "...........YwY..",
        "............Y...",
        "....KKKKKK......",
        "...KMlMMMMK.....",
        "..KMlMMMMGGK....",
        ".KMMMMMMGGGGK...",
        ".KMMMMMGGGGGK...",
        ".KGMMGGGGGgGK...",
        "..KGGGGGgggK....",
        "...KKKKKKKK.....",
        ".KBBBBBBBBBBBK..",
        "KBbbbbbbbbbbbbK.",
        ".KKKKKKKKKKKKK..",
        "................",
        "................",
    ],
    # Ticket Hungry: a ticket with a bite out of it
    "ticket_hungry": [
        "................",
        "................",
        "................",
        "KKKKKKKKKKK.....",
        "KYYYYKYYYYYK....",
        "KyyyyyyyyyyyK...",
        ".KyyyKyyyyyyK.y.",
        "..KyyyyyyyyK....",
        ".KyyyKyyyyyyK.o.",
        "KyyyyyyyyOOOyK..",
        "KooooKoooooooooK",
        "KKKKKKKKKKKKKKKK",
        "................",
        "................",
        "................",
        "................",
    ],
    # Digging Expert: a shovel and a coin
    "digging_expert": [
        ".....KKKKKKK....",
        ".....KOOnOOK....",
        ".KKK.KKKnKKK....",
        "KyYyK..KnK......",
        "KyoyK..KnK......",
        "KyyoK..KnK......",
        ".KKK...KnK......",
        "....KKKKKKKKK...",
        "....KMlllMMMK...",
        "....KMlMMMMGK...",
        "....KMlMMMMGK...",
        "....KMMMMMGGK...",
        ".....KMMMGGK....",
        "......KMGGK.....",
        ".......KKK......",
        "................",
    ],
    # Fool's Gold: a brassy nugget that glints
    "fools_gold": [
        "...........Y....",
        "..........YwY...",
        "...........Y....",
        "................",
        ".....KKKKK......",
        "...KKYYAyyKK....",
        "..KYYAyyyyooK...",
        ".KYAyyYyyyoooK..",
        ".KAyyyyyyaoooK..",
        "KyyYyyyyaooOOK..",
        "KyyyyyyooooOOK..",
        ".KoyyyaooOOOK...",
        "..KKooOOOOKK....",
        "....KKKKKK......",
        "................",
        "................",
    ],
}

LUMP = [
    ".KKKKK.",
    "KMlMMMK",
    "KMyMMGK",
    "KMMMoGK",
    "KGMGGGK",
    ".KKKKK.",
]

TICKET = [
    "................",
    "................",
    "................",
    "KKKKKKKKKKKKKKKK",
    "KYYYYKYYYYYYYYYK",
    "KyyyyyyyyyyoyyyK",
    ".KyyyKyyyyoooyK.",
    "..KyyyyyyyyoyK..",
    ".KyyyKyyyyyyyyK.",
    "KyyyyyyyyOOOOyyK",
    "KooooKoooooooooK",
    "KKKKKKKKKKKKKKKK",
    "................",
    "................",
    "................",
    "................",
]


# top-bar buttons (assets/ui/icons/<name>.png): the Backpack and Settings are icon buttons
MENU_ICONS = {
    "backpack": [
        "................",
        "......KKKK......",
        ".....KK..KK.....",
        "....KKKKKKKK....",
        "...KOOOOOOOOK...",
        "..KOOyOOOOOOnK..",
        "..KOOOOOOOOOnK..",
        "..KnnnnKKnnnnK..",
        "..KOOOOKyKOOnK..",
        "..KOOOOOKOOOnK..",
        "..KOKKKKKKKOnK..",
        "..KOKOOOOOKOnK..",
        "..KOKOyOOOKOnK..",
        "..KOKKKKKKKOnK..",
        "...KKKKKKKKKK...",
        "................",
    ],
    "settings": [
        "................",
        ".......KK.......",
        "...KK.KMMK.KK...",
        "..KMMKKMMKKMMK..",
        "..KMlMMMMMMMMK..",
        "...KMMMKKMMMK...",
        ".KKKMMK..KMMKKK.",
        "KMlMMK....KMMMGK",
        "KMMMMK....KMMMGK",
        ".KKKMMK..KMMKKK.",
        "...KMMMKKMMGK...",
        "..KMMMMMMMMGGK..",
        "..KMMKKMMKKGGK..",
        "...KK.KMGK.KK...",
        ".......KK.......",
        "................",
    ],
}


def make_menu_icons():
    out_dir = ROOT / "assets/ui/icons"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = {}
    for name, grid in MENU_ICONS.items():
        img = Image.new("RGBA", (16, 16))
        stamp(img, [r.ljust(16, ".")[:16] for r in grid], PAL)
        img.save(out_dir / f"{name}.png")
        out[name] = img
    return out


def make_icons():
    UPG.mkdir(parents=True, exist_ok=True)
    out = {}
    for uid, grid in ICONS.items():
        img = Image.new("RGBA", (16, 16))
        if grid is None:  # rocky riches: three lumps + a plus
            for at in ((1, 8), (8, 8), (4, 3)):
                stamp(img, LUMP, PAL, at)
            stamp(img, [".Y.", "YwY", ".Y."], PAL, (12, 0))
        else:
            stamp(img, [r.ljust(16, ".")[:16] for r in grid], PAL)
        img.save(UPG / f"{uid}.png")
        out[uid] = img
    t = Image.new("RGBA", (16, 16))
    stamp(t, [r.ljust(16, ".")[:16] for r in TICKET], PAL)
    t.save(ROOT / "assets/ui/ticket.png")
    out["ticket"] = t
    return out


def _put(img, x, y, hexcol):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), _rgb(hexcol) + (255,)) if hexcol else img.putpixel((x, y), (0, 0, 0, 0))


# ---- the skin: drawn here in code (Resurrect 64 colours), all at 1 art px; the game scales it by UI_PIXEL_SCALE
BUTTON_COLOURS = {  # highlight, face, shade, edge (the chunky underside)
    "button": ("#e6904e", "#cd683d", "#9e4539", "#6e2727"),
    "button_hover": ("#fbb954", "#e6904e", "#cd683d", "#6e2727"),
    "button_disabled": ("#7f708a", "#625565", "#4a3f52", "#3e3546"),
}


def draw_button(hi, face, shade, edge, w=16, h=18):
    """A chunky wooden key: dark outline with cut corners, light top / left bevel, shaded right side,
    a shadow line, then 3 rows of underside so it stands up off the menu."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            c = face
            if y == 0 or y == h - 1 or x == 0 or x == w - 1:
                c = "#2e222f"
            elif y >= h - 4:
                c = edge                       # the underside
            elif y == h - 5:
                c = shade                      # shadow line under the face
            elif y == 1:
                c = hi                         # top bevel
            elif x == 1:
                c = hi                         # left bevel
            elif x == w - 2:
                c = shade                      # right side in shade
            _put(img, x, y, c)
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        _put(img, x, y, None)                  # rounded corners
    _put(img, 2, 2, "#fbb954" if hi != "#7f708a" else "#9babb2")  # a glint
    return img


def draw_button_pressed(w=16, h=18):
    """Pushed in: the key sits 3 px lower, its underside is squashed to 1 row, the face is darker
    and the top bevel turns into an inner shadow."""
    img = Image.new("RGBA", (w, h))
    top = 3
    for y in range(top, h):
        for x in range(w):
            c = "#9e4539"
            if y == top or y == h - 1 or x == 0 or x == w - 1:
                c = "#2e222f"
            elif y == h - 2:
                c = "#6e2727"
            elif y == top + 1:
                c = "#6e2727"                  # inner shadow along the top
            elif x == 1:
                c = "#6e2727"
            _put(img, x, y, c)
    for x, y in ((0, top), (w - 1, top), (0, h - 1), (w - 1, h - 1)):
        _put(img, x, y, None)
    return img


def draw_panel(w=32, h=32):
    """A menu: dark slate inside a 4 px wooden frame (planks, lit from the top left), a dark inner
    line, and iron brackets with a rivet on the corners."""
    img = Image.new("RGBA", (w, h))
    light, mid, dark, deep = "#cd683d", "#9e4539", "#6e2727", "#45293f"
    inside = "#3e3546"
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            top_left = min(x, y) == d
            if d == 0:
                c = "#2e222f"
            elif d == 1:
                c = light if top_left else dark
            elif d in (2, 3):
                # plank grain along the frame (period 6 so it tiles)
                along = x if (y == d or h - 1 - y == d) else y
                c = dark if along % 6 == 0 and d == 2 else mid
            elif d == 4:
                c = deep
            elif d == 5:
                c = "#2e222f"
            else:
                c = inside
            _put(img, x, y, c)
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        _put(img, x, y, None)
    plate = [
        "KKKKKKK.",
        "KlMMMMGK",
        "KMMMMGGK",
        "KMMgMGK.",
        "KMMMGK..",
        "KMGGK...",
        "KGGK....",
        ".KK.....",
    ]
    pal = {"K": "#2e222f", "l": "#c7dcd0", "M": "#9babb2", "G": "#625565", "g": "#3e3546"}
    for flip_x in (False, True):
        for flip_y in (False, True):
            for py, row in enumerate(plate):
                for px_, ch in enumerate(row):
                    if ch == ".":
                        continue
                    X = w - 1 - px_ if flip_x else px_
                    Y = h - 1 - py if flip_y else py
                    _put(img, X, Y, pal[ch])
    return img


def draw_slot(w=12, h=12):
    """A sunken box inside a menu (shop cards, upgrade rows): outline, shadow along the top / left,
    light along the bottom / right, dark plum inside."""
    img = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d == 0:
                c = "#2e222f"
            elif d == 1:
                c = "#231a24" if min(x, y) == 1 else "#694f62"
            else:
                c = "#45293f"
            _put(img, x, y, c)
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        _put(img, x, y, None)
    return img


def make_skin():
    SKIN.mkdir(parents=True, exist_ok=True)
    variants = {name: draw_button(*cols) for name, cols in BUTTON_COLOURS.items()}
    variants["button_pressed"] = draw_button_pressed()
    variants["panel"] = draw_panel()
    variants["slot"] = draw_slot()
    knob = Image.new("RGBA", (8, 12))
    stamp(knob, [
        ".KKKKKK.",
        "KhhhhhhK",
        "KhffffsK",
        "KhffffsK",
        "KhffffsK",
        "KhffffsK",
        "KhffffsK",
        "KssssssK",
        "KeeeeeeK",
        "KeeeeeeK",
        ".KKKKKK.",
        "........",
    ], {"K": "#2e222f", "h": "#e6904e", "f": "#cd683d", "s": "#9e4539", "e": "#6e2727"})
    variants["grabber"] = knob
    for name, img in variants.items():
        img.save(SKIN / f"{name}.png")
    return variants


# art_source/cave_sheet.png, left to right -> cave id (None = skip; the last one is the Old Mine's wall_tile.png)
CAVE_TILES = ["shale_hollow", "crimson_deep", "blackrock_tunnels", "crystal_grotto", "magma_veins", None]


def cut_caves():
    sheet = Image.open(ROOT / "art_source/cave_sheet.png").convert("RGBA")
    for i, cid in enumerate(CAVE_TILES):
        if cid:
            sheet.crop((i * 32, 0, i * 32 + 32, 32)).save(ROOT / f"assets/wall/{cid}.png")


def main():
    skin = make_skin()
    icons = make_icons()
    icons.update(make_menu_icons())
    cut_caves()
    # preview sheet
    items = list(icons.values())
    prev = Image.new("RGBA", (16 * 6 * len(items) + 10 * len(items), 16 * 6), (40, 30, 30, 255))
    for i, im in enumerate(items):
        prev.alpha_composite(im.resize((96, 96), Image.NEAREST), (i * 106, 0))
    w = sum(im.width for im in skin.values()) + 10 * len(skin)
    sk = Image.new("RGBA", (w, max(im.height for im in skin.values())), (40, 30, 30, 255))
    x = 0
    for im in skin.values():
        sk.alpha_composite(im, (x, 0))
        x += im.width + 10
    sheet = Image.new("RGBA", (max(prev.width, sk.width * 2), prev.height + sk.height * 2 + 10), (40, 30, 30, 255))
    sheet.alpha_composite(prev, (0, 0))
    sheet.alpha_composite(sk.resize((sk.width * 2, sk.height * 2), Image.NEAREST), (0, prev.height + 10))
    sheet.save(ROOT / "art_source/ui/preview.png")
    print("skin:", ", ".join(skin), "| icons:", ", ".join(icons))


if __name__ == "__main__":
    main()
