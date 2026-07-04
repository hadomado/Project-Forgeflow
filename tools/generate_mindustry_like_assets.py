from __future__ import annotations

import csv
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw


TARGET = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
ROOT = TARGET / "assets" / "cc0_factory_defense_pack"
random.seed(42)


PALETTE = {
    "transparent": (0, 0, 0, 0),
    "outline": (25, 28, 32, 255),
    "shadow": (48, 45, 50, 150),
    "ground_dark": (73, 82, 70, 255),
    "ground": (92, 105, 86, 255),
    "ground_light": (119, 134, 105, 255),
    "ore_dark": (93, 70, 40, 255),
    "ore": (202, 151, 67, 255),
    "ore_light": (255, 209, 103, 255),
    "rock_dark": (56, 61, 68, 255),
    "rock": (85, 93, 103, 255),
    "rock_light": (123, 134, 145, 255),
    "path": (84, 75, 62, 255),
    "path_light": (111, 100, 82, 255),
    "metal_dark": (45, 53, 62, 255),
    "metal": (90, 104, 118, 255),
    "metal_light": (154, 170, 181, 255),
    "blue_dark": (38, 77, 112, 255),
    "blue": (74, 143, 189, 255),
    "blue_light": (132, 206, 236, 255),
    "green": (90, 181, 116, 255),
    "red": (203, 76, 67, 255),
    "red_light": (255, 122, 98, 255),
    "yellow": (245, 190, 83, 255),
    "white": (232, 238, 226, 255),
}


catalog: list[dict[str, str | int]] = []
animations: dict[str, dict[str, int | str]] = {}


def ensure(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def save(img: Image.Image, rel: str, kind: str, note: str, frame_w: int = 0, frame_h: int = 0, frames: int = 1) -> None:
    path = ROOT / rel
    ensure(path.parent)
    img.save(path)
    catalog.append(
        {
            "file": str(path.relative_to(TARGET)).replace("\\", "/"),
            "kind": kind,
            "width": img.width,
            "height": img.height,
            "frames": frames,
            "frame_width": frame_w or img.width,
            "frame_height": frame_h or img.height,
            "note": note,
        }
    )
    if frames > 1:
        animations[str(path.relative_to(TARGET)).replace("\\", "/")] = {
            "frame_width": frame_w,
            "frame_height": frame_h,
            "frames": frames,
            "layout": "horizontal",
            "note": note,
        }


def px(size: int = 32) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (size, size), PALETTE["transparent"])
    return img, ImageDraw.Draw(img)


def draw_noise_tile(base: str, light: str, dark: str, rel: str, label: str, speckles: int = 24) -> None:
    img, d = px(32)
    d.rectangle((0, 0, 31, 31), fill=PALETTE[base])
    for _ in range(speckles):
        x = random.randrange(32)
        y = random.randrange(32)
        c = PALETTE[light if random.random() > 0.45 else dark]
        d.point((x, y), fill=c)
        if random.random() > 0.75:
            d.point((min(31, x + 1), y), fill=c)
    d.rectangle((0, 0, 31, 31), outline=(0, 0, 0, 25))
    save(img, rel, "tile", label)


def arrow(draw: ImageDraw.ImageDraw, cx: int, cy: int, direction: str, color: tuple[int, int, int, int]) -> None:
    if direction == "east":
        pts = [(cx - 7, cy - 5), (cx + 4, cy - 5), (cx + 4, cy - 10), (cx + 12, cy), (cx + 4, cy + 10), (cx + 4, cy + 5), (cx - 7, cy + 5)]
    elif direction == "west":
        pts = [(cx + 7, cy - 5), (cx - 4, cy - 5), (cx - 4, cy - 10), (cx - 12, cy), (cx - 4, cy + 10), (cx - 4, cy + 5), (cx + 7, cy + 5)]
    elif direction == "north":
        pts = [(cx - 5, cy + 7), (cx - 5, cy - 4), (cx - 10, cy - 4), (cx, cy - 12), (cx + 10, cy - 4), (cx + 5, cy - 4), (cx + 5, cy + 7)]
    else:
        pts = [(cx - 5, cy - 7), (cx - 5, cy + 4), (cx - 10, cy + 4), (cx, cy + 12), (cx + 10, cy + 4), (cx + 5, cy + 4), (cx + 5, cy - 7)]
    draw.polygon(pts, fill=color)


