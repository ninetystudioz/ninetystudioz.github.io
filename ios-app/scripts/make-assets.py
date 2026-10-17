# Ninety iOS — draws the app icon and splash (the NINETY mark on #171b1f) so no binary files live in the repo.
from PIL import Image, ImageDraw
import os
os.makedirs('assets', exist_ok=True)
# v7.94 four Android apps: NF_ICON_BG gives each app its own background (iOS leaves it unset -> #171b1f)
_h = (os.environ.get('NF_ICON_BG') or '#171b1f').strip().lstrip('#')
try:
    BG = (int(_h[0:2], 16), int(_h[2:4], 16), int(_h[4:6], 16)) if len(_h) == 6 else (23, 27, 31)
except ValueError:
    BG = (23, 27, 31)
def mark(size, scale):
    S = 4; W = size * S; im = Image.new('RGB', (W, W), BG); d = ImageDraw.Draw(im)
    k = scale * S; ox = (W - 300 * k) / 2; oy = (W - 192 * k) / 2
    d.rectangle([ox, oy, ox + 300 * k, oy + 192 * k], fill='white')
    d.polygon([(ox + 151 * k, oy + 53 * k), (ox + 151 * k, oy + 192 * k), (ox + 300 * k, oy + 192 * k)], fill=BG)
    return im.resize((size, size), Image.LANCZOS)
mark(1024, 2.0).save('assets/icon-only.png')
mark(2732, 2.4).save('assets/splash.png')
mark(2732, 2.4).save('assets/splash-dark.png')
print('assets ok')
