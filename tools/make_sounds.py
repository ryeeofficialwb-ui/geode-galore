"""Synthesizes PLACEHOLDER sounds as 16-bit mono WAVs (pure Python, no libraries needed).

    py tools/make_sounds.py

Writes into assets/audio/. Replace any of these files with your own sound later
(same file name; .wav, .ogg or .mp3 all work - see README.md).
Sounds you already replaced are SKIPPED (any file with that name exists). Use --force to overwrite.
"""
import math, random, struct, sys, wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets/audio"
SR = 22050
rnd = random.Random(7)


def n(d): return int(SR * d)
def env(i, total, attack=0.004, release=0.01, decay=None):
    t = i / SR; e = 1.0
    if t < attack: e = t / attack
    r = total / SR - t
    if r < release: e *= max(r / release, 0)
    if decay: e *= math.exp(-t * decay)
    return e
def sweep(f0, f1, d, decay=None, wave_fn=math.sin):
    tot = n(d); ph = 0.0; out = []
    for i in range(tot):
        f = f0 + (f1 - f0) * i / tot; ph += 2 * math.pi * f / SR
        out.append(wave_fn(ph) * env(i, tot, decay=decay))
    return out
def sine(f, d, decay=None): return sweep(f, f, d, decay)
def square(ph): return 1.0 if math.sin(ph) >= 0 else -1.0
def noise(d, decay=None, smooth=1):
    tot = n(d); out = []; acc = 0.0
    for i in range(tot):
        acc += (rnd.uniform(-1, 1) - acc) / smooth
        out.append(acc * env(i, tot, decay=decay))
    return out
def mix(total, *parts):
    """parts: (samples, start_seconds, gain)"""
    buf = [0.0] * n(total)
    for s, start, g in parts:
        o = n(start)
        for i, v in enumerate(s):
            if o + i < len(buf): buf[o + i] += v * g
    return buf
FORCE = "--force" in sys.argv


def save(name, x, peak=0.8):
    if not FORCE and any((OUT / f"{name}.{e}").exists() for e in ("wav", "ogg", "mp3")):
        print("skip", name, "(already exists)")
        return
    m = max(max(abs(v) for v in x), 1e-6)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v / m * peak)) * 32767)) for v in x))
    print("wrote", name)


OUT.mkdir(parents=True, exist_ok=True)
# hit: pickaxe on stone - sharp click + dull thud
save("hit", mix(0.14, (noise(0.03, 120), 0, 0.8), (sweep(180, 70, 0.14, 30), 0, 0.9), (noise(0.12, 40, 6), 0, 0.5)))
# break: rock splits - crunchy noise burst + low thump
save("break", mix(0.45, (noise(0.4, 9, 3), 0, 0.9), (sweep(140, 45, 0.25, 14), 0, 1.0), (noise(0.05, 80), 0.06, 0.5), (noise(0.05, 80), 0.13, 0.4)))
# drop_common: an ore pops out - short rising blip
save("drop_common", sweep(520, 900, 0.14, 14))
# drop_rare: a rare gem - sparkly arpeggio
save("drop_rare", mix(0.8, *[(mix(0.5, (sine(f, 0.5, 7), 0, 1), (sine(f * 2, 0.5, 10), 0, 0.3)), k * 0.08, 1 - 0.12 * k)
                            for k, f in enumerate([784, 988, 1175, 1568])]))
# drop_none: rock was empty - sad falling tone
save("drop_none", sweep(420, 220, 0.35, 6), peak=0.5)
# buy: coin clink
save("buy", mix(0.4, (sine(1319, 0.3, 14), 0, 1), (sine(1760, 0.3, 14), 0.06, 0.9)))
# sell: cash register-ish double coin
save("sell", mix(0.5, (sine(1568, 0.3, 12), 0, 1), (sine(2093, 0.35, 10), 0.08, 1), (noise(0.03, 100), 0, 0.2)))
# click: UI button
save("click", sweep(900, 700, 0.04, 40), peak=0.5)
# error: low buzz (not enough coins, out of stock)
save("error", [v * 0.6 for v in sweep(150, 130, 0.18, 6, square)], peak=0.5)
# restock: shop refilled - two-note chime
save("restock", mix(0.6, (sine(659, 0.4, 7), 0, 1), (sine(988, 0.45, 7), 0.12, 1)))

# slice_perfect: bright swish + ding
save("slice_perfect", mix(0.6, (noise(0.18, 14, 2), 0, 0.5), (sweep(600, 1800, 0.12, 10), 0, 0.5),
                          (sine(1568, 0.45, 7), 0.1, 1.0), (sine(2349, 0.4, 9), 0.16, 0.6)))
# slice_good: plain swish
save("slice_good", mix(0.3, (noise(0.22, 12, 2), 0, 0.8), (sweep(500, 1200, 0.15, 12), 0, 0.4)))
# slice_miss: scrape + low bonk
save("slice_miss", mix(0.35, (noise(0.15, 20, 4), 0, 0.6), (sweep(220, 120, 0.25, 10), 0.03, 0.8)), peak=0.6)
# wall_break: big rumble crumble
save("wall_break", mix(1.2, (noise(1.1, 3, 5), 0, 1.0), (sweep(90, 35, 0.6, 5), 0, 1.0),
                       *[(noise(0.06, 60), 0.1 + 0.12 * k, 0.5) for k in range(7)]))
# screen_slide: soft whoosh
save("screen_slide", noise(0.3, 9, 8), peak=0.5)

