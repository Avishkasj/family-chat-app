#!/usr/bin/env python3
"""Frames raw captures into App Store marketing screenshots.

    python3 tool/store/make_store_screenshots.py

Reads store/app-store-screenshots/raw/<device>/*.png (from
capture_store_screenshots.sh) and writes App Store-ready images to
store/app-store-screenshots/<device>/ at Apple's exact sizes:
  iphone-6.3 -> 1206 x 2622 (iPhone 6.3", also used for 6.1")
  ipad-13    -> 2064 x 2752 (iPad 13")

Each screenshot gets its own colour theme, a bold headline with an accent
phrase, the capture in a device frame, and a floating callout that
highlights the feature.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BASE = os.path.join(ROOT, 'store', 'app-store-screenshots')
ICON = os.path.join(ROOT, 'assets', 'branding', 'famnest_icon_1024.png')
SF = '/System/Library/Fonts/SFNS.ttf'
EMOJI = '/System/Library/Fonts/Apple Color Emoji.ttc'

WHITE = (255, 255, 255)
INK = (24, 28, 32)
MUTED = (110, 116, 122)

# Per-screenshot theme: gradient (top, bottom), glow colours, accent colour.
THEMES = {
    '01-family-chat': dict(top=(20, 150, 130), bottom=(7, 70, 62),
                           glows=[(80, 220, 190), (255, 196, 120)], accent=(255, 224, 138)),
    '02-family-call': dict(top=(255, 150, 104), bottom=(214, 72, 52),
                           glows=[(255, 214, 140), (255, 110, 120)], accent=(255, 241, 196)),
    '03-poll': dict(top=(124, 108, 255), bottom=(58, 44, 186),
                    glows=[(176, 150, 255), (90, 200, 255)], accent=(255, 224, 138)),
    '04-chats': dict(top=(18, 78, 92), bottom=(8, 30, 40),
                     glows=[(30, 160, 150), (60, 110, 220)], accent=(120, 236, 210)),
    '05-family': dict(top=(52, 196, 120), bottom=(14, 120, 80),
                      glows=[(170, 240, 150), (40, 190, 200)], accent=(255, 241, 170)),
    '06-privacy': dict(top=(34, 46, 84), bottom=(10, 14, 32),
                       glows=[(30, 170, 150), (110, 90, 255)], accent=(110, 236, 205)),
}

# Headline lines as (text, is_accent) runs, and a subtitle.
COPY = {
    '01-family-chat': ([[("Your family's", False)], [('private chat', True)]],
                       'Talk, share photos and plan together'),
    '02-family-call': ([[('Call everyone', False)], [('for lunch', True)]],
                       'One tap — everyone answers'),
    '03-poll': ([[('Decide', False), (' together', True)]],
                'Quick polls for family plans'),
    '04-chats': ([[('No internet.', False)], [('No cloud.', True)]],
                 'Messages never leave your home Wi‑Fi'),
    '05-family': ([[("See who's", False), (' home', True)]],
                  'Live status for the whole family'),
    '06-privacy': ([[('Private by', False)], [('design', True)]],
                   'Face ID lock · end‑to‑end encryption'),
}

DEVICES = {
    'iphone-6.3': dict(size=(1206, 2622), screen_w=900, title=118, sub=50,
                       top=150, radius=112, bezel=24, island=True, scale=1.0,
                       callout=1.6),
    'ipad-13': dict(size=(2064, 2752), screen_w=1560, title=156, sub=66,
                    top=170, radius=58, bezel=36, island=False, scale=1.55,
                    callout=2.3),
}


# -- type & emoji ------------------------------------------------------------

def font(size, weight='Bold'):
    f = ImageFont.truetype(SF, int(size))
    f.set_variation_by_name(weight)
    return f


def emoji(char, size):
    """Colour emoji image (Apple Color Emoji renders at 160px)."""
    f = ImageFont.truetype(EMOJI, 160)
    im = Image.new('RGBA', (200, 200), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((0, 0), char, font=f, embedded_color=True)
    im = im.crop(im.getbbox())
    s = int(size)
    return im.resize((s, round(im.height * s / im.width)), Image.LANCZOS)


def text_width(draw, text, f):
    return draw.textlength(text, font=f)


# -- backgrounds & shapes ----------------------------------------------------

def background(size, theme):
    w, h = size
    col = Image.new('RGB', (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(
            round(theme['top'][i] + (theme['bottom'][i] - theme['top'][i]) * t)
            for i in range(3)))
    bg = col.resize((w, h)).convert('RGBA')
    # Soft coloured light blobs for depth.
    for (cx, cy, r), colour, alpha in [
        ((0.05, 0.08, 0.55), theme['glows'][0], 120),
        ((1.0, 0.42, 0.45), theme['glows'][1], 90),
        ((0.15, 0.95, 0.5), theme['glows'][0], 70),
    ]:
        layer = Image.new('RGBA', (w, h), colour + (0,))
        mask = Image.new('L', (w, h), 0)
        ImageDraw.Draw(mask).ellipse(
            (w * (cx - r), h * cy - w * r, w * (cx + r), h * cy + w * r), fill=alpha)
        mask = mask.filter(ImageFilter.GaussianBlur(w * 0.16))
        layer.putalpha(mask)
        bg.alpha_composite(layer)
    return bg


def shadow(canvas, box, radius, blur, offset=(0, 24), alpha=110, colour=(0, 0, 0)):
    w, h = canvas.size
    mask = Image.new('L', (w, h), 0)
    x0, y0, x1, y1 = box
    ImageDraw.Draw(mask).rounded_rectangle(
        (x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]), radius, fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    layer = Image.new('RGBA', (w, h), colour + (0,))
    layer.putalpha(mask)
    canvas.alpha_composite(layer)


def rounded(img, radius):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius, fill=255)
    out = img.convert('RGBA')
    out.putalpha(mask)
    return out


def card(canvas, box, radius, fill=(255, 255, 255, 244), blur=40, alpha=90):
    shadow(canvas, box, radius, blur, offset=(0, int(blur * 0.5)), alpha=alpha)
    layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius, fill=fill)
    canvas.alpha_composite(layer)


def pill(canvas, x, y, label, k, icon=None, fill=(255, 255, 255, 236),
         colour=INK, size=40, centre=False):
    """Rounded label with optional emoji; returns its width."""
    d = ImageDraw.Draw(canvas)
    f = font(size * k, 'Semibold')
    pad_x, pad_y = 30 * k, 18 * k
    icon_img = emoji(icon, size * 1.05 * k) if icon else None
    icon_w = icon_img.width + 14 * k if icon_img else 0
    w = pad_x * 2 + icon_w + text_width(d, label, f)
    h = size * k + pad_y * 2
    if centre:
        x -= w / 2
    card(canvas, (x, y, x + w, y + h), h / 2, fill=fill, blur=24 * k, alpha=70)
    cx = x + pad_x
    if icon_img:
        canvas.alpha_composite(icon_img, (int(cx), int(y + (h - icon_img.height) / 2)))
        cx += icon_w
    ImageDraw.Draw(canvas).text((cx, y + h / 2), label, font=f, fill=colour, anchor='lm')
    return w


# -- device ------------------------------------------------------------------

def device(canvas, shot, x, y, spec):
    sw = spec['screen_w']
    sh = round(shot.height * sw / shot.width)
    screen = shot.resize((sw, sh), Image.LANCZOS)
    bezel, radius = spec['bezel'], spec['radius']
    edge = max(6, bezel // 4)
    fw, fh = sw + 2 * bezel, sh + 2 * bezel
    shadow(canvas, (x, y, x + fw, y + fh), radius + bezel, 70, offset=(0, 50), alpha=150)

    frame = Image.new('RGBA', (fw + 2 * edge, fh + 2 * edge), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    # Titanium edge: vertical metallic gradient.
    metal = Image.new('RGBA', frame.size)
    md = ImageDraw.Draw(metal)
    for i in range(frame.height):
        t = i / frame.height
        v = int(150 + 60 * abs(0.5 - t) * 2)
        md.line((0, i, frame.width, i), fill=(v, v + 2, v + 6, 255))
    mmask = Image.new('L', frame.size, 0)
    ImageDraw.Draw(mmask).rounded_rectangle(
        (0, 0, frame.width - 1, frame.height - 1), radius + bezel + edge, fill=255)
    frame.paste(metal, (0, 0), mmask)
    fd.rounded_rectangle((edge, edge, edge + fw - 1, edge + fh - 1),
                         radius + bezel, fill=(12, 13, 15, 255))
    frame.alpha_composite(rounded(screen, radius), (edge + bezel, edge + bezel))
    if spec['island']:
        iw, ih = int(sw * 0.30), int(sw * 0.088)
        ix, iy = edge + bezel + (sw - iw) // 2, edge + bezel + int(sw * 0.026)
        fd.rounded_rectangle((ix, iy, ix + iw, iy + ih), ih // 2, fill=(0, 0, 0, 255))
    canvas.alpha_composite(frame, (x - edge, y - edge))
    # Side buttons (phone only).
    if spec['island']:
        d = ImageDraw.Draw(canvas)
        bc = (130, 134, 140, 255)
        for (by, bh) in [(0.17, 0.035), (0.23, 0.06), (0.31, 0.06)]:
            d.rounded_rectangle((x - edge - 7, y + fh * by, x - edge + 2, y + fh * (by + bh)), 4, fill=bc)
        d.rounded_rectangle((x + fw + edge - 2, y + fh * 0.25, x + fw + edge + 7, y + fh * 0.34), 4, fill=bc)
    return (x, y, x + fw, y + fh)


# -- callouts ----------------------------------------------------------------

def icon_image(size):
    return rounded(Image.open(ICON).convert('RGBA').resize((int(size), int(size)), Image.LANCZOS),
                   int(size * 0.225))


def callout_hero(canvas, k, W, y):
    """Feature badges under the headline."""
    items = [('\U0001F4F6', 'No internet'), ('\U0001F512', 'Encrypted'),
             ('\U0001F3E0', 'At home')]
    size = 30
    d = ImageDraw.Draw(canvas)
    f = font(size * k, 'Semibold')
    widths = [60 * k + size * 1.05 * k + 14 * k + d.textlength(t, font=f) for _, t in items]
    gap = 16 * k
    x = (W - sum(widths) - gap * (len(items) - 1)) / 2
    for (icon, label), w in zip(items, widths):
        x += pill(canvas, x, y, label, k, icon=icon, size=size,
                  fill=(255, 255, 255, 64), colour=WHITE) + gap
    return size * k + 36 * k


def callout_notification(canvas, k, W, dev):
    """An iOS-style notification for a family call, with answer buttons."""
    w = W * 0.92 if W < 1500 else W * 0.84
    x = (W - w) / 2
    y = dev[1] + (dev[3] - dev[1]) * 0.07
    pad = 34 * k
    h = 330 * k
    card(canvas, (x, y, x + w, y + h), 46 * k, fill=(250, 250, 252, 246), blur=50 * k, alpha=120)
    d = ImageDraw.Draw(canvas)
    ic = icon_image(84 * k)
    canvas.alpha_composite(ic, (int(x + pad), int(y + pad)))
    tx = x + pad + 84 * k + 24 * k
    d.text((tx, y + pad + 4 * k), 'FAMNEST', font=font(28 * k, 'Semibold'), fill=MUTED)
    d.text((x + w - pad, y + pad + 4 * k), 'now', font=font(28 * k, 'Regular'), fill=MUTED, anchor='ra')
    em = emoji('\U0001F35B', 44 * k)
    canvas.alpha_composite(em, (int(tx), int(y + pad + 40 * k)))
    d.text((tx + em.width + 12 * k, y + pad + 38 * k), 'Lunch is ready!',
           font=font(40 * k, 'Bold'), fill=INK)
    d.text((tx, y + pad + 94 * k), 'Mum is calling the family',
           font=font(32 * k, 'Regular'), fill=(60, 64, 70))
    # Answer buttons.
    by = y + h - pad - 74 * k
    labels = [('\U0001F3C3', 'On my way'), ('⏳', '5 min'), ('\U0001F645', "Can't come")]
    bw = (w - 2 * pad - 2 * 16 * k) / 3
    for i, (icon, label) in enumerate(labels):
        bx = x + pad + i * (bw + 16 * k)
        fill = (15, 123, 108, 255) if i == 0 else (234, 236, 240, 255)
        colour = WHITE if i == 0 else INK
        d.rounded_rectangle((bx, by, bx + bw, by + 74 * k), 37 * k, fill=fill)
        em = emoji(icon, 32 * k)
        f = font(28 * k, 'Semibold')
        tw = em.width + 10 * k + d.textlength(label, font=f)
        sx = bx + (bw - tw) / 2
        canvas.alpha_composite(em, (int(sx), int(by + (74 * k - em.height) / 2)))
        d.text((sx + em.width + 10 * k, by + 37 * k), label, font=f, fill=colour, anchor='lm')


def callout_poll(canvas, k, W, dev):
    y = dev[1] + (dev[3] - dev[1]) * 0.165
    pill(canvas, W / 2, y, 'Kandy wins \u2014 3 of 4 votes', k, icon='\U0001F3C6',
         size=38, centre=True)


def callout_offline(canvas, k, W, dev):
    y = dev[1] + (dev[3] - dev[1]) * 0.60
    pill(canvas, W / 2, y, 'Works on home Wi‑Fi only', k, icon='\U0001F4F6', size=40, centre=True)
    pill(canvas, W / 2, y + 120 * k, '0 messages sent to the cloud', k, icon='☁️',
         size=40, centre=True, fill=(255, 255, 255, 230))


def callout_home(canvas, k, W, dev):
    w, h = 560 * k, 150 * k
    x = (W - w) / 2
    y = dev[1] + (dev[3] - dev[1]) * 0.66
    card(canvas, (x, y, x + w, y + h), 40 * k, blur=40 * k, alpha=100)
    d = ImageDraw.Draw(canvas)
    colours = [((214, 100, 160), 'G'), ((140, 90, 214), 'K'), ((120, 190, 90), 'M')]
    r = 44 * k
    for i, (c, letter) in enumerate(colours):
        cx = x + 40 * k + r + i * r * 1.35
        cy = y + h / 2
        d.ellipse((cx - r - 5 * k, cy - r - 5 * k, cx + r + 5 * k, cy + r + 5 * k), fill=WHITE)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)
        d.text((cx, cy), letter, font=font(38 * k, 'Semibold'), fill=WHITE, anchor='mm')
    tx = x + 40 * k + r * 2 + 2 * r * 1.35 + 30 * k
    d.text((tx, y + 40 * k), '3 at home now', font=font(38 * k, 'Bold'), fill=INK)
    d.ellipse((tx, y + 100 * k, tx + 18 * k, y + 118 * k), fill=(46, 184, 114))
    d.text((tx + 28 * k, y + 109 * k), 'Online', font=font(30 * k, 'Medium'),
           fill=(46, 150, 100), anchor='lm')


def callout_face_id(canvas, k, W, dev):
    size = 220 * k
    x = min(dev[2] - size * 0.45, W - size - W * 0.03)
    y = dev[1] + (dev[3] - dev[1]) * 0.60
    card(canvas, (x, y, x + size, y + size), size * 0.23, fill=(20, 24, 40, 236),
         blur=60 * k, alpha=140)
    d = ImageDraw.Draw(canvas)
    g = (110, 236, 205)
    # Proportions relative to the badge so the glyph never distorts.
    m, L, t = size * 0.22, size * 0.17, max(3, int(size * 0.04))
    x0, y0, x1, y1 = x + m, y + m, x + size - m, y + size - m
    # Corner brackets.
    for (cx, cy, sx, sy) in [(x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)]:
        d.line((cx, cy, cx + sx * L, cy), fill=g, width=t)
        d.line((cx, cy, cx, cy + sy * L), fill=g, width=t)
    # Face.
    ex = (x1 - x0)
    d.line((x0 + ex * 0.3, y0 + ex * 0.33, x0 + ex * 0.3, y0 + ex * 0.43), fill=g, width=t)
    d.line((x0 + ex * 0.7, y0 + ex * 0.33, x0 + ex * 0.7, y0 + ex * 0.43), fill=g, width=t)
    d.line((x0 + ex * 0.5, y0 + ex * 0.33, x0 + ex * 0.5, y0 + ex * 0.58,
            x0 + ex * 0.44, y0 + ex * 0.58), fill=g, width=t, joint='curve')
    d.arc((x0 + ex * 0.28, y0 + ex * 0.45, x0 + ex * 0.72, y0 + ex * 0.78), 30, 150, fill=g, width=t)
    # Floats over the phone's left edge, beside the Face ID badge.
    pill(canvas, max(W * 0.03, dev[0] - 30 * k), y + size * 0.5,
         'End‑to‑end encrypted', k, icon='\U0001F512', size=38)


CALLOUTS = {
    '02-family-call': callout_notification,
    '03-poll': callout_poll,
    '04-chats': callout_offline,
    '05-family': callout_home,
    '06-privacy': callout_face_id,
}


# -- composition --------------------------------------------------------------

def headline(canvas, spec, lines, subtitle, theme, y):
    d = ImageDraw.Draw(canvas)
    W = canvas.width
    f = font(spec['title'], 'Heavy')
    line_h = int(spec['title'] * 1.08)
    y += (2 - len(lines)) * line_h // 2
    for runs in lines:
        total = sum(d.textlength(t, font=f) for t, _ in runs)
        x = (W - total) / 2
        for text, accent in runs:
            d.text((x, y), text, font=f, fill=theme['accent'] if accent else WHITE)
            x += d.textlength(text, font=f)
        y += line_h
    y = max(y, spec['top_text'] + 2 * line_h)
    y += int(spec['sub'] * 0.5)
    d.text((W / 2, y), subtitle, font=font(spec['sub'], 'Medium'),
           fill=(255, 255, 255, 228), anchor='ma')
    return y + int(spec['sub'] * 1.4)


def compose(device_name, name, raw_path):
    spec = dict(DEVICES[device_name])
    W, H = spec['size']
    k = spec['scale']
    theme = THEMES[name]
    canvas = background((W, H), theme)
    lines, subtitle = COPY[name]

    y = spec['top']
    if name == '01-family-chat':
        # Hero: app icon + name above the headline.
        ic = icon_image(150 * k)
        d = ImageDraw.Draw(canvas)
        wf = font(60 * k, 'Bold')
        total = ic.width + 26 * k + d.textlength('FamNest', font=wf)
        x = (W - total) / 2
        shadow(canvas, (x, y, x + ic.width, y + ic.height), ic.width * 0.225, 20 * k,
               offset=(0, 10 * k), alpha=90)
        canvas.alpha_composite(ic, (int(x), int(y)))
        d.text((x + ic.width + 26 * k, y + ic.height / 2), 'FamNest', font=wf,
               fill=WHITE, anchor='lm')
        y += ic.height + 50 * k
    spec['top_text'] = y
    y = headline(canvas, spec, lines, subtitle, theme, y)
    if name == '01-family-chat':
        y += int(spec['sub'] * 0.3)
        y += callout_hero(canvas, spec['callout'] * 0.85, W, y)
    y += 40 * k

    shot = Image.open(raw_path).convert('RGB')
    fw = spec['screen_w'] + 2 * spec['bezel']
    dev = device(canvas, shot, int((W - fw) / 2), int(y), spec)
    if name in CALLOUTS:
        CALLOUTS[name](canvas, spec['callout'], W, dev)

    out_dir = os.path.join(BASE, device_name)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'{name}.png')
    canvas.convert('RGB').save(out, optimize=True)
    return out


def main():
    made = 0
    for device_name in DEVICES:
        raw_dir = os.path.join(BASE, 'raw', device_name)
        if not os.path.isdir(raw_dir):
            continue
        for file in sorted(os.listdir(raw_dir)):
            name = os.path.splitext(file)[0]
            if name in COPY:
                print(compose(device_name, name, os.path.join(raw_dir, file)))
                made += 1
    print(f'{made} screenshots written to {BASE}')


if __name__ == '__main__':
    main()
