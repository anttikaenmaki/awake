#!/usr/bin/env python3
# Copyright (C) 2026 Antti Käenmäki
"""Render the menu bar template icons from the Awake logo artwork.

The menu bar uses template images: macOS only looks at the alpha channel and
tints the glyph black on light menu bars and white on dark ones, like the
other status items. The "on" state is a bolder cut of the same glyph, made by
growing the letter outline with a round brush so the counters and curves keep
their shape.

Usage:
    python3 tools/render-status-icons.py [source.png] [output-dir]

Defaults to app/AwakeStatusApp/Assets/awake-off.png and
app/AwakeStatusApp/Assets. Requires Pillow and NumPy.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

POINT_SIZE = 18
SCALES = (1, 2)
# Stroke growth for the bold "on" glyph, in source pixels (1024 px artwork).
# About 0.7 pt on each side at menu bar size.
BOLD_RADIUS = 22
# Empty border kept around the bold glyph, in source pixels.
MARGIN = 6


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


def square_crop_box(mask: np.ndarray, margin: int) -> tuple[int, int, int]:
    rows = np.flatnonzero(mask.any(axis=1))
    cols = np.flatnonzero(mask.any(axis=0))
    top, bottom = rows[0], rows[-1] + 1
    left, right = cols[0], cols[-1] + 1
    side = max(bottom - top, right - left) + 2 * margin
    center_y = (top + bottom) / 2
    center_x = (left + right) / 2
    return round(center_y - side / 2), round(center_x - side / 2), side


def crop(alpha: np.ndarray, box: tuple[int, int, int]) -> np.ndarray:
    top, left, side = box
    return alpha[top:top + side, left:left + side]


def write_template(alpha: np.ndarray, path: Path, pixels: int) -> None:
    coverage = Image.fromarray(np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8))
    coverage = coverage.resize((pixels, pixels), Image.Resampling.LANCZOS)
    rgba = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    rgba.putalpha(coverage)
    dpi = 72 * pixels // POINT_SIZE
    rgba.save(path, optimize=True, dpi=(dpi, dpi))


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    assets = repo_root / "app" / "AwakeStatusApp" / "Assets"
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else assets / "awake-off.png"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else assets
    output_dir.mkdir(parents=True, exist_ok=True)

    pad = BOLD_RADIUS + MARGIN
    regular = np.pad(load_alpha(source), pad)
    bold_mask = dilate(regular >= 0.5, BOLD_RADIUS)
    bold = np.maximum(supersampled_coverage(bold_mask), regular)

    # Both states share one crop so the glyph does not shift when it toggles.
    box = square_crop_box(bold_mask, MARGIN)
    for name, alpha in (("StatusOffTemplate", regular), ("StatusOnTemplate", bold)):
        for scale in SCALES:
            suffix = "" if scale == 1 else f"@{scale}x"
            write_template(crop(alpha, box), output_dir / f"{name}{suffix}.png", POINT_SIZE * scale)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
