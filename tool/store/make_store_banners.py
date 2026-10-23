#!/usr/bin/env python3
"""Builds the App Store product-page Header and Search Results assets.

    python3 tool/store/make_store_banners.py

Uses the raw iPhone captures (store/app-store-screenshots/raw/iphone-6.3)
and the same visual language as make_store_screenshots.py. Writes:
  store/app-store-header/header-3840x1646.png
  store/app-store-header/header-5244x2950.png
  store/app-store-search-results/search-results-3840x2560.png
  store/app-store-search-results/search-results-1920x1280.png
"""
import os

from PIL import Image, ImageDraw

import make_store_screenshots as base

ROOT = base.ROOT
RAW = os.path.join(ROOT, 'store', 'app-store-screenshots', 'raw', 'iphone-6.3')
THEME = dict(base.THEMES['01-family-chat'], glows=[(80, 220, 190), (40, 150, 200)])
WHITE = base.WHITE


def phone(shot_name, screen_h):
    """A framed iPhone on its own transparent canvas."""
    shot = Image.open(os.path.join(RAW, f'{shot_name}.png')).convert('RGB')
    sw = round(screen_h * shot.width / shot.height)
    k = sw / 900
    spec = dict(screen_w=sw, radius=int(112 * k), bezel=int(24 * k), island=True)
    # Generous margin so the soft shadow isn't clipped before rotation.
    margin = int(420 * k)
    fw = sw + 2 * spec['bezel']
    fh = screen_h + 2 * spec['bezel']
    canvas = Image.new('RGBA', (fw + 2 * margin, fh + 2 * margin), (0, 0, 0, 0))
    base.device(canvas, shot, margin, margin, spec)
    return canvas, k


def notification(scale):
    """The 'Lunch is ready!' notification card, cropped from a scratch canvas."""
    # Room around the card so its soft shadow isn't clipped.
    scratch = Image.new('RGBA', (1206, 1200), (0, 0, 0, 0))
    base.callout_notification(scratch, 1.6, 1206, (0, 300, 0, 300))
    card = scratch.crop(scratch.getbbox())
    return card.resize((round(card.width * scale), round(card.height * scale)),
                       Image.LANCZOS)


def compose(W, H, out):
    canvas = base.background((W, H), THEME)
    d = ImageDraw.Draw(canvas)
    u = min(W / 3840, H / 1646 * 1.25)  # type scale

    # -- phones (right) ------------------------------------------------------
    # Size the fanned group from the phones themselves so it fits any aspect
    # ratio: the group is ~2.5 phone-widths wide and must fit the right 52%.
    phone_ratio = 1206 / 2622 * 1.05  # frame width / screen height
    frame_w = min(H * 0.74 * phone_ratio, W * 0.52 / 2.5)
    screen_h = int(frame_w / phone_ratio)
    spread = frame_w * 0.78
    centre_x = W - W * 0.045 - frame_w * 1.25
    phones = [('03-poll', 7, 0.86, -1), ('01-family-chat', -7, 0.86, 1),
              ('02-family-call', 0, 1.0, 0)]
    centre_box = None
    for name, angle, scale, side in phones:
        img, k = phone(name, int(screen_h * scale))
        if angle:
            img = img.rotate(angle, resample=Image.BICUBIC, expand=True)
        x = int(centre_x + side * spread - img.width / 2)
        y = int(H * 0.53 - img.height / 2 + (H * 0.04 if angle else 0))
        canvas.alpha_composite(img, (x, y))
        if not angle:
            centre_box = (x, y, x + img.width, y + img.height)
    # Notification floating over the centre phone.
    note = notification(scale=screen_h / 2100)
    nx = int((centre_box[0] + centre_box[2]) / 2 - note.width / 2 - frame_w * 0.25)
    ny = int((centre_box[1] + centre_box[3]) / 2 - screen_h * 0.40)
    canvas.alpha_composite(note, (nx, ny))

    # -- text (left) ------------------------------------------------------------
    left = W * 0.075
    text_w = W * 0.40
    ic = base.icon_image(170 * u * 1.2)
    y = H * 0.5 - 560 * u
    base.shadow(canvas, (left, y, left + ic.width, y + ic.height), ic.width * 0.225,
                20 * u, offset=(0, 10 * u), alpha=90)
    canvas.alpha_composite(ic, (int(left), int(y)))
    d.text((left + ic.width + 34 * u, y + ic.height / 2), 'FamNest',
           font=base.font(92 * u, 'Bold'), fill=WHITE, anchor='lm')
    y += ic.height + 70 * u

    title = base.font(178 * u, 'Heavy')
    for text, accent in [("Your family's", False), ('private chat', True)]:
        d.text((left, y), text, font=title, fill=THEME['accent'] if accent else WHITE)
        y += 196 * u
    y += 24 * u
    sub = base.font(66 * u, 'Medium')
    d.text((left, y), 'Messages, photos, polls and family calls', font=sub,
           fill=(255, 255, 255, 230))
    y += 84 * u
    d.text((left, y), 'over your home Wi‑Fi — no internet needed.', font=sub,
           fill=(255, 255, 255, 230))
    y += 140 * u
    x = left
    for icon, label in [('\U0001F4F6', 'No internet'), ('\U0001F512', 'Encrypted'),
                        ('\U0001F3E0', 'Stays at home')]:
        x += base.pill(canvas, x, y, label, 1.35 * u, icon=icon, size=40,
                       fill=(255, 255, 255, 60), colour=WHITE) + 24 * u
    assert x < left + text_w + W * 0.1, 'badges overflow into the phones'

    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.convert('RGB').save(out, optimize=True)
    print(out, f'{W}x{H}')


def main():
    header = os.path.join(ROOT, 'store', 'app-store-header')
    search = os.path.join(ROOT, 'store', 'app-store-search-results')
    compose(3840, 1646, os.path.join(header, 'header-3840x1646.png'))
    compose(5244, 2950, os.path.join(header, 'header-5244x2950.png'))
    compose(3840, 2560, os.path.join(search, 'search-results-3840x2560.png'))
    big = Image.open(os.path.join(search, 'search-results-3840x2560.png'))
    small = big.resize((1920, 1280), Image.LANCZOS)
    small.save(os.path.join(search, 'search-results-1920x1280.png'), optimize=True)
    print(os.path.join(search, 'search-results-1920x1280.png'), '1920x1280')


if __name__ == '__main__':
    main()