# tap: pick tip on stone - bright tick
save("tap", mix(0.12, (noise(0.02, 160), 0, 0.9), (sweep(1400, 900, 0.06, 50), 0, 0.6), (sweep(300, 160, 0.1, 35), 0, 0.5)))
# crack: gritty little crackle while you crack a line into the wall (played many times in a row)
save("crack", mix(0.09, (noise(0.012, 300), 0, 1.0), (noise(0.01, 300), 0.025, 0.7), (noise(0.012, 260), 0.05, 0.5), (sweep(520, 260, 0.06, 45), 0, 0.25)), peak=0.6)
# lid: lighter lid clink (metal)
save("lid", mix(0.16, (sine(2637, 0.15, 30), 0, 0.8), (sine(3951, 0.1, 45), 0, 0.4), (noise(0.01, 300), 0, 0.6)), peak=0.6)
# flick: flint wheel scrape + sparks
save("flick", mix(0.12, (noise(0.06, 40, 1), 0, 0.9), (noise(0.01, 400), 0.04, 0.6), (noise(0.01, 400), 0.07, 0.4)), peak=0.6)
# misfire: dull scrape with no spark + low thunk
save("misfire", mix(0.2, (noise(0.08, 30, 4), 0, 0.7), (sweep(140, 90, 0.15, 20, square), 0, 0.35)), peak=0.6)
# ignite: soft whoomph as the flame catches
save("ignite", mix(0.4, (noise(0.35, 8, 12), 0, 1.0), (sweep(90, 160, 0.3, 9), 0, 0.5)), peak=0.7)
# fizzle: flame dies
save("fizzle", mix(0.45, (noise(0.4, 7, 4), 0, 0.8), (sweep(300, 120, 0.3, 8), 0, 0.3)), peak=0.5)
# life_lost: low falling double tone
save("life_lost", mix(0.7, (sweep(330, 200, 0.3, 5), 0, 1), (sweep(250, 120, 0.35, 5), 0.28, 1)), peak=0.6)
# stage_up: rising fanfare
save("stage_up", mix(0.9, *[(mix(0.45, (sine(f, 0.45, 6), 0, 1), (sine(f * 2, 0.45, 9), 0, 0.25)), k * 0.11, 1) for k, f in enumerate([523, 659, 784, 1047])]))
# stage_down: falling notes
save("stage_down", mix(0.9, *[(sine(f, 0.4, 6), k * 0.14, 1) for k, f in enumerate([523, 440, 349, 262])]), peak=0.6)
# drill: short grinding buzz (played many times in a row)
save("drill", mix(0.11, (noise(0.1, 25, 2), 0, 0.7), ([v * 0.5 for v in sweep(110, 95, 0.1, 18, square)], 0, 0.6)), peak=0.7)
# pry: creak + pop as the wedge comes out
save("pry", mix(0.5, ([v * 0.4 for v in sweep(180, 420, 0.25, 4, square)], 0, 0.5), (noise(0.08, 50, 2), 0.22, 0.9),
                (sweep(260, 90, 0.2, 18), 0.22, 1.0)))
# timeout: combo lost - descending three-note buzz
save("timeout", mix(0.55, *[([v * 0.6 for v in sweep(f, f * 0.97, 0.16, 8, square)], k * 0.14, 1.0) for k, f in enumerate([392, 330, 262])]), peak=0.55)

# music: calm 4-chord pad loop (16 s). Loops seamlessly because every chord fades in and out.
chords = [(220.0, 261.63, 329.63), (174.61, 220.0, 261.63), (196.0, 246.94, 293.66), (164.81, 207.65, 246.94)]
seg = 4.0
music = [0.0] * n(seg * len(chords))
for c, notes in enumerate(chords):
    o = n(seg * c)
    for i in range(n(seg)):
        t = i / SR
        a = math.sin(math.pi * t / seg) ** 2  # smooth swell
        v = sum(math.sin(2 * math.pi * f * t) + 0.25 * math.sin(4 * math.pi * f * t + 0.3) for f in notes)
        v += 0.6 * math.sin(2 * math.pi * notes[0] / 2 * t)  # bass
        music[o + i] += v * a
save("music", music, peak=0.5)

# music_mine: the mining wall - upbeat 128 bpm loop: kick, pick clinks on the off-beats, plucky minor bass.
bpm = 128.0; beat = 60.0 / bpm; bars = 8
mine = [0.0] * n(beat * 4 * bars)
kick = sweep(120, 45, 0.18, 22)
clink = mix(0.12, (sine(1760, 0.12, 30), 0, 0.6), (sine(2637, 0.1, 40), 0, 0.3), (noise(0.01, 300), 0, 0.3))
shaker = noise(0.05, 70, 1)
def put(buf, x, at, g):
    o = n(at)
    for i, v in enumerate(x):
        if o + i < len(buf): buf[o + i] += v * g
bass_notes = [110.0, 110.0, 130.81, 98.0, 110.0, 146.83, 130.81, 98.0]  # A minor-ish walk, one note per bar
for bar in range(bars):
    for b4 in range(4):
        t = (bar * 4 + b4) * beat
        put(mine, kick, t, 0.9)
        put(mine, clink, t + beat * 0.5, 0.35 if b4 % 2 else 0.25)
        put(mine, shaker, t + beat * 0.25, 0.12)
        put(mine, shaker, t + beat * 0.75, 0.12)
        f = bass_notes[bar] * (1.5 if b4 == 3 else 1.0)
        put(mine, [v * 0.8 for v in sweep(f, f, beat * 0.9, 5, lambda ph: math.sin(ph) + 0.3 * math.sin(2 * ph))], t, 0.55)
    # little pentatonic lick every other bar
    if bar % 2 == 1:
        for k, f in enumerate([440, 523.25, 587.33, 659.25]):
            put(mine, sine(f, beat * 0.45, 9), bar * 4 * beat + (2 + k * 0.5) * beat, 0.18)
save("music_mine", mine, peak=0.5)
