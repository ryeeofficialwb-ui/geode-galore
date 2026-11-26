"""Balances the rocks and writes the whole ROCKS table in scripts/config.gd.

    py -3.12 tools/tune_drops.py            (prints the result)
    py -3.12 tools/tune_drops.py --write    (also writes it into config.gd)

What it does, for every rock:
  - PRICE by size: the rock's art is measured (its solid pixels on assets/rocks/rocks.png). The smallest
    rock costs PRICE_MIN, the biggest PRICE_MAX, the rest in between (sizes spread out exponentially).
  - ORES: each rock can only drop a few ores now - a handful of cheap ones, one or two around its price
    and sometimes a jackpot worth more than the rock. Every ore is in at least one rock.
  - CHANCES: tuned so a rock's ores are worth TARGET_RETURN of its price on AVERAGE (1.05 = the house
    loses 5% at the start: you win less than half the breaks, but the jackpots make up for it).
    Upgrades push this up: see UPGRADES in config.gd (about 2x at half levels, 4x maxed).
  - STOCK: the pricier the rock, the less often it's in stock (stock_chance) and the fewer there are.
  - HITS and ROLLS grow with size.
Names stay as they are in config.gd. Ore prices / amounts come from ORES in config.gd.
(Upgrades and the market aren't counted: this is at normal prices with no upgrades.)
"""
import math
import random
import re
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "scripts/config.gd"
ATLAS = ROOT / "scripts/sprite_atlas.gd"
SHEET = ROOT / "assets/rocks/rocks.png"
PRICE_MIN = 10
PRICE_MAX = 1000
TARGET_RETURN = 1.05   # what a rock's ores are worth on average, x its price (no upgrades, normal prices)
STOCK_CHANCE = (0.9, 0.06)  # chance to be in stock at each restock: cheapest .. priciest
STOCK_MAX = (8, 1)          # most in stock: cheapest .. priciest
SAMPLES = 30000


