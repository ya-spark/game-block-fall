#!/usr/bin/env python3
"""Block Fall app icon: a glowing T piece falling toward a gap in the stack, with speed streaks and
sparkles. Original art drawn with Pillow; used by gen_store_art.py (store icon and launcher icons).
Run this file directly to write a single icon PNG."""
import math
import sys
from PIL import Image, ImageDraw, ImageFilter

COLORS = {"I": (0, 220, 235), "O": (255, 200, 40), "T": (190, 100, 255), "S": (60, 210, 110),
          "Z": (240, 70, 80), "J": (60, 120, 240), "L": (255, 140, 40)}
S = 512
CELL = 80
OX = (S - 6 * CELL) // 2


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (y / h * 0.7 + x / w * 0.3)
            px[x, y] = (int(8 + 6 * t), int(34 + 40 * (1 - t)), int(52 + 40 * (1 - t)))
    return img.convert("RGBA")


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


def glow(size, draw_fn, radius, boost=1.0):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    blurred = layer.filter(ImageFilter.GaussianBlur(radius))
    if boost != 1.0:
        r, g, b, a = blurred.split()
        a = a.point(lambda v: min(255, int(v * boost)))
        blurred = Image.merge("RGBA", (r, g, b, a))
    return blurred


def star(d, cx, cy, r, color, thin=0.18):
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else r * thin
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    d.polygon(pts, fill=color)


def build():
    img = gradient(S, S)

    # soft light behind the falling piece
    img = Image.alpha_composite(img, glow((S, S), lambda d: d.ellipse([110, 20, 400, 290], fill=(150, 90, 255, 120)), 55))

    # settled stack: 6 columns, a T-shaped slot (cols 1-3 on row 4, col 2 on row 5) waits for the piece
    stack = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stack)
    bottom = S - 16 - CELL
    rows = {
        5: {0: "Z", 1: "Z", 3: "I", 4: "O", 5: "L"},
        4: {0: "J", 4: "S", 5: "L"},
        3: {0: "J", 5: "L"},
    }
    ybase = bottom - 1 * CELL  # row 4 y; row 5 is `bottom`
    ys = {5: bottom, 4: bottom - CELL, 3: bottom - 2 * CELL}
    for row, cells in rows.items():
        for col, p in cells.items():
            gem(sd, OX + col * CELL, ys[row], CELL - 3, COLORS[p])

    # landing slot: cyan glow + white outline (the ghost of the piece)
    slot = [(1, 4), (2, 4), (3, 4), (2, 5)]

    def slot_fill(d):
        for col, row in slot:
            d.rounded_rectangle([OX + col * CELL, ys[row], OX + col * CELL + CELL - 3, ys[row] + CELL - 3], 12,
                                fill=(0, 230, 255, 230))
    img = Image.alpha_composite(img, glow((S, S), slot_fill, 20, 1.6))
    img = Image.alpha_composite(img, stack)
    ghost = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(ghost)
    for col, row in slot:
        gd.rounded_rectangle([OX + col * CELL + 5, ys[row] + 5, OX + col * CELL + CELL - 8, ys[row] + CELL - 8], 12,
                             outline=(210, 255, 255, 235), width=4, fill=(0, 220, 255, 55))
    img = Image.alpha_composite(img, ghost)

    # speed streaks above the falling piece
    streaks = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    st = ImageDraw.Draw(streaks)
    piece_top = 96
    for cx, h, a, w in [(OX + 1 * CELL + 38, 120, 210, 13), (OX + 2 * CELL + 38, 150, 235, 15), (OX + 3 * CELL + 38, 110, 200, 13),
                        (OX + 1 * CELL + 4, 70, 120, 7), (OX + 3 * CELL + 74, 80, 120, 7), (OX + 2 * CELL + 8, 60, 100, 6)]:
        for y in range(max(0, piece_top - h), piece_top + 10):
            t = (y - (piece_top - h)) / (h + 10)
            st.line([(cx - w // 2, y), (cx + w // 2, y)], fill=(235, 222, 255, int(a * t * t)))
    img = Image.alpha_composite(img, streaks.filter(ImageFilter.GaussianBlur(1.2)))

    # the falling piece, tilted a little
    piece = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    pd = ImageDraw.Draw(piece)
    pcells = [(1, 0), (2, 0), (3, 0), (2, 1)]
    for col, r in pcells:
        gem(pd, OX + col * CELL, piece_top + r * CELL, CELL - 3, COLORS["T"], prism=(col, r) == (2, 1))
    aura = glow((S, S), lambda d: [d.rounded_rectangle([OX + c * CELL - 4, piece_top + r * CELL - 4,
                                                          OX + c * CELL + CELL + 1, piece_top + r * CELL + CELL + 1], 16,
                                                         fill=(200, 140, 255, 190)) for c, r in pcells], 14, 1.4)
    piece = Image.alpha_composite(aura, piece)
    piece = piece.rotate(-8, resample=Image.BICUBIC, center=(S // 2, piece_top + CELL))
    img = Image.alpha_composite(img, piece)

    # sparkles and particles
    fx = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fx)
    for (x, y, r, c) in [(92, 150, 34, (255, 255, 255, 255)), (428, 112, 40, (255, 240, 170, 255)),
                         (410, 262, 26, (190, 255, 255, 255)), 
                         (250, 380, 0, None)]:
        if c:
            star(fd, x, y, r, c)
    for (x, y, r, c) in [(150, 60, 6, (255, 255, 255, 230)), (365, 40, 5, (255, 220, 120, 230)), (460, 190, 6, (190, 255, 255, 230)),
                         (40, 230, 5, (210, 170, 255, 230)), (330, 330, 5, (255, 255, 255, 220))]:
        fd.ellipse([x - r, y - r, x + r, y + r], fill=c)
    img = Image.alpha_composite(img, glow((S, S), lambda d: [d.ellipse([x - 26, y - 26, x + 26, y + 26], fill=(255, 255, 255, 110))
                                                              for x, y in [(92, 150), (428, 112), (410, 262)]], 12))
    img = Image.alpha_composite(img, fx)
    return img.convert("RGB")


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "icon-512.png"
    icon = build()
    icon.save(out)
    for size in (192, 96, 48):
        icon.resize((size, size), Image.LANCZOS).save(out.replace(".png", f"-{size}.png"))
    print("saved", out)
