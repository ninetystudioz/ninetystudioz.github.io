# Ninety Android - the launcher icon (the NINETY mark on #171b1f), written straight into the generated Android project
# after capacitor-assets. capacitor-assets made the legacy icons from icon-only.png but left Capacitor's default adaptive
# foreground (the blue X), and Android 8+ shows the adaptive one - so the app got the Capacitor logo (v7.36b).
# Writes: legacy square + round icons, the adaptive icon (foreground + background colour) and a monochrome layer
# for Android 13 themed icons. No binary files live in the repo.
from PIL import Image, ImageDraw
import glob
import os

RES = 'android/app/src/main/res'
BG = (23, 27, 31, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
DPI = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def mark(d, cx, cy, w, fg, cut):
    """The NINETY mark: a 300x192 block with the corner cut, centred on (cx, cy), w pixels wide."""
    k = w / 300.0
    ox, oy = cx - 150 * k, cy - 96 * k
    d.rectangle([ox, oy, ox + 300 * k, oy + 192 * k], fill=fg)
    d.polygon([(ox + 151 * k, oy + 53 * k), (ox + 151 * k, oy + 192 * k), (ox + 300 * k, oy + 192 * k)], fill=cut)


def render(size, shape, mark_w, fg, bg, cut):
    s = 4
    big = size * s
    im = Image.new('RGBA', (big, big), CLEAR)
    d = ImageDraw.Draw(im)
    if shape == 'square':
        d.rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.2), fill=bg)
    elif shape == 'round':
        d.ellipse([0, 0, big - 1, big - 1], fill=bg)
    mark(d, big / 2, big / 2, big * mark_w, fg, cut)
    return im.resize((size, size), Image.LANCZOS)


def write(path, im):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


ADAPTIVE = '''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'''

if not os.path.isdir(RES):
    raise SystemExit('android-icons: no Android project at ' + RES)

for q, f in DPI.items():
    d = os.path.join(RES, 'mipmap-' + q)
    legacy = int(round(48 * f))
    adaptive = int(round(108 * f))
    write(os.path.join(d, 'ic_launcher.png'), render(legacy, 'square', 0.56, WHITE, BG, BG))
    write(os.path.join(d, 'ic_launcher_round.png'), render(legacy, 'round', 0.52, WHITE, BG, BG))
    # adaptive layers: the mark stays inside the 66dp safe zone of the 108dp canvas (any mask shape keeps it whole)
    write(os.path.join(d, 'ic_launcher_foreground.png'), render(adaptive, 'none', 0.44, WHITE, CLEAR, CLEAR))
    write(os.path.join(d, 'ic_launcher_monochrome.png'), render(adaptive, 'none', 0.44, WHITE, CLEAR, CLEAR))
    for old in ('ic_launcher_background.png',):
        p = os.path.join(d, old)
        if os.path.exists(p):
            os.remove(p)

anydpi = set(glob.glob(os.path.join(RES, 'mipmap-anydpi*')))
anydpi.add(os.path.join(RES, 'mipmap-anydpi-v26'))
for d in sorted(anydpi):
    os.makedirs(d, exist_ok=True)
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with open(os.path.join(d, name), 'w') as fh:
            fh.write(ADAPTIVE)

os.makedirs(os.path.join(RES, 'values'), exist_ok=True)
with open(os.path.join(RES, 'values', 'ic_launcher_background.xml'), 'w') as fh:
    fh.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#171B1F</color>\n</resources>\n')

print('android icons ok:', ', '.join(sorted(os.path.basename(x) for x in anydpi)))
