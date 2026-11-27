"""Draws the newer Upgrades icons (16 x 16, Resurrect 64, same style as tools/make_ui.py) - and ONLY these,
so the rest of the UI art isn't redrawn.

    py -3.12 tools/make_upgrade_icons.py

Writes assets/ui/upgrades/rock_piles.png, strongbox.png and rebirth.png (art_source/ui/upgrades/<name>.aseprite
are the same, to touch up in Aseprite).
"""
from pathlib import Path
from PIL import Image
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_ui import stamp, PAL, LUMP, ROOT  # noqa: E402

UPG = ROOT / "assets/ui/upgrades"

# Strongbox: an iron-banded wooden chest with a gold lock
STRONGBOX = [
    "................",
    "................",
    "..KKKKKKKKKKKK..",
    ".KnOOOOOOOOOOnK.",
    ".KOOOOOOOOOOOOK.",
    ".KMMMMMMMMMMMMK.",
    ".KKKKKKyyKKKKKK.",
    ".KnOOOKyYKOOOnK.",
    ".KOOOOOKKOOOOOK.",
    ".KOOOOOOOOOOOOK.",
    ".KMMMMMMMMMMMMK.",
    ".KnOOOOOOOOOOnK.",
    ".KnnnnnnnnnnnnK.",
    "..KKKKKKKKKKKK..",
    "................",
    "................",
]

# Rebirth: an artifact slot with a gold plus (one more slot) and a sparkle
REBIRTH = [
    "................",
    "..KKKKKKKKKKK...",
    ".KmmmmmmmmmmmK..",
    ".KmgggggggggmK..",
    ".KmgggKKKgggmK..",
    ".KmgggKyKgggmK..",
    ".KmgKKKyKKKgmK..",
    ".KmgKyyYyyKgmK..",
    ".KmgKKKyKKKgmK..",
    ".KmgggKyKgggmK..",
    ".KmgggKKKgggmK..",
    ".KmgggggggggmK..",
    ".KmmmmmmmmmmmK..",
    "..KKKKKKKKKKK...",
    "................",
    "................",
]


def rock_piles():
    """A pyramid of lumps (3 / 2 / 1, back to front) and a green plus."""
    img = Image.new("RGBA", (16, 16))
    for at in ((5, 4),):           # top
        stamp(img, LUMP, PAL, at)
    for at in ((2, 7), (7, 7)):    # middle
        stamp(img, LUMP, PAL, at)
    for at in ((0, 10), (5, 10), (9, 10)):  # front
        stamp(img, LUMP, PAL, at)
    stamp(img, [".e.", "eEe", ".e."], PAL, (13, 0))
    return img


def from_grid(grid, sparkle=False):
    img = Image.new("RGBA", (16, 16))
    stamp(img, grid, PAL)
    if sparkle:
        stamp(img, [".Y.", "YwY", ".Y."], PAL, (13, 0))
    return img


def main():
    UPG.mkdir(parents=True, exist_ok=True)
    icons = {"rock_piles": rock_piles(), "strongbox": from_grid(STRONGBOX), "rebirth": from_grid(REBIRTH, True)}
    for name, img in icons.items():
        img.save(UPG / f"{name}.png")
        print("wrote", (UPG / f"{name}.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
