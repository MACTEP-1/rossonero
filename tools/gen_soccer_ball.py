#!/usr/bin/env python3
"""
Generates resources/drawables/soccer_ball.png - a classic black/white
soccer ball icon, rasterized rather than drawn as Monkey C vector shapes.

Why a bitmap instead of vector code: three rounds of hand-coded Monkey C
polygon math (Icons.drawSoccerBall) all looked wrong once actually
rendered in the simulator - a flower, then a pinwheel, then something
that reads as a spider/crab rather than a ball - because at a ~50-70px
icon size, small errors in pentagon proportions and placement are very
visible and I have no way to see the render myself before shipping it.
A rasterized PNG sidesteps that: it's generated and visually inspected
right here before ever reaching the Monkey C code, using the same
drawScaledBitmap approach already proven out for the Milan crest and the
Santorini Sunset background photo in the sibling projects.

Renders at high resolution with anti-aliasing (supersampled 4x then
downsampled) so it stays crisp at any actual on-device icon size, with a
transparent background outside the ball's circle so the red/black stripe
background still shows through the rest of the icon's bounding box.
"""

import math
from PIL import Image, ImageDraw

SUPER = 4
SIZE = 240 * SUPER
R = SIZE * 0.47
CX = SIZE / 2
CY = SIZE / 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Ball base: white fill, dark outline.
draw.ellipse([CX - R, CY - R, CX + R, CY + R], fill=(255, 255, 255, 255))

def pentagon(cx, cy, radius, start_deg):
    pts = []
    for i in range(5):
        a = math.radians(start_deg + i * 72.0)
        pts.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
    return pts

# Central pentagon, point-up.
pent_r = R * 0.34
draw.polygon(pentagon(CX, CY, pent_r, -90.0), fill=(20, 20, 20, 255))

# Five rim pentagons, aligned with the central pentagon's own vertex
# angles, placed far enough out that part of each one extends past the
# ball's outline and gets cropped by the circle mask below - this is
# what gives the classic "partial black panel peeking at the edge" look
# real ball photos have, instead of every panel floating fully visible.
ring_r = R * 0.80
outer_pent_r = R * 0.36
for i in range(5):
    angle_deg = -90.0 + i * 72.0
    rad = math.radians(angle_deg)
    ox = CX + math.cos(rad) * ring_r
    oy = CY + math.sin(rad) * ring_r
    draw.polygon(pentagon(ox, oy, outer_pent_r, angle_deg - 90.0), fill=(20, 20, 20, 255))

# Crop everything to the circle (removes the parts of the rim pentagons
# that stuck out past the ball, and keeps the icon's corners transparent).
mask = Image.new("L", (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.ellipse([CX - R, CY - R, CX + R, CY + R], fill=255)
img.putalpha(Image.composite(img.split()[3], Image.new("L", (SIZE, SIZE), 0), mask))

# Outline stroke on top, also masked to the circle.
outline = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
outline_draw = ImageDraw.Draw(outline)
stroke_w = max(2, int(SIZE * 0.012))
outline_draw.ellipse([CX - R, CY - R, CX + R, CY + R], outline=(20, 20, 20, 255), width=stroke_w)
img = Image.alpha_composite(img, outline)

final_size = 240
img = img.resize((final_size, final_size), Image.LANCZOS)
img.save("/home/claude/rossonero/resources/drawables/soccer_ball.png")
print("saved", img.size)