def make_sheet(frame_count: int, size: int) -> tuple[Image.Image, list[ImageDraw.ImageDraw]]:
    sheet = Image.new("RGBA", (frame_count * size, size), PALETTE["transparent"])
    draws = []
    for i in range(frame_count):
        frame = Image.new("RGBA", (size, size), PALETTE["transparent"])
        sheet.alpha_composite(frame, (i * size, 0))
        draws.append(ImageDraw.Draw(sheet))
    return sheet, draws


def cell(draw: ImageDraw.ImageDraw, frame: int, size: int = 32) -> tuple[int, int]:
    return frame * size, 0


def draw_building_base(d: ImageDraw.ImageDraw, ox: int, oy: int, w: int = 32, h: int = 32) -> None:
    d.rectangle((ox + 5, oy + 6, ox + w - 6, oy + h - 5), fill=PALETTE["outline"])
    d.rectangle((ox + 7, oy + 8, ox + w - 8, oy + h - 7), fill=PALETTE["metal_dark"])
    d.rectangle((ox + 9, oy + 10, ox + w - 10, oy + h - 9), fill=PALETTE["metal"])
    d.line((ox + 9, oy + 10, ox + w - 10, oy + 10), fill=PALETTE["metal_light"])


def conveyor(direction: str) -> None:
    frames = 8
    sheet = Image.new("RGBA", (frames * 32, 32), PALETTE["transparent"])
    d = ImageDraw.Draw(sheet)
    for f in range(frames):
        ox = f * 32
        draw_building_base(d, ox, 0)
        d.rectangle((ox + 7, 12, ox + 24, 20), fill=PALETTE["outline"])
        d.rectangle((ox + 8, 13, ox + 23, 19), fill=PALETTE["blue_dark"])
        for step in range(-16, 34, 8):
            shift = (f * 2) % 8
            if direction in ("east", "west"):
                x = ox + step + shift
                d.line((x, 13, x + 7, 19), fill=PALETTE["blue_light"])
            else:
                y = step + shift
                d.line((ox + 8, y, ox + 23, y + 7), fill=PALETTE["blue_light"])
        arrow(d, ox + 16, 16, direction, PALETTE["yellow"])
    save(sheet, f"art/blocks/conveyor_{direction}_sheet.png", "animated_block", f"Conveyor belt moving {direction}", 32, 32, frames)


def drill(direction: str) -> None:
    frames = 4
    sheet = Image.new("RGBA", (frames * 32, 32), PALETTE["transparent"])
    d = ImageDraw.Draw(sheet)
    for f in range(frames):
        ox = f * 32
        draw_building_base(d, ox, 0)
        spin = f % 4
        pts = [(ox + 16, 7), (ox + 20 + spin, 16), (ox + 16, 25), (ox + 12 - spin, 16)]
        d.polygon(pts, fill=PALETTE["ore_light"], outline=PALETTE["outline"])
        d.ellipse((ox + 12, 12, ox + 20, 20), fill=PALETTE["metal_light"], outline=PALETTE["outline"])
        arrow(d, ox + 16, 16, direction, PALETTE["green"])
    save(sheet, f"art/blocks/drill_{direction}_sheet.png", "animated_block", f"Ore drill with {direction} output", 32, 32, frames)


