"""MacroRunner logo: an "M" drawn as a heartbeat line, cyan with a lime
spark at its end, on a deep navy background. Writes every Android launcher
and notification size, plus a large copy for the report."""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

RES = sys.argv[1]          # android/app/src/main/res
# Run: python tool/brand/make_logo.py android/app/src/main/res docs
DOCS = sys.argv[2]         # where the 1024 px preview goes
S = 1024                   # working canvas = 108 dp adaptive icon
CYAN = (0, 245, 255)       # the app's cyberpunk palette
PINK = (255, 43, 214)
LIME = (183, 255, 0)

# The heartbeat "M", inside the 66 dp safe zone of the adaptive icon.
LINE = [(232, 590), (352, 590), (432, 352), (512, 640), (592, 352),
        (672, 590), (742, 590)]
SPARK = (800, 590)
WIDTH = 64


def background(size):
    """Navy, a little lighter in the middle."""
    img = Image.new('RGB', (size, size), (7, 10, 22))
    glow = Image.new('L', (size, size), 0)
    ImageDraw.Draw(glow).ellipse(
        [size * 0.12, size * 0.1, size * 0.88, size * 0.86], fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.18))
    img.paste(Image.new('RGB', (size, size), (22, 32, 72)), mask=glow)
    return img


def gradient(alpha=255):
    """Cyan on the left fading into pink on the right."""
    img = Image.new('RGBA', (S, S))
    x0, x1 = LINE[0][0], LINE[-1][0]
    for x in range(S):
        t = min(1, max(0, (x - x0) / (x1 - x0)))
        c = tuple(round(a + (b - a) * t) for a, b in zip(CYAN, PINK))
        ImageDraw.Draw(img).line([(x, 0), (x, S)], fill=c + (alpha,))
    return img


def line_mask(width):
    mask = Image.new('L', (S, S), 0)
    d = ImageDraw.Draw(mask)
    d.line(LINE, fill=255, width=width, joint='curve')
    for x, y in (LINE[0], LINE[-1]):
        r = width / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return mask


def spark(img, fill):
    r = WIDTH * 0.78
    ImageDraw.Draw(img).ellipse(
        [SPARK[0] - r, SPARK[1] - r, SPARK[0] + r, SPARK[1] + r], fill=fill)


def glyph(color=None, glow=True):
    """The line and spark on a transparent canvas; [color] draws it in one
    colour (notification and themed icons)."""
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    if color is not None:
        img.paste(Image.new('RGBA', (S, S), color + (255,)),
                  mask=line_mask(WIDTH))
        spark(img, color)
        return img
    if glow:
        halo = Image.new('RGBA', (S, S), (0, 0, 0, 0))
        halo.paste(gradient(160), mask=line_mask(WIDTH * 2))
        spark(halo, LIME + (170,))
        img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(34)))
    stroke = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    stroke.paste(gradient(), mask=line_mask(WIDTH))
    img = Image.alpha_composite(img, stroke)
    spark(img, LIME)
    return img


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path, optimize=True)


def rounded(img, radius_ratio=0.22):
    mask = Image.new('L', img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * radius_ratio), fill=255)
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(img, mask=mask)
    return out


full = background(S).convert('RGBA')
full = Image.alpha_composite(full, glyph())
# Legacy icons (before Android 8) show the whole square, so the glyph is
# scaled up a little from the adaptive safe zone.
legacy = full.crop((96, 96, S - 96, S - 96)).resize((S, S), Image.LANCZOS)
legacy = rounded(legacy)

densities = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
for name, k in densities.items():
    folder = os.path.join(RES, f'mipmap-{name}')
    save(legacy, os.path.join(folder, 'ic_launcher.png'), int(48 * k))
    save(background(S), os.path.join(folder, 'ic_launcher_background.png'),
         int(108 * k))
    save(glyph(), os.path.join(folder, 'ic_launcher_foreground.png'),
         int(108 * k))
    save(glyph(color=(255, 255, 255), glow=False),
         os.path.join(folder, 'ic_launcher_monochrome.png'), int(108 * k))
    # Notification icon: white on transparent, 24 dp, glyph filling it.
    note = glyph(color=(255, 255, 255), glow=False).crop((180, 180, S - 180,
                                                          S - 180))
    save(note, os.path.join(RES, f'drawable-{name}', 'ic_stat_notify.png'),
         int(24 * k))

os.makedirs(DOCS, exist_ok=True)
rounded(full).save(os.path.join(DOCS, 'logo_macrorunner.png'), optimize=True)
print('ok')
