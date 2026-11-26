"""Makes the 8-frame torch: your stick (art_source/torch/stick.png) with a wrapped head, your scorch marks
(art_source/torch/stick_scorched.png) glowing on it, and its own big red torch flame.

    py -3.12 tools/make_torch.py

Writes art_source/torch/:
    stick_head.png              the stick with the wrapped head (no scorch, no flame), on the torch canvas
    flame_0.png ... flame_7.png the "flame" layer for each frame: the scorch glow + flame + sparks
    torch_0.png ... torch_7.png the two put together
    torch_sheet.png             the 8 torch frames side by side
Then tools/make_torch.lua (run by Aseprite) builds art_source/torch/torch.aseprite with a "stick" layer
and a "flame" layer.

The flame: drawn from scratch (not the lighter's), wide at the bottom so it swallows the whole head,
several tongues licking up, mostly reds. Its colour comes from a "heat" value per pixel: hot in the
middle-bottom, cooling towards the edges and the top, with rising waves of heat running through it.
Breathing: the whole flame swells and shrinks once per loop, and the scorch glow on the wrap follows it,
creeping down the head as the flame swells and pulling back up as it shrinks.
"""
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
STICK_SRC = ROOT / "art_source/torch/stick.png"
SCORCH_SRC = ROOT / "art_source/torch/stick_scorched.png"   # your scorch drawing
SCORCH_AT = (18, 37)       # where that drawing sat on the old 48x76 canvas (stick at STICK_POS_OLD)
STICK_POS_OLD = (2, 38)
OUT = ROOT / "art_source/torch"
FRAMES = 8
CANVAS = (56, 90)
STICK_POS = (2, 52)        # where the stick's bounding box goes on the canvas
HEAD_LEN = 10              # px (along the stick) of cloth wrap at the top

# flame shape
FLAME_H = 38               # px tall (at rest)
FLAME_HALF_W = 11.5        # half width at its widest (near the bottom)
FLAME_SINK = 2             # px the flame's bottom overlaps the top of the head
BREATHE = 0.14             # flame swells / shrinks by up to 14% (height) once per loop
SWAY = 2.2                 # px the top leans at most
TONGUES = 0.42             # how much the rising waves cut tongues into the outline

OUTLINE = (46, 34, 47, 255)
WRAP = [(70, 50, 50, 255), (107, 77, 77, 255), (150, 112, 86, 255)]  # dark, mid, light (cloth)
# the torch flame's colours, coolest to hottest: mostly reds, a little orange / yellow in the core
HEAT = [(110, 39, 39), (174, 35, 52), (158, 69, 57), (205, 104, 61), (247, 150, 23), (251, 255, 134)]
HEAT_AT = [0.0, 0.16, 0.34, 0.52, 0.72, 0.90]   # heat value where each colour starts
# the scorch on the wrap, coolest to hottest (your maroon and crimson, then glowing red-orange)
SCORCH = [(110, 39, 39, 255), (174, 35, 52, 255), (205, 104, 61, 255)]
SCORCH_REACH = (1.0, 11.5)  # how far down the head (px along the stick) the glow reaches: shrunk .. swollen

# sparks: (x offset from flame centre, frame it starts on, sideways drift per frame)
SPARKS = [(-6, 0, -1), (5, 2, 1), (1, 4, 0), (-3, 5, 1), (7, 6, 0)]
SPARK_LIFE = 4
SPARK_RISE = 4


def _axis(x, y):
    """t grows towards the stick's top-right end, s across the stick (small = upper-left side)."""
    return (x - y) / math.sqrt(2), (x + y) / math.sqrt(2)


def _stick_on_canvas():
    st = Image.open(STICK_SRC).convert("RGBA")
    st = st.crop(st.getbbox())
    c = Image.new("RGBA", CANVAS)
    c.alpha_composite(st, STICK_POS)
    return c