def turret() -> None:
    frames = 4
    sheet = Image.new("RGBA", (frames * 32, 32), PALETTE["transparent"])
    d = ImageDraw.Draw(sheet)
    for f in range(frames):
        ox = f * 32
        recoil = 2 if f == 1 else 0
        draw_building_base(d, ox, 0)
        d.ellipse((ox + 9, 9, ox + 23, 23), fill=PALETTE["blue"], outline=PALETTE["outline"])
        d.rectangle((ox + 15 - recoil, 3, ox + 19 - recoil, 15), fill=PALETTE["outline"])
        d.rectangle((ox + 16 - recoil, 4, ox + 18 - recoil, 15), fill=PALETTE["metal_light"])
        if f == 1:
            d.polygon([(ox + 17, 1), (ox + 14, 5), (ox + 20, 5)], fill=PALETTE["yellow"])
    save(sheet, "art/blocks/turret_shoot_sheet.png", "animated_block", "Compact turret firing animation", 32, 32, frames)


def core() -> None:
    frames = 6
    sheet = Image.new("RGBA", (frames * 96, 96), PALETTE["transparent"])
    d = ImageDraw.Draw(sheet)
    for f in range(frames):
        ox = f * 96
        pulse = int(8 + math.sin(f / frames * math.tau) * 4)
        d.rectangle((ox + 10, 14, ox + 86, 84), fill=PALETTE["outline"])
        d.rectangle((ox + 14, 18, ox + 82, 80), fill=PALETTE["metal_dark"])
        d.rectangle((ox + 22, 26, ox + 74, 72), fill=PALETTE["metal"])
        d.ellipse((ox + 38 - pulse // 2, 38 - pulse // 2, ox + 58 + pulse // 2, 58 + pulse // 2), fill=PALETTE["blue_light"], outline=PALETTE["outline"])
        for x in (24, 68):
            for y in (28, 66):
                d.rectangle((ox + x - 5, y - 5, ox + x + 5, y + 5), fill=PALETTE["yellow"], outline=PALETTE["outline"])
    save(sheet, "art/blocks/core_idle_sheet.png", "animated_block", "3x3 command core idle pulse", 96, 96, frames)


def enemy(name: str, body: str, accent: str, size: int, frames: int = 6) -> None:
    sheet = Image.new("RGBA", (frames * 32, 32), PALETTE["transparent"])
    d = ImageDraw.Draw(sheet)
    for f in range(frames):
        ox = f * 32
        bob = int(math.sin(f / frames * math.tau) * 2)
        d.ellipse((ox + 16 - size, 16 - size + bob, ox + 16 + size, 16 + size + bob), fill=PALETTE["outline"])
        d.ellipse((ox + 17 - size, 17 - size + bob, ox + 15 + size, 15 + size + bob), fill=PALETTE[body])
        d.rectangle((ox + 11, 13 + bob, ox + 21, 17 + bob), fill=PALETTE[accent])
        d.rectangle((ox + 7, 22 - bob, ox + 11, 25 - bob), fill=PALETTE["outline"])
        d.rectangle((ox + 21, 22 + bob, ox + 25, 25 + bob), fill=PALETTE["outline"])
    save(sheet, f"art/enemies/{name}_walk_sheet.png", "animated_enemy", f"{name.replace('_', ' ').title()} enemy walk loop", 32, 32, frames)


def explosion(name: str, color: str, frames: int = 8) -> None:
    sheet = Image.new("RGBA", (frames * 64, 64), PALETTE["transparent"])
    d = ImageDraw.Draw(sheet)
    for f in range(frames):
        ox = f * 64
        r = 5 + f * 4
        alpha = max(30, 240 - f * 27)
        c = (*PALETTE[color][:3], alpha)
        d.ellipse((ox + 32 - r, 32 - r, ox + 32 + r, 32 + r), fill=c, outline=PALETTE["outline"] if f < 4 else None)
        if f < 5:
            d.ellipse((ox + 28 - r // 2, 28 - r // 2, ox + 28 + r // 2, 28 + r // 2), fill=PALETTE["ore_light"])
    save(sheet, f"art/effects/{name}_sheet.png", "animated_effect", f"{name.replace('_', ' ').title()} effect", 64, 64, frames)


def icon(name: str, shape: str, color: str) -> None:
    img, d = px(32)
    d.rounded_rectangle((3, 3, 28, 28), radius=4, fill=PALETTE["metal_dark"], outline=PALETTE["outline"], width=2)
    if shape == "drill":
        d.polygon([(16, 7), (23, 16), (16, 25), (9, 16)], fill=PALETTE[color], outline=PALETTE["outline"])
    elif shape == "belt":
        d.rectangle((8, 12, 24, 20), fill=PALETTE[color], outline=PALETTE["outline"])
        arrow(d, 16, 16, "east", PALETTE["yellow"])
    elif shape == "turret":
        d.ellipse((9, 11, 23, 25), fill=PALETTE[color], outline=PALETTE["outline"])
        d.rectangle((15, 5, 19, 15), fill=PALETTE["metal_light"], outline=PALETTE["outline"])
    elif shape == "wall":
        for x in (8, 16):
            d.rectangle((x, 8, x + 8, 24), fill=PALETTE[color], outline=PALETTE["outline"])
    elif shape == "trash":
        d.rectangle((10, 12, 22, 25), fill=PALETTE[color], outline=PALETTE["outline"])
        d.line((9, 10, 23, 10), fill=PALETTE["outline"], width=2)
    else:
        d.ellipse((10, 10, 22, 22), fill=PALETTE[color], outline=PALETTE["outline"])
    save(img, f"art/ui/icons/{name}.png", "ui_icon", f"{name.replace('_', ' ').title()} toolbar icon")


def projectile(name: str, color: str, length: int) -> None:
    img = Image.new("RGBA", (32, 32), PALETTE["transparent"])
    d = ImageDraw.Draw(img)
    d.line((16, 16 + length, 16, 16 - length), fill=PALETTE["outline"], width=4)
    d.line((16, 16 + length, 16, 16 - length), fill=PALETTE[color], width=2)
    d.ellipse((12, 10, 20, 18), fill=PALETTE[color], outline=PALETTE["outline"])
    save(img, f"art/projectiles/{name}.png", "projectile", f"{name.replace('_', ' ').title()} projectile")


def static_block(name: str, color: str, variant: int) -> None:
    img, d = px(32)
    draw_building_base(d, 0, 0)
    if name.startswith("wall"):
        for x in range(7, 25, 8):
            d.rectangle((x, 8, x + 7, 25), fill=PALETTE[color], outline=PALETTE["outline"])
        d.line((8, 16 + variant, 24, 16 + variant), fill=PALETTE["metal_light"])
    elif name.startswith("router"):
        d.ellipse((8, 8, 24, 24), fill=PALETTE[color], outline=PALETTE["outline"])
        for direction in ("east", "west", "north", "south"):
            arrow(d, 16, 16, direction, PALETTE["yellow"])
    else:
        d.rectangle((10, 7, 22, 25), fill=PALETTE[color], outline=PALETTE["outline"])
        d.line((12, 9, 20, 23), fill=PALETTE["yellow"], width=2)
    save(img, f"art/blocks/{name}.png", "block", f"{name.replace('_', ' ').title()} block")


def item(name: str, color: str, variant: int) -> None:
    img, d = px(16)
    if name == "ore":
        d.polygon([(8, 1), (14, 6), (12, 14), (4, 15), (1, 7)], fill=PALETTE["outline"])
        d.polygon([(8, 3), (12, 7), (10, 12), (5, 13), (3, 8)], fill=PALETTE[color])
        d.point((8 + variant % 3, 6), fill=PALETTE["ore_light"])
    else:
        d.rectangle((3, 3, 12, 12), fill=PALETTE["outline"])
        d.rectangle((4, 4, 11, 11), fill=PALETTE[color])
    save(img, f"art/items/{name}_{variant}.png", "item", f"{name.title()} item variant {variant}")


def main() -> None:
    ensure(ROOT)

    for i in range(8):
        draw_noise_tile("ground", "ground_light", "ground_dark", f"art/tiles/ground_{i}.png", f"Buildable ground variant {i}", 18 + i)
    for i in range(6):
        draw_noise_tile("ore_dark", "ore_light", "ore", f"art/tiles/ore_{i}.png", f"Ore tile variant {i}", 30 + i * 2)
    for i in range(6):
        draw_noise_tile("rock_dark", "rock_light", "rock", f"art/tiles/rock_{i}.png", f"Blocking rock tile variant {i}", 22 + i)
    for i in range(4):
        draw_noise_tile("path", "path_light", "ground_dark", f"art/tiles/enemy_path_{i}.png", f"Enemy path tile variant {i}", 20)
    draw_noise_tile("red", "red_light", "path", "art/tiles/enemy_spawn.png", "Enemy spawn marker", 26)

    for direction in ("north", "east", "south", "west"):
        conveyor(direction)
        drill(direction)
    turret()
    core()

    for i, color in enumerate(("metal", "metal_light", "blue_dark")):
        static_block(f"wall_{i}", color, i)
    static_block("router_four_way", "blue", 0)
    static_block("power_node_placeholder", "green", 0)

    for i in range(8):
        item("ore", "ore", i)
    item("ammo_crate", "yellow", 0)

    enemy("scout", "red", "red_light", 9)
    enemy("crawler", "ore_dark", "yellow", 8)
    enemy("bruiser", "rock", "red_light", 11)
    enemy("runner", "green", "yellow", 7)
    enemy("boss_seed", "blue_dark", "red_light", 13)

    projectile("ore_slug", "ore_light", 7)
    projectile("blue_laser", "blue_light", 9)
    projectile("red_enemy_shot", "red_light", 6)

    explosion("small_hit", "yellow", 6)
    explosion("ore_burst", "ore_light", 8)
    explosion("core_damage", "red_light", 8)

    for name, shape, color in (
        ("build_drill", "drill", "ore_light"),
        ("build_conveyor", "belt", "blue"),
        ("build_turret", "turret", "blue_light"),
        ("build_wall", "wall", "metal_light"),
        ("delete_tool", "trash", "red_light"),
        ("ore_counter", "dot", "ore_light"),
        ("health", "dot", "green"),
        ("wave", "dot", "red_light"),
    ):
        icon(name, shape, color)

    (ROOT / "LICENSE_CC0.txt").write_text(
        "CC0 1.0 Universal dedication for this generated asset pack.\n"
        "These original placeholder assets were generated for this project and may be used, copied, modified, and redistributed without attribution.\n"
        "They do not include Mindustry art, names, sprites, sounds, UI, or other copied assets.\n",
        encoding="utf-8",
    )
    (ROOT / "README_ASSETS.md").write_text(
        "# CC0 Factory Defense Asset Pack\n\n"
        "Original free placeholder art for a Godot 4 top-down automation and tower-defense prototype.\n\n"
        "## Contents\n\n"
        "- 25 tile sprites for ground, ore, rock, enemy paths, and spawn markers.\n"
        "- Animated block sprite sheets for conveyors, drills, turret firing, and the 3x3 core.\n"
        "- Static blocks for walls, a router placeholder, and a power-node placeholder.\n"
        "- Item sprites, projectiles, enemy walk loops, hit effects, and toolbar icons.\n\n"
        "Sprite sheets are horizontal. See `animation_metadata.json` for frame sizes and frame counts.\n\n"
        "## License\n\n"
        "CC0 1.0 Universal. These are original generated assets and intentionally do not copy Mindustry assets.\n",
        encoding="utf-8",
    )
    (ROOT / "animation_metadata.json").write_text(json.dumps(animations, indent=2), encoding="utf-8")
    with (ROOT / "asset_catalog.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["file", "kind", "width", "height", "frames", "frame_width", "frame_height", "note"])
        writer.writeheader()
        writer.writerows(catalog)


if __name__ == "__main__":
    main()
