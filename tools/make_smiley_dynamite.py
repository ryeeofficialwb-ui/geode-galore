"""Draws two 32x32 item icons in the game's hand-drawn item style (the 32x32 ones in assets/ui/items:
1px #2e222f outline, Resurrect 64 colours, lit from the top-left, white glints):

    smiley    a shaded yellow face: eyes with glints, an open grin, blush
    dynamite  one stick on the diagonal: shaded paper tube, label band, end cap, curly fuse, spark

Writes each part as its own layer PNG into art_source/icons_v2/ (tools/make_smiley_dynamite.lua then
builds smiley.aseprite / dynamite.aseprite from them), plus the flat icon and a 10x preview.
No PIL needed.

    py -3.12 tools/make_smiley_dynamite.py
"""
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art_source/icons_v2"
S = 32
K = "#2e222f"


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def blank():
    return [[None] * S for _ in range(S)]


def save_png(path, layers, scale=1, bg=None):
    """layers: list of 32x32 grids of hex colours / None, drawn in order (later on top)."""
    w = h = S * scale
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            px = None
            for g in layers:
                c = g[y // scale][x // scale]
                if c:
                    px = c
            if px:
                raw += bytes(hexrgb(px)) + b"\xff"
            elif bg:
                raw += bytes(hexrgb(bg)) + b"\xff"
            else:
                raw += b"\x00\x00\x00\x00"

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def outline(g, solid=None):
    """A 1px dark outline round everything in g (outside pixels touching it side-on)."""
    out = blank()
    for y in range(S):
        for x in range(S):
            if g[y][x] or (solid and solid[y][x]):
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < S and 0 <= yy < S and g[yy][xx]:
                    out[y][x] = K
                    break
    return out


def put(g, x, y, c):
    if 0 <= x < S and 0 <= y < S:
        g[y][x] = c


# ------------------------------------------------------------------ smiley
def smiley():
    face = blank()
    cx, cy, r = 16.0, 16.0, 11.6
    light = (-0.5, -0.62, 0.6)
    ln = math.sqrt(sum(v * v for v in light))
    light = tuple(v / ln for v in light)
    for y in range(S):
        for x in range(S):
            dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
            d2 = dx * dx + dy * dy
            if d2 > 1.0:
                continue
            z = math.sqrt(max(0.0, 1.0 - d2))
            i = dx * light[0] + dy * light[1] + z * light[2]
            if d2 > 0.86 and dx + dy > 0.6:
                c = "#fb6b1d"          # the dark rim at the bottom right
            elif i > 0.88:
                c = "#fbff86"
            elif i > 0.3:
                c = "#f9c22b"
            elif i > -0.05:
                c = "#f79617"
            else:
                c = "#fb6b1d"
            face[y][x] = c
    # glints: a little curved highlight up top-left
    for x, y in ((9, 8), (10, 7), (11, 7), (8, 9), (8, 10)):
        put(face, x, y, "#ffffff")
    put(face, 12, 7, "#fbff86")

    feat = blank()
    # eyes: tall ovals with a white glint
    for ex in (11, 19):
        for y in range(11, 16):          # 2 wide, 5 tall
            put(feat, ex, y, K)
            put(feat, ex + 1, y, K)
        put(feat, ex, 12, "#ffffff")     # glint (top-left, where the light comes from)
        put(feat, ex + 1, 11, "#3e3546")  # softer top corner
        put(feat, ex, 15, "#3e3546")      # softer bottom corner
    # an open grin: lip line, teeth, dark mouth, tongue
    for x in range(10, 22):
        put(feat, x, 18, K)
    put(feat, 9, 17, K)
    put(feat, 22, 17, K)
    put(feat, 10, 19, K)
    put(feat, 21, 19, K)
    for x in range(11, 21):
        put(feat, x, 19, "#ffffff")       # teeth
    put(feat, 15, 19, "#c7dcd0")
    put(feat, 16, 19, "#c7dcd0")
    put(feat, 11, 20, K)
    put(feat, 20, 20, K)
    for x in range(12, 20):
        put(feat, x, 20, "#6e2727")       # inside the mouth
    put(feat, 12, 21, K)
    put(feat, 19, 21, K)
    for x in range(13, 19):
        put(feat, x, 21, "#e83b3b")       # tongue
    put(feat, 14, 21, "#f68181")
    put(feat, 15, 21, "#f68181")
    for x in range(13, 19):
        put(feat, x, 22, K)
    # blush
    for x, y in ((7, 18), (8, 18), (23, 18), (24, 18)):
        put(feat, x, y, "#f68181")
    put(feat, 7, 18, "#fca790")
    put(feat, 23, 18, "#fca790")

    line = outline(face)
    return [("outline", line), ("face", face), ("features", feat)]


# ------------------------------------------------------------------ dynamite
def dynamite():
    ax, ay = 6.0, 26.0                     # bottom-left end of the stick's axis
    bx, by = 22.0, 10.0                    # top-right end
    L = math.hypot(bx - ax, by - ay)
    dx, dy = (bx - ax) / L, (by - ay) / L  # along the stick
    nx, ny = -dy, dx                       # across it (towards the bottom right)
    R = 3.7
    stick = blank()
    cap = blank()
    for y in range(S):
        for x in range(S):
            px, py = x + 0.5 - ax, y + 0.5 - ay
            t = px * dx + py * dy
            v = px * nx + py * ny
            if t < -0.6 or t > L + 0.6 or abs(v) > R:
                continue
            # rounded ends
            if t < 0.0 and (t * t / 0.36 + v * v / (R * R)) > 1.0:
                continue
            vn = v / R                            # -1 (lit side, top-left) .. 1 (shade)
            if t > L - 1.3:                       # the top end: the tube's opening, packed dark
                if abs(vn) < 0.55:
                    c = "#4c3e24" if vn > -0.2 else "#966c6c"
                else:
                    c = "#f68181" if vn < 0 else "#ae2334"
                cap[y][x] = c
                continue
            band = L * 0.36 <= t <= L * 0.62          # the paper label
            ring = abs(t - 2.2) < 0.7 or abs(t - (L - 3.4)) < 0.7
            if band:
                ramp = ["#ffffff", "#ffffff", "#c7dcd0", "#9babb2", "#7f708a"]  # white paper
            elif ring:
                ramp = ["#f68181", "#e83b3b", "#ae2334", "#7a3045", "#6e2727"]
            else:
                ramp = ["#ffffff", "#f68181", "#e83b3b", "#ae2334", "#6e2727"]
            if vn < -0.78:
                c = ramp[1]
            elif vn < -0.45:
                c = ramp[0] if (band or not ring) and 3.0 < t < L - 4.0 and int(t) % 7 not in (0, 1) else ramp[1]
            elif vn < 0.3:
                c = ramp[2]
            elif vn < 0.7:
                c = ramp[3]
            else:
                c = ramp[4]
            stick[y][x] = c
    # a little writing on the label: two dark ticks
    for t, w in ((L * 0.45, 1.2), (L * 0.53, 1.2)):
        for k in (-1, 0, 1):
            x = int(ax + dx * t + nx * k * w)
            y = int(ay + dy * t + ny * k * w)
            if stick[y][x] in ("#c7dcd0", "#ffffff", "#9babb2"):
                stick[y][x] = "#3e3546"

    fuse = blank()
    path = [(23, 9), (24, 8), (24, 7), (25, 6), (26, 6), (27, 5), (27, 4), (26, 3)]
    for i, (x, y) in enumerate(path):
        put(fuse, x, y, "#ab947a" if i % 2 == 0 else "#966c6c")
    put(fuse, 26, 3, "#3e3546")                    # the burnt tip
    spark = blank()
    sx, sy = 26, 2
    put(spark, sx, sy, "#ffffff")
    for ddx, ddy in ((1, 0), (-1, 0), (0, -1), (0, 1)):
        put(spark, sx + ddx, sy + ddy, "#fbff86")
    for ddx, ddy in ((2, 0), (-2, 0), (0, -2)):
        put(spark, sx + ddx, sy + ddy, "#f9c22b")
    for ddx, ddy in ((1, -1), (-1, -1), (1, 1)):
        put(spark, sx + ddx, sy + ddy, "#f79617")
    for x, y, c in ((30, 1, "#f9c22b"), (29, 4, "#f79617"), (22, 1, "#f79617"), (30, 5, "#fb6b1d")):
        put(spark, x, y, c)
    spark[3][26] = spark[3][26]  # (the burnt tip stays under the spark's lower arm)

    solid = blank()
    for g in (stick, cap, fuse):
        for y in range(S):
            for x in range(S):
                if g[y][x]:
                    solid[y][x] = g[y][x]
    line = outline(solid, spark)
    return [("outline", line), ("stick", stick), ("cap", cap), ("fuse", fuse), ("spark", spark)]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, layers in (("smiley", smiley()), ("dynamite", dynamite())):
        for lname, g in layers:
            save_png(OUT / f"{name}_{lname}.png", [g])
        grids = [g for _, g in layers]
        save_png(OUT / f"{name}.png", grids)
        save_png(OUT / f"{name}_preview.png", grids, scale=10, bg="#3e3546")
        print("wrote", name, "(", ", ".join(n for n, _ in layers), ")")


if __name__ == "__main__":
    main()
