#!/usr/bin/env python3
"""Generates every FamNest app / notification icon from code.

    python3 tool/generate_icons.py

Artwork: a single white mark - a chat bubble shaped like a house, with three
"typing" dots - on a deep, flat teal. Minimal and two-colour so it stays
crisp at every size. The dev flavour adds a small orange "DEV" pill.
Requires Pillow (pip install pillow).
"""
import json
import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 4  # supersampling factor for smooth edges

TEAL_TOP = (18, 140, 122)
TEAL_BOTTOM = (10, 94, 84)
WHITE = (255, 255, 255)
DEV_ORANGE = (245, 124, 0)

# The mark, in unit coordinates (0..1 of the icon), clockwise, with the
# corner radius applied to each vertex.
HOUSE_BUBBLE = [
    ((0.500, 0.190), 0.070),  # roof peak
    ((0.805, 0.430), 0.070),  # right eave
    ((0.805, 0.735), 0.105),  # bottom right
    ((0.400, 0.735), 0.040),  # tail start
    ((0.235, 0.835), 0.030),  # tail tip
    ((0.195, 0.690), 0.020),  # tail meets the left wall
    ((0.195, 0.430), 0.070),  # left eave
]
DOTS_Y = 0.575
DOT_RADIUS = 0.043
DOT_SPACING = 0.135


def _fillet(points):
    """Polygon with every corner rounded by its radius (unit coords)."""
    out = []
    n = len(points)
    for i in range(n):
        (px, py), radius = points[i]
        (ax, ay), _ = points[i - 1]
        (bx, by), _ = points[(i + 1) % n]
        v1 = (ax - px, ay - py)
        v2 = (bx - px, by - py)
        l1 = math.hypot(*v1)
        l2 = math.hypot(*v2)
        u1 = (v1[0] / l1, v1[1] / l1)
        u2 = (v2[0] / l2, v2[1] / l2)
        angle = math.acos(max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1])))
        # Distance from the corner to the tangent points.
        t = min(radius / math.tan(angle / 2), l1 * 0.45, l2 * 0.45)
        r = t * math.tan(angle / 2)
        p1 = (px + u1[0] * t, py + u1[1] * t)
        p2 = (px + u2[0] * t, py + u2[1] * t)
        bis = (u1[0] + u2[0], u1[1] + u2[1])
        bl = math.hypot(*bis)
        d = r / math.sin(angle / 2)
        cx, cy = px + bis[0] / bl * d, py + bis[1] / bl * d
        a1 = math.atan2(p1[1] - cy, p1[0] - cx)
        a2 = math.atan2(p2[1] - cy, p2[0] - cx)
        sweep = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
        steps = 96
        for k in range(steps + 1):
            a = a1 + sweep * k / steps
            out.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def gradient(size):
    """Flat teal with a barely-there vertical gradient."""
    col = Image.new('RGB', (1, size))
    for y in range(size):
        t = y / (size - 1)
        col.putpixel((0, y), tuple(
            round(TEAL_TOP[i] + (TEAL_BOTTOM[i] - TEAL_TOP[i]) * t)
            for i in range(3)))
    return col.resize((size, size))


def glyph_masks(size, scale=1.0):
    """Returns (mark, dots) masks for a canvas of [size].

    [scale] shrinks the artwork around the centre (adaptive icon safe zone).
    """
    big = size * SS
    off = big * (1 - scale) / 2

    def p(x, y):
        return (off + x * big * scale, off + y * big * scale)

    mark = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mark).polygon(
        [p(x, y) for x, y in _fillet(HOUSE_BUBBLE)], fill=255)

    dots = Image.new('L', (big, big), 0)
    d = ImageDraw.Draw(dots)
    r = DOT_RADIUS * big * scale
    for i in (-1, 0, 1):
        cx, cy = p(0.5 + i * DOT_SPACING, DOTS_Y)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    return mark, dots


def down(img, size):
    return img.resize((size, size), Image.LANCZOS)


def full_icon(size, dev=False, rounded=False):
    """Full-colour square icon (iOS / legacy Android / store)."""
    big = size * SS
    canvas = gradient(big).convert('RGBA')
    mark, dots = glyph_masks(size)
    canvas.paste(WHITE + (255,), (0, 0), mark)
    canvas.paste(TEAL_BOTTOM + (255,), (0, 0), dots)
    if dev:
        _dev_pill(canvas, big, y=0.915, width=0.30, height=0.10)
    if rounded:
        mask = Image.new('L', (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, big - 1, big - 1), radius=big * 0.225, fill=255)
        canvas.putalpha(mask)
    out = down(canvas, size)
    return out if rounded else out.convert('RGB')


def _dev_pill(canvas, big, y, width, height):
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle(
        (big * (0.5 - width / 2), big * (y - height / 2),
         big * (0.5 + width / 2), big * (y + height / 2)),
        radius=big * height / 2, fill=DEV_ORANGE + (255,))
    d.text((big / 2, big * y), 'DEV', fill=WHITE,
           font=_font(int(big * height * 0.62)), anchor='mm')


