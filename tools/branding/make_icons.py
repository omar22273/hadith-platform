"""Builds the «هَدْي» launcher icon set from the approved master artwork.

Source: tools/branding/hady_icon_master.jpg (1024x1024, the official final icon).
Outputs, all under android/app/src/main/res:

  * mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png        48/72/96/144/192 px
        legacy square icon (API 24-25): the full artwork on a rounded transparent tile
  * mipmap-{...}/ic_launcher_round.png                             same sizes
        legacy round icon: the adaptive composition cut to a circle
  * drawable-{...}/ic_launcher_foreground.png                      108dp at each density
        the golden arch + lantern extracted from the artwork on a transparent layer,
        scaled so every visible pixel stays inside the 66dp adaptive-icon safe zone
  * drawable-{...}/ic_launcher_monochrome.png                      Android 13+ themed layer
        the line work only (arch, lantern frame), glow dropped, opaque shapes for tinting
  * values/ic_launcher_background.xml                              royal navy #0A1128
  * mipmap-anydpi-v26/ic_launcher.xml and ic_launcher_round.xml    adaptive icon definitions

Run: python3 tools/branding/make_icons.py   (needs Pillow, numpy, scipy)
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage, optimize

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
MASTER = os.path.join(ROOT, 'tools', 'branding', 'hady_icon_master.jpg')

BACKGROUND = (10, 17, 40)  # #0A1128
BACKGROUND_HEX = '#0A1128'
# Navy of the artwork interior, used to un-premultiply the edge pixels of the gold line work.
ARTWORK_NAVY = np.array([12.0, 24.0, 50.0])

# Region of the master that holds the arch and the lantern, excluding the outer frame lines
# and their rounded corners.
SYMBOL_BOX = (285, 222, 740, 780)  # left, top, right, bottom

DENSITIES = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0}
LEGACY_DP = 48
ADAPTIVE_DP = 108
SAFE_RADIUS_DP = 33.0  # the adaptive-icon safe zone is a 66dp circle


def load_master() -> Image.Image:
    image = Image.open(MASTER).convert('RGB')
    if image.size != (1024, 1024):
        raise SystemExit('the master artwork must be 1024x1024, got %s' % (image.size,))
    return image


def extract_symbol(master: Image.Image):
    """Returns (colour, alpha, blue) of the gold/amber line work, navy pulled out as alpha.

    The navy is not flat (it brightens toward the glow), so coverage is read from how far the
    red channel rises above the blue one: navy sits near -40, gold lines near +100, amber
    glow above +200.
    """
    crop = np.asarray(master.crop(SYMBOL_BOX)).astype(np.float64)
    red_over_blue = crop[..., 0] - crop[..., 2]
    alpha = np.clip((red_over_blue + 28.0) / 112.0, 0.0, 1.0)
    coverage = np.clip((red_over_blue + 40.0) / 140.0, 0.05, 1.0)[..., None]
    color = np.clip(ARTWORK_NAVY + (crop - ARTWORK_NAVY) / coverage, 0, 255)
    return color, alpha, crop[..., 2]


def enclosing_center(alpha: np.ndarray):
    """Centre (x, y) of the smallest circle holding every clearly visible symbol pixel."""
    ys, xs = np.nonzero(alpha > 0.5)
    points = np.stack([xs, ys], axis=1).astype(np.float64)
    start = points.mean(axis=0)
    result = optimize.minimize(
        lambda c: np.sqrt(((points - c) ** 2).sum(axis=1)).max(),
        start,
        method='Nelder-Mead',
        options={'xatol': 0.05, 'fatol': 0.05, 'maxiter': 2000},
    )
    center = result.x
    radius = float(np.sqrt(((points - center) ** 2).sum(axis=1)).max())
    return center, radius


def line_mask(alpha: np.ndarray, blue: np.ndarray) -> np.ndarray:
    """Thin line work as a 0..1 mask. The amber glow is saturated (blue channel near zero)
    while the pale gold lines keep blue, so the blue channel's local contrast isolates the
    lines even where they cross the glow."""
    contrast = blue - ndimage.gaussian_filter(blue, sigma=6.0)
    lines = np.clip(contrast / 55.0, 0.0, 1.0) * np.clip(alpha * 2.0, 0.0, 1.0)
    lines = np.where(lines < 0.18, 0.0, lines)  # drop the faint haze around the glow
    lines = ndimage.grey_dilation(lines, size=(5, 5))
    return np.clip(ndimage.gaussian_filter(lines, sigma=0.8) * 1.5, 0.0, 1.0)


def place_layer(color, alpha, blue, center, radius, canvas_px: int, mono: bool) -> Image.Image:
    """Scales the symbol so its enclosing circle has the safe radius, centred on the canvas."""
    scale = (SAFE_RADIUS_DP / ADAPTIVE_DP) * canvas_px / radius
    height, width = alpha.shape
    mask = line_mask(alpha, blue) if mono else alpha
    rgb = np.zeros_like(color) if mono else color
    premult = np.dstack([rgb * mask[..., None], mask * 255.0]).astype(np.float32)
    new_size = (max(1, round(width * scale)), max(1, round(height * scale)))
    channels = [np.asarray(Image.fromarray(premult[..., i], 'F').resize(new_size, Image.LANCZOS)) for i in range(4)]
    resized = np.dstack(channels).astype(np.float64)
    a = np.clip(resized[..., 3:4], 0.0, 255.0)
    out_rgb = np.where(a > 0.5, resized[..., :3] * 255.0 / np.maximum(a, 1e-6), 0.0)
    symbol = Image.fromarray(np.dstack([np.clip(out_rgb, 0, 255), a]).astype(np.uint8), 'RGBA')
    left = round(canvas_px / 2.0 - center[0] * scale)
    top = round(canvas_px / 2.0 - center[1] * scale)
    if left < 0 or top < 0 or left + new_size[0] > canvas_px or top + new_size[1] > canvas_px:
        raise SystemExit('symbol does not fit the %dpx canvas (offset %d,%d)' % (canvas_px, left, top))
    canvas = Image.new('RGBA', (canvas_px, canvas_px), (0, 0, 0, 0))
    canvas.alpha_composite(symbol, (left, top))
    return canvas


def legacy_square(master: Image.Image, size: int) -> Image.Image:
    """The full artwork (frame included) on a rounded tile with transparent corners."""
    side = 730
    cx, cy = 512, 510
    crop = master.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)).convert('RGBA')
    big = 4
    mask = Image.new('L', (side * big, side * big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, side * big - 1, side * big - 1), radius=int(side * big * 0.2), fill=255)
    crop.putalpha(mask.resize((side, side), Image.LANCZOS))
    return crop.resize((size, size), Image.LANCZOS)


def adaptive_composite(foreground: Image.Image) -> Image.Image:
    base = Image.new('RGBA', foreground.size, BACKGROUND + (255,))
    base.alpha_composite(foreground)
    return base


def legacy_round(foreground_108: Image.Image, size: int) -> Image.Image:
    """The adaptive composition cut to the visible 72dp circle."""
    composite = adaptive_composite(foreground_108)
    visible = round(composite.size[0] * 72 / ADAPTIVE_DP)
    start = (composite.size[0] - visible) // 2
    cropped = composite.crop((start, start, start + visible, start + visible))
    big = size * 4
    cropped = cropped.resize((big, big), Image.LANCZOS)
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, big - 1, big - 1), fill=255)
    cropped.putalpha(mask)
    return cropped.resize((size, size), Image.LANCZOS)


def write_text(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(content)


def main() -> int:
    master = load_master()
    color, alpha, blue = extract_symbol(master)
    center, radius = enclosing_center(alpha)
    print('symbol enclosing circle: centre (%.1f, %.1f) radius %.1f px of the master' % (center[0] + SYMBOL_BOX[0], center[1] + SYMBOL_BOX[1], radius))

    for density, factor in DENSITIES.items():
        adaptive_px = round(ADAPTIVE_DP * factor)
        legacy_px = round(LEGACY_DP * factor)
        foreground = place_layer(color, alpha, blue, center, radius, adaptive_px, mono=False)
        monochrome = place_layer(color, alpha, blue, center, radius, adaptive_px, mono=True)
        os.makedirs(os.path.join(RES, 'drawable-' + density), exist_ok=True)
        os.makedirs(os.path.join(RES, 'mipmap-' + density), exist_ok=True)
        foreground.save(os.path.join(RES, 'drawable-' + density, 'ic_launcher_foreground.png'), optimize=True)
        monochrome.save(os.path.join(RES, 'drawable-' + density, 'ic_launcher_monochrome.png'), optimize=True)
        legacy_square(master, legacy_px).save(os.path.join(RES, 'mipmap-' + density, 'ic_launcher.png'), optimize=True)
        legacy_round(foreground, legacy_px).save(os.path.join(RES, 'mipmap-' + density, 'ic_launcher_round.png'), optimize=True)

    write_text(
        os.path.join(RES, 'values', 'ic_launcher_background.xml'),
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">%s</color>\n</resources>\n' % BACKGROUND_HEX,
    )
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
        '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
        '</adaptive-icon>\n'
    )
    write_text(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml'), adaptive)
    write_text(os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher_round.xml'), adaptive)
    return 0


if __name__ == '__main__':
    sys.exit(main())
