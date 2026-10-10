#!/usr/bin/env python3
"""Writes the header icons the addon ships (Media/Icon*.tga): white line
art on transparent, 32 x 32, tinted in the game with vertex colours. Drawn
four times larger and scaled down, so the edges are soft. Uncompressed
32-bit TGA, rows bottom to top, like the other files in Media/. Ported
from Forever Quest Log's tools/make_icons.py; Reset, Session and Mode are
the meter window's own header icons.

Also renders Media/MinimapIcon.tga (64 x 64, colour) from
docs/curseforge/minimap-icon.svg with rsvg-convert.

Needs Pillow (python3 -m pip install pillow). Run from the repository
root:  python3 tools/make_icons.py
"""
import io
import math
import os
import shutil
import struct
import subprocess

from PIL import Image, ImageDraw

SIZE = 32
SUB = 4
BIG = SIZE * SUB
WHITE = (255, 255, 255, 255)


def scaled(v):
    return v * SUB


def line_width(px):
    return max(1, int(px * SUB))


def new():
    img = Image.new("RGBA", (BIG, BIG), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img)


def poly(draw, points, width=2.4):
    pts = [(scaled(x), scaled(y)) for x, y in points]
    draw.line(pts, fill=WHITE, width=line_width(width), joint="curve")
    r = line_width(width) / 2
    for x, y in (pts[0], pts[-1]):
        draw.ellipse((x - r, y - r, x + r, y + r), fill=WHITE)


def chevron_down(draw):
    poly(draw, [(9, 13), (16, 20), (23, 13)], 2.8)


def chevron_up(draw):
    poly(draw, [(9, 19), (16, 12), (23, 19)], 2.8)


def chevron_right(draw):
    poly(draw, [(13, 9), (20, 16), (13, 23)], 3.2)


def lock_body(draw):
    draw.rounded_rectangle((scaled(8), scaled(15), scaled(24), scaled(27)), radius=scaled(2.5),
                           outline=WHITE, width=line_width(2.4))


def lock(draw):
    lock_body(draw)
    draw.arc((scaled(11), scaled(6), scaled(21), scaled(20)), 180, 360, fill=WHITE, width=line_width(2.4))
    poly(draw, [(11, 13), (11, 15)])
    poly(draw, [(21, 13), (21, 15)])


def unlock(draw):
    lock_body(draw)
    draw.arc((scaled(11), scaled(6), scaled(21), scaled(20)), 180, 320, fill=WHITE, width=line_width(2.4))
    poly(draw, [(11, 13), (11, 15)])


def gear(draw):
    cx = cy = scaled(16)
    teeth, outer, inner = 8, scaled(11.5), scaled(8.5)
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = outer if (i % 4) in (0, 1) else inner
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    draw.polygon(pts, fill=WHITE)
    hole = scaled(4)
    draw.ellipse((cx - hole, cy - hole, cx + hole, cy + hole), fill=(255, 255, 255, 0))


def grip(draw):
    for x in (12, 20):
        for y in (9, 16, 23):
            r = scaled(1.9)
            draw.ellipse((scaled(x) - r, scaled(y) - r, scaled(x) + r, scaled(y) + r), fill=WHITE)


def reset(draw):
    # A circular arrow: start over.
    draw.arc((scaled(7), scaled(7), scaled(25), scaled(25)), 40, 320, fill=WHITE, width=line_width(2.6))
    a = math.radians(40)
    x, y = 16 + 9 * math.cos(a), 16 + 9 * math.sin(a)
    poly(draw, [(x - 5.5, y + 0.5), (x, y), (x + 0.5, y - 5.5)], 2.6)


def session(draw):
    # A clock: which fight.
    draw.ellipse((scaled(6), scaled(6), scaled(26), scaled(26)), outline=WHITE, width=line_width(2.6))
    poly(draw, [(16, 10), (16, 16.5), (20.5, 19)], 2.6)


def mode(draw):
    # Three meter bars of falling length: what is measured.
    for i, w in enumerate((20, 14, 9)):
        y = 8 + i * 6.5
        draw.rounded_rectangle((scaled(6), scaled(y), scaled(6 + w), scaled(y + 4)), radius=scaled(1),
                               fill=WHITE)


def check(draw):
    poly(draw, [(7, 17), (13, 23), (25, 10)], 3.4)


def arrow_corner(draw):
    # Diagonal arrow towards the top right; the addon mirrors it per corner.
    poly(draw, [(7, 25), (24, 8)], 2.6)
    poly(draw, [(13, 7), (25, 7), (25, 19)], 2.6)


ICONS = {
    "IconChevronDown": chevron_down,
    "IconChevronUp": chevron_up,
    "IconChevronRight": chevron_right,
    "IconLock": lock,
    "IconUnlock": unlock,
    "IconGear": gear,
    "IconGrip": grip,
    "IconCheck": check,
    "IconArrowCorner": arrow_corner,
    "IconReset": reset,
    "IconSession": session,
    "IconMode": mode,
}


def write_tga(img, path):
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    rows = []
    px = img.load()
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = px[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    with open(path, "wb") as f:
        f.write(header)
        f.write(b"".join(rows))


MINIMAP_SVG = os.path.join("docs", "curseforge", "minimap-icon.svg")
MINIMAP_SIZE = 64


def minimap_icon(repo, media):
    """Media/MinimapIcon.tga (minimap button and TOC IconTexture) from
    docs/curseforge/minimap-icon.svg; needs rsvg-convert (librsvg)."""
    if not shutil.which("rsvg-convert"):
        print("MinimapIcon skipped: rsvg-convert not found")
        return
    png = subprocess.run(["rsvg-convert", "-w", str(MINIMAP_SIZE), "-h", str(MINIMAP_SIZE),
                          os.path.join(repo, MINIMAP_SVG)], check=True, capture_output=True).stdout
    img = Image.open(io.BytesIO(png)).convert("RGBA")
    write_tga(img, os.path.join(media, "MinimapIcon.tga"))
    print("MinimapIcon")


def main():
    repo = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    root = os.path.join(repo, "Media")
    for name, fn in ICONS.items():
        img, draw = new()
        fn(draw)
        small = img.resize((SIZE, SIZE), Image.LANCZOS)
        write_tga(small, os.path.join(root, name + ".tga"))
        print(name)
    minimap_icon(repo, root)


if __name__ == "__main__":
    main()
