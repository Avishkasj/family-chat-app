#!/usr/bin/env python3
"""Paints an original 'sunrise over the tea hills' photo for the demo chat.

Usage: make_demo_photo.py <out.jpg>   (prints JSON with size + thumbnail)
"""
import base64
import io
import json
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

W, H = 1600, 1200
random.seed(7)


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def ridge(y0, amp, seed, freq=1.0):
    random.seed(seed)
    phases = [random.random() * 6.28 for _ in range(4)]
    pts = []
    for x in range(0, W + 8, 8):
        u = x / W
        y = y0 + amp * (0.55 * math.sin(u * 5.1 * freq + phases[0])
                        + 0.30 * math.sin(u * 11.7 * freq + phases[1])
                        + 0.15 * math.sin(u * 23.3 * freq + phases[2]))
        pts.append((x, y))
    return pts + [(W, H), (0, H)]


img = Image.new('RGB', (W, H))
px = img.load()
sky_top, sky_mid, sky_low = (126, 170, 214), (247, 196, 160), (255, 226, 178)
for y in range(H):
    t = y / (H * 0.62)
    c = lerp(sky_top, sky_mid, min(t, 1) ** 0.9) if t < 1 else sky_mid
    if 0.55 < t:
        c = lerp(c, sky_low, min((t - 0.55) / 0.45, 1))
    for x in range(W):
        px[x, y] = c

# Sun with glow.
glow = Image.new('L', (W, H), 0)
gd = ImageDraw.Draw(glow)
sx, sy = int(W * 0.63), int(H * 0.47)
for r, a in [(420, 40), (260, 70), (150, 120)]:
    gd.ellipse((sx - r, sy - r, sx + r, sy + r), fill=a)
glow = glow.filter(ImageFilter.GaussianBlur(90))
img = Image.composite(Image.new('RGB', (W, H), (255, 236, 196)), img, glow)
d = ImageDraw.Draw(img)
d.ellipse((sx - 70, sy - 70, sx + 70, sy + 70), fill=(255, 246, 222))

# Misty mountain layers, far to near.
layers = [
    (H * 0.52, 60, 1, (176, 168, 190), 0.9),
    (H * 0.58, 70, 2, (140, 146, 170), 1.2),
    (H * 0.66, 80, 3, (96, 128, 128), 1.0),
]
for y0, amp, seed, colour, f in layers:
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(ridge(y0, amp, seed, f), fill=colour + (255,))
    img.paste(layer, (0, 0), layer)
    mist = Image.new('L', (W, H), 0)
    ImageDraw.Draw(mist).rectangle((0, y0 + amp * 0.2, W, y0 + amp * 1.6), fill=60)
    mist = mist.filter(ImageFilter.GaussianBlur(40))
    img = Image.composite(Image.new('RGB', (W, H), (250, 228, 205)), img, mist)

# Tea hill in the foreground with rows of bushes.
hill = ridge(H * 0.78, 50, 9, 0.6)
hl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ImageDraw.Draw(hl).polygon(hill, fill=(58, 112, 62, 255))
rows = Image.new('RGBA', (W, H), (0, 0, 0, 0))
rd = ImageDraw.Draw(rows)
for i in range(26):
    y = H * 0.74 + i * 14 + (i ** 1.6)
    rd.arc((-W * 0.4, y - 120, W * 1.4, y + 380), 195, 345,
           fill=(92, 150, 78, 255), width=max(4, int(4 + i * 0.9)))
mask = hl.split()[3]
hl.paste(rows, (0, 0), Image.composite(rows.split()[3], Image.new('L', (W, H), 0), mask))
img.paste(hl, (0, 0), hl)

# Gentle grain so it reads as a photo.
noise = Image.effect_noise((W, H), 12).convert('RGB')
img = Image.blend(img, noise, 0.04).filter(ImageFilter.GaussianBlur(0.6))

out = sys.argv[1]
img.save(out, quality=88)
thumb = img.copy()
thumb.thumbnail((24, 24))
buf = io.BytesIO()
thumb.save(buf, 'PNG')
print(json.dumps({
    'w': W, 'h': H,
    'thumb': base64.urlsafe_b64encode(buf.getvalue()).decode().rstrip('='),
}))
