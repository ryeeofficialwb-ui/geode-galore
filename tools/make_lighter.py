"""Cuts art_source/lighter_sheet.png into the lighter frames the game uses, and makes the
in-between frames of the lid opening (the sheet only has "open + lit" and "closed").

    py -3.12 tools/make_lighter.py

Writes assets/lighter/:
    lighter_0.png ... lighter_5.png   lid closed (0) -> fully open (5), no flame. Opening plays 0->5,
                                      closing plays 5->0. Redraw any of them by hand if you like.
(The flame itself is the 8-frame animation flame_0.png ... flame_7.png, made by tools/make_flame.py.)
All frames share one canvas so the lighter doesn't jump around while it animates.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "art_source/lighter_sheet.png"
OUT = ROOT / "assets/lighter"

W, H = 84, 80                 # frame canvas (open frame's coordinates)
CLOSED_SHIFT = 45             # closed frame sits 45px right of the open frame on the sheet
PIVOT = (43.5, 45.5)          # lid hinge, in canvas coordinates
LID_ROWS = (29, 46)           # rows of the closed frame that are lid (y from..to, exclusive)
FLAME_BOX = (56, 0, 72, 30)   # where the flame is on the open frame
LID_CUT_X = 43                # on the open frame, pixels left of this are the swung-open lid
ANGLES = [22, 55, 95, 140]    # in-between lid angles (degrees, opening towards the left)


def main():
    sheet = Image.open(SHEET).convert("RGBA")
    open_f = sheet.crop((0, 0, W, H))
    closed = Image.new("RGBA", (W, H))
    closed.paste(sheet.crop((84, 0, sheet.width, H)), (84 - CLOSED_SHIFT, 0))  # only the closed lighter

    # flame on its own + the open frame without it
    flame = open_f.crop(FLAME_BOX)
    flame = flame.crop(flame.getbbox())
    open_unlit = open_f.copy()
    open_unlit.paste(Image.new("RGBA", (FLAME_BOX[2] - FLAME_BOX[0], FLAME_BOX[3])), FLAME_BOX[:2])

    # body with the chimney showing (open frame minus its lid)
    body = open_unlit.copy()
    px = body.load()
    for y in range(H):
        for x in range(LID_CUT_X):
            if y < 62:
                px[x, y] = (0, 0, 0, 0)

    # the closed lid (plus hinge knob) on its own
    lid = Image.new("RGBA", (W, H))
    lid.paste(closed.crop((0, LID_ROWS[0], W, LID_ROWS[1])), (0, LID_ROWS[0]))
    for y in range(LID_ROWS[1], 51):  # hinge knob below the seam
        for x in range(0, 4):
            lid.putpixel((x + 40, y), closed.getpixel((x + 40, y)))

    OUT.mkdir(parents=True, exist_ok=True)
    frames = [closed]
    for a in ANGLES:
        f = body.copy()
        rl = lid.rotate(a, resample=Image.NEAREST, center=PIVOT)
        f.alpha_composite(rl)
        frames.append(f)
    frames.append(open_unlit)
    for i, f in enumerate(frames):
        f.save(OUT / f"lighter_{i}.png")
    # flame anchor (bottom-centre of the flame on the canvas) for reference
    fb = open_f.crop(FLAME_BOX).getbbox()
    print("frames:", len(frames), "flame size:", flame.size,
          "flame bottom-centre on canvas:", (FLAME_BOX[0] + (fb[0] + fb[2]) / 2, fb[3]))


if __name__ == "__main__":
    main()
