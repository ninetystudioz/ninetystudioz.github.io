# Ninety iOS — draws the app icon and splash (the NINETY mark on #171b1f) so no binary files live in the repo.
from PIL import Image, ImageDraw
import os
os.makedirs('assets', exist_ok=True)
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
