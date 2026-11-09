#!/usr/bin/env python3
"""Draws the app icon from the flask's own geometry (BuddyView.swift), in the green family:
a grained sheet-paper tile, the flask with a flat ground shadow (no glow), and a typed FIG. 1 label.

    python3 scripts/make_icon.py

Writes design-previews/icon-src/icon_*.png, Resources/AppIcon.iconset and Resources/AppIcon.icns.
Needs Pillow.
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT = os.path.join(ROOT, "Resources", "Fonts", "SpecialElite-Regular.ttf")

def hexc(h, a=255): return ((h >> 16) & 255, (h >> 8) & 255, h & 255, a)
SHEET = hexc(0xF8F3E6); INK = hexc(0x24211B); INK3 = hexc(0x776F60)
GLASS = hexc(0xE6EBDA); SHINE = hexc(0xF4F6EC); LIQ = hexc(0x8EA672); DEEP = hexc(0x6E8A55)
LINE = hexc(0x506B39); CHEEK = hexc(0xB2432C, int(255 * 0.22)); GRAIN = (0x59, 0x47, 0x2E)

S = 4096  # draw big, scale down
U = S / 512 * 3.3          # px per flask unit
OX = S / 2 - 50 * U
OY = S / 512 * 104 - 15 * U

def P(x, y): return (OX + x * U, OY + y * U)

def quad(p0, c, p1, n=24):
    return [((1-t)**2*p0[0] + 2*(1-t)*t*c[0] + t*t*p1[0], (1-t)**2*p0[1] + 2*(1-t)*t*c[1] + t*t*p1[1]) for t in (i/n for i in range(1, n+1))]

def body():
    pts = [(41, 21), (41, 42), (21.5, 77)]
    pts += quad((21.5, 77), (16, 90), (29, 90))
    pts += [(71, 90)]
    pts += quad((71, 90), (84, 90), (78.5, 77))
    pts += [(59, 42), (59, 21)]
    return [P(*p) for p in pts]

def rrect(d, box, r, **kw): d.rounded_rectangle(box, r, **kw)

def vgrad(size, top, bottom, y0, y1):
    w, h = size
    g = Image.new("RGBA", size)
    gd = ImageDraw.Draw(g)
    for y in range(h):
        f = min(1, max(0, (y - y0) / max(1, (y1 - y0))))
        gd.line([(0, y), (w, y)], fill=tuple(int(top[i] * (1 - f) + bottom[i] * f) for i in range(4)))
    return g

def draw():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 512
    tile = (50 * k, 50 * k, 462 * k, 462 * k)
    # Soft drop shadow under the tile, then the tile itself.
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    rrect(ImageDraw.Draw(sh), (tile[0], tile[1] + 8 * k, tile[2], tile[3] + 8 * k), 92 * k, fill=(36, 33, 27, 70))
    sh = sh.filter(ImageFilter.GaussianBlur(10 * k))
    img.alpha_composite(sh)
    mask = Image.new("L", (S, S), 0)
    rrect(ImageDraw.Draw(mask), tile, 92 * k, fill=255)
    paper = Image.new("RGBA", (S, S), SHEET)
    # Grain: brown specks, 0 to 10 percent, in 4 px cells so they survive the downscale.
    rnd = random.Random(0x9E3779B9)
    gr = Image.new("RGBA", (S // 4, S // 4))
    gp = gr.load()
    for y in range(S // 4):
        for x in range(S // 4):
            gp[x, y] = GRAIN + (int(rnd.random() * 26),)
    paper.alpha_composite(gr.resize((S, S), Image.NEAREST))
    img.paste(paper, (0, 0), mask)
    d = ImageDraw.Draw(img)
    rrect(d, tile, 92 * k, outline=hexc(0x24211B, 50), width=int(2 * k))

    # Label rule and FIG. 1.
    d.line([(tile[0], 400 * k), (tile[2], 400 * k)], fill=hexc(0x24211B, 120), width=int(2 * k))
    font = ImageFont.truetype(FONT, int(24 * k))
    d.text((256 * k, 436 * k), "FIG. 1", font=font, fill=INK3, anchor="ms")

    # Ground shadow: a flat ink ellipse at 10 percent, no blur.
    gs = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    a, b = P(20, 89.5), P(80, 96.5)
    ImageDraw.Draw(gs).ellipse([a, b], fill=hexc(0x24211B, 26))
    img.alpha_composite(gs)

    poly = body()
    bmask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(bmask).polygon(poly, fill=255)
    # Glass, then liquid with a gentle wave, both clipped to the flask.
    glass = vgrad((S, S), SHINE, GLASS, P(0, 25)[1], P(0, 90)[1])
    img.paste(glass, (0, 0), bmask)
    level = 57
    wave = [P(0, 100)]
    for i in range(0, 101):
        wave.append(P(i, level + math.sin(i / 7.0 + 1.2) * 1.4))
    wave.append(P(100, 100))
    lmask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(lmask).polygon(wave, fill=255)
    lmask = ImageChops.multiply(lmask, bmask)
    liquid = vgrad((S, S), LIQ, DEEP, P(0, level)[1], P(0, 92)[1])
    img.paste(liquid, (0, 0), lmask)

    d = ImageDraw.Draw(img)
    # Bubbles.
    for (bx, by, r) in [(47, 50, 1.7), (54, 33, 1.4), (50, 63, 1.2)]:
        c = P(bx, by)
        d.ellipse([c[0] - r * U, c[1] - r * U, c[0] + r * U, c[1] + r * U], fill=(255, 255, 255, 215), outline=hexc(0x506B39, 140), width=int(0.6 * U))
    # Outline and rim.
    lw = int(2.2 * U)
    d.line(poly + [poly[0]], fill=LINE, width=lw, joint="curve")
    for p in poly:
        d.ellipse([p[0] - lw / 2, p[1] - lw / 2, p[0] + lw / 2, p[1] + lw / 2], fill=LINE)
    r0, r1 = P(37, 15), P(63, 22)
    rrect(d, (r0[0], r0[1], r1[0], r1[1]), 3.5 * U, fill=GLASS, outline=LINE, width=int(2.0 * U))
    # Sheen.
    d.line([P(29, 78), P(36.5, 64)], fill=(255, 255, 255, 190), width=int(2.6 * U))
    for p in (P(29, 78), P(36.5, 64)):
        rr = 1.3 * U; d.ellipse([p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr], fill=(255, 255, 255, 190))
    e0, e1 = P(44, 26), P(46.4, 35)
    d.ellipse([e0, e1], fill=(255, 255, 255, 180))
    # Cheeks, in red pen.
    ch = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for cx in (32.5, 67.5):
        ImageDraw.Draw(ch).ellipse([P(cx - 4.2, 76.5), P(cx + 4.2, 80.9)], fill=CHEEK)
    img.alpha_composite(ch)
    d = ImageDraw.Draw(img)
    # Happy caret eyes, white over a soft green stroke.
    for ex in (41.5, 58.5):
        pts = [P(ex - 4.2, 72.2), P(ex, 67.6), P(ex + 4.2, 72.2)]
        for col, w in ((hexc(0x506B39, 90), 4.2), ((255, 255, 255, 255), 2.6)):
            d.line(pts, fill=col, width=int(w * U), joint="curve")
            for p in (pts[0], pts[2]):
                rr = w * U / 2; d.ellipse([p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr], fill=col)
    return img

big = draw()
src = os.path.join(ROOT, "design-previews", "icon-src")
iconset = os.path.join(ROOT, "Resources", "AppIcon.iconset")
os.makedirs(src, exist_ok=True); os.makedirs(iconset, exist_ok=True)
sizes = {}
for px in (16, 32, 64, 128, 256, 512, 1024):
    im = big.resize((px, px), Image.LANCZOS)
    sizes[px] = im
    im.save(os.path.join(src, f"icon_{px}.png"))
for pt in (16, 32, 128, 256, 512):
    sizes[pt].save(os.path.join(iconset, f"icon_{pt}x{pt}.png"))
    sizes[pt * 2].save(os.path.join(iconset, f"icon_{pt}x{pt}@2x.png"))
sizes[1024].save(os.path.join(ROOT, "Resources", "AppIcon.icns"), format="ICNS")
print("icon written")
