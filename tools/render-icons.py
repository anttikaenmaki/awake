#!/usr/bin/env python3
# Copyright (C) 2026 Antti Käenmäki
"""Render the menu bar icons and the Finder app icon from the Awake logo.

Menu bar: template images. macOS only looks at their alpha channel and tints
the glyph black on light menu bars and white on dark ones, like the other
status items. The "on" state is a bolder cut of the same glyph, made by
growing the letter outline with a round brush so the counters and curves keep
their shape.

App icon: the white glyph with a soft shadow on a dark rounded square, so it
reads on light and dark Finder backgrounds and keeps the standard macOS icon
shape. Written as AppIcon.png (1024 px) and AppIcon.icns.

Usage:
    python3 tools/render-icons.py [source.png] [output-dir]

Defaults to app/AwakeStatusApp/Assets/awake-off.png and
app/AwakeStatusApp/Assets. Requires Pillow and NumPy.
"""

from __future__ import annotations

import io
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

POINT_SIZE = 18
SCALES = (1, 2)
# Stroke growth for the bold "on" glyph, in source pixels (1024 px artwork).
# About 0.7 pt on each side at menu bar size.
BOLD_RADIUS = 22
# Empty border kept around the bold glyph, in source pixels.
MARGIN = 6

APP_ICON_SIZE = 1024
# Standard macOS icon grid: an 824 px rounded square centred on the canvas,
# leaving room for the drop shadow.
TILE_SIZE = 824
TILE_RADIUS = 185
TILE_TOP_COLOR = (44, 58, 84)
TILE_BOTTOM_COLOR = (14, 21, 34)
GLYPH_WIDTH = 640
# (icns type, pixel size); PNG payloads are valid for all of these types.
ICNS_ENTRIES = (
    (b"icp4", 16),
    (b"icp5", 32),
    (b"icp6", 64),
    (b"ic07", 128),
    (b"ic08", 256),
    (b"ic09", 512),
    (b"ic10", 1024),
    (b"ic11", 32),
    (b"ic12", 64),
    (b"ic13", 256),
    (b"ic14", 512),
)


def load_alpha(path: Path) -> np.ndarray:
    image = Image.open(path).convert("RGBA")
    return np.asarray(image, dtype=np.float32)[..., 3] / 255.0


def dilate(mask: np.ndarray, radius: int) -> np.ndarray:
    padded = np.pad(mask, radius)
    height, width = mask.shape
    grown = np.zeros_like(mask)
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy <= radius * radius:
                grown |= padded[radius + dy:radius + dy + height, radius + dx:radius + dx + width]
    return grown


