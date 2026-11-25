"""Makes the 8-frame flicker animation from your flame drawing (art_source/flame_v2.png).

    py -3.12 tools/make_flame.py

Writes art_source/flame_anim/flame_0.png ... flame_7.png (+ flame_sheet.png, 8 frames side by side)
and copies the frames to assets/lighter/ for the game.

Movement: the flame leans left / right (more at the tip), stretches / squashes, the thin tip grows /
shrinks, and the bottom (red base + blue gas) breathes wider / narrower and wobbles.
Escaping flame: in TONGUE_FRAMES the thin tip pinches off and floats up as its own little tongue ; the next
frame it drifts higher, smaller and one shade cooler, then it's gone.
Colour: only your palette is used. Pixels are given a "heat" (dark red < red-orange < orange < yellow
< white) and bands of heat rise up through the flame, so pixels step one shade hotter or cooler as a
band passes. Edge pixels stay in the red / orange shades so the outline keeps reading.
"""
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_source/flame_v2.png"
OUT = ROOT / "art_source/flame_anim"
FRAMES = 8
CANVAS = (24, 56)       # every frame is the same size; the base sits at the bottom centre (room on top for escaping bits)
BODY_ROWS = 32          # rows 0..31 of the drawing are the flame body, below that the base + gas
SWAY = 1.6              # px the tip leans at most
STRETCH = 0.08          # body stretches / squashes by up to 8%
TIP_GROW = 2            # px the thin tip grows / shrinks
BASE_BREATHE = 0.28     # the base gets up to 28% wider / narrower
BASE_WOBBLE = 1         # px the base shifts sideways
HEAT_BANDS = 0.32       # how tight the rising heat bands are (bigger = more, thinner bands)
TONGUE_FRAMES = (2, 6)  # frames where the tip pinches off and floats away (the frame after shows it drifting higher)
TONGUE_ROWS = 7         # how many rows of the tip break off
TONGUE_GAP = 2          # px gap between the flame and the piece that broke off
HEAT_STRENGTH = 0.4     # how much of the flame a band covers (0 = no colour change, 1 = constantly changing)

# your palette, coolest to hottest. The blue gas is kept apart.
HEAT = ["#9e4539", "#cd683d", "#f79617", "#fbff86", "#ffffff"]
GAS = "#8fd3ff"
GAS_ALPHAS = [70, 124, 160]   # your gas is see-through in 3 steps; it pulses between them


def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


HEAT_RGB = [_rgb(h) for h in HEAT]
GAS_RGB = _rgb(GAS)


def _heat_of(c):
    for i, h in enumerate(HEAT_RGB):
        if c[:3] == h:
            return i
    return None


def _scaled_row(row, sx, w):
    """Stretch one row sideways around its centre (nearest pixel)."""
    out = Image.new("RGBA", (w, 1))
    cx = (w - 1) / 2
    for x in range(w):
        src = round(cx + (x - cx) / sx)
        if 0 <= src < w:
            out.putpixel((x, 0), row.getpixel((src, 0)))
    return out


def _recolour(img, ph):
    """Rising heat bands: interior pixels step one shade hotter / cooler. Stays on the palette."""
    px = img.load()
    w, h = img.size
    solid = [[px[x, y][3] > 0 for x in range(w)] for y in range(h)]
    changes = []
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0:
                continue
            if p[:3] == GAS_RGB:
                # the gas glow pulses: step its see-through level up / down with a faster wave
                lvl = min(range(len(GAS_ALPHAS)), key=lambda i: abs(GAS_ALPHAS[i] - p[3]))
                gw = math.sin(ph * 2 + x * 0.5 + y * 0.7)
                lvl = max(0, min(len(GAS_ALPHAS) - 1, lvl + (1 if gw > 0.35 else -1 if gw < -0.35 else 0)))
                if GAS_ALPHAS[lvl] != p[3]:
                    changes.append((x, y, GAS_RGB + (GAS_ALPHAS[lvl],)))
                continue
            heat = _heat_of(p)
            if heat is None:
                continue
            edge = any(not (0 <= x + dx < w and 0 <= y + dy < h and solid[y + dy][x + dx])
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            # bands move up as the phase goes on (y = 0 is the top), slightly slanted with the sway
            wave = math.sin(y * HEAT_BANDS + ph + x * 0.25 * math.sin(ph))
            limit = 1.0 - HEAT_STRENGTH
            step = 1 if wave > limit else -1 if wave < -limit else 0
            new = heat + step
            if edge:
                new = max(0, min(2, new))                      # edges stay red / orange
            elif heat >= 3:
                new = max(3, min(4, new))                      # the hot core only swaps yellow <-> white
            else:
                new = max(1, min(3, new))                      # the warm part: red-orange <-> orange <-> yellow
            if new != heat:
                changes.append((x, y, HEAT_RGB[new] + (p[3],)))
    for x, y, c in changes:
        px[x, y] = c


def _drop_lonely_pixels(img):
    """Removes pixels that ended up with no neighbours at all (bits that broke off while shifting rows)."""
    px = img.load()
    w, h = img.size
    lonely = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 0:
                continue
            if not any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] > 0
                       for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy):
                lonely.append((x, y))
    for x, y in lonely:
        px[x, y] = (0, 0, 0, 0)


