"""Packs every rock into ONE texture and every ore & gem into ONE texture.

    py -3.12 tools/slice_sheets.py            (ores & gems; the rocks texture is left alone if it exists)
    py -3.12 tools/slice_sheets.py --rocks    (also re-cuts assets/rocks/rocks.png from the drawing sheet)

art_source/sheet_v3.png : your drawing sheet, 32x32 cells. What each cell is, is listed in GRID below.
Writes:
    assets/rocks/rocks.png   all rocks in id order (rock_01, rock_02 ... left to right), 32x32 cells, 10 a row
                             (kept 32x32, so big rocks stay big). If you draw / export this file yourself,
                             keep that order: the tool only overwrites it with --rocks.
    assets/ores/ores.png     all ores (cheapest first), then all gems (cheapest first), 32x32 cells, 10 a row
                             (each one trimmed to a square and centred in its cell)
    scripts/sprite_atlas.gd  where each one sits in those textures (the game reads this; don't edit by hand)
Prices come from ROCKS / ORES in scripts/config.gd, so run this again after changing prices or adding art.
Add a new rock / ore: draw it in a free cell of the drawing sheet, write its name in GRID, add it to ROCKS /
ORES in scripts/config.gd, then run this.
"""
import re
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "art_source/sheet_v3.png"
CONFIG = ROOT / "scripts/config.gd"
CELL = 32
COLS = 10
# None = empty cell. "rock_NN" names are rocks, everything else an ore / gem.
GRID = [
    ["rock_01", "rock_02", "rock_03", "rock_04", "rock_05", "rock_06", "rock_07", "rock_08", "rock_09", "rock_10"],
    ["rock_11", "rock_12", "rock_13", "rock_14", "rock_15", "rock_16", "rock_17", "rock_18", "rock_19", "rock_20"],
    ["rock_21", "rock_22", "rock_23", "rock_24", "rock_25", "rock_26", "rock_27", "rock_28", "rock_29", "rock_30"],
    ["copper", "rhodonite", "iron", "gold", "silver", "lead", "jade", "uranium", "zinc", "dreamstone"],
    ["rustvein", "lapis", "stibnite", "obsidian", "veridium", "hellspec", "cryo_core", "polyphite", "daevorium", "mudspec"],
    # the round orange gem (4th) was the old Topaz; Topaz is the orange triangle now (last)
    ["peridot", "ruby", "sapphire", None, "emerald", "amethyst", "onyx", "tourmaline", "zapperion", "topaz"],
    ["white_quartz", "aquamarine", "tigers_eye", "rose_quartz", "pearl", None, None, None, None, None],
]


def read_prices():
    """{id: (price, is_gem)} from config.gd's ROCKS ("price") and ORES ("sell_price", "type")."""
    out = {}
    for line in CONFIG.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*"(\w+)":\s*\{.*?"(?:sell_)?price":\s*(\d+)', line)
        if m:
            out[m.group(1)] = (int(m.group(2)), '"type": "gem"' in line)
    return out


def cut(sheet, r, c):
    return sheet.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))


def pack(items, path, write=True):
    """items: [(name, image <= 32x32)] -> one texture, each image centred in its own 32x32 cell.
    Returns {name: (x, y, w, h)}."""
    rows = max(1, (len(items) + COLS - 1) // COLS)
    out = Image.new("RGBA", (COLS * CELL, rows * CELL))
    regions = {}
    for i, (name, img) in enumerate(items):
        x = (i % COLS) * CELL + (CELL - img.width) // 2
        y = (i // COLS) * CELL + (CELL - img.height) // 2
        out.paste(img, (x, y))
        regions[name] = (x, y, img.width, img.height)
    if write:
        path.parent.mkdir(parents=True, exist_ok=True)
        out.save(path)
    return regions


def gd_dict(regions):
    lines = [f'\t"{n}": Rect2({x}, {y}, {w}, {h}),' for n, (x, y, w, h) in regions.items()]
    return "{\n" + "\n".join(lines) + "\n}"


def main():
    prices = read_prices()
    sheet = Image.open(SHEET).convert("RGBA")
    rocks, ores = [], []
    for r, row in enumerate(GRID):
        for c, name in enumerate(row):
            if name is None:
                continue
            cell = cut(sheet, r, c)
            box = cell.getbbox()
            if box is None:
                print("empty cell for", name)
                continue
            if name.startswith("rock_"):
                rocks.append((name, cell))
            else:
                item = cell.crop(box)
                side = max(item.size)  # centre on a square so icons line up
                sq = Image.new("RGBA", (side, side))
                sq.paste(item, ((side - item.width) // 2, (side - item.height) // 2))
                ores.append((name, sq))
            if name not in prices:
                print("not in config.gd (sorted last):", name)
    big = (10 ** 9, True)
    rocks.sort(key=lambda it: it[0])  # id order: rock_01, rock_02, ...
    ores.sort(key=lambda it: (prices.get(it[0], big)[1], prices.get(it[0], big)[0], it[0]))  # ores, then gems
    rock_file = ROOT / "assets/rocks/rocks.png"
    rock_regions = pack(rocks, rock_file, write="--rocks" in sys.argv or not rock_file.exists())
    ore_regions = pack(ores, ROOT / "assets/ores/ores.png")
    (ROOT / "scripts/sprite_atlas.gd").write_text(
        "## Made by tools/slice_sheets.py - don't edit by hand (run the tool again instead).\n"
        "## Where each rock sits in assets/rocks/rocks.png (rock_01 .. rock_30, 10 a row, in id order) and each ore / gem in assets/ores/ores.png.\n\n"
        f"const ROCKS := {gd_dict(rock_regions)}\n\n"
        f"const ORES := {gd_dict(ore_regions)}\n",
        encoding="utf-8")
    print("rocks.png:", ", ".join(n for n, _ in rocks))
    print("ores.png:", ", ".join(n for n, _ in ores))


if __name__ == "__main__":
    main()
