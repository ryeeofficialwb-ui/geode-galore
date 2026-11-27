"""Gem shape outline sheet: 100 gem-cut silhouettes, outline only, on a 320x320 sheet (10x10 cells of 32x32).

    py -3.12 tools/make_gem_shapes.py

Each shape gets an inner outline too (room for glass refraction) unless it's too small to fit one.
Writes art_source/gems/gem_shapes.png (both lines), gem_shapes_outer.png / gem_shapes_inner.png (one per layer),
a labelled 4x preview and gem_shapes.txt (cell -> shape name, size).
Shapes or sizes that match a gem already in assets/ores/ores.png are skipped on purpose (checked at the end).
"""
import math
import os
import re

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "art_source", "gems")
CELL = 32
COLS = 10
OUTLINE = (20, 16, 28, 255)
PAD = 0.35  # stretch a hair past the box so sharp tips still land on a pixel


# ---------------------------------------------------------------- geometry helpers
def in_poly(x, y, pts):
    inside = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def fit(pts, w, h):
    """Scale points so they fill the w x h box (plus PAD)."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    return [(-PAD + (x - x0) / (x1 - x0) * (w + 2 * PAD), -PAD + (y - y0) / (y1 - y0) * (h + 2 * PAD)) for x, y in pts]


def rot(pts, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


# ---------------------------------------------------------------- shapes: each returns inside(x, y) for a w x h box
def polygon(pts):
    def make(w, h):
        p = fit(pts, w, h)
        return lambda x, y: in_poly(x, y, p)
    return make


def ellipse(egg=0.0):
    def make(w, h):
        a, b = w / 2, h / 2
        def f(x, y):
            u = (x - a) / a
            v = (y - b) / b
            u /= 1 + egg * v  # egg: narrower at the top
            return u * u + v * v <= 1.0
        return f
    return make


def superellipse(n):
    def make(w, h):
        a, b = w / 2, h / 2
        return lambda x, y: abs((x - a) / a) ** n + abs((y - b) / b) ** n <= 1.0
    return make


def pear(e=1.0):
    """Round bottom, pointed top. e < 1 bulges the sides out (raindrop), e > 1 pulls them in (onion / flame)."""
    def make(w, h):
        r = w / 2
        cx, cy = w / 2, h - r
        d = cy + PAD
        sin_a = min(r / d, 0.999)
        tan_a = sin_a / math.sqrt(1 - sin_a * sin_a)
        y_t = cy - r * sin_a
        def f(x, y):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                return True
            if -PAD <= y <= y_t:
                t = (y + PAD) / (y_t + PAD)
                hw = (y_t + PAD) * tan_a * t ** e
                return abs(x - cx) <= hw
            return False
        return f
    return make


def rotated(shape, deg, bw, bh):
    """Base shape built bw x bh, turned deg degrees inside a w x h box."""
    def make(w, h):
        f = shape(bw, bh)
        a = math.radians(-deg)
        c, s_ = math.cos(a), math.sin(a)
        def g(x, y):
            dx, dy = x - w / 2, y - h / 2
            return f(dx * c - dy * s_ + bw / 2, dx * s_ + dy * c + bh / 2)
        return g
    return make


def barrel():
    def make(w, h):
        a, b = w / 2, h * 0.78
        return lambda x, y: ((x - w / 2) / a) ** 2 + ((y - h / 2) / b) ** 2 <= 1.0
    return make


def flip_v(shape):
    def make(w, h):
        f = shape(w, h)
        return lambda x, y: f(x, h - y)
    return make


def swap_xy(shape):
    """Turn a vertical shape on its side (shape is built h x w then transposed)."""
    def make(w, h):
        f = shape(h, w)
        return lambda x, y: f(y, x)
    return make


def lens():
    """Marquise / navette: two circle arcs meeting in points at top and bottom."""
    def make(w, h):
        a, b = w / 2, h / 2 + PAD
        R = (a * a + b * b) / (2 * a)
        off = R - a
        cy = h / 2
        return lambda x, y: (x - (w / 2 - off)) ** 2 + (y - cy) ** 2 <= R * R and (x - (w / 2 + off)) ** 2 + (y - cy) ** 2 <= R * R
    return make


def heart():
    pts = []
    for i in range(240):
        t = i / 240 * 2 * math.pi
        pts.append((16 * math.sin(t) ** 3, -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))))
    return polygon(pts)


def rounded_poly(pts, radius_frac):
    def make(w, h):
        p = fit(pts, w, h)
        r = radius_frac * min(w, h)
        cx = sum(q[0] for q in p) / len(p)
        cy = sum(q[1] for q in p) / len(p)
        # shrink toward the centre so adding the radius back keeps the box size
        k = 1 - r / (min(w, h) / 2) * 1.0
        s = [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in p]
        def f(x, y):
            if in_poly(x, y, s):
                return True
            n = len(s)
            return any(seg_dist(x, y, *s[i], *s[(i + 1) % n]) <= r for i in range(n))
        return f
    return make


def curved_triangle(flat=1.35, down=False):
    """Trillion with bowed-out sides: three shallow arcs between the corners."""
    verts = [(0.0, -1.0), (0.866, 0.5), (-0.866, 0.5)]
    pts = []
    for i in range(3):
        a, b = verts[i], verts[(i + 1) % 3]
        side = math.dist(a, b)
        R = side * flat
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        ln = math.hypot(mx, my)
        dd = math.sqrt(R * R - (side / 2) ** 2)
        cx, cy = -mx / ln * dd + mx, -my / ln * dd + my  # centre sits inward, so the arc bows out
        a0 = math.atan2(a[1] - cy, a[0] - cx)
        a1 = math.atan2(b[1] - cy, b[0] - cx)
        if a1 < a0:
            a1 += 2 * math.pi
        if a1 - a0 > math.pi:
            a0, a1 = a1, a0 + 2 * math.pi
        for k in range(40):
            t = a0 + (a1 - a0) * k / 40
            pts.append((cx + R * math.cos(t), cy + R * math.sin(t)))
    if down:
        pts = [(x, -y) for x, y in pts]
    return polygon(pts)


def star(points, inner):
    """Drawn as straight 1px lines between the points (spikes come out cleaner than a filled edge)."""
    pts = []
    for i in range(points * 2):
        r = 1.0 if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / points
        pts.append((r * math.cos(a), r * math.sin(a)))
    make = polygon(pts)
    make.lines = pts
    return make


def line_outline(pts, w, h):
    """Polygon outline drawn with Bresenham lines, vertices snapped into the w x h box."""
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    v = [((x - x0) / (x1 - x0) * (w - 1), (y - y0) / (y1 - y0) * (h - 1)) for x, y in pts]
    return draw_poly(v, w, h)


def draw_poly(v, w, h):
    v = [(round(x), round(y)) for x, y in v]
    line = [[False] * w for _ in range(h)]
    for i in range(len(v)):
        (ax, ay), (bx, by) = v[i], v[(i + 1) % len(v)]
        dx, dy = abs(bx - ax), -abs(by - ay)
        sx, sy = (1 if ax < bx else -1), (1 if ay < by else -1)
        err = dx + dy
        while True:
            line[ay][ax] = True
            if (ax, ay) == (bx, by):
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                ax += sx
            if e2 <= dx:
                err += dx
                ay += sy
    return line


def regular(n, start_deg=-90):
    return polygon([(math.cos(math.radians(start_deg + i * 360 / n)), math.sin(math.radians(start_deg + i * 360 / n))) for i in range(n)])


def cross(arm):
    """Greek cross; arm = arm thickness as a fraction of the box."""
    def make(w, h):
        def f(x, y):
            return abs(x - w / 2) <= arm * w / 2 or abs(y - h / 2) <= arm * h / 2
        return f
    return make


def latin_cross(arm, bar_y):
    def make(w, h):
        return lambda x, y: abs(x - w / 2) <= arm * w / 2 or abs(y - bar_y * h) <= arm * w / 2
    return make


def quatrefoil():
    def make(w, h):
        r = w * 0.27
        cs = [(w / 2, r), (w / 2, h - r), (r, h / 2), (w - r, h / 2)]
        return lambda x, y: any((x - a) ** 2 + (y - b) ** 2 <= r * r for a, b in cs) or (abs(x - w / 2) + abs(y - h / 2) <= w * 0.3)
    return make


def flower(petals=5):
    def make(w, h):
        R = w / 2
        pr = R * 0.36
        cs = [(w / 2 + (R - pr) * math.cos(-math.pi / 2 + i * 2 * math.pi / petals),
               h / 2 + (R - pr) * math.sin(-math.pi / 2 + i * 2 * math.pi / petals)) for i in range(petals)]
        return lambda x, y: (x - w / 2) ** 2 + (y - h / 2) ** 2 <= (R * 0.55) ** 2 or any((x - a) ** 2 + (y - b) ** 2 <= pr * pr for a, b in cs)
    return make


def crescent(cut=0.85, shift=0.55):
    def make(w, h):
        r = h / 2
        cx, cy = r, h / 2
        r2 = r * cut
        ox = cx + r * shift
        return lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r and (x - ox) ** 2 + (y - cy) ** 2 > r2 * r2
    return make


def half_moon():
    def make(w, h):
        a, b = w / 2, h
        return lambda x, y: ((x - a) / a) ** 2 + ((y - h) / b) ** 2 <= 1.0
    return make


def gothic(top_frac):
    """Bullet / gothic arch: straight sides, pointed arched top."""
    def make(w, h):
        top_h = top_frac * h
        a = w / 2
        b = top_h + PAD
        R = (a * a + b * b) / (2 * a)
        def f(x, y):
            if y >= top_h:
                return True
            # two arcs with centres on the shoulder line, meeting at the tip
            return (x - (w - R)) ** 2 + (y - top_h) ** 2 <= R * R and (x - R) ** 2 + (y - top_h) ** 2 <= R * R
        return f
    return make


# ---------------------------------------------------------------- round 2 shapes (from the user's colour marks)
def star_pts(points, inner):
    pts = []
    for i in range(points * 2):
        r = 1.0 if i % 2 == 0 else inner
        a = -math.pi / 2 + i * math.pi / points
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def _tangent(px, py, cx, cy, r, side):
    """Tangent point on circle (cx, cy, r) seen from (px, py); side=+1 picks the right-hand one, -1 the left."""
    dx, dy = cx - px, cy - py
    d = math.hypot(dx, dy)
    a = math.atan2(dy, dx)
    b = math.asin(r / d)
    best = None
    for s_ in (1, -1):
        t = a + s_ * b
        L = math.sqrt(d * d - r * r)
        q = (px + L * math.cos(t), py + L * math.sin(t))
        if best is None or (q[0] - best[0]) * side > 0:
            best = q
    return best


def heart2():
    """Rounder heart: two overlapping circles and straight sides tangent down to the tip."""
    def make(w, h):
        r = 0.27 * w
        c1, c2 = (r, r), (w - r, r)
        tip = (w / 2, h + PAD)
        tl = _tangent(*tip, *c1, r, -1)
        tr = _tangent(*tip, *c2, r, 1)
        body = [tl, c1, c2, tr, tip]
        return lambda x, y: ((x - c1[0]) ** 2 + (y - c1[1]) ** 2 <= r * r or (x - c2[0]) ** 2 + (y - c2[1]) ** 2 <= r * r
                             or in_poly(x, y, body))
    return make


def _stem(w, h, y0):
    """Flared foot for the spade and club."""
    def f(x, y):
        if y < y0:
            return False
        t = (y - y0) / (h - y0)
        return abs(x - w / 2) <= w * (0.07 + 0.17 * t * t)
    return f


def spade():
    def make(w, h):
        hh = h * 0.8
        hf = heart2()(w, hh)
        st = _stem(w, h, h * 0.55)
        return lambda x, y: (y <= hh and hf(x, hh - y)) or st(x, y)
    return make


def club():
    def make(w, h):
        r = 0.26 * w
        cs = [(w / 2, r), (r, r * 2.3), (w - r, r * 2.3)]
        mid = (w / 2, r * 2.0, r * 0.75)
        st = _stem(w, h, r * 2.4)
        return lambda x, y: (any((x - a) ** 2 + (y - b) ** 2 <= r * r for a, b in cs)
                             or (x - mid[0]) ** 2 + (y - mid[1]) ** 2 <= mid[2] ** 2 or st(x, y))
    return make


def trefoil():
    def make(w, h):
        r = 0.27 * w
        d = (w / 2 - r) / math.cos(math.radians(30))
        cx, cy = w / 2, r + d
        cs = [(cx + d * math.cos(math.radians(a)), cy + d * math.sin(math.radians(a))) for a in (-90, 30, 150)]
        return lambda x, y: (any((x - a) ** 2 + (y - b) ** 2 <= r * r for a, b in cs)
                             or (x - cx) ** 2 + (y - cy) ** 2 <= (d * 0.9) ** 2)
    return make


def fan():
    """Fan cut: a wedge with a curved top, point at the bottom."""
    def make(w, h):
        R = h + PAD
        ax, ay = w / 2, h + PAD
        half = math.asin(min(1.0, (w / 2 - 0.3) / R))
        def f(x, y):
            dx, dy = x - ax, ay - y
            return dx * dx + dy * dy <= R * R and dy > 0 and abs(math.atan2(dx, dy)) <= half
        return f
    return make


def d_cut():
    """Flat back, rounded front (like a D)."""
    def make(w, h):
        return lambda x, y: (x / w) ** 2 + ((y - h / 2) / (h / 2)) ** 2 <= 1.0
    return make


def bell():
    def make(w, h):
        top = 0.45 * h
        a = 0.34 * w
        def f(x, y):
            if y < top:
                v = (top - y) / top
                hw = a * math.sqrt(max(0.0, 1 - v * v))
            else:
                t = (y - top) / (h - top)
                hw = a + (w / 2 + PAD - a) * t ** 2.2
            return abs(x - w / 2) <= hw
        return f
    return make


def arch():
    """Round arch: half circle on a short block."""
    def make(w, h):
        r = w / 2
        return lambda x, y: (y >= r and abs(x - r) <= r) or (x - r) ** 2 + (y - r) ** 2 <= r * r
    return make


def heater():
    """Heater shield: flat top, straight sides, then curving into a point."""
    def make(w, h):
        top = 0.36 * h
        def f(x, y):
            if y < top:
                return abs(x - w / 2) <= w / 2
            t = min(1.0, (y - top) / (h + PAD - top))
            return abs(x - w / 2) <= w / 2 * (1 - t ** 1.7) ** 0.8
        return f
    return make


def capsule():
    def make(w, h):
        r = h / 2
        return lambda x, y: abs(x - w / 2) <= w / 2 - r or (abs(x - w / 2) - (w / 2 - r)) ** 2 + (y - r) ** 2 <= r * r
    return make


def keystone():
    pts = [(0.5 + 0.5 * math.cos(t), 0.24 - 0.24 * math.sin(t)) for t in [math.pi - math.pi * k / 24 for k in range(25)]]
    return polygon(pts + [(0.8, 1), (0.2, 1)])


# ---------------------------------------------------------------- the 100 shapes (10 rows of 10)
DIAMOND_PROFILE = [(0.3, 0), (0.7, 0), (1, 0.3), (0.5, 1), (0, 0.3)]
DIAMOND_TALL = [(0.32, 0), (0.68, 0), (1, 0.22), (0.5, 1), (0, 0.22)]
HEX_DT = [(0.5, 0), (1, 0.18), (1, 0.82), (0.5, 1), (0, 0.82), (0, 0.18)]
HEX_ST = [(0.5, 0), (1, 0.22), (1, 1), (0, 1), (0, 0.22)]

def clip_rect(c):  # rectangle with all four corners cut by c (fraction of the short side, applied per axis)
    return polygon([(c, 0), (1 - c, 0), (1, c), (1, 1 - c), (1 - c, 1), (c, 1), (0, 1 - c), (0, c)])

def clip_rect_wh(cx, cy):
    return polygon([(cx, 0), (1 - cx, 0), (1, cy), (1, 1 - cy), (1 - cx, 1), (cx, 1), (0, 1 - cy), (0, cy)])

SHAPES = [
    # row 0 - round & oval
    ("round", ellipse(), 9, 9),
    ("round", ellipse(), 14, 14),
    ("round", ellipse(), 17, 17),
    ("round", ellipse(), 28, 28),
    ("oval", ellipse(), 12, 18),
    ("oval", ellipse(), 14, 22),
    ("oval", ellipse(), 26, 30),
    ("oval (flat)", ellipse(), 22, 14),
    ("capsule", capsule(), 28, 16),
    ("egg", ellipse(0.18), 20, 26),
    # row 1 - pear & drop
    ("pear", pear(), 9, 15),
    ("pear", pear(), 13, 21),
    ("pear", pear(), 19, 30),
    ("pear (fat)", pear(), 25, 30),
    ("pear (tilted)", rotated(pear(), 45, 13, 26), 30, 30),
    ("pear (upside down)", flip_v(pear()), 15, 23),
    ("pear (upside down)", flip_v(pear()), 23, 28),
    ("pear (sideways)", swap_xy(pear()), 28, 17),
    ("briolette", pear(0.65), 11, 28),
    ("flame drop", pear(1.3), 15, 27),
    # row 2 - marquise & lozenge
    ("marquise", lens(), 15, 24),
    ("marquise", lens(), 11, 27),
    ("marquise (fat)", lens(), 19, 30),
    ("marquise (flat)", swap_xy(lens()), 30, 11),
    ("marquise (flat)", swap_xy(lens()), 23, 13),
    ("spade", spade(), 24, 27),
    ("lozenge", polygon([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)]), 13, 23),
    ("lozenge", polygon([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)]), 19, 30),
    ("lozenge (flat)", polygon([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)]), 30, 17),
    ("soft rhombus", rounded_poly([(0.5, 0), (1, 0.5), (0.5, 1), (0, 0.5)], 0.14), 27, 27),
    # row 3 - hearts & cushions
    ("heart", heart(), 11, 10),
    ("heart (round)", heart2(), 21, 19),
    ("heart", heart(), 23, 21),
    ("heart (round)", heart2(), 28, 25),
    ("cushion", superellipse(3.2), 14, 14),
    ("cushion", superellipse(3.2), 20, 20),
    ("cushion", superellipse(3.2), 30, 30),
    ("cushion (long)", superellipse(3.2), 16, 24),
    ("cushion (wide)", superellipse(3.2), 26, 18),
    ("antique cushion", superellipse(5.5), 26, 26),
    # row 4 - step cuts
    ("princess", polygon([(0, 0), (1, 0), (1, 1), (0, 1)]), 12, 12),
    ("princess", polygon([(0, 0), (1, 0), (1, 1), (0, 1)]), 20, 20),
    ("princess (wide)", polygon([(0, 0), (1, 0), (1, 1), (0, 1)]), 24, 16),
    ("emerald cut", clip_rect_wh(0.2, 0.14), 12, 18),
    ("emerald cut", clip_rect_wh(0.2, 0.14), 16, 23),
    ("emerald cut", clip_rect_wh(0.18, 0.12), 20, 30),
    ("emerald cut (wide)", clip_rect_wh(0.12, 0.18), 28, 18),
    ("asscher", clip_rect(0.28), 16, 16),
    ("asscher", clip_rect(0.28), 27, 27),
    ("barrel", barrel(), 24, 28),
    # row 5 - baguettes, trapezoids, half moons
    ("fan", fan(), 29, 23),
    ("truncated triangle", polygon([(0.4, 0), (0.6, 0), (1, 0.8), (0.9, 1), (0.1, 1), (0, 0.8)]), 26, 23),
    ("arrowhead", polygon([(0.5, 0), (1, 0.9), (0.93, 1), (0.5, 0.8), (0.07, 1), (0, 0.9)]), 23, 28),
    ("trefoil", trefoil(), 26, 25),
    ("D cut", d_cut(), 16, 26),
    ("trapezoid", polygon([(0.22, 0), (0.78, 0), (1, 1), (0, 1)]), 20, 12),
    ("trapezoid", polygon([(0.2, 0), (0.8, 0), (1, 1), (0, 1)]), 30, 18),
    ("bell", bell(), 24, 26),
    ("arch", arch(), 26, 22),
    ("epaulette", polygon([(0, 0), (1, 0), (1, 0.55), (0.7, 1), (0.3, 1), (0, 0.55)]), 28, 14),
    # row 6 - triangles, kites, shields
    ("heater shield", heater(), 22, 27),
    ("triangle", polygon([(0.5, 0), (1, 1), (0, 1)]), 29, 26),
    ("triangle (down)", polygon([(0, 0), (1, 0), (0.5, 1)]), 17, 15),
    ("tall triangle", polygon([(0.5, 0), (1, 1), (0, 1)]), 15, 27),
    ("trillion", curved_triangle(1.3), 27, 24),
    ("trillion (rounded, down)", rounded_poly([(0, 0), (1, 0), (0.5, 1)], 0.2), 25, 22),
    ("kite", polygon([(0.5, 0), (1, 0.32), (0.5, 1), (0, 0.32)]), 11, 19),
    ("kite (wide)", polygon([(0.5, 0), (1, 0.38), (0.5, 1), (0, 0.38)]), 25, 30),
    ("shield", polygon([(0, 0), (1, 0), (1, 0.45), (0.5, 1), (0, 0.45)]), 15, 18),
    ("shield", polygon([(0.15, 0), (0.85, 0), (1, 0.15), (1, 0.5), (0.5, 1), (0, 0.5), (0, 0.15)]), 27, 28),
    # row 7 - polygons
    ("pentagon", regular(5), 21, 20),
    ("pentagon", regular(5), 27, 26),
    ("hexagon (pointy)", regular(6), 15, 17),
    ("hexagon (flat)", regular(6, 0), 26, 22),
    ("long hexagon", polygon([(0.2, 0), (0.8, 0), (1, 0.5), (0.8, 1), (0.2, 1), (0, 0.5)]), 30, 14),
    ("octagon", regular(8, 22.5), 14, 14),
    ("octagon", regular(8, 22.5), 20, 20),
    ("long octagon", clip_rect_wh(5 / 26, 5 / 17), 26, 17),
    ("decagon", regular(10, 18), 26, 26),
    ("heptagon", regular(7), 17, 17),
    # row 8 - fancy
    ("puffy star", rounded_poly(star_pts(5, 0.56), 0.1), 27, 26),
    ("star", star(5, 0.45), 29, 28),
    ("sparkle", star(4, 0.42), 27, 27),
    ("six star", star(6, 0.55), 25, 28),
    ("cross", cross(0.46), 20, 20),
    ("club", club(), 26, 27),
    ("quatrefoil", quatrefoil(), 26, 26),
    ("crescent (thick)", crescent(0.74, 0.62), 28, 28),
    ("flower", flower(5), 28, 28),
    ("bullet", gothic(0.42), 20, 28),
    # row 9 - diamond profiles & crystals
    ("keystone", keystone(), 26, 24),
    ("diamond", polygon(DIAMOND_PROFILE), 23, 18),
    ("diamond", polygon(DIAMOND_PROFILE), 30, 24),
    ("diamond (tall)", polygon(DIAMOND_TALL), 21, 27),
    ("crystal", polygon(HEX_DT), 7, 20),
    ("crystal (wide)", polygon(HEX_DT), 25, 30),
    ("crystal (flat)", polygon([(y, x) for x, y in HEX_DT]), 30, 12),
    ("crystal point", polygon(HEX_ST), 9, 22),
    ("crystal point (wide)", polygon(HEX_ST), 23, 27),
    ("crystal (diagonal)", polygon(rot([(0, -15), (5, -11), (5, 11), (0, 15), (-5, 11), (-5, -11)], 45)), 28, 28),
]


# ---------------------------------------------------------------- build
def build_mask(shape, w, h):
    f = shape(w, h)
    return [[f(x + 0.5, y + 0.5) for x in range(w)] for y in range(h)]


def outline(mask):
    h, w = len(mask), len(mask[0])
    def m(x, y):
        return 0 <= x < w and 0 <= y < h and mask[y][x]
    return [[mask[y][x] and not (m(x - 1, y) and m(x + 1, y) and m(x, y - 1) and m(x, y + 1)) for x in range(w)] for y in range(h)]


def pixel_perfect(line):
    """Drop the elbow pixel of small L-steps so curves read as clean 1px lines (real corners stay)."""
    h, w = len(line), len(line[0])
    def on(x, y):
        return 0 <= x < w and 0 <= y < h and line[y][x]
    def run(x, y, dx, dy):
        n = 0
        while on(x + dx, y + dy):
            x, y, n = x + dx, y + dy, n + 1
        return n
    for y in range(h - 1):
        for x in range(w - 1):
            block = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            if all(line[by][bx] for bx, by in block):
                def outside_links(pt):
                    px, py = pt
                    return sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                               if (dx or dy) and (px + dx, py + dy) not in block and on(px + dx, py + dy))
                bx, by = min(block, key=outside_links)
                line[by][bx] = False
    changed = True
    while changed:
        changed = False
        for y in range(h):
            for x in range(w):
                if not line[y][x]:
                    continue
                nb = [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and on(x + dx, y + dy)]
                if len(nb) != 2:
                    continue
                (ax, ay), (bx, by) = nb
                if not ((ax == 0) != (bx == 0) and (ay == 0) != (by == 0) and abs(ax) + abs(ay) == 1 and abs(bx) + abs(by) == 1):
                    continue
                hx = ax if ax else bx
                vy = ay if ay else by
                if run(x, y, hx, 0) >= 3 and run(x, y, 0, vy) >= 3:
                    continue  # a real corner
                line[y][x] = False
                changed = True
    return line


def erode(mask, r, r2=None):
    """Keep only pixels whose whole disc (radius r, or squared radius r2) is inside the shape."""
    h, w = len(mask), len(mask[0])
    r2 = r * r if r2 is None else r2
    disc = [(dx, dy) for dx in range(-r - 1, r + 2) for dy in range(-r - 1, r + 2) if dx * dx + dy * dy <= r2]
    def m(x, y):
        return 0 <= x < w and 0 <= y < h and mask[y][x]
    return [[mask[y][x] and all(m(x + dx, y + dy) for dx, dy in disc) for x in range(w)] for y in range(h)]


def open3(mask):
    """Morphological opening with a 3x3 square: removes bits of the shape thinner than 3px."""
    h, w = len(mask), len(mask[0])
    def m(g, x, y):
        return 0 <= x < w and 0 <= y < h and g[y][x]
    e = [[all(m(mask, x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)) for x in range(w)] for y in range(h)]
    return [[any(m(e, x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)) for x in range(w)] for y in range(h)]


def largest_part(mask):
    """Drop little islands an erosion can leave behind (keeps the biggest 4-connected piece)."""
    h, w = len(mask), len(mask[0])
    seen = [[False] * w for _ in range(h)]
    best = []
    for y0 in range(h):
        for x0 in range(w):
            if mask[y0][x0] and not seen[y0][x0]:
                part, stack = [], [(x0, y0)]
                seen[y0][x0] = True
                while stack:
                    x, y = stack.pop()
                    part.append((x, y))
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if 0 <= nx < w and 0 <= ny < h and mask[ny][nx] and not seen[ny][nx]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
                if len(part) > len(best):
                    best = part
    out = [[False] * w for _ in range(h)]
    for x, y in best:
        out[y][x] = True
    return out


def poly_vertices(pts, w, h):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    return [((x - x0) / (x1 - x0) * (w - 1), (y - y0) / (y1 - y0) * (h - 1)) for x, y in pts]


def offset_poly(v, d):
    """Move every edge of polygon v inward by d px (mitred corners) - a smaller copy with the same angles."""
    area = sum(v[i][0] * v[(i + 1) % len(v)][1] - v[(i + 1) % len(v)][0] * v[i][1] for i in range(len(v)))
    sgn = 1 if area > 0 else -1
    lines = []
    for i in range(len(v)):
        (ax, ay), (bx, by) = v[i], v[(i + 1) % len(v)]
        ex, ey = bx - ax, by - ay
        ln = math.hypot(ex, ey)
        nx, ny = -ey / ln * sgn, ex / ln * sgn  # inward normal
        lines.append(((ax + nx * d, ay + ny * d), (ex, ey)))
    out = []
    for i in range(len(v)):
        (p1, d1), (p2, d2) = lines[i - 1], lines[i]
        den = d1[0] * d2[1] - d1[1] * d2[0]
        t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / den
        out.append((p1[0] + d1[0] * t, p1[1] + d1[1] * t))
    return out


def touches(a, b):
    """True if any pixel of line a sits on or next to (8-way) a pixel of line b."""
    h, w = len(a), len(a[0])
    return any(a[y][x] and any(0 <= x + dx < w and 0 <= y + dy < h and b[y + dy][x + dx]
                               for dx in (-1, 0, 1) for dy in (-1, 0, 1))
               for y in range(h) for x in range(w))


def inner_poly_outline(pts, outer, symmetric):
    """Inner outline for line-drawn shapes (stars): the polygon offset inward until it clears the outer line."""
    h, w = len(outer), len(outer[0])
    v = poly_vertices(pts, w, h)
    d = 2.0 if min(w, h) < 18 else 3.0
    while d < min(w, h) / 3:
        iv = offset_poly(v, d)
        if all(-0.5 <= x <= w - 0.5 and -0.5 <= y <= h - 0.5 for x, y in iv):
            line = draw_poly(iv, w, h)
            if symmetric:
                line = mirror(line)
            if not touches(line, outer):
                return line
        d += 0.5
    return None


INNER_MIN = 4  # the inner outline needs at least this many pixels each way, or the shape keeps just its outer line


def inner_outline(mask, symmetric):
    """Second outline set inside the first: 1px gap on small gems, 2px on big ones. None if it won't fit."""
    h, w = len(mask), len(mask[0])
    area = sum(map(sum, mask))
    for gap in ((2, 1) if min(w, h) >= 18 else (1,)):
        # squared radius (gap+1)^2 + gap^2 is the smallest disc that keeps the two lines from touching, even diagonally
        inner = largest_part(open3(erode(mask, 1 + gap, (1 + gap) ** 2 + gap ** 2)))
        if sum(map(sum, inner)) >= 0.33 * area:
            break  # a 2px gap that eats most of a thin shape falls back to 1px
    if not any(any(r) for r in inner):
        return None
    ys = [y for y, r in enumerate(inner) if any(r)]
    xs = [x for x in range(w) if any(r[x] for r in inner)]
    if max(xs) - min(xs) + 1 < INNER_MIN or max(ys) - min(ys) + 1 < INNER_MIN:
        return None
    line = pixel_perfect(outline(inner))
    return mirror(line) if symmetric else line


