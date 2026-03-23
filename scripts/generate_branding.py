#!/usr/bin/env python3
"""
Generate SimPlex branded image assets using Pillow.

Produces:
  - icon_focus_fhd.png  (540x405)  - Roku home screen focused icon
  - icon_side_fhd.png   (246x140)  - Roku home screen side icon
  - splash_fhd.jpg      (1920x1080) - App launch splash screen
  - bg_gradient.png      (1920x1080) - In-app gradient background (no text)

Design:
  - Background: diagonal linear gradient #1A1A2E → #0A0A14
  - Text: "Sim" in white, "Plex" in gold (#F3B125), centered
  - Text stroke: gray (#666666) outline via offset rendering
  - Font: Inter Bold from SimPlex/fonts/Inter-Bold.ttf
"""

import os
import math
from PIL import Image, ImageDraw, ImageFont

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
FONT_PATH = os.path.join(PROJECT_ROOT, "SimPlex", "fonts", "Inter-Bold.ttf")
IMAGES_DIR = os.path.join(PROJECT_ROOT, "SimPlex", "images")

# Colors
COLOR_BG_START = (0x1A, 0x1A, 0x2E)  # Dark navy
COLOR_BG_END = (0x0A, 0x0A, 0x14)    # Near-black
COLOR_WHITE = (0xFF, 0xFF, 0xFF)
COLOR_GOLD = (0xF3, 0xB1, 0x25)       # Plex gold
COLOR_STROKE = (0x66, 0x66, 0x66)

# Asset definitions: (filename, width, height, font_size, stroke_offset, is_jpeg)
ASSETS = [
    ("icon_focus_fhd.png", 540, 405, 72, 2, False),
    ("icon_side_fhd.png", 246, 140, 28, 1, False),
    ("splash_fhd.jpg", 1920, 1080, 120, 3, True),
]


def create_gradient(width: int, height: int) -> Image.Image:
    """Create a diagonal linear gradient from top-left to bottom-right."""
    img = Image.new("RGB", (width, height))
    pixels = img.load()
    # Diagonal distance normalization factor
    max_dist = width + height
    for y in range(height):
        for x in range(width):
            # Interpolation factor based on diagonal position
            t = (x + y) / max_dist
            r = int(COLOR_BG_START[0] + (COLOR_BG_END[0] - COLOR_BG_START[0]) * t)
            g = int(COLOR_BG_START[1] + (COLOR_BG_END[1] - COLOR_BG_START[1]) * t)
            b = int(COLOR_BG_START[2] + (COLOR_BG_END[2] - COLOR_BG_START[2]) * t)
            pixels[x, y] = (r, g, b)
    return img


def render_simplex_text(
    draw: ImageDraw.ImageDraw,
    font: ImageFont.FreeTypeFont,
    canvas_width: int,
    canvas_height: int,
    stroke_offset: int,
) -> None:
    """Render centered 'SimPlex' text with stroke effect."""
    text_sim = "Sim"
    text_plex = "Plex"

    # Measure text parts
    bbox_sim = font.getbbox(text_sim)
    bbox_plex = font.getbbox(text_plex)
    # getbbox returns (left, top, right, bottom)
    w_sim = bbox_sim[2] - bbox_sim[0]
    w_plex = bbox_plex[2] - bbox_plex[0]
    h_sim = bbox_sim[3] - bbox_sim[1]
    h_plex = bbox_plex[3] - bbox_plex[1]

    total_width = w_sim + w_plex
    max_height = max(h_sim, h_plex)

    # Center position
    x_start = (canvas_width - total_width) // 2
    y_start = (canvas_height - max_height) // 2

    # Adjust for font top bearing
    y_offset_sim = -bbox_sim[1]
    y_offset_plex = -bbox_plex[1]

    x_sim = x_start - bbox_sim[0]
    x_plex = x_start + w_sim - bbox_plex[0]

    y_sim = y_start + y_offset_sim
    y_plex = y_start + y_offset_plex

    # Draw stroke (gray text at offsets behind the main text)
    offsets = []
    for dx in range(-stroke_offset, stroke_offset + 1):
        for dy in range(-stroke_offset, stroke_offset + 1):
            if dx == 0 and dy == 0:
                continue
            # Only use the cardinal and diagonal extremes for cleaner stroke
            if abs(dx) + abs(dy) > 0:
                offsets.append((dx, dy))

    for dx, dy in offsets:
        draw.text((x_sim + dx, y_sim + dy), text_sim, fill=COLOR_STROKE, font=font)
        draw.text((x_plex + dx, y_plex + dy), text_plex, fill=COLOR_STROKE, font=font)

    # Draw main text
    draw.text((x_sim, y_sim), text_sim, fill=COLOR_WHITE, font=font)
    draw.text((x_plex, y_plex), text_plex, fill=COLOR_GOLD, font=font)


def generate_asset(
    filename: str,
    width: int,
    height: int,
    font_size: int,
    stroke_offset: int,
    is_jpeg: bool,
) -> None:
    """Generate a single branded asset."""
    print(f"  Generating {filename} ({width}x{height})...")
    img = create_gradient(width, height)
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_PATH, font_size)
    render_simplex_text(draw, font, width, height, stroke_offset)

    output_path = os.path.join(IMAGES_DIR, filename)
    if is_jpeg:
        # Convert to RGB explicitly for JPEG (already RGB but be safe)
        img = img.convert("RGB")
        img.save(output_path, "JPEG", quality=95)
    else:
        img.save(output_path, "PNG")

    # Verify dimensions
    verify = Image.open(output_path)
    assert verify.size == (width, height), f"Dimension mismatch: {verify.size} != ({width}, {height})"
    print(f"    OK: {output_path} ({os.path.getsize(output_path):,} bytes)")


def generate_gradient_bg() -> None:
    """Generate the in-app gradient background (no text)."""
    width, height = 1920, 1080
    filename = "bg_gradient.png"
    print(f"  Generating {filename} ({width}x{height}, no text)...")
    img = create_gradient(width, height)
    output_path = os.path.join(IMAGES_DIR, filename)
    img.save(output_path, "PNG")

    verify = Image.open(output_path)
    assert verify.size == (width, height), f"Dimension mismatch: {verify.size} != ({width}, {height})"
    print(f"    OK: {output_path} ({os.path.getsize(output_path):,} bytes)")


def main():
    print("SimPlex Branding Asset Generator")
    print(f"  Font: {FONT_PATH}")
    print(f"  Output: {IMAGES_DIR}")
    print()

    # Verify font exists
    if not os.path.isfile(FONT_PATH):
        raise FileNotFoundError(f"Font not found: {FONT_PATH}")

    # Ensure output directory exists
    os.makedirs(IMAGES_DIR, exist_ok=True)

    # Generate text assets (icon, splash)
    for asset in ASSETS:
        generate_asset(*asset)

    # Generate gradient-only background
    generate_gradient_bg()

    print()
    print("All assets generated successfully.")


if __name__ == "__main__":
    main()
