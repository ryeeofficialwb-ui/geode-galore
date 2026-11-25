"""Balances the rocks: sets each rock's "quality" (and, if it has to, its "rolls") in scripts/config.gd so
that what's inside is worth about VALUE_RATIO x its shop price, on average.

    py -3.12 tools/tune_drops.py                        (prints the result for every rock)
    py -3.12 tools/tune_drops.py rock_21 rock_22 --write  (tunes only those rocks and writes them into config.gd)

It reads the ORES and ROCKS tables straight from config.gd (prices, chances, amounts, bonuses), so add
ores / rocks there first, then run this. Only "rolls" and "quality" of each rock are changed; everything
else stays as you wrote it.
How drops work in the game (see Game.drop_chance):
  - every ore has a chance on the CHEAPEST rocks and a chance on the BEST rocks ("chance": [cheap, best]);
  - every rock has a "quality" from 0 to 1 that slides between the two, and a few "rolls";
  - a rock can have a "bonus" that multiplies the chance of a few ores (its speciality).
(Upgrades and the market aren't counted: this is the value at normal prices with no upgrades.)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "scripts/config.gd"
VALUE_RATIO = 1.6  # what the rocks were balanced to by hand (Indev 0.3: most are worth 1.4 - 2x their price)


def read_ores(src):
    body = re.search(r"^const ORES := \{.*?\n(.*?)^\}", src, re.M | re.S).group(1)
    ores = {}
    for m in re.finditer(r'^\t"([a-z0-9_]+)": \{.*?"sell_price": (\d+).*?"chance": \[([\d.]+), ([\d.]+)\], "amount": \[(\d+), (\d+)\]',
                         body, re.M):
        oid, price, lo, hi, amin, amax = m.groups()
        ores[oid] = (int(price), float(lo), float(hi), (int(amin) + int(amax)) / 2.0)
    return ores


def read_rocks(src):
    body = re.search(r"^const ROCKS := \{.*?\n(.*?)^\}", src, re.M | re.S).group(1)
    rocks = []
    for line in body.splitlines():
        m = re.match(r'^\t"(rock_\d+)": \{"name": "([^"]+)", "price": (\d+).*?"rolls": (\d+), "quality": ([\d.]+)', line)
        if not m:
            continue
        bonus = {}
        b = re.search(r'"bonus": \{([^}]*)\}', line)
        if b:
            for k, v in re.findall(r'"([a-z0-9_]+)": ([\d.]+)', b.group(1)):
                bonus[k] = float(v)
        rocks.append((m.group(1), m.group(2), int(m.group(3)), int(m.group(4)), float(m.group(5)), bonus))
    return rocks


def ev(ores, quality, rolls, bonus):
    total = 0.0
    for oid, (price, lo, hi, amount) in ores.items():
        ch = min((lo + (hi - lo) * quality) * bonus.get(oid, 1.0), 100.0) / 100.0
        total += ch * amount * price
    return total * rolls


def p_empty(ores, quality, rolls, bonus):
    p = 1.0
    for oid, (_price, lo, hi, _a) in ores.items():
        p *= 1.0 - min((lo + (hi - lo) * quality) * bonus.get(oid, 1.0), 100.0) / 100.0
    return p ** rolls


def main():
    src = CONFIG.read_text(encoding="utf-8")
    ores = read_ores(src)
    print(f"{len(ores)} ores / gems")
    only = [a for a in sys.argv[1:] if a.startswith("rock_")]
    for rid, name, price, rolls, old_q, bonus in read_rocks(src):
        if only and rid not in only:
            continue
        target = price * VALUE_RATIO
        while ev(ores, 1.0, rolls, bonus) < target:
            rolls += 1
        lo, hi = 0.0, 1.0
        for _ in range(40):
            mid = (lo + hi) / 2
            if ev(ores, mid, rolls, bonus) < target:
                lo = mid
            else:
                hi = mid
        q = round(hi, 2)
        print(f"{rid} {name:16s} price {price:4d}  rolls {rolls}  quality {old_q:.2f} -> {q:.2f}"
              f"  worth ~{ev(ores, q, rolls, bonus):6.1f}  empty {p_empty(ores, q, rolls, bonus) * 100:4.1f}%")
        src = re.sub(r'(\t"%s": \{[^\n]*?"rolls": )\d+(, "quality": )[\d.]+' % rid, r"\g<1>%d\g<2>%s" % (rolls, q), src, count=1)
    if "--write" in sys.argv:
        CONFIG.write_text(src, encoding="utf-8", newline="")
        print("wrote", CONFIG)


if __name__ == "__main__":
    main()
