#!/usr/bin/env python3
"""生成 1024x1024 的 AppIcon（渐变底 + 白色 G 字母 + 细内描边）。

运行：
    python3 Tools/make_icon.py
输出：
    GTIIT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
OUT = Path(__file__).resolve().parent.parent / "GTIIT/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


def gradient() -> Image.Image:
    xs = np.linspace(0.0, 1.0, SIZE)[None, :]
    ys = np.linspace(0.0, 1.0, SIZE)[:, None]
    t = np.clip(xs * 0.62 + ys * 0.38, 0.0, 1.0)[..., None]
    start = np.array([46, 92, 226], dtype=np.float64)
    end = np.array([13, 160, 143], dtype=np.float64)
    rgb = start[None, None, :] * (1.0 - t) + end[None, None, :] * t

    # 左上柔光，避免纯线性渐变发闷
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    dist = np.sqrt((xx - SIZE * 0.24) ** 2 + (yy - SIZE * 0.18) ** 2) / (SIZE * 0.9)
    glow = np.clip(1.0 - dist, 0.0, 1.0)[..., None] ** 2
    rgb = rgb + glow * 26.0

    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB")


def main() -> None:
    icon = gradient().convert("RGBA")

    # 内描边
    inset, radius = 76, 210
    outline = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(outline)
    draw.rounded_rectangle(
        [inset, inset, SIZE - inset, SIZE - inset],
        radius=radius,
        outline=(255, 255, 255, 46),
        width=4,
    )
    icon.alpha_composite(outline)

    font = None
    for candidate in FONT_CANDIDATES:
        if Path(candidate).exists():
            font = ImageFont.truetype(candidate, 620)
            break
    if font is None:
        raise SystemExit("找不到可用字体")

    glyph = "G"
    bbox = font.getbbox(glyph)
    width = bbox[2] - bbox[0]
    height = bbox[3] - bbox[1]
    origin = (SIZE / 2 - width / 2 - bbox[0], SIZE / 2 - height / 2 - bbox[1] - 8)

    # 柔和投影
    shadow = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((origin[0], origin[1] + 16), glyph, font=font, fill=(6, 30, 60, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    icon.alpha_composite(shadow)

    # 白色字形
    ImageDraw.Draw(icon).text(origin, glyph, font=font, fill=(255, 255, 255, 255))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
