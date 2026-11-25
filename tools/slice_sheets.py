"""Cuts the sprite sheet in art_source/ into one PNG per rock / ore / gem.

    py -3.12 tools/slice_sheets.py

art_source/sheet_v3.png : 32x32 cells. What each cell is, is listed in GRID below (row by row).
    rows 1-3: rocks -> assets/rocks/rock_NN.png        (kept 32x32, so big rocks stay big)
    rows 4-5: ores  -> assets/ores/<name>.png          (trimmed + centred on a square)
    rows 6-7: gems  -> assets/ores/<name>.png
Add a new rock / ore: draw it in a free cell, write its name in GRID, run this, then add it to
ROCKS / ORES in scripts/config.gd. You can also skip this tool and draw the single PNGs directly.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "art_source/sheet_v3.png"
CELL = 32
# None = empty cell. "rock_NN" names go to assets/rocks/, everything else to assets/ores/.
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


def main():
    sheet = Image.open(SHEET).convert("RGBA")
    for r, row in enumerate(GRID):
        for c, name in enumerate(row):
            if name is None:
                continue
            cell = sheet.crop((c * CELL, r * CELL, (c + 1) * CELL, (r + 1) * CELL))
            box = cell.getbbox()
            if box is None:
                print("empty cell for", name)
                continue
            if name.startswith("rock_"):
                cell.save(ROOT / f"assets/rocks/{name}.png")
            else:
                item = cell.crop(box)
                side = max(item.size)  # centre on a square canvas so icons line up
                sq = Image.new("RGBA", (side, side))
                sq.paste(item, ((side - item.width) // 2, (side - item.height) // 2))
                sq.save(ROOT / f"assets/ores/{name}.png")
            print("cut", name)


if __name__ == "__main__":
    main()
