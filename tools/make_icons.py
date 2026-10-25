"""Renders the CamTrip "D" logo (CT on a four-color band) into every icon
the Android app and the web build need. Usage: python make_icons.py <repo>"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

REPO = sys.argv[1]
FONT = 'C:/Windows/Fonts/georgiab.ttf'
BANDS = ['#D6DDF0', '#EBDCE8', '#1E2547', '#3B2F5C']  # default palette (신주쿠 밤거리)
NAVY = '#16213A'
IVORY = '#F4F1EA'
SS = 4  # supersampling


def bands(draw, w, h, x0=0, y0=0):
    for i, c in enumerate(BANDS):
        draw.rectangle([x0 + w * i / 4, y0, x0 + w * (i + 1) / 4, y0 + h], fill=c)


def ct(draw, size, cx, cy, font_px, gap, colors):
    font = ImageFont.truetype(FONT, font_px)
    c_box = draw.textbbox((0, 0), 'C', font=font)
    t_box = draw.textbbox((0, 0), 'T', font=font)
    cw, tw = c_box[2] - c_box[0], t_box[2] - t_box[0]
    top = min(c_box[1], t_box[1])
    hgt = max(c_box[3], t_box[3]) - top
    total = cw + gap + tw
    x = cx - total / 2
    y = cy - hgt / 2 - top
    draw.text((x - c_box[0], y), 'C', font=font, fill=colors[0])
    draw.text((x + cw + gap - t_box[0], y), 'T', font=font, fill=colors[1])


def render(px, fn):
    big = Image.new('RGBA', (px * SS, px * SS), (0, 0, 0, 0))
    fn(ImageDraw.Draw(big), px * SS)
    return big.resize((px, px), Image.LANCZOS)


def full_icon(d, s, radius=0.0, font=0.32, gap=0.06):
    """Legacy/full icon: bands + CT, optional rounded corners."""
    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * radius), fill=255)
    layer = Image.new('RGBA', (s, s))
    ld = ImageDraw.Draw(layer)
    bands(ld, s, s)
    # C sits on the light half, T on the dark half.
    ct(ld, s, s / 2, s / 2, int(s * font), int(s * gap), (NAVY, IVORY))
    d._image.paste(layer, (0, 0), mask)


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


res = os.path.join(REPO, 'android', 'app', 'src', 'main', 'res')
dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

for name, k in dens.items():
    # Legacy launcher (48dp), rounded square.
    save(render(int(48 * k), lambda d, s: full_icon(d, s, radius=0.22)), f'{res}/mipmap-{name}/ic_launcher.png')
    # Adaptive layers (108dp canvas, 66dp safe zone in the middle).
    save(render(int(108 * k), lambda d, s: bands(d, s, s)), f'{res}/mipmap-{name}/ic_launcher_background.png')

    def fg(d, s):
        # The C stays on the 2nd band and the T on the 3rd, both inside the
        # 66dp safe circle, so the letters survive any mask shape.
        ct(d, s, s / 2, s / 2, int(s * 0.30), int(s * 0.06), (NAVY, IVORY))
    save(render(int(108 * k), fg), f'{res}/mipmap-{name}/ic_launcher_foreground.png')

    def mono(d, s):
        # Themed icon (Android 13+): one color, CT with a short bar under it
        # so the band is still remembered.
        font = int(s * 0.26)
        ct(d, s, s / 2, s * 0.47, font, int(s * 0.05), ('#000000', '#000000'))
        bw, bh = s * 0.27, s * 0.028
        d.rectangle([s / 2 - bw / 2, s * 0.62, s / 2 + bw / 2, s * 0.62 + bh], fill='#000000')
    save(render(int(108 * k), mono), f'{res}/mipmap-{name}/ic_launcher_monochrome.png')

    def stat(d, s):
        # Notification icon (24dp): white silhouette only.
        ct(d, s, s / 2, s * 0.42, int(s * 0.56), int(s * 0.05), ('#FFFFFF', '#FFFFFF'))
        bw, bh = s * 0.62, s * 0.09
        d.rectangle([s / 2 - bw / 2, s * 0.80, s / 2 + bw / 2, s * 0.80 + bh], fill='#FFFFFF')
    save(render(int(24 * k), stat), f'{res}/drawable-{name}/ic_stat_camtrip.png')

    def splash(d, s):
        # Android 12+ splash icon: system crops a circle out of the middle.
        r = s * 0.333
        cx = cy = s / 2
        layer = Image.new('RGBA', (s, s))
        ld = ImageDraw.Draw(layer)
        bands(ld, 2 * r, 2 * r, cx - r, cy - r)
        ct(ld, s, cx, cy, int(s * 0.20), int(s * 0.035), (NAVY, IVORY))
        m = Image.new('L', (s, s), 0)
        ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
        d._image.paste(layer, (0, 0), m)
    save(render(int(288 * k), splash), f'{res}/drawable-{name}/splash_icon.png')

# Store icon and web icons.
save(render(512, lambda d, s: full_icon(d, s)), os.path.join(REPO, 'docs', 'store', 'icon-512.png'))
web = os.path.join(REPO, 'web')
save(render(192, lambda d, s: full_icon(d, s, radius=0.22)), f'{web}/icons/Icon-192.png')
save(render(512, lambda d, s: full_icon(d, s, radius=0.22)), f'{web}/icons/Icon-512.png')
save(render(192, lambda d, s: full_icon(d, s, font=0.26, gap=0.05)), f'{web}/icons/Icon-maskable-192.png')
save(render(512, lambda d, s: full_icon(d, s, font=0.26, gap=0.05)), f'{web}/icons/Icon-maskable-512.png')
save(render(64, lambda d, s: full_icon(d, s, radius=0.22)), f'{web}/favicon.png')
print('done')
