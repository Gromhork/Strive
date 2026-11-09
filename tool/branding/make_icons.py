"""Generate the Strive launcher icons (Android + iOS) from the in-app logo.

The logo (StriveLogo in lib/main.dart) is a rounded square (radius = 30 % of size)
with a top-left -> bottom-right LinearGradient gym -> brand -> swim and a white
Icons.bolt_rounded at 66 % of the size.

Usage (from the repo root):
    pip install pillow numpy fonttools
    python tool/branding/make_icons.py [path/to/materialicons-regular.otf]
    python tool/branding/make_icons.py --notification-only [font]   # only ic_notification.xml

Outputs:
    assets/branding/strive_icon_1024.png             master (rounded square, transparent corners)
    assets/branding/strive_icon_foreground_1024.png  adaptive foreground (bolt on 108 dp canvas)
    android/app/src/main/res/mipmap-*/ic_launcher.png, ic_launcher_round.png   legacy icons
    android/app/src/main/res/mipmap-anydpi-v26/ic_launcher(_round).xml          adaptive icons
    android/app/src/main/res/drawable/ic_launcher_background.xml, _foreground.xml
    android/app/src/main/res/drawable/ic_notification.xml   status-bar icon (white bolt, 24 dp)
    ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png  (sizes taken from Contents.json)
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DEFAULT_FONT = r'D:\Programmieren\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf'
ARGS = [a for a in sys.argv[1:] if not a.startswith('--')]
FONT = ARGS[0] if ARGS else os.environ.get('MATERIAL_ICONS_FONT', DEFAULT_FONT)

# lib/core/theme.dart
GYM = (0xFF, 0x6B, 0x3D)
BRAND = (0x8B, 0x7C, 0xFF)
SWIM = (0x3D, 0xB2, 0xFF)
BOLT_ROUNDED = 0xF5CA  # Icons.bolt_rounded (flutter/lib/src/material/icons.dart)

ICON_SCALE = 0.66   # bolt font size relative to tile (as in StriveLogo)
RADIUS = 0.30       # corner radius relative to tile
HI = 2048           # supersampling resolution

# Adaptive icon (108 dp canvas, 72 dp visible, 66 dp safe zone).
# Foreground glyph em size in dp: bolt height = 0.75 em -> 0.75 * 53.3 = 40 dp,
# bolt bbox half-diagonal ~22 dp, well inside the 33 dp safe-zone radius.
ADAPTIVE_EM_DP = 53.3

# Status-bar (small notification) icon: 24 dp canvas, 22 dp live area (1 dp padding).
# The bolt ink box is 0.75 em tall (64..448 of 512) and taller than wide, so its
# height defines the size: em = 22 / 0.75 dp.
NOTIF_DP = 24
NOTIF_LIVE_DP = 22
NOTIF_EM_DP = NOTIF_LIVE_DP / 0.75


def gradient(size):
    """LinearGradient(topLeft -> bottomRight) with 3 evenly spaced stops."""
    ax = np.arange(size, dtype=np.float64) + 0.5
    t = (ax[None, :] + ax[:, None]) / (2.0 * size)  # 0 at top-left, 1 at bottom-right
    stops = np.array([GYM, BRAND, SWIM], dtype=np.float64)
    out = np.empty((size, size, 3))
    for c in range(3):
        out[..., c] = np.interp(t, [0.0, 0.5, 1.0], stops[:, c])
    return Image.fromarray(np.round(out).astype(np.uint8), 'RGB')


def bolt_mask(canvas, em_px):
    """Alpha mask (L) of the bolt glyph, ink-box-centred on a canvas x canvas square.

    The glyph's ink box (x 149..363, y 64..448 in a 512 em) is centred on the em box,
    so centring the ink box matches Flutter's Icon placement and is optically centred.
    """
    font = ImageFont.truetype(FONT, size=int(round(em_px)))
    ch = chr(BOLT_ROUNDED)
    tmp = Image.new('L', (int(em_px * 2), int(em_px * 2)), 0)
    ImageDraw.Draw(tmp).text((em_px * 0.5, em_px * 0.5), ch, font=font, fill=255)
    box = tmp.getbbox()
    if box is None:
        raise RuntimeError('bolt glyph not found in font %s' % FONT)
    glyph = tmp.crop(box)
    mask = Image.new('L', (canvas, canvas), 0)
    mask.paste(glyph, ((canvas - glyph.width) // 2, (canvas - glyph.height) // 2))
    return mask


def logo(shape='rounded', inset=0.0):
    """Hi-res RGBA logo. shape: 'rounded' | 'circle' | 'square'. inset: transparent margin fraction."""
    pad = int(round(HI * inset))
    tile = HI - 2 * pad
    img = Image.new('RGBA', (HI, HI), (0, 0, 0, 0))
    body = gradient(tile).convert('RGBA')
    white = Image.new('RGBA', (tile, tile), (255, 255, 255, 255))
    body.paste(white, (0, 0), bolt_mask(tile, tile * ICON_SCALE))
    shape_mask = Image.new('L', (tile, tile), 0)
    d = ImageDraw.Draw(shape_mask)
    if shape == 'rounded':
        d.rounded_rectangle((0, 0, tile - 1, tile - 1), radius=tile * RADIUS, fill=255)
    elif shape == 'circle':
        d.ellipse((0, 0, tile - 1, tile - 1), fill=255)
    else:
        shape_mask.paste(255, (0, 0, tile, tile))
    img.paste(body, (pad, pad), shape_mask)
    return img


def save(img, path, size, rgb=False):
    out = img.resize((size, size), Image.LANCZOS)
    if rgb:
        out = out.convert('RGB')
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path, optimize=True)
    print('wrote', os.path.relpath(path, ROOT), size)


def bolt_path_data(em_dp=ADAPTIVE_EM_DP, viewport=108):
    """SVG path data for the bolt, centred in a viewport x viewport box (for vector drawables)."""
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont

    f = TTFont(FONT)
    upem = f['head'].unitsPerEm
    gs = f.getGlyphSet()
    name = f.getBestCmap()[BOLT_ROUNDED]
    s = em_dp / upem
    off = (viewport - em_dp) / 2  # em box centred; glyph ink is centred in the em box
    pen = SVGPathPen(gs, ntos=lambda v: ('%.2f' % v).rstrip('0').rstrip('.'))
    # font coordinates are y-up: flip y
    gs[name].draw(TransformPen(pen, (s, 0, 0, -s, off, off + em_dp)))
    return pen.getCommands()


def hexc(c):
    return '#FF%02X%02X%02X' % c


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)
    print('wrote', os.path.relpath(path, ROOT))


def android_vectors(res):
    # Gradient spans the visible 72 dp area (18..90) like the logo tile; clamps outside.
    write(os.path.join(res, 'drawable', 'ic_launcher_background.xml'), f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/branding/make_icons.py - do not edit by hand. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:aapt="http://schemas.android.com/aapt"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:pathData="M0,0h108v108h-108z">
        <aapt:attr name="android:fillColor">
            <gradient
                android:type="linear"
                android:startX="18"
                android:startY="18"
                android:endX="90"
                android:endY="90"
                android:tileMode="clamp">
                <item android:offset="0" android:color="{hexc(GYM)}" />
                <item android:offset="0.5" android:color="{hexc(BRAND)}" />
                <item android:offset="1" android:color="{hexc(SWIM)}" />
            </gradient>
        </aapt:attr>
    </path>
</vector>
''')
    write(os.path.join(res, 'drawable', 'ic_launcher_foreground.xml'), f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/branding/make_icons.py - do not edit by hand.
     Icons.bolt_rounded, centred, ~40 dp tall: inside the 66 dp safe zone.
     Also used as the monochrome (themed icon) layer. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="{bolt_path_data()}" />
</vector>
''')
    adaptive = '''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/branding/make_icons.py - do not edit by hand. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'''
    for n in ('ic_launcher', 'ic_launcher_round'):
        write(os.path.join(res, 'mipmap-anydpi-v26', n + '.xml'), adaptive)


def notification_icon(res):
    """Monochrome status-bar icon used by every notification (local reminders and
    the GPS foreground service). Android only uses the alpha channel and tints it."""
    write(os.path.join(res, 'drawable', 'ic_notification.xml'), f'''<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/branding/make_icons.py - do not edit by hand.
     Small notification icon: Strive bolt, white on transparent, {NOTIF_LIVE_DP} dp tall
     on the {NOTIF_DP} dp canvas (1 dp padding as per the Android status-bar guideline). -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="{NOTIF_DP}dp"
    android:height="{NOTIF_DP}dp"
    android:viewportWidth="{NOTIF_DP}"
    android:viewportHeight="{NOTIF_DP}">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="{bolt_path_data(NOTIF_EM_DP, NOTIF_DP)}" />
</vector>
''')


def foreground_png():
    """Adaptive foreground as PNG (bolt on transparent 108 dp canvas), for reuse."""
    img = Image.new('RGBA', (HI, HI), (255, 255, 255, 0))
    white = Image.new('RGBA', (HI, HI), (255, 255, 255, 255))
    img.paste(white, (0, 0), bolt_mask(HI, HI * ADAPTIVE_EM_DP / 108))
    return img


def main():
    if not os.path.isfile(FONT):
        sys.exit('Material Icons font not found: %s' % FONT)

    rounded = logo('rounded')
    save(rounded, os.path.join(ROOT, 'assets', 'branding', 'strive_icon_1024.png'), 1024)
    save(foreground_png(), os.path.join(ROOT, 'assets', 'branding', 'strive_icon_foreground_1024.png'), 1024)

    # Android legacy icons (pre-adaptive launchers): 44/48 keyline -> 2 dp transparent margin.
    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    legacy_r = logo('rounded', inset=2 / 48)
    legacy_c = logo('circle', inset=2 / 48)
    for dpi, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        save(legacy_r, os.path.join(res, 'mipmap-' + dpi, 'ic_launcher.png'), px)
        save(legacy_c, os.path.join(res, 'mipmap-' + dpi, 'ic_launcher_round.png'), px)
    android_vectors(res)
    notification_icon(res)

    # iOS: full-bleed square, opaque (iOS applies its own mask).
    square = logo('square')
    iconset = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    with open(os.path.join(iconset, 'Contents.json'), encoding='utf-8') as fh:
        contents = json.load(fh)
    done = set()
    for im in contents['images']:
        fn = im.get('filename')
        if not fn or fn in done:
            continue
        done.add(fn)
        px = int(round(float(im['size'].split('x')[0]) * int(im['scale'].rstrip('x'))))
        save(square, os.path.join(iconset, fn), px, rgb=True)


if __name__ == '__main__':
    if '--notification-only' in sys.argv:
        notification_icon(os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res'))
    else:
        main()
