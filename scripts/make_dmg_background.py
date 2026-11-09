#!/usr/bin/env python3
"""Draws the DMG window background: field-journal paper with grain, a thin ink rule with the
title and version, and one pencil arrow from the app to Applications.

    python3 scripts/make_dmg_background.py 0.2.7

Writes Resources/dmg/background.png (640 x 400) and background@2x.png (1280 x 800).
Needs Pillow. Re-run it when the version changes, then commit the two PNGs.
"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFont

VERSION = sys.argv[1] if len(sys.argv) > 1 else "0.2.7"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "Resources", "Fonts", "SpecialElite-Regular.ttf")
OUT = os.path.join(ROOT, "Resources", "dmg")

PAPER = (0xEF, 0xE6, 0xD2)
INK = (0x24, 0x21, 0x1B)
INK3 = (0x77, 0x6F, 0x60)
PENCIL = (0x8F, 0x88, 0x7B)
GRAIN = (0x59, 0x47, 0x2E)

# Finder icon centers (points), from the create-dmg layout in .github/workflows/build.yml.
APP = (170, 210)
DROP = (470, 210)


def draw(scale):
    W, H = 640 * scale, 400 * scale
    img = Image.new("RGB", (W, H), PAPER)
    # Grain: the same brown specks as the app's PaperGrain, 0 to 10 percent.
    rnd = random.Random(0x9E3779B9)
    px = img.load()
    for y in range(H):
        for x in range(W):
            a = (rnd.random() * 0.10)
            r, g, b = px[x, y]
            px[x, y] = (int(r * (1 - a) + GRAIN[0] * a), int(g * (1 - a) + GRAIN[1] * a), int(b * (1 - a) + GRAIN[2] * a))
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, 13 * scale)

    # Running head: title left, version right, then a 0.8 pt ink rule 28 pt from the top.
    rule_y = 28 * scale
    d.text((24 * scale, rule_y - 6 * scale), "Paper Tree for Mac", font=font, fill=INK3, anchor="ls")
    d.text((W - 24 * scale, rule_y - 6 * scale), f"version {VERSION}", font=font, fill=INK3, anchor="rs")
    d.line([(24 * scale, rule_y), (W - 24 * scale, rule_y)], fill=INK, width=max(1, round(0.8 * scale)))

    # One pencil arrow with a hand wobble, from the app slot toward Applications.
    x0, x1 = APP[0] + 74, DROP[0] - 74
    y = APP[1] - 6
    pts = []
    steps = 60
    for i in range(steps + 1):
        f = i / steps
        px_ = x0 + (x1 - x0) * f
        py_ = y - math.sin(f * math.pi) * 10 + math.sin(f * 11) * 0.9
        pts.append((px_ * scale, py_ * scale))
    lw = max(1, round(1.5 * scale))
    d.line(pts, fill=PENCIL, width=lw, joint="curve")
    # Arrowhead: two short strokes, a little uneven, like a pencil.
    ex, ey = pts[-1]
    px2, py2 = pts[-4]
    ang = math.atan2(ey - py2, ex - px2)
    for side, length in ((-1, 11), (1, 9.5)):
        a = ang + math.pi + side * 0.5
        d.line([(ex, ey), (ex + math.cos(a) * length * scale, ey + math.sin(a) * length * scale)], fill=PENCIL, width=lw)

    d.text(((x0 + x1) / 2 * scale, (y + 26) * scale), "Drag Paper Tree into Applications", font=font, fill=INK3, anchor="ms")
    return img


os.makedirs(OUT, exist_ok=True)
draw(1).save(os.path.join(OUT, "background.png"))
draw(2).save(os.path.join(OUT, "background@2x.png"))
print("wrote", OUT)