def _wrap_head(img):
    """Thickens the top HEAD_LEN px of the stick by 1px and paints it as wrapped cloth.
    Returns the head's pixels and the top-end centre (where the flame sits)."""
    px = img.load()
    w, h = img.size
    solid = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 0]
    tmax = max(_axis(x, y)[0] for x, y in solid)
    head = {(x, y) for x, y in solid if _axis(x, y)[0] >= tmax - HEAD_LEN}
    grown = set(head)
    for x, y in head:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                n = (x + dx, y + dy)
                if 0 <= n[0] < w and 0 <= n[1] < h and _axis(*n)[0] <= tmax + 0.8:
                    grown.add(n)
    ss = [_axis(x, y)[1] for x, y in grown]
    smin, smax = min(ss), max(ss)
    tlo = min(_axis(x, y)[0] for x, y in grown)
    thi = max(_axis(x, y)[0] for x, y in grown)
    for x, y in grown:
        edge = any((x + dx, y + dy) not in grown for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            px[x, y] = OUTLINE
            continue
        t, s = _axis(x, y)
        across = (s - smin) / max(smax - smin, 1)
        tone = 2 if across < 0.38 else 1 if across < 0.7 else 0
        band = int(round(t - tlo)) % 3 == 1
        px[x, y] = OUTLINE if band and tone < 2 else WRAP[max(0, tone - 1)] if band else WRAP[tone]
    end = [(x, y) for x, y in grown if _axis(x, y)[0] >= thi - 1.5]
    anchor = (round(sum(x for x, _ in end) / len(end)), round(sum(y for _, y in end) / len(end)))
    return grown, thi, anchor


def _scorch_marks(head):
    """Your scorch drawing -> {canvas pixel: level} (0 = maroon, 1 = crimson), only on the wrap."""
    sc = Image.open(SCORCH_SRC).convert("RGBA")
    shift = (STICK_POS[0] - STICK_POS_OLD[0] + SCORCH_AT[0], STICK_POS[1] - STICK_POS_OLD[1] + SCORCH_AT[1])
    marks = {}
    for y in range(sc.height):
        for x in range(sc.width):
            c = sc.getpixel((x, y))
            p = (x + shift[0], y + shift[1])
            if c[3] and p in head and c[:3] in (SCORCH[0][:3], SCORCH[1][:3]):
                marks[p] = 0 if c[:3] == SCORCH[0][:3] else 1
    return marks


def _breath(k):
    """0 = flame at its smallest, 1 = at its biggest. One breath per loop."""
    return 0.5 - 0.5 * math.cos(2 * math.pi * k / FRAMES)


def _scorch_layer(marks, thi, k):
    """The scorch glow for frame k: marks near the flame step one shade hotter, marks past the
    glow's reach step one shade cooler (the crimson ones fade to maroon, the maroon ones disappear)."""
    layer = Image.new("RGBA", CANVAS)
    reach = SCORCH_REACH[0] + (SCORCH_REACH[1] - SCORCH_REACH[0]) * _breath(k)
    for (x, y), lvl in marks.items():
        depth = thi - _axis(x, y)[0]
        if depth < reach - 2.5:
            lvl += 1
        elif depth > reach + 1.0:
            lvl -= 1
        if lvl >= 0:
            layer.putpixel((x, y), SCORCH[min(lvl, 2)])
    return layer


def _hash(x, y):
    v = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
    return v - math.floor(v)


def _flame_frame(k, anchor):
    ph = 2 * math.pi * k / FRAMES
    b = _breath(k)
    H = FLAME_H * (1 - BREATHE / 2 + BREATHE * b)
    HW = FLAME_HALF_W * (0.95 + 0.1 * b)
    cx = anchor[0] - 1.0
    base = anchor[1] + FLAME_SINK
    img = Image.new("RGBA", CANVAS)
    px = img.load()
    for y in range(CANVAS[1]):
        u = (base - y) / H                    # 0 at the flame's bottom, 1 at its usual top
        if u < -0.02 or u > 1.35:
            continue
        lean = SWAY * math.sin(ph + 0.4) * max(u, 0) ** 1.5
        # rising waves (whole-number multiples of ph so the 8 frames loop)
        for x in range(CANVAS[0]):
            dx = (x - cx - lean)
            uu = max(u, 0.0)
            # widest a bit above the bottom, rounded at the bottom, pointy at the top
            width = HW * min(1.0, math.sqrt((u + 0.03) / 0.22)) * (1 - uu) ** 0.85 if 0 <= uu < 1 and u > -0.03 else 0.0
            wave = (math.sin(uu * 9.0 - ph * 2 + dx * 0.45) * 0.55 +
                    math.sin(uu * 15.0 - ph * 3 - dx * 0.7 + 1.3) * 0.30 +
                    math.sin(uu * 5.0 - ph + dx * 0.25 + 2.1) * 0.15)
            edge = 1 - abs(dx) / max(width, 0.01) if width > 0 else -1
            edge += TONGUES * wave * (0.4 + uu)
            # licks that break off above the top
            if uu >= 0.88:
                lick = wave - 0.55 - (uu - 0.88) * 2.2
                if abs(dx) < 2.6 and lick > 0:
                    heat = 0.1 + lick * 0.4
                    px[x, y] = HEAT[0 if heat < 0.16 else 1] + (255,)
                if uu >= 1 or edge <= 0:
                    continue
            if edge <= 0:
                continue
            heat = edge * 0.75 + (1 - uu) * 0.55 * min(1.0, 0.35 + uu / 0.2) - 0.25 + 0.12 * wave
            heat = min(1.0, heat)
            lvl = max(i for i, a in enumerate(HEAT_AT) if heat >= a) if heat >= 0 else 0
            if edge < 0.12:
                lvl = min(lvl, 1)              # the outline stays dark / crimson
            px[x, y] = HEAT[lvl] + (255,)
    _drop_lonely(img)
    return img


def _drop_lonely(img):
    px = img.load()
    w, h = img.size
    lonely = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] and not any(
        0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3]
        for dx in (-1, 0, 1) for dy in (-1, 0, 1) if dx or dy)]
    for p in lonely:
        px[p] = (0, 0, 0, 0)


