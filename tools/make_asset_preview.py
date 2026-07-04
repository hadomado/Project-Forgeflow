from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(sys.argv[1])
pngs = sorted((ROOT / "art").rglob("*.png"))
thumb = 72
label_h = 28
cols = 6
rows = (len(pngs) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * thumb, rows * (thumb + label_h)), (34, 36, 38, 255))
draw = ImageDraw.Draw(sheet)

try:
    font = ImageFont.truetype("arial.ttf", 9)
except Exception:
    font = ImageFont.load_default()

for i, path in enumerate(pngs):
    col = i % cols
    row = i // cols
    x = col * thumb
    y = row * (thumb + label_h)
    draw.rectangle((x + 2, y + 2, x + thumb - 3, y + thumb - 3), fill=(48, 52, 56, 255), outline=(86, 92, 98, 255))
    with Image.open(path).convert("RGBA") as img:
        preview = img.copy()
        preview.thumbnail((thumb - 12, thumb - 12), Image.Resampling.NEAREST)
        px = x + (thumb - preview.width) // 2
        py = y + (thumb - preview.height) // 2
        sheet.alpha_composite(preview, (px, py))
    label = path.stem[:18]
    draw.text((x + 4, y + thumb + 5), label, fill=(224, 229, 218, 255), font=font)

sheet.save(ROOT / "asset_preview_sheet.png")
