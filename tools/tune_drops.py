"""Balances the rocks for the "every rock can drop every ore / gem" system and writes the ROCKS and
ORES tables into scripts/config.gd.

    py -3.12 tools/tune_drops.py            (prints the result)
    py -3.12 tools/tune_drops.py --write    (also writes it into scripts/config.gd)

How drops work in the game (see Game.drop_chance):
  - every ore has a chance on the CHEAPEST rocks and a chance on the BEST rocks (ORE_CURVE below);
  - every rock has a "quality" from 0 to 1 that slides between the two, and a few "rolls";
  - a rock can have a "bonus" that multiplies the chance of a few ores (its speciality).
This script picks each rock's quality so that, on average, what's inside is worth about
VALUE_RATIO x its price (a bit below 1, so the mining wall still matters). You can just edit the
numbers in config.gd by hand instead; this is only a helper.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "scripts/config.gd"
VALUE_RATIO = 0.9

# id: name, sell price, rare, colour, % chance on the cheapest rocks, % on the best rocks, amount min, max
ORE_CURVE = [
    ("lead", "Lead", 4, False, "#a99ab5", 32.0, 10.0, 1, 2),
    ("copper", "Copper", 6, False, "#e8925f", 22.0, 12.0, 1, 1),
    ("iron", "Iron", 8, False, "#dcc6ba", 15.0, 15.0, 1, 2),
    ("zinc", "Zinc", 11, False, "#8fd3c9", 10.0, 14.0, 1, 2),
    ("rhodonite", "Rhodonite", 14, False, "#ec85a6", 4.0, 12.0, 1, 1),
    ("rustvein", "Rustvein", 16, False, "#f57d4a", 3.0, 13.0, 1, 2),
    ("silver", "Silver", 20, False, "#dfe9ec", 2.5, 16.0, 1, 1),
    ("jade", "Jade", 30, False, "#62cf9e", 1.2, 11.0, 1, 1),
    ("gold", "Gold", 45, False, "#ffd84a", 0.8, 12.0, 1, 1),
    ("peridot", "Peridot", 60, True, "#aee35c", 0.2, 4.0, 1, 1),
    ("topaz", "Topaz", 250, True, "#ffb347", 0.12, 3.5, 1, 1),
    ("uranium", "Uranium", 200, True, "#6cff5a", 0.08, 3.0, 1, 1),
    ("amethyst", "Amethyst", 250, True, "#c690e6", 0.08, 3.0, 1, 1),
    ("sapphire", "Sapphire", 250, True, "#6a98ff", 0.05, 2.5, 1, 1),
    ("tourmaline", "Tourmaline", 200, True, "#ff8aa5", 0.05, 2.2, 1, 1),
    ("ruby", "Ruby", 250, True, "#ff4a5e", 0.04, 2.0, 1, 1),
    ("onyx", "Onyx", 100, True, "#b9b3cf", 0.03, 1.8, 1, 1),
    ("emerald", "Emerald", 500, True, "#45e3c4", 0.025, 1.5, 1, 1),
    ("zapperion", "Zapperion", 650, True, "#e2e679", 0.02, 1.4, 1, 1),
    ("dreamstone", "Dreamstone", 1000, True, "#d9a6ff", 0.015, 1.2, 1, 1),
]
# "ore" or "gem" (upgrades: Miner's Favor / Rocky Riches = ores, Jeweler's Favor = gems)
GEMS = {"rhodonite", "jade", "peridot", "topaz", "amethyst", "sapphire", "tourmaline", "ruby", "onyx", "emerald", "zapperion", "dreamstone"}

# each rock's speciality: ore -> chance multiplier
BONUS = {
    "rock_01": {"silver": 1.5},
    "rock_03": {"sapphire": 1.5, "ruby": 1.5},
    "rock_04": {"jade": 1.5},
    "rock_05": {"peridot": 2.0},
    "rock_06": {"rhodonite": 2.0},
    "rock_07": {"gold": 1.5, "topaz": 1.5},
    "rock_08": {"emerald": 3.0},
    "rock_09": {"lead": 1.5, "copper": 1.5},
    "rock_11": {"dreamstone": 2.0},
    "rock_12": {"uranium": 2.0},
    "rock_13": {"zinc": 2.0, "iron": 1.5},
    "rock_14": {"zinc": 2.5},
    "rock_15": {"zinc": 1.5, "jade": 1.5},
    "rock_16": {"onyx": 2.0},
    "rock_17": {"uranium": 1.5, "zinc": 1.5},
    "rock_18": {"uranium": 2.0, "onyx": 1.5},
    "rock_19": {"onyx": 2.0, "dreamstone": 1.5},
    "rock_20": {"dreamstone": 2.0, "onyx": 1.5, "uranium": 1.5},
}


def ev(quality, rolls, bonus):
    total = 0.0
    for oid, _n, price, _r, _c, lo, hi, amin, amax in ORE_CURVE:
        ch = min((lo + (hi - lo) * quality) * bonus.get(oid, 1.0), 100.0) / 100.0
        total += ch * (amin + amax) / 2.0 * price
    return total * rolls


def p_empty(quality, rolls, bonus):
    p = 1.0
    for oid, _n, _p, _r, _c, lo, hi, *_ in ORE_CURVE:
        p *= 1.0 - min((lo + (hi - lo) * quality) * bonus.get(oid, 1.0), 100.0) / 100.0
    return p ** rolls


def main():
    src = CONFIG.read_text(encoding="utf-8")
    rocks = re.findall(r'"(rock_\d+)": \{\s*"name": "([^"]+)", "price": (\d+), "shop_weight": (\d+)(?:, "hits_min": (\d+), "hits_max": (\d+))?', src)
    out_rocks = []
    for rid, name, price, weight, hmin, hmax in rocks:
        price = int(price)
        bonus = BONUS.get(rid, {})
        target = price * VALUE_RATIO
        rolls = 1 if price < 30 else 2 if price < 70 else 3
        while ev(1.0, rolls, bonus) < target:
            rolls += 1
        lo, hi = 0.0, 1.0
        for _ in range(40):
            mid = (lo + hi) / 2
            if ev(mid, rolls, bonus) < target:
                lo = mid
            else:
                hi = mid
        q = round(hi, 2)
        out_rocks.append((rid, name, price, int(weight), hmin, hmax, rolls, q, bonus))
        print(f"{rid} {name:14s} price {price:4d}  rolls {rolls}  quality {q:.2f}  worth ~{ev(q, rolls, bonus):6.1f}"
              f"  empty {p_empty(q, rolls, bonus) * 100:4.1f}%")
    if "--write" not in sys.argv:
        return
    # ROCKS table
    lines = ["const ROCKS := {  # configurable (whole table)"]
    for rid, name, price, weight, hmin, hmax, rolls, q, bonus in out_rocks:
        hits = f', "hits_min": {hmin}, "hits_max": {hmax}' if hmin else ""
        b = ", ".join(f'"{k}": {v}' for k, v in bonus.items())
        extra = f', "bonus": {{{b}}}' if bonus else ""
        lines.append(f'\t"{rid}": {{"name": "{name}", "price": {price}, "shop_weight": {weight}{hits}, "rolls": {rolls}, "quality": {q}{extra}}},')
    lines.append("}")
    src = re.sub(r"const ROCKS := \{  # configurable \(whole table\)\n.*?\n\}\n", "\n".join(lines) + "\n", src, count=1, flags=re.S)
    # ORES table
    lines = ["const ORES := {  # configurable (whole table)"]
    for oid, n, price, rare, col, lo, hi, amin, amax in ORE_CURVE:
        lines.append(f'\t"{oid}": {{"name": "{n}", "sell_price": {price}, "rare": {str(rare).lower()}, "color": Color("{col}"), '
                     f'"chance": [{lo}, {hi}], "amount": [{amin}, {amax}]}},')
    lines.append("}")
    src = re.sub(r"const ORES := \{  # configurable \(whole table\)\n.*?\n\}\n", "\n".join(lines) + "\n", src, count=1, flags=re.S)
    CONFIG.write_text(src, encoding="utf-8")
    print("wrote", CONFIG)


if __name__ == "__main__":
    main()