def mirror(mask):
    """Force left-right symmetry (copy the left half onto the right)."""
    w = len(mask[0])
    for row in mask:
        for x in range(w // 2):
            row[w - 1 - x] = row[x]
    return mask


def trim(mask):
    ys = [y for y, r in enumerate(mask) if any(r)]
    xs = [x for x in range(len(mask[0])) if any(r[x] for r in mask)]
    return [r[min(xs):max(xs) + 1] for r in mask[min(ys):max(ys) + 1]]


## lapis, obsidian and jade are clusters / chunks, not cut shapes, so only the cut gems count for the size rule
GEMS = {"white_quartz", "rose_quartz", "peridot", "tigers_eye", "onyx", "aquamarine", "tourmaline", "amethyst", "ruby", "sapphire", "topaz", "emerald", "pearl", "zapperion"}


def existing_gems():
    """Filled silhouettes of every ore & gem already on ores.png."""
    sheet = Image.open(os.path.join(ROOT, "assets", "ores", "ores.png")).convert("RGBA")
    src = open(os.path.join(ROOT, "scripts", "sprite_atlas.gd")).read().split("const ORES")[1]
    out = {}
    for name, x, y, w, h in re.findall(r'"(\w+)": Rect2\((\d+), (\d+), (\d+), (\d+)\)', src):
        c = sheet.crop((int(x), int(y), int(x) + int(w), int(y) + int(h))).getchannel("A")
        c = c.crop(c.getbbox())
        out[name] = [[c.getpixel((i, j)) > 0 for i in range(c.width)] for j in range(c.height)]
    return out


def fill(mask_outline):
    """Fill an outline back into a solid silhouette (flood the outside)."""
    h, w = len(mask_outline), len(mask_outline[0])
    outside = [[False] * (w + 2) for _ in range(h + 2)]
    stack = [(0, 0)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w + 2 and 0 <= y < h + 2) or outside[y][x]:
            continue
        if 1 <= x <= w and 1 <= y <= h and mask_outline[y - 1][x - 1]:
            continue
        outside[y][x] = True
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return [[not outside[y + 1][x + 1] for x in range(w)] for y in range(h)]


def iou(a, b):
    """Best overlap of two silhouettes, centred on each other."""
    ha, wa, hb, wb = len(a), len(a[0]), len(b), len(b[0])
    W, H = max(wa, wb), max(ha, hb)
    def place(m, w, h):
        ox, oy = (W - w) // 2, (H - h) // 2
        return {(x + ox, y + oy) for y in range(h) for x in range(w) if m[y][x]}
    sa, sb = place(a, wa, ha), place(b, wb, hb)
    return len(sa & sb) / len(sa | sb)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    assert len(SHAPES) == 100, len(SHAPES)
    sheet = Image.new("RGBA", (CELL * COLS, CELL * COLS), (0, 0, 0, 0))
    inner_sheet = sheet.copy()
    legend = []
    made = []
    for i, (name, shape, w, h) in enumerate(SHAPES):
        mask = build_mask(shape, w, h)
        symmetric = not any(k in name for k in ("diagonal", "sideways", "crescent", "tilted", "D cut"))
        if symmetric:
            mask = mirror(mask)
        mask = trim(mask)
        if getattr(shape, "lines", None):
            line = line_outline(shape.lines, w, h)
            mask = fill(line)
        else:
            line = outline(mask)
        line = pixel_perfect(line)
        if symmetric:
            line = mirror(line)
        mh, mw = len(line), len(line[0])
        cx, cy = (i % COLS) * CELL, (i // COLS) * CELL
        ox, oy = cx + (CELL - mw) // 2, cy + (CELL - mh) // 2
        for y in range(mh):
            for x in range(mw):
                if line[y][x]:
                    sheet.putpixel((ox + x, oy + y), OUTLINE)
        if getattr(shape, "lines", None):
            inner = inner_poly_outline(shape.lines, line, symmetric)
        else:
            inner = inner_outline(mask, symmetric)
        if inner:
            for y in range(mh):
                for x in range(mw):
                    if inner[y][x]:
                        inner_sheet.putpixel((ox + x, oy + y), OUTLINE)
        note = "" if inner else "  (no inner outline - too small)"
        legend.append(f"{i:3d}  row {i // COLS} col {i % COLS}  {name:26s} {mw}x{mh}  Rect2({ox}, {oy}, {mw}, {mh}){note}")
        made.append((i, name, mask, mw, mh))

    # ---- never reuse a shape + size you already have
    old = existing_gems()
    clashes = []
    for i, name, mask, mw, mh in made:
        for oname, om in old.items():
            if oname not in GEMS:
                continue
            ow, oh = len(om[0]), len(om)
            if abs(ow - mw) <= 1 and abs(oh - mh) <= 1:
                clashes.append(f"{i} {name} {mw}x{mh} is the size of {oname} {ow}x{oh} (overlap {iou(mask, om):.2f})")
    sizes = {}
    for i, name, mask, mw, mh in made:
        key = (tuple(map(tuple, mask)))
        if key in sizes:
            clashes.append(f"{i} {name} is the same as {sizes[key]}")
        sizes[key] = f"{i} {name}"

    sheet.save(os.path.join(OUT_DIR, "gem_shapes_outer.png"))
    inner_sheet.save(os.path.join(OUT_DIR, "gem_shapes_inner.png"))
    sheet.alpha_composite(inner_sheet)
    sheet.save(os.path.join(OUT_DIR, "gem_shapes.png"))
    with open(os.path.join(OUT_DIR, "gem_shapes.txt"), "w") as fh:
        fh.write("Gem shape outlines - art_source/gems/gem_shapes.png (320x320, 10x10 cells of 32x32)\n\n")
        fh.write("\n".join(legend) + "\n")

    # labelled preview for checking
    big = Image.new("RGBA", (sheet.width * 4, sheet.height * 4), (236, 232, 240, 255))
    big.alpha_composite(sheet.resize(big.size, Image.NEAREST))
    d = ImageDraw.Draw(big)
    for i, (name, *_rest) in enumerate(SHAPES):
        d.text(((i % COLS) * 128 + 2, (i // COLS) * 128 + 1), f"{i}", fill=(200, 40, 60, 255))
    for k in range(1, COLS):
        d.line([(k * 128, 0), (k * 128, big.height)], fill=(190, 186, 200, 255))
        d.line([(0, k * 128), (big.width, k * 128)], fill=(190, 186, 200, 255))
    big.save(os.path.join(OUT_DIR, "gem_shapes_preview.png"))

    print("\n".join(legend))
    print("\nclashes with existing gems / each other:", clashes or "none")


if __name__ == "__main__":
    main()
