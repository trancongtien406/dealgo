#!/usr/bin/env python3
"""Regenerate the launch-screen mark from the in-app logo.

Source: assets/images/dealgo_app_icon.png (the DealGoLogo tile on a white card).
Cuts the dark rounded tile out (transparent outside), centres it on the 288-unit
launch canvas at 150 units so its corners stay inside the 192-unit circle that
Android 12+ shows, and writes every iOS / Android / Flutter copy.

Needs Pillow, numpy and scipy. Run from mobile/: python3 tool/gen_launch_mark.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

SRC = 'assets/images/dealgo_app_icon.png'
TILE = 150 / 288
RES = 'android/app/src/main/res'
LAUNCH = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
OUT = {
    f'{LAUNCH}/LaunchImage.png': 288,
    f'{LAUNCH}/LaunchImage@2x.png': 576,
    f'{LAUNCH}/LaunchImage@3x.png': 864,
    f'{RES}/drawable-mdpi/launch_mark.png': 288,
    f'{RES}/drawable-hdpi/launch_mark.png': 432,
    f'{RES}/drawable-xhdpi/launch_mark.png': 576,
    f'{RES}/drawable-xxhdpi/launch_mark.png': 864,
    f'{RES}/drawable-xxxhdpi/launch_mark.png': 1152,
    'assets/images/launch_mark.png': 864,
}

im = Image.open(SRC).convert('RGB')
lum = np.asarray(im, dtype=float).mean(axis=2)
# White card + shadow = bright area connected to the image corners.
lab, _ = ndimage.label(lum > 150)
card = np.isin(lab, [lab[0, 0], lab[0, -1], lab[-1, 0], lab[-1, -1]])
tile = ndimage.binary_fill_holes(~card)
tile = ndimage.binary_erosion(tile, iterations=2)  # drop the light anti-aliased rim
ys, xs = np.where(tile)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
alpha = Image.fromarray((tile * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
rgba = im.copy()
rgba.putalpha(alpha)
side = max(x1 - x0, y1 - y0) + 1
left = int(round((x0 + x1) / 2 - side / 2))
top = int(round((y0 + y1) / 2 - side / 2))
crop = rgba.crop((left, top, left + side, top + side))

for path, px in OUT.items():
    s = round(px * TILE)
    canvas = Image.new('RGBA', (px, px), (0, 0, 0, 0))
    canvas.alpha_composite(crop.resize((s, s), Image.LANCZOS), ((px - s) // 2, (px - s) // 2))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    canvas.save(path, optimize=True)
    print(px, path)