def _font(px):
    for path in ['/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf',
                 '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
                 '/Library/Fonts/Arial Bold.ttf']:
        if os.path.exists(path):
            return ImageFont.truetype(path, px)
    return ImageFont.load_default()


def adaptive_foreground(size, dev=False):
    """Android adaptive foreground (108dp canvas, art inside the safe zone)."""
    big = size * SS
    canvas = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    mark, dots = glyph_masks(size, scale=0.62)
    canvas.paste(WHITE + (255,), (0, 0), mark)
    canvas.paste(TEAL_BOTTOM + (255,), (0, 0), dots)
    if dev:
        _dev_pill(canvas, big, y=0.78, width=0.20, height=0.065)
    return down(canvas, size)


def silhouette(size, scale):
    """White mark with the dots cut out (monochrome / notification icon)."""
    mark, dots = glyph_masks(size, scale=scale)
    alpha = Image.composite(Image.new('L', mark.size, 0), mark, dots)
    icon = Image.new('RGBA', mark.size, WHITE + (0,))
    icon.putalpha(alpha)
    return down(icon, size)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def ios(set_name, dev):
    folder = os.path.join(ROOT, 'ios/Runner/Assets.xcassets', set_name)
    contents = json.load(open(os.path.join(folder, 'Contents.json')))
    master = full_icon(1024, dev=dev)
    for image in contents['images']:
        name = image.get('filename')
        if not name:
            continue
        pts = float(image['size'].split('x')[0])
        px = round(pts * int(image['scale'][0]))
        master.resize((px, px), Image.LANCZOS).save(os.path.join(folder, name))


DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

ADAPTIVE_XML = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'''

BACKGROUND_XML = '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient
        android:angle="270"
        android:startColor="#128C7A"
        android:endColor="#0A5E54"
        android:type="linear"/>
</shape>
'''


def android(source_set, dev):
    res = os.path.join('android/app/src', source_set, 'res')
    for density, factor in DENSITIES.items():
        save(full_icon(round(48 * factor), dev=dev, rounded=True),
             res, f'mipmap-{density}', 'ic_launcher.png')
        save(adaptive_foreground(round(108 * factor), dev=dev),
             res, f'mipmap-{density}', 'ic_launcher_foreground.png')
        save(silhouette(round(108 * factor), scale=0.70),
             res, f'mipmap-{density}', 'ic_launcher_monochrome.png')
    for name, text in [('mipmap-anydpi-v26/ic_launcher.xml', ADAPTIVE_XML),
                       ('drawable/ic_launcher_background.xml', BACKGROUND_XML)]:
        path = os.path.join(ROOT, res, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, 'w').write(text)


SPLASH = (15, 123, 108)  # #0F7B6C, flat brand teal behind the splash mark
SPLASH_PT = 160  # logical size of the splash image on both platforms


def splash():
    """Splash mark (white, dots see-through) for iOS, Android and Flutter."""
    for name in ['LaunchImage', 'prodLaunchImage', 'devLaunchImage']:
        folder = os.path.join(ROOT, 'ios/Runner/Assets.xcassets',
                              f'{name}.imageset')
        os.makedirs(folder, exist_ok=True)
        images = []
        for scale in (1, 2, 3):
            filename = f'{name}{"" if scale == 1 else f"@{scale}x"}.png'
            silhouette(SPLASH_PT * scale, 1.0).save(os.path.join(folder, filename))
            images.append({'idiom': 'universal', 'filename': filename,
                           'scale': f'{scale}x'})
        json.dump({'images': images, 'info': {'version': 1, 'author': 'xcode'}},
                  open(os.path.join(folder, 'Contents.json'), 'w'), indent=2)
        readme = os.path.join(folder, 'README.md')
        if os.path.exists(readme):
            os.remove(readme)
    res = 'android/app/src/main/res'
    for density, factor in DENSITIES.items():
        save(silhouette(round(SPLASH_PT * factor), 1.0),
             res, f'drawable-{density}', 'splash_logo.png')
        # Android 12+ splash icon: 288dp canvas, visible inside a 192dp circle.
        save(silhouette(round(288 * factor), 0.62),
             res, f'drawable-{density}', 'splash_icon.png')
    save(silhouette(SPLASH_PT * 3, 1.0), 'assets/branding/splash_logo.png')


def notification_icons():
    res = 'android/app/src/main/res'
    for density, factor in DENSITIES.items():
        save(silhouette(round(24 * factor), scale=1.18),
             res, f'drawable-{density}', 'ic_stat_famnest.png')


if __name__ == '__main__':
    ios('AppIcon.appiconset', dev=False)
    ios('prodAppIcon.appiconset', dev=False)
    ios('devAppIcon.appiconset', dev=True)
    for source_set, dev in [('main', False), ('prod', False), ('dev', True)]:
        android(source_set, dev)
    notification_icons()
    splash()
    save(full_icon(1024), 'assets/branding/famnest_icon_1024.png')
    save(full_icon(512), 'assets/branding/famnest_play_store_512.png')
    print('Icons generated.')