def read_ores(src):
    body = re.search(r"^const ORES := \{.*?\n(.*?)^\}", src, re.M | re.S).group(1)
    ores = {}
    for m in re.finditer(r'^\t"([a-z0-9_]+)": \{.*?"sell_price": (\d+).*?"amount": \[(\d+), (\d+)\]', body, re.M):
        ores[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
    return ores


def read_names(src):
    body = re.search(r"^const ROCKS := \{.*?\n(.*?)^\}", src, re.M | re.S).group(1)
    return dict(re.findall(r'^\t"(rock_\d+)": \{"name": "([^"]+)"', body, re.M))


def sizes():
    im = Image.open(SHEET).convert("RGBA")
    src = ATLAS.read_text(encoding="utf-8").split("const ORES")[0]
    out = {}
    for n, x, y, w, h in re.findall(r'"(rock_\d+)": Rect2\((\d+), (\d+), (\d+), (\d+)\)', src):
        x, y, w, h = map(int, (x, y, w, h))
        out[n] = sum(1 for p in im.crop((x, y, x + w, y + h)).getdata() if p[3] > 128)
    return out


def nice(p):
    step = 1 if p < 20 else 5 if p < 100 else 10 if p < 500 else 25
    return int(round(p / step) * step)


def pick_ores(rid, price, ores):
    rng = random.Random(rid)
    by_price = sorted(ores, key=lambda o: ores[o][0])
    def band(lo, hi):
        return [o for o in by_price if lo < ores[o][0] <= hi]
    cheap = band(price / 10.0, price / 2.0) or by_price[:3]
    mid = band(price / 2.0, price * 1.5)
    jack = band(price * 1.5, price * 4.0)
    chosen = rng.sample(cheap, min(3, len(cheap)))
    if len(chosen) < 2:  # the cheapest rocks: take the cheapest ores
        chosen = by_price[:3]
    if mid:
        chosen += rng.sample(mid, min(2, len(mid)))
    if jack and rng.random() < 0.7:
        chosen.append(rng.choice(jack))
    return list(dict.fromkeys(chosen))


def value_samples(drops, rolls, ores, rng, n):
    out = []
    for _ in range(n):
        v = 0
        for _r in range(rolls):
            for o, (c, a, b) in drops.items():
                if rng.random() * 100.0 < c:
                    v += rng.randint(a, b) * ores[o][0]
        out.append(v)
    return out


def tune(rid, price, chosen, rolls, ores):
    weights = {o: (price / ores[o][0]) ** 0.8 for o in chosen}
    def make(s):
        return {o: (min(95.0, weights[o] * s), ores[o][1], ores[o][2]) for o in chosen}
    def mean(drops):  # exact average worth of one break
        return rolls * sum(c / 100.0 * (a + b) / 2.0 * ores[o][0] for o, (c, a, b) in drops.items())
    lo, hi = 0.0, 200.0
    for _ in range(40):
        s = (lo + hi) / 2
        if mean(make(s)) < price * TARGET_RETURN:
            lo = s
        else:
            hi = s
    drops = {o: (round(c, 3 if c < 1 else 2), a, b) for o, (c, a, b) in make(hi).items()}
    vals = value_samples(drops, rolls, ores, random.Random(2), SAMPLES)
    pay = sum(1 for v in vals if v >= price) / len(vals)
    return drops, pay, mean(drops)


def main():
    src = CONFIG.read_text(encoding="utf-8")
    ores = read_ores(src)
    names = read_names(src)
    size = sizes()
    amin, amax = min(size.values()), max(size.values())
    rows = []
    for rid in sorted(size, key=lambda r: (size[r], r)):
        t = (size[rid] - amin) / max(amax - amin, 1)
        price = PRICE_MIN if t <= 0 else PRICE_MAX if t >= 1 else nice(PRICE_MIN * (PRICE_MAX / PRICE_MIN) ** t)
        rows.append([rid, t, price, pick_ores(rid, price, ores)])
    # every ore must be in at least one rock: add it to the rock whose price suits it best
    used = {o for r in rows for o in r[3]}
    for o in sorted(set(ores) - used, key=lambda o: ores[o][0]):
        best = min(rows, key=lambda r: abs(math.log(r[2] / ores[o][0])) + (5 if len(r[3]) >= 7 else 0))
        best[3].append(o)
    lines = []
    print("%-8s %-14s %5s %4s  %-6s %-5s  %s" % ("id", "name", "size", "price", "stock", "pays", "ores"))
    for rid, t, price, chosen in rows:
        rolls = 1 if price < 60 else 2 if price < 300 else 3
        drops, pay, avg = tune(rid, price, chosen, rolls, ores)
        logt = math.log(price / PRICE_MIN) / math.log(PRICE_MAX / PRICE_MIN)
        sc = round(STOCK_CHANCE[0] * (STOCK_CHANCE[1] / STOCK_CHANCE[0]) ** logt, 2)
        sm = max(1, round(STOCK_MAX[0] + (STOCK_MAX[1] - STOCK_MAX[0]) * logt))
        hmin = 2 + round(4 * t)
        d = ", ".join('"%s": [%s, %d, %d]' % (o, c, a, b) for o, (c, a, b) in sorted(drops.items(), key=lambda kv: ores[kv[0]][0]))
        lines.append('\t"%s": {"name": "%s", "price": %d, "stock_chance": %s, "stock_max": %d, "hits_min": %d, "hits_max": %d, "rolls": %d, "drops": {%s}},'
                     % (rid, names[rid], price, sc, sm, hmin, hmin + 2, rolls, d))
        print("%-8s %-14s %5d %5d  %4.0f%%x%d  %3.0f%%  avg %5.0f  %s" % (rid, names[rid], size[rid], price, sc * 100, sm, pay * 100, avg, ", ".join(drops)))
    if "--write" in sys.argv:
        crlf = "\r\n" in src
        src = src.replace("\r\n", "\n")
        new = re.sub(r"(^const ROCKS := \{[^\n]*\n)(.*?)(^\})", lambda m: m.group(1) + "\n".join(lines) + "\n" + m.group(3), src, count=1, flags=re.M | re.S)
        CONFIG.write_text(new.replace("\n", "\r\n") if crlf else new, encoding="utf-8", newline="")
        print("wrote ROCKS into", CONFIG)


if __name__ == "__main__":
    main()
