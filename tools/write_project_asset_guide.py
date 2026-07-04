from __future__ import annotations

import csv
import json
import sys
from pathlib import Path


TARGET = Path(sys.argv[1])
ASSETS = TARGET / "assets"
ONLINE = ASSETS / "free_online_asset_library"
GUIDE = ASSETS / "MINDUSTRY_LIKE_ASSET_LIBRARY_PLAN.md"


def count_files(root: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for path in root.rglob("*"):
        if path.is_file():
            ext = path.suffix.lower() or "[no extension]"
            counts[ext] = counts.get(ext, 0) + 1
    return counts


def main() -> None:
    online_manifest = json.loads((ONLINE / "free_asset_library_manifest.json").read_text(encoding="utf-8"))
    online_catalog = list(csv.DictReader((ONLINE / "free_asset_file_catalog.csv").open(encoding="utf-8")))
    project_counts = count_files(ASSETS)
    png_count = project_counts.get(".png", 0)

    lines = [
        "# Mindustry-Like Asset Library Plan",
        "",
        "This project now has a comprehensive free art library for building a top-down 2D automation and tower-defense prototype.",
        "",
        "## Current Library Size",
        "",
        f"- Total files under `assets/`: {sum(project_counts.values())}",
        f"- PNG image assets under `assets/`: {png_count}",
        f"- Imported free online library files: {len(online_catalog)}",
        f"- Imported online PNGs: {sum(1 for row in online_catalog if row['extension'] == '.png')}",
        "",
        "## Source Packs",
        "",
    ]

    for pack in online_manifest["packs"]:
        lines.extend(
            [
                f"### {pack['title']}",
                "",
                f"- Source: {pack['source_url']}",
                f"- Downloaded from: {pack['download_url']}",
                f"- Publisher: {pack['publisher']}",
                f"- License: {pack['license']}",
                f"- Local folder: `{pack['local_folder']}`",
                f"- Imported files: {pack['total_files']}",
                f"- Extension counts: {pack['extension_counts']}",
                f"- Use it for: {pack['fit']}",
                "",
            ]
        )

    lines.extend(
        [
            "## Build Coverage Plan",
            "",
            "### Terrain And Map Tiles",
            "",
            "Use the custom `cc0_factory_defense_pack/art/tiles` set for ore, buildable ground, walls, pathing, and spawn markers. Add Kenney top-down shooter floor, wall, road, rubble, furniture, and decal sprites for richer map variety.",
            "",
            "### Factory Blocks",
            "",
            "Use the custom generated animated drills, conveyors, core, walls, router placeholder, and power-node placeholder as the first playable factory visual set. Add Kenney machinery-like props, crates, barrels, barricades, and tile details as alternate skins or environment dressing.",
            "",
            "### Defense Blocks",
            "",
            "Use Kenney Tower Defense (Top-Down) for turrets, tower bases, barrels, muzzle/projectile language, and defense silhouettes. Mix the custom turret and projectile sheets where a more factory-like look is useful.",
            "",
            "### Enemies And Vehicles",
            "",
            "Use Kenney Top-Down Tanks for armored ground enemies, vehicle bosses, wreckage, treads, shells, and battlefield props. Use Top-down Shooter characters/zombies as placeholder humanoid or organic enemies if you want variety beyond vehicles.",
            "",
            "### Resources And Logistics",
            "",
            "Use the custom ore item sprites for conveyor payloads and storage counts. Use Kenney crates, barrels, pickups, and icons as alternate resources, ammo crates, supply drops, or decoration.",
            "",
            "### Projectiles And Effects",
            "",
            "Use custom projectiles and hit effects for immediate gameplay readability. Use Kenney tower-defense and shooter effects for bullets, lasers, explosions, decals, and impact variation.",
            "",
            "### UI And HUD",
            "",
            "Use the custom toolbar icons for drill, conveyor, turret, wall, delete, ore, health, and waves. Use any Kenney SVG/PNG UI-like symbols as secondary icons, minimap markers, or build-category art.",
            "",
            "## Suggested Folder Usage In Godot",
            "",
            "- `assets/cc0_factory_defense_pack`: original small coherent prototype set.",
            "- `assets/free_online_asset_library`: high-volume source library from free online packs.",
            "- `assets/free_online_asset_library/free_asset_file_catalog.csv`: searchable asset file list.",
            "- `assets/free_online_asset_library/free_asset_library_manifest.json`: source, license, download, and category metadata.",
            "",
            "## License Notes",
            "",
            "The imported Kenney pages list these packs as Creative Commons CC0. Keep the source folders and manifests in the project so provenance remains clear. The generated factory-defense pack is also CC0 and intentionally does not copy Mindustry art, names, sprites, UI, or sounds.",
            "",
        ]
    )

    GUIDE.write_text("\n".join(lines), encoding="utf-8")
    print(str(GUIDE))


if __name__ == "__main__":
    main()
