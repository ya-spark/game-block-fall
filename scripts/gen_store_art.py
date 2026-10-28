#!/usr/bin/env python3
"""Draws the Blockfall icon, feature graphic and launcher icons with Pillow (original art)."""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
COLORS = {"I": (0, 220, 235), "O": (255, 200, 40), "T": (150, 90, 235), "S": (60, 210, 110),
          "Z": (240, 70, 80), "J": (60, 120, 240), "L": (255, 140, 40)}


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (y / h * 0.7 + x / w * 0.3)
            px[x, y] = (int(8 + 6 * t), int(34 + 40 * (1 - t)), int(52 + 40 * (1 - t)))
    return img


def gem(d, x, y, s, c, prism=False):
    r = max(2, s // 6)
    dark = tuple(int(v * 0.55) for v in c)
    light = tuple(min(255, int(v * 1.25) + 20) for v in c)
    d.rounded_rectangle([x, y, x + s - 1, y + s - 1], r, fill=dark)
    p = max(2, s // 10)
    d.rounded_rectangle([x + p, y + p, x + s - 1 - p, y + s - 1 - p], r, fill=c)
    d.rounded_rectangle([x + p * 2, y + p * 2, x + s - 1 - p * 3, y + s // 2 - 1], r, fill=light)
    if prism:
        cx, cy, k = x + s // 2, y + s // 2, s // 3
        d.polygon([(cx, cy - k), (cx + k, cy), (cx, cy + k), (cx - k, cy)], fill=(235, 255, 255))


def scene(w, h, cell, ox, oy):
    img = gradient(w, h).convert("RGBA")
    layout = [  # (col,row,piece,prism) well of 6 cols
        (0, 6, "Z"), (1, 6, "Z"), (1, 5, "Z"), (2, 5, "Z"),
        (0, 5, "J"), (0, 4, "J"), (0, 3, "J"), (1, 3, "J"),
        (2, 6, "I"), (3, 6, "I"), (4, 6, "I"), (5, 6, "I"),
        (3, 5, "O"), (4, 5, "O"), (3, 4, "O"), (4, 4, "O"),
        (5, 5, "L"), (5, 4, "L"), (5, 3, "L"), (4, 3, "L"),
        (2, 4, "T"), (2, 3, "T"), (2, 2, "T"), (3, 2, "T"),
        (3, 0, "S"), (4, 0, "S"), (2, 1, "S"), (3, 1, "S"),
    ]
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rectangle([ox, oy + cell * 5, ox + cell * 6, oy + cell * 7], fill=(0, 220, 235, 90))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(cell // 2)))
    d = ImageDraw.Draw(img)
    for col, row, p in layout:
        gem(d, ox + col * cell, oy + row * cell, cell - 2, COLORS[p], prism=(col, row) == (3, 4))
    return img


def main():
    out = os.path.join(ROOT, "store", "google-play", "graphics")
    cell = 64
    icon = scene(512, 512, cell, (512 - 6 * cell) // 2, 64 - 6)
    icon.convert("RGB").save(os.path.join(out, "icon-512.png"))
    # feature graphic
    fg = scene(1024, 500, 52, 80, 70).convert("RGBA")
    fg2 = gradient(1024, 500).convert("RGBA")
    well = scene(1024, 500, 52, 80, 70)
    mask = Image.new("L", (1024, 500), 0)
    ImageDraw.Draw(mask).rectangle([0, 0, 420, 500], fill=255)
    fg2.paste(well, (0, 0), mask)
    d = ImageDraw.Draw(fg2)
    x = 520
    for i, ch in enumerate("BLOCKFALL"):
        pass
    # block-letter title built from gems: 5x5 glyphs
    glyphs = {
        "B": ["1110", "1001", "1110", "1001", "1110"], "L": ["1000", "1000", "1000", "1000", "1111"],
        "O": ["0110", "1001", "1001", "1001", "0110"], "C": ["0111", "1000", "1000", "1000", "0111"],
        "K": ["1001", "1010", "1100", "1010", "1001"], "F": ["1111", "1000", "1110", "1000", "1000"],
        "A": ["0110", "1001", "1111", "1001", "1001"],
    }
    keys = list(COLORS.values())
    s = 21
    for line, text, y0 in (("a", "BLOCK", 190), ("b", "FALL", 320)):
        px = 470
        for i, ch in enumerate(text):
            for r, row in enumerate(glyphs[ch]):
                for c, v in enumerate(row):
                    if v == "1":
                        gem(d, px + c * s, y0 + r * s - 40, s - 1, keys[(i + (0 if line == "a" else 3)) % 7])
            px += 5 * s
    fg2.convert("RGB").save(os.path.join(out, "feature-graphic-1024x500.png"))
    # launcher icons
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for name, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        icon.convert("RGB").resize((size, size), Image.LANCZOS).save(
            os.path.join(res, f"mipmap-{name}", "ic_launcher.png"))


if __name__ == "__main__":
    main()
