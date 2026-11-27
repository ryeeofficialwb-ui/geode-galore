"""How far can a human get down the mine? A Monte Carlo model of a run (Old Mine, no artifacts, no upgrades,
3 lives a stage), using the game's numbers from scripts/config.gd and a simple human model:

  reaction time  - seeing something new and starting to move (the user's 150-200 ms / 50-100 ms)
  Fitts' law     - aiming at a circle: a + b * log2(distance / width + 1)
  steering law   - tracing a line: time ~ length / width of the allowed corridor
  timing jitter  - how precisely you hit a rhythm (flicks, relight); worse while the mouse is busy too

Run:  py -3.12 tools/reach_model.py
"""
import math
import random
import statistics

# ---------------------------------------------------------------- the game's numbers (config.gd)
LIVES = 3
WICK_TIME, LIGHT_DURATION = 12.0, 18.0
STAGE_FUEL_STEP, STAGE_FUEL_MIN = 0.07, 0.45
MISS_WICK, FLICK_FAIL_WICK, TRACK_MISS_WICK = 0.12, 0.06, 0.05
FLICK_GAIN = 1.8
ZONE_CALM, ZONE_STRESS = 0.34, 0.24
REST_BPM, STRESS_BPM, STAGE_BPM, PERFORM_BPM = 60, 180, 5, 10
RELIGHT_TIME, RELIGHT_HITS, RELIGHT_EVERY = 5.0, 4, 2
RELIGHT_SPEED, RELIGHT_UP, RELIGHT_ZONE, RELIGHT_SHRINK, RELIGHT_MIN = 1.3, 1.3, 0.2, 0.8, 0.06
FPS = 60.0
WICK_FOR = {}   # a move that sets its own wick time (Nail & Hammer)
WEIGHTS = {"tap": 25, "zigzag": 25, "slash": 20, "drill": 15, "pry": 15, "track": 15, "swirl": 15,
           "bigslash": 12, "spin": 12, "nail": 14}
UNLOCK = {"slash": 1, "zigzag": 2, "drill": 3, "pry": 4, "nail": 4, "swirl": 5,
          "track": 6, "bigslash": 6, "spin": 6, "tap": 6}
NAIL_LAYOUTS = [(3, 3), (5, 3), (7, 1)]
WALL_W, WALL_H = 1020.0, 460.0   # the area moves can use at 1280 x 720


def fuel(s):            # light / wick / tap rings / nails speed up 7% a stage, floor 45% (stage 9)
    return max(1.0 - (s - 1) * STAGE_FUEL_STEP, STAGE_FUEL_MIN)


def move_size(s):       # circles and line tolerance shrink, x0.75 from stage 13
    return max(1.35 - 0.05 * (s - 1), 0.75)


def walls(s):
    return 3 + (s - 1) // 5


def actions_max(s):
    return 5 + (s - 1) // 3


def bpm(s, playing_well):
    b = REST_BPM + STAGE_BPM * (s - 1) + (PERFORM_BPM if playing_well else 0)
    return min(b, STRESS_BPM)


# ---------------------------------------------------------------- humans
HUMANS = {
    "average (150-200 ms)": dict(rt=(0.150, 0.200), fitts_a=0.06, fitts_b=0.125, steer=0.060, cps=7.0,
                                 rps=4.0, jitter=0.022, dual=2.0, err=0.04, well=False),
    "perfect (50-100 ms)": dict(rt=(0.050, 0.100), fitts_a=0.04, fitts_b=0.080, steer=0.038, cps=11.0,
                                rps=7.0, jitter=0.010, dual=1.6, err=0.015, well=True),
}


class Human:
    def __init__(self, p):
        self.p = p

    def rt(self):
        return random.uniform(*self.p["rt"])

    def noise(self):
        return random.lognormvariate(0.0, 0.18)

    def aim(self, dist, width, react=True):
        t = self.p["fitts_a"] + self.p["fitts_b"] * math.log2(dist / width + 1.0)
        return (self.rt() if react else 0.0) + t * self.noise()

    def trace(self, length, tol):
        return (0.08 + self.p["steer"] * length / (2.0 * tol)) * self.noise()


def wick(k, s):
    return WICK_FOR.pop(k, WICK_TIME * fuel(s))