def _sparks(img, k, anchor):
    px = img.load()
    top = img.getbbox()[1]
    for dx0, start, drift in SPARKS:
        age = (k - start) % FRAMES
        if age >= SPARK_LIFE:
            continue
        x = anchor[0] + dx0 + drift * age
        y = top + 8 - SPARK_RISE * age
        heat = max(1, 4 - age)
        if 0 <= x < CANVAS[0] and 0 <= y < CANVAS[1] and px[x, y][3] == 0:
            px[x, y] = HEAT[heat] + (255,)


def main():
    stick = _stick_on_canvas()
    head, thi, anchor = _wrap_head(stick)
    marks = _scorch_marks(head)
    OUT.mkdir(parents=True, exist_ok=True)
    stick.save(OUT / "stick_head.png")
    sheet = Image.new("RGBA", (CANVAS[0] * FRAMES, CANVAS[1]))
    for k in range(FRAMES):
        layer = _scorch_layer(marks, thi, k)
        flame = _flame_frame(k, anchor)
        _sparks(flame, k, anchor)
        layer.alpha_composite(flame)
        layer.save(OUT / f"flame_{k}.png")
        full = stick.copy()
        full.alpha_composite(layer)
        full.save(OUT / f"torch_{k}.png")
        sheet.alpha_composite(full, (k * CANVAS[0], 0))
    sheet.save(OUT / "torch_sheet.png")
    print("wrote", FRAMES, "frames to", OUT, "| scorch marks:", len(marks), "| flame anchor", anchor)


if __name__ == "__main__":
    main()
