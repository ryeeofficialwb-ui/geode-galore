"""Builds the app icon from the Pebble rock (assets/rocks/rock_02.png).

    py -3.12 tools/make_icon.py

Writes icon.png (256x256: the window / taskbar icon, project setting config/icon) and icon.ico
(16-256 px: the .exe's icon, export preset application/icon). Pixel art is scaled up by whole numbers
(nearest neighbour), centred on a transparent square.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/rocks/rock_02.png"


def square(img, side, pad=1):
    """The rock's pixels, scaled by the biggest whole number that fits in side x side (with a pad)."""
    rock = img.crop(img.getbbox())
    k = max(1, (side - 2 * pad * max(1, side // 32)) // max(rock.size))
    big = rock.resize((rock.width * k, rock.height * k), Image.NEAREST)
    out = Image.new("RGBA", (side, side))
    out.alpha_composite(big, ((side - big.width) // 2, (side - big.height) // 2))
    return out


def main():
    img = Image.open(SRC).convert("RGBA")
    square(img, 256).save(ROOT / "icon.png")
    sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [square(img, s) for s in sizes]
    frames[-1].save(ROOT / "icon.ico", sizes=[(s, s) for s in sizes], append_images=frames[:-1])
    print("wrote icon.png and icon.ico")


if __name__ == "__main__":
    main()