# ---------------------------------------------------------------- one move: (seconds, wick burnt by misses, failed outright)
def do_move(h, k, s):
    m, f = move_size(s), fuel(s)
    miss = 0.0
    if k in ("slash", "bigslash", "zigzag", "swirl"):
        if k == "slash":
            length, tol, limit = random.uniform(480, 860), 60 * m, 0.9
        elif k == "bigslash":
            length, tol, limit = WALL_W, 80 * m, 0.7
        elif k == "zigzag":
            corners = random.randint(3, min(int(7 + 0.5 * (s - 1)), 11))
            length, tol, limit = corners * 125.0, 40 * m, None
        else:
            length, tol, limit = random.uniform(1100, 1500), 38 * m, None
        t = h.aim(300, 80 * m)
        for attempt in range(6):
            tt = h.trace(length, tol)
            if limit and tt > limit:          # too slow: go faster next time (wobblier)
                if tt * 0.85 <= limit and random.random() > h.p["err"] * 4:
                    t += limit
                    return t, miss, False
                t += limit
                miss += MISS_WICK
                continue
            if random.random() < h.p["err"] * (length / 600):   # strayed off the line
                t += tt * random.random()
                miss += MISS_WICK
                continue
            return t + tt, miss, False
        return t, miss, False
    if k == "drill":
        n = random.randint(8, 15)
        return h.aim(300, 110 * m) + n / h.p["cps"] * h.noise(), 0.0, False
    if k == "track":
        n = random.randint(8, 14)
        speed = 170.0 / max(f, 0.3)
        r = 52 * m
        p_miss = min(0.08 * (speed / 170.0) * (52.0 / r) * (0.125 / h.p["fitts_b"]), 0.7)
        t, hits = h.aim(300, 2 * r), 0
        while hits < n:
            t += 1.0 / (h.p["cps"] * 0.65)
            if random.random() < p_miss:
                miss += TRACK_MISS_WICK
            else:
                hits += 1
        return t, miss, False
    if k == "pry":
        return h.aim(300, 110 * m) + random.uniform(0.6, 1.1), (MISS_WICK if random.random() < h.p["err"] else 0.0), False
    if k == "spin":
        limit = 3.5 * (1 + f) / 2
        turns = random.choice([3, 3.5, 4, 4.5, 5])
        t = h.aim(300, 220)
        for attempt in range(4):
            tt = turns / h.p["rps"] * h.noise()
            if tt <= limit:
                return t + tt, miss, False
            t += limit
            miss += MISS_WICK
        return t, miss, False
    if k == "tap":
        n = random.randint(3, 6)
        r = 38 * m
        hit_t, circles = 0.0, []
        for i in range(n):
            if i:
                hit_t += random.uniform(0.3, 0.65) * f
            circles.append((hit_t - random.uniform(0.65, 1.8) * f, hit_t))
        start = min(c[0] for c in circles)
        circles = [(a - start, b - start) for a, b in circles]
        now, hits = 0.0, 0
        for spawn, hit in sorted(circles, key=lambda c: c[1]):
            ready = max(now, spawn + h.rt()) + h.aim(250, 2 * r, react=False)
            press = max(ready, hit) + random.gauss(0, h.p["jitter"] * 1.5)
            if abs(press - hit) <= 0.22:
                hits += 1
                now = press
            else:
                miss += MISS_WICK
                now = max(ready, hit + 0.22)
        return now, miss, hits == 0
    if k == "nail":
        cols, rows = random.choice(NAIL_LAYOUTS)
        n = cols * rows
        gap = (WALL_W * 0.62) / max(cols - 1, 1)
        r = min(30 * m, (min(gap, WALL_H * 0.7 / max(rows - 1, 1)) if rows > 1 else gap) / 2.3)
        limit = 0.8 + max(0.5 * f, 0.34) * (n - 1)
        WICK_FOR["nail"] = max(WICK_TIME * f, limit + 2.5)   # the wick always outlasts the nails' clock
        t = h.aim(300, 2 * r)
        for attempt in range(4):
            tt = sum(h.aim(gap, 2 * r, react=False) for _ in range(n - 1))
            if tt <= limit:
                return t + tt, miss, False
            t += limit
            miss += MISS_WICK
        return t, miss, False
    raise ValueError(k)


# ---------------------------------------------------------------- the lighter
def flick_cost(h, s):
    """(wick burnt per second by mistimed flicks, does the light fade anyway?) while doing moves."""
    b = bpm(s, h.p["well"])
    period = 60.0 / b
    stress = (b - REST_BPM) / (STRESS_BPM - REST_BPM)
    window = (ZONE_CALM + (ZONE_STRESS - ZONE_CALM) * stress) * period
    sd = h.p["jitter"] * h.p["dual"]
    p_hit = math.erf((window / 2) / (sd * math.sqrt(2)))
    need = 1.0 / FLICK_GAIN                   # part of the beats you must land to keep up with the fade
    if p_hit < need:
        return (b / 60.0) * (1 - p_hit) * FLICK_FAIL_WICK, LIGHT_DURATION * fuel(s) / (1 - p_hit * FLICK_GAIN)
    tries = (b / 60.0) * need / p_hit
    return tries * (1 - p_hit) * FLICK_FAIL_WICK, None


