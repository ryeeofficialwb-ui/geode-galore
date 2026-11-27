"""A 32x32 BOOK TEMPLATE to design on: a closed book lying tilted (3/4 view, like the item book art),
outlines only, with the BINDER (front cover + spine) and the PAGES (the block of page edges) on separate layers.

Writes into art_source/icons_v2/:
    book_pages_fill.png   flat placeholder colour of the pages   (hide / delete / recolour)
    book_pages_line.png   the pages' outline
    book_binder_fill.png  flat placeholder colour of cover + spine
    book_binder_line.png  the binder's outline (incl. the line between cover and spine)
    book_preview.png      everything, 10x
tools/make_book_outline.lua then builds book.aseprite from them.

    py -3.12 tools/make_book_outline.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art_source/icons_v2"
S = 32
LINE = (0x2e, 0x22, 0x2f, 255)
BINDER = (0x8a, 0x7f, 0x8e, 255)
PAGES = (0xe8, 0xe2, 0xd0, 255)

def add(p, q, k=1.0):
    return (p[0] + q[0] * k, p[1] + q[1] * k)


def inside(poly, x, y):
    n, c = len(poly), False
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            c = not c
    return c


# front cover (top face), corners clockwise from the top-left; T = the book's thickness (down, a touch right)
A, B, C, D = (11.0, 1.5), (29.5, 7.0), (24.0, 22.5), (4.5, 17.5)
T = (1.0, 5.5)
LIP = (0.0, 2.4)  # the back cover showing under the pages


COVER = [A, B, C, D]
PAGES_FACE = [D, C, B, add(B, T), add(C, T), add(D, T)]          # page edges along the bottom and the right side
BACK_LIP = [add(D, T), add(C, T), add(B, T), add(add(B, T), LIP), add(add(C, T), LIP), add(add(D, T), LIP)]
SPINE = [add(A, (-0.5, 0.5)), D, add(add(D, T), LIP), add(add(D, T), (-3.0, 0.8)), add(D, (-3.2, 0.0)), add(A, (-2.6, 2.6))]  # the binding wrapped round the left edge


# label map: higher number = in front
REGIONS = [("pages", 1, [PAGES_FACE]), ("binder", 2, [BACK_LIP]), ("binder", 3, [SPINE]), ("binder", 4, [COVER])]
label = [[0] * S for _ in range(S)]
part = [[None] * S for _ in range(S)]
for name, prio, polys in REGIONS:
    for y in range(S):
        for x in range(S):
            if any(inside(p, x + 0.5, y + 0.5) for p in polys) and prio > label[y][x]:
                label[y][x] = prio
                part[y][x] = name


def outline(x, y):
    """Outline pixel: next to empty space, or in front of a region that's behind it (one line per edge)."""
    L = label[y][x]
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx, ny = x + dx, y + dy
        n = label[ny][nx] if 0 <= nx < S and 0 <= ny < S else 0
        if n == 0 or n < L:
            return True
    return False


layers = {k: Image.new("RGBA", (S, S), (0, 0, 0, 0)) for k in ("pages_fill", "pages_line", "binder_fill", "binder_line")}
for y in range(S):
    for x in range(S):
        if not part[y][x]:
            continue
        p = part[y][x]
        if outline(x, y):
            layers[p + "_line"].putpixel((x, y), LINE)
        else:
            layers[p + "_fill"].putpixel((x, y), PAGES if p == "pages" else BINDER)

OUT.mkdir(parents=True, exist_ok=True)
flat = Image.new("RGBA", (S, S), (0, 0, 0, 0))
for k in ("pages_fill", "pages_line", "binder_fill", "binder_line"):
    layers[k].save(OUT / f"book_{k}.png")
    flat.alpha_composite(layers[k])
prev = Image.new("RGBA", (S, S), (0x3a, 0x44, 0x52, 255))
prev.alpha_composite(flat)
prev.resize((S * 10, S * 10), Image.NEAREST).save(OUT / "book_preview.png")
print("wrote", OUT / "book_*.png")
