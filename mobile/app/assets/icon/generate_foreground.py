#!/usr/bin/env python3
"""
Generate the adaptive icon foreground (transparent background with white martini).
For Android adaptive icons.
"""

from PIL import Image, ImageDraw

# Icon dimensions (adaptive icons use 432x432 with safe zone)
SIZE = 1024

# Colors
LIGHT_BLUE = "#87CEEB"  # Martini glass (Sky Blue)
WHITE = "#FFFFFF"       # Toothpick
OLIVE_GREEN = "#8FD14F" # Olive
PIMENTO_RED = "#D2302C" # Pimento center

# Scale factor
SCALE = 2

def create_foreground():
    # Create image with transparent background
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Martini glass coordinates (scaled from SVG)
    # Glass bowl triangle points
    bowl_points = [
        (96 * SCALE, 96 * SCALE),   # Top left
        (256 * SCALE, 256 * SCALE), # Bottom center (tip)
        (416 * SCALE, 96 * SCALE),  # Top right
    ]

    # Line width
    line_width = 32

    # Draw the V-shape of the glass
    draw.line([bowl_points[0], bowl_points[1]], fill=LIGHT_BLUE, width=line_width)
    draw.line([bowl_points[1], bowl_points[2]], fill=LIGHT_BLUE, width=line_width)
    draw.line([bowl_points[0], bowl_points[2]], fill=LIGHT_BLUE, width=line_width)

    # Fill the glass with semi-transparent light blue
    fill_points = [
        (128 * SCALE, 128 * SCALE),
        (256 * SCALE, 256 * SCALE),
        (384 * SCALE, 128 * SCALE),
    ]
    liquid_color = (135, 206, 235, 77)  # Light blue with ~30% opacity
    draw.polygon(fill_points, fill=liquid_color)

    # Redraw the outline on top
    draw.line([bowl_points[0], bowl_points[1]], fill=LIGHT_BLUE, width=line_width)
    draw.line([bowl_points[1], bowl_points[2]], fill=LIGHT_BLUE, width=line_width)
    draw.line([bowl_points[0], bowl_points[2]], fill=LIGHT_BLUE, width=line_width)

    # Draw stem
    stem_start = (256 * SCALE, 256 * SCALE)
    stem_end = (256 * SCALE, 440 * SCALE)
    draw.line([stem_start, stem_end], fill=LIGHT_BLUE, width=line_width)

    # Draw base
    base_start = (176 * SCALE, 440 * SCALE)
    base_end = (336 * SCALE, 440 * SCALE)
    draw.line([base_start, base_end], fill=LIGHT_BLUE, width=line_width)

    # Draw rounded ends
    radius = line_width // 2
    draw.ellipse([stem_end[0] - radius, stem_end[1] - radius,
                  stem_end[0] + radius, stem_end[1] + radius], fill=LIGHT_BLUE)
    draw.ellipse([base_start[0] - radius, base_start[1] - radius,
                  base_start[0] + radius, base_start[1] + radius], fill=LIGHT_BLUE)
    draw.ellipse([base_end[0] - radius, base_end[1] - radius,
                  base_end[0] + radius, base_end[1] + radius], fill=LIGHT_BLUE)

    # Draw olive
    olive_center = (200 * SCALE, 150 * SCALE)
    olive_radius = 40
    draw.ellipse([olive_center[0] - olive_radius, olive_center[1] - olive_radius,
                  olive_center[0] + olive_radius, olive_center[1] + olive_radius],
                 fill=OLIVE_GREEN)

    # Draw pimento
    pimento_radius = 16
    draw.ellipse([olive_center[0] - pimento_radius, olive_center[1] - pimento_radius,
                  olive_center[0] + pimento_radius, olive_center[1] + pimento_radius],
                 fill=PIMENTO_RED)

    # Draw toothpick
    toothpick_start = (olive_center[0] - 30, olive_center[1] + 30)
    toothpick_end = (olive_center[0] + 60, olive_center[1] - 60)
    draw.line([toothpick_start, toothpick_end], fill=WHITE, width=6)

    return img

if __name__ == "__main__":
    import os

    # Generate the foreground
    foreground = create_foreground()

    # Save to the assets/icon directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "icon_foreground.png")

    foreground.save(output_path, "PNG")
    print(f"Foreground saved to: {output_path}")
    print(f"Size: {foreground.size[0]}x{foreground.size[1]}")
