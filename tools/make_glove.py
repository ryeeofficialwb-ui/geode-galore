"""Turns art_source/hands/hand_6.png (bare hand) into a thick leather work glove.

    py -3.12 tools/make_glove.py

Steps: grow the silhouette 1 px outward (outer outline becomes fill, a new outline wraps it - the
outlines between fingers stay), recolour the skin tones to leather (Resurrect 64), cover the nails,
and add a cuff with a seam + stitching at the wrist.
Writes art_source/hands/glove_6.png (32 x 32) and glove_6_preview.png (8x).
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "art_source/hands/hand_6.png"
OUT = ROOT / "art_source/hands/glove_6.png"
PREVIEW = ROOT / "art_source/hands/glove_6_preview.png"


def _rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


# source skin tones, darkest to lightest -> tone index
SKIN = {
    (75, 15, 52): 0,     # outline
    (158, 65, 81): 1,    # deep shadow
    (181, 108, 98): 2,   # shadow
    (160, 148, 145): 4,  # nail -> leather base
    (198, 148, 118): 4,  # base
    (211, 179, 150): 5,  # light
    (208, 190, 180): 5,  # nail shine -> leather light
}
# leather glove (Resurrect 64)
GLOVE = {0: "#2e222f", 1: "#6e2727", 2: "#9e4539", 4: "#cd683d", 5: "#e6904e", 6: "#fbb954"}
# cuff: a paler, heavier leather band
CUFF = {1: "#9e4539", 2: "#cd683d", 4: "#e6904e", 5: "#fbb954", 6: "#fbb954"}
STITCH = "#6e2727"

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def main():
    src = Image.open(SRC).convert("RGBA")
    W, H = src.size
    tone = {}
    for y in range(H):
        for x in range(W):
            p = src.getpixel((x, y))
            if p[3]:
                tone[(x, y)] = SKIN[p[:3]]

    def inside(x, y):
        return 0 <= x < W and 0 <= y < H

    # 1) grow: transparent pixels touching the silhouette become the new outline
    grow = {(x + dx, y + dy) for (x, y) in tone for dx, dy in N4
            if inside(x + dx, y + dy) and (x + dx, y + dy) not in tone}
    new = dict(tone)
    # old outer outline pixels become fill, shaded like their inner neighbours (one step darker
    # on the shadow side, so the thicker edge reads as rounded)
    for (x, y), t in tone.items():
        if t != 0 or not any((x + dx, y + dy) in grow for dx, dy in N4):
            continue
        inner = [tone[(x + dx, y + dy)] for dx, dy in N4 if tone.get((x + dx, y + dy), 0) != 0]
        if not inner:
            continue
        t2 = max(set(inner), key=inner.count)
        if any((x + dx, y + dy) in grow for dx, dy in ((1, 0), (0, 1))):  # bottom / right edge
            t2 = {5: 4, 4: 2, 2: 1, 1: 1}[t2]
        new[(x, y)] = t2
    for p in grow:
        new[p] = 0
    # any fill left touching transparency / the canvas edge goes back to outline
    for (x, y), t in list(new.items()):
        if t and any(not inside(x + dx, y + dy) or (x + dx, y + dy) not in new for dx, dy in N4):
            new[(x, y)] = 0

    # 2) cuff: the wrist end (top right), cut across the arm (axis runs ~(-2, 3))
    def along(x, y):
        return 3 * y - 2 * x

    SEAM = -21
    out = Image.new("RGBA", (W, H))
    for (x, y), t in new.items():
        a = along(x, y)
        if t == 0:
            col = GLOVE[0]
        elif SEAM - 3 < a <= SEAM:  # seam between cuff and glove
            col = GLOVE[0]
        elif a <= SEAM - 3:
            col = CUFF[t]
        else:
            col = GLOVE[t]
        out.putpixel((x, y), _rgb(col))
    # stitching: every other pixel on a line just inside the cuff
    for (x, y), t in new.items():
        a = along(x, y)
        if t and SEAM - 8 < a <= SEAM - 6 and (x + y) % 2 == 0:
            if out.getpixel((x, y))[:3] != _rgb(GLOVE[0])[:3]:
                out.putpixel((x, y), _rgb(STITCH))

    out.save(OUT)
    out.resize((W * 8, H * 8), Image.NEAREST).save(PREVIEW)
    print("wrote", OUT.relative_to(ROOT), "and", PREVIEW.relative_to(ROOT))


if __name__ == "__main__":
    main()
