#!/usr/bin/env python3
"""
Generate the My AI Bartender app icon with correct purple background.
Creates a 1024x1024 PNG with:
- Purple background (#7C3AED)
- White martini glass
- Green olive with red pimento
"""

from PIL import Image, ImageDraw

# Icon dimensions
SIZE = 1024

# Colors
PURPLE_BG = "#7C3AED"   # Purple/violet background (matches Android)
LIGHT_BLUE = "#87CEEB"  # Martini glass (Sky Blue)
WHITE = "#FFFFFF"       # Toothpick
OLIVE_GREEN = "#8FD14F" # Olive
PIMENTO_RED = "#D2302C" # Pimento center

# Scale factor (SVG was 512, we want 1024)
SCALE = 2

def create_icon():
    # Create image with purple background
    img = Image.new('RGB', (SIZE, SIZE), PURPLE_BG)
    draw = ImageDraw.Draw(img)

    # Martini glass coordinates (scaled from SVG)
    # Glass bowl triangle points
    bowl_points = [
        (96 * SCALE, 96 * SCALE),   # Top left
        (256 * SCALE, 256 * SCALE), # Bottom center (tip)
        (416 * SCALE, 96 * SCALE),  # Top right
    ]

    # Draw glass bowl outline (light blue)
    line_width = 32  # Scaled from 16

    # Draw the V-shape of the glass
    draw.line([bowl_points[0], bowl_points[1]], fill=LIGHT_BLUE, width=line_width)
    draw.line([bowl_points[1], bowl_points[2]], fill=LIGHT_BLUE, width=line_width)
    draw.line([bowl_points[0], bowl_points[2]], fill=LIGHT_BLUE, width=line_width)

    # Fill the glass with semi-transparent effect (lighter purple)
    fill_points = [
        (128 * SCALE, 128 * SCALE),
        (256 * SCALE, 256 * SCALE),
        (384 * SCALE, 128 * SCALE),
    ]
    # Create a lighter fill color for the liquid
    liquid_color = "#9D6AED"  # Lighter purple for liquid effect
    draw.polygon(fill_points, fill=liquid_color)

    # Redraw the outline on top to ensure clean edges
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

    # Draw rounded ends for stem and base
    radius = line_width // 2
    # Stem bottom
    draw.ellipse([stem_end[0] - radius, stem_end[1] - radius,
                  stem_end[0] + radius, stem_end[1] + radius], fill=LIGHT_BLUE)
    # Base ends
    draw.ellipse([base_start[0] - radius, base_start[1] - radius,
                  base_start[0] + radius, base_start[1] + radius], fill=LIGHT_BLUE)
    draw.ellipse([base_end[0] - radius, base_end[1] - radius,
                  base_end[0] + radius, base_end[1] + radius], fill=LIGHT_BLUE)

    # Draw olive
    olive_center = (200 * SCALE, 150 * SCALE)
    olive_radius = 40  # Scaled from 20
    draw.ellipse([olive_center[0] - olive_radius, olive_center[1] - olive_radius,
                  olive_center[0] + olive_radius, olive_center[1] + olive_radius],
                 fill=OLIVE_GREEN)

    # Draw pimento (red center of olive)
    pimento_radius = 16  # Scaled from 8
    draw.ellipse([olive_center[0] - pimento_radius, olive_center[1] - pimento_radius,
                  olive_center[0] + pimento_radius, olive_center[1] + pimento_radius],
                 fill=PIMENTO_RED)

    # Draw toothpick (thin white line through olive)
    toothpick_start = (olive_center[0] - 30, olive_center[1] + 30)
    toothpick_end = (olive_center[0] + 60, olive_center[1] - 60)
    draw.line([toothpick_start, toothpick_end], fill=WHITE, width=6)

    return img

if __name__ == "__main__":
    import os

    # Generate the icon
    icon = create_icon()

    # Save to the assets/icon directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "icon.png")

    icon.save(output_path, "PNG")
    print(f"Icon saved to: {output_path}")
    print(f"Size: {icon.size[0]}x{icon.size[1]}")
