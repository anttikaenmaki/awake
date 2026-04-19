#!/usr/bin/env python3

from __future__ import annotations

import sys
import math
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


def background_mask(image: Image.Image, step_threshold: float = 18.0) -> list[bool]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    mask = [False] * (width * height)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        index = y * width + x
        if mask[index]:
            return
        mask[index] = True
        queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        r0, g0, b0, _ = pixels[x, y]
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                continue
            index = ny * width + nx
            if mask[index]:
                continue
            r1, g1, b1, _ = pixels[nx, ny]
            distance = math.sqrt((r1 - r0) ** 2 + (g1 - g0) ** 2 + (b1 - b0) ** 2)
            if distance <= step_threshold:
                mask[index] = True
                queue.append((nx, ny))

    return mask


def build_off_template(source: Path, target: Path) -> None:
    image = Image.open(source).convert("RGBA")
    width, height = image.size
    pixels = image.load()
    bg_mask = background_mask(image)

    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out_pixels = out.load()

    for y in range(height):
        for x in range(width):
            if bg_mask[y * width + x]:
                continue
            r, g, b, _ = pixels[x, y]
            whiteness = min(r, g, b)
            if whiteness < 160:
                continue
            alpha = round(255 * (whiteness - 160) / (255 - 160))
            if alpha > 0:
                out_pixels[x, y] = (0, 0, 0, alpha)

    out.save(target)


def build_on_template(source: Path, target: Path) -> None:
    image = Image.open(source).convert("RGBA")
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    width, height = image.size

    design_width = 360.0
    design_height = 320.0
    target_left = width * 0.10
    target_top = height * 0.06
    target_width = width * 0.80
    target_height = height * 0.88
    scale = min(target_width / design_width, target_height / design_height)
    drawn_width = design_width * scale
    drawn_height = design_height * scale
    origin_x = target_left + (target_width - drawn_width) / 2.0
    origin_y = target_top + (target_height - drawn_height) / 2.0

    def pt(x: float, y: float) -> tuple[float, float]:
        return (
            origin_x + x * scale,
            origin_y + (design_height - y) * scale,
        )

    outer = [
        pt(118, 286),
        pt(200, 36),
        pt(322, 286),
        pt(258, 286),
        pt(232, 214),
        pt(168, 214),
        pt(142, 286),
    ]
    inner = [
        pt(181, 178),
        pt(200, 126),
        pt(219, 178),
    ]
    flourish = [
        pt(56, 246),
        pt(87, 217),
        pt(147, 217),
    ]
    outline_width = max(round(width * 0.11), 2)

    draw.polygon(outer, fill=(0, 0, 0, 255))
    draw.polygon(inner, fill=(0, 0, 0, 0))
    draw.line(outer + [outer[0]], fill=(0, 0, 0, 255), width=outline_width)
    draw.line(inner + [inner[0]], fill=(0, 0, 0, 255), width=outline_width)
    draw.line(flourish, fill=(0, 0, 0, 255), width=outline_width)

    out.save(target)


def main() -> int:
    if len(sys.argv) != 4:
        print("Usage: prepare-awake-assets.py <awake-off.png> <awake-on.png> <output-dir>", file=sys.stderr)
        return 1

    off_source = Path(sys.argv[1])
    on_source = Path(sys.argv[2])
    output_dir = Path(sys.argv[3])
    output_dir.mkdir(parents=True, exist_ok=True)

    build_off_template(off_source, output_dir / "StatusOffTemplate.png")
    build_on_template(on_source, output_dir / "StatusOnTemplate.png")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