def _cool(c, steps=1):
    heat = _heat_of(c)
    if heat is None:
        return c
    return HEAT_RGB[max(0, heat - steps)] + (c[3],)


def _pinch_tip(img, lean):
    """Breaks the top TONGUE_ROWS off the flame and lifts them TONGUE_GAP px (a bit along the lean).
    Returns the piece that broke off as [(x, y, colour)] at its new position."""
    px = img.load()
    w, h = img.size
    top = next(y for y in range(h) if any(px[x, y][3] > 0 for x in range(w)))
    piece = []
    for y in range(top, top + TONGUE_ROWS):
        for x in range(w):
            if px[x, y][3] > 0:
                piece.append((x, y, px[x, y]))
                px[x, y] = (0, 0, 0, 0)
    dx = 1 if lean > 0.3 else -1 if lean < -0.3 else 0
    moved = []
    for x, y, c in piece:
        nx, ny = x + dx, y - TONGUE_GAP
        if 0 <= nx < w and 0 <= ny < h:
            px[nx, ny] = c
            moved.append((nx, ny, c))
    return moved


def _drift(img, piece, lean):
    """The broken-off piece a frame later: higher, smaller (its top half) and darker."""
    if not piece:
        return
    px = img.load()
    w, h = img.size
    ys = sorted({y for _, y, _ in piece})
    keep = set(ys[:max(1, (len(ys) + 1) // 2)])
    dx = 1 if lean > 0.3 else -1 if lean < -0.3 else 0
    for x, y, c in piece:
        if y in keep:
            nx, ny = x + dx, y - 5
            if 0 <= nx < w and 0 <= ny < h:
                px[nx, ny] = _cool(c)


def main():
    src = Image.open(SRC).convert("RGBA")
    art = src.crop(src.getbbox())
    w, h = art.size
    body = art.crop((0, 0, w, BODY_ROWS))
    base = art.crop((0, BODY_ROWS, w, h))
    OUT.mkdir(parents=True, exist_ok=True)
    frames = []
    for k in range(FRAMES):
        ph = 2 * math.pi * k / FRAMES
        stretch = 1.0 + STRETCH * math.sin(ph * 2 + 0.8)
        tip = round(TIP_GROW * math.sin(ph + 1.9))
        new_h = max(8, round(BODY_ROWS * stretch) + tip)
        frame = Image.new("RGBA", CANVAS)
        ox = (CANVAS[0] - w) // 2
        base_y = CANVAS[1] - base.height
        # the base + gas: breathes wider / narrower, wobbles sideways; the lower (gas) rows move most
        breathe = 1.0 + BASE_BREATHE * math.sin(ph * 2 + 2.4)
        wobble = round(BASE_WOBBLE * math.sin(ph + 0.6))
        for by in range(base.height):
            g = by / max(base.height - 1, 1)                    # 0 just under the body, 1 at the bottom
            row = _scaled_row(base.crop((0, by, w, by + 1)), 1.0 + (breathe - 1.0) * (0.4 + 0.6 * g), w)
            frame.alpha_composite(row, (ox + round(wobble * math.sqrt(g)), base_y + by + (1 if g > 0.5 and math.sin(ph * 2) > 0.5 else 0)))
        # the body, from the bottom up: map each new row to a source row (nearest), shift it sideways
        for ny in range(new_h):
            t = ny / max(new_h - 1, 1)                          # 0 at the bottom of the body, 1 at the tip
            sy = BODY_ROWS - 1 - min(BODY_ROWS - 1, int(round(t * (BODY_ROWS - 1))))
            lean = SWAY * math.sin(ph) * t ** 1.6
            row = body.crop((0, sy, w, sy + 1))
            frame.alpha_composite(row, (ox + int(round(lean)), base_y - 1 - ny))
        _drop_lonely_pixels(frame)
        _recolour(frame, ph)
        frames.append(frame)
    # flame escaping: the tip pinches off in TONGUE_FRAMES and drifts away in the frame after
    for k in TONGUE_FRAMES:
        lean = SWAY * math.sin(2 * math.pi * k / FRAMES)
        piece = _pinch_tip(frames[k], lean)
        _drift(frames[(k + 1) % FRAMES], piece, lean)
    for k, frame in enumerate(frames):
        frame.save(OUT / f"flame_{k}.png")
    sheet =Image.new("RGBA", (CANVAS[0] * FRAMES, CANVAS[1]))
    for k, f in enumerate(frames):
        sheet.alpha_composite(f, (k * CANVAS[0], 0))
    sheet.save(OUT / "flame_sheet.png")
    game = ROOT / "assets/lighter"  # the copies the game plays
    for k, frame in enumerate(frames):
        frame.save(game / f"flame_{k}.png")
    print("wrote", FRAMES, "frames to", OUT)


if __name__ == "__main__":
    main()