def supersampled_coverage(mask: np.ndarray, factor: int = 4) -> np.ndarray:
    """Turn a hard mask into a soft coverage map by smoothing its edges."""
    image = Image.fromarray((mask * 255).astype(np.uint8))
    small = image.resize((mask.shape[1] // factor, mask.shape[0] // factor), Image.Resampling.BOX)
    smooth = small.resize((mask.shape[1], mask.shape[0]), Image.Resampling.BICUBIC)
    return np.asarray(smooth, dtype=np.float32) / 255.0


def bounding_box(mask: np.ndarray) -> tuple[int, int, int, int]:
    rows = np.flatnonzero(mask.any(axis=1))
    cols = np.flatnonzero(mask.any(axis=0))
    return rows[0], rows[-1] + 1, cols[0], cols[-1] + 1


def square_crop_box(mask: np.ndarray, margin: int) -> tuple[int, int, int]:
    top, bottom, left, right = bounding_box(mask)
    side = max(bottom - top, right - left) + 2 * margin
    center_y = (top + bottom) / 2
    center_x = (left + right) / 2
    return round(center_y - side / 2), round(center_x - side / 2), side


def crop(alpha: np.ndarray, box: tuple[int, int, int]) -> np.ndarray:
    top, left, side = box
    return alpha[top:top + side, left:left + side]


def alpha_image(alpha: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8))


def write_template(alpha: np.ndarray, path: Path, pixels: int) -> None:
    coverage = alpha_image(alpha).resize((pixels, pixels), Image.Resampling.LANCZOS)
    rgba = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    rgba.putalpha(coverage)
    dpi = 72 * pixels // POINT_SIZE
    rgba.save(path, optimize=True, dpi=(dpi, dpi))


def render_status_icons(source_alpha: np.ndarray, output_dir: Path) -> None:
    pad = BOLD_RADIUS + MARGIN
    regular = np.pad(source_alpha, pad)
    bold_mask = dilate(regular >= 0.5, BOLD_RADIUS)
    bold = np.maximum(supersampled_coverage(bold_mask), regular)

    # Both states share one crop so the glyph does not shift when it toggles.
    box = square_crop_box(bold_mask, MARGIN)
    for name, alpha in (("StatusOffTemplate", regular), ("StatusOnTemplate", bold)):
        for scale in SCALES:
            suffix = "" if scale == 1 else f"@{scale}x"
            write_template(crop(alpha, box), output_dir / f"{name}{suffix}.png", POINT_SIZE * scale)


def shadow(mask: Image.Image, offset_y: int, blur: float, opacity: float) -> Image.Image:
    shifted = Image.new("L", mask.size, 0)
    shifted.paste(mask, (0, offset_y))
    soft = shifted.filter(ImageFilter.GaussianBlur(blur))
    alpha = soft.point(lambda value: round(value * opacity))
    layer = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    layer.putalpha(alpha)
    return layer


def render_app_icon(source_alpha: np.ndarray) -> Image.Image:
    supersample = 2
    size = APP_ICON_SIZE * supersample
    tile_size = TILE_SIZE * supersample
    tile_origin = (size - tile_size) // 2

    tile_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(tile_mask).rounded_rectangle(
        (tile_origin, tile_origin, tile_origin + tile_size - 1, tile_origin + tile_size - 1),
        radius=TILE_RADIUS * supersample,
        fill=255,
    )
    ramp = np.linspace(0.0, 1.0, size, dtype=np.float32)[:, None, None]
    top = np.array(TILE_TOP_COLOR, dtype=np.float32)
    bottom = np.array(TILE_BOTTOM_COLOR, dtype=np.float32)
    gradient = np.broadcast_to(top + (bottom - top) * ramp, (size, size, 3))
    tile = Image.fromarray(gradient.astype(np.uint8), "RGB").convert("RGBA")
    tile.putalpha(tile_mask)

    top_edge, bottom_edge, left_edge, right_edge = bounding_box(source_alpha > 0.5)
    glyph = alpha_image(source_alpha[top_edge:bottom_edge, left_edge:right_edge])
    glyph_width = GLYPH_WIDTH * supersample
    glyph_height = round(glyph.height * glyph_width / glyph.width)
    glyph = glyph.resize((glyph_width, glyph_height), Image.Resampling.LANCZOS)
    glyph_mask = Image.new("L", (size, size), 0)
    # Sit the glyph slightly above centre so it looks centred once the shadow
    # below it is added.
    glyph_mask.paste(glyph, ((size - glyph_width) // 2, (size - glyph_height) // 2 - 12 * supersample))

    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.alpha_composite(shadow(tile_mask, 12 * supersample, 16 * supersample, 0.35))
    icon.alpha_composite(tile)
    glyph_shadow = shadow(glyph_mask, 10 * supersample, 12 * supersample, 0.55)
    glyph_shadow.putalpha(Image.fromarray(np.minimum(
        np.asarray(glyph_shadow.getchannel("A")), np.asarray(tile_mask)
    )))
    icon.alpha_composite(glyph_shadow)
    white = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    white.putalpha(glyph_mask)
    icon.alpha_composite(white)
    return icon.resize((APP_ICON_SIZE, APP_ICON_SIZE), Image.Resampling.LANCZOS)


def png_bytes(image: Image.Image) -> bytes:
    stream = io.BytesIO()
    image.save(stream, "PNG", optimize=True)
    return stream.getvalue()


def write_icns(icon: Image.Image, path: Path) -> None:
    payloads = {}
    entries = []
    for icns_type, pixels in ICNS_ENTRIES:
        if pixels not in payloads:
            payloads[pixels] = png_bytes(icon.resize((pixels, pixels), Image.Resampling.LANCZOS))
        entries.append((icns_type, payloads[pixels]))

    body = b"".join(icns_type + struct.pack(">I", 8 + len(data)) + data for icns_type, data in entries)
    toc = b"".join(icns_type + struct.pack(">I", 8 + len(data)) for icns_type, data in entries)
    toc_block = b"TOC " + struct.pack(">I", 8 + len(toc)) + toc
    path.write_bytes(b"icns" + struct.pack(">I", 8 + len(toc_block) + len(body)) + toc_block + body)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    assets = repo_root / "app" / "AwakeStatusApp" / "Assets"
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else assets / "awake-off.png"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else assets
    output_dir.mkdir(parents=True, exist_ok=True)

    source_alpha = load_alpha(source)
    render_status_icons(source_alpha, output_dir)

    app_icon = render_app_icon(source_alpha)
    app_icon.save(output_dir / "AppIcon.png", optimize=True)
    write_icns(app_icon, output_dir / "AppIcon.icns")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