def relight_ok(h, s):
    need = RELIGHT_HITS + (s - 1) // RELIGHT_EVERY
    t, hits, v, z = 0.0, 0, RELIGHT_SPEED, RELIGHT_ZONE
    sd = h.p["jitter"]
    while t < RELIGHT_TIME:
        t += max(1.0 / v, 0.18)               # wait for the marker to come round again
        if t > RELIGHT_TIME:
            break
        step = v / FPS                         # the marker jumps this far every frame
        p = math.erf((max(z / v, 1 / FPS) / 2) / (sd * math.sqrt(2))) * min(1.0, z / step)
        if random.random() < p:
            hits += 1
            if hits >= need:
                return True
            v *= RELIGHT_UP
            z = max(z * RELIGHT_SHRINK, RELIGHT_MIN)
        else:
            hits = max(hits - 1, 0)
    return False


# ---------------------------------------------------------------- a run
def pick(s, last):
    pool = {k: w for k, w in WEIGHTS.items() if s >= UNLOCK[k]}
    if len(pool) > 1:
        pool.pop(last, None)   # never the same move twice in a row (when there's another)
    r = random.random() * sum(pool.values())
    for k, w in pool.items():
        r -= w
        if r <= 0:
            return k
    return k


def play_stage(h, s):
    """True if the stage gets cleared before the lives run out."""
    lives = LIVES
    burn_flicks, fade_death = flick_cost(h, s)
    while lives > 0:
        clean = True
        lit_for = 0.0
        last = ""
        for w in range(walls(s)):
            for a in range(random.randint(3, actions_max(s))):
                k = pick(s, last)
                last = k
                t, miss, failed = do_move(h, k, s)
                lit_for += t
                burnt = t / wick(k, s) + miss + burn_flicks * t
                died = failed or burnt >= 1.0 or (fade_death is not None and lit_for >= fade_death)
                if died:
                    lit_for = 0.0
                    if not relight_ok(h, s):
                        clean = False
                        break
            if not clean:
                break
        if clean:
            return True
        lives -= 1
    return False


def run(h, cap=200):
    s = 1
    while s < cap and play_stage(h, s):
        s += 1
    return s   # the stage the run ended on


def main():
    random.seed(7)
    print("stage  fuel  wick   BPM  walls  actions  relight hits")
    for s in [1, 3, 5, 7, 9, 13, 17, 21, 25, 30, 40]:
        print("%5d  %.2f  %4.1fs  %3d  %5d  3-%-5d  %d" % (s, fuel(s), WICK_TIME * fuel(s), bpm(s, False), walls(s),
                                                         actions_max(s), RELIGHT_HITS + (s - 1) // RELIGHT_EVERY))
    for name, p in HUMANS.items():
        h = Human(p)
        print("\n== %s ==" % name)
        for s in [5, 9, 13, 17, 21, 25, 30]:
            ok = sum(relight_ok(h, s) for _ in range(2000)) / 2000
            fb, fd = flick_cost(h, s)
            clear = sum(play_stage(h, s) for _ in range(300)) / 300
            print("stage %2d: relight %5.1f%%   flick misfires burn %.3f wick/s%s   clears the stage %5.1f%%"
                  % (s, ok * 100, fb, "  LIGHT FADES ANYWAY" if fd else "", clear * 100))
        for s in [9, 13, 17]:
            deaths = {}
            for k in WEIGHTS:
                if s < UNLOCK[k]:
                    continue
                n = 0
                fb, fd = flick_cost(h, s)
                for _ in range(2000):
                    t, miss, failed = do_move(h, k, s)
                    n += failed or t / wick(k, s) + miss + fb * t >= 1.0
                deaths[k] = n / 20.0
            print("stage %d, %% of moves that kill the light: %s" % (s, ", ".join("%s %.1f" % kv for kv in sorted(deaths.items(), key=lambda kv: -kv[1]))))
        ends = sorted(run(h) for _ in range(400))
        q = lambda x: ends[min(int(x * len(ends)), len(ends) - 1)]
        print("run ends on stage: median %d, best 10%% reach %d+, best 1%% reach %d+, max seen %d"
              % (statistics.median(ends), q(0.9), q(0.99), ends[-1]))


if __name__ == "__main__":
    main()
