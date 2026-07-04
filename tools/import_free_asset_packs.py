from __future__ import annotations

import csv
import json
import re
import shutil
import sys
import time
import urllib.request
import zipfile
from pathlib import Path


TARGET = Path(sys.argv[1])
LIBRARY_ROOT = TARGET / "assets" / "free_online_asset_library"
DOWNLOADS = LIBRARY_ROOT / "_downloads"
PACKS = [
    {
        "id": "kenney_tower_defense_top_down",
        "title": "Tower Defense (Top-Down)",
        "source_url": "https://kenney.nl/assets/tower-defense-top-down",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Directly useful for turrets, tower defense props, projectiles, and defensive game readability.",
    },
    {
        "id": "kenney_top_down_shooter",
        "title": "Top-down Shooter",
        "source_url": "https://kenney.nl/assets/top-down-shooter",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Adjacent top-down tiles, characters, props, effects, furniture, decals, and enemy placeholders.",
    },
    {
        "id": "kenney_top_down_tanks",
        "title": "Top-Down Tanks",
        "source_url": "https://kenney.nl/assets/top-down-tanks",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Useful for vehicle enemies, armored drones, turrets, barrels, shells, tracks, and battlefield props.",
    },
    {
        "id": "kenney_racing_pack",
        "title": "Racing Pack",
        "source_url": "https://kenney.nl/assets/racing-pack",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Top-down roads, vehicle silhouettes, track pieces, barriers, signs, and terrain transitions for map dressing.",
    },
    {
        "id": "kenney_space_shooter_extension",
        "title": "Space Shooter Extension",
        "source_url": "https://kenney.nl/assets/space-shooter-extension",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Adjacent 2D weapons, lasers, ships, debris, effects, and sci-fi silhouettes for enemies and projectiles.",
    },
    {
        "id": "kenney_simple_space",
        "title": "Simple Space",
        "source_url": "https://kenney.nl/assets/simple-space",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Simple sci-fi map objects, backgrounds, and ship shapes useful for drone and map-theme variants.",
    },
    {
        "id": "kenney_alien_ufo_pack",
        "title": "Alien UFO Pack",
        "source_url": "https://kenney.nl/assets/alien-ufo-pack",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Adjacent character and vehicle sprites for flying-drone placeholders, elite enemies, and quirky boss variants.",
    },
    {
        "id": "kenney_sci_fi_rts",
        "title": "Sci-Fi RTS",
        "source_url": "https://kenney.nl/assets/sci-fi-rts",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "RTS-style sci-fi buildings, map tiles, structures, and base components that map well to factory blocks.",
    },
    {
        "id": "kenney_road_textures",
        "title": "Road Textures",
        "source_url": "https://kenney.nl/assets/road-textures",
        "publisher": "Kenney",
        "license": "Creative Commons CC0",
        "fit": "Tileable 64x64 roads and industrial ground textures for paths, lanes, and enemy approach routes.",
    },
]

HEADERS = {"User-Agent": "Codex asset importer/1.0 (+local project asset collection)"}
ASSET_EXTS = {".png", ".svg", ".jpg", ".jpeg", ".aseprite", ".tsx", ".tmx", ".json", ".xml", ".txt", ".md", ".ogg", ".wav", ".mp3"}


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read()


def safe_extract(zip_path: Path, dest: Path) -> None:
    with zipfile.ZipFile(zip_path) as zf:
        for info in zf.infolist():
            target = (dest / info.filename).resolve()
            if not str(target).startswith(str(dest.resolve())):
                raise RuntimeError(f"Unsafe zip entry: {info.filename}")
        zf.extractall(dest)


def catalog_pack(pack: dict[str, str], folder: Path) -> dict[str, object]:
    files = []
    counts: dict[str, int] = {}
    for path in sorted(folder.rglob("*")):
        if not path.is_file():
            continue
        ext = path.suffix.lower() or "[no extension]"
        counts[ext] = counts.get(ext, 0) + 1
        files.append(
            {
                "pack_id": pack["id"],
                "file": str(path.relative_to(TARGET)).replace("\\", "/"),
                "extension": ext,
                "bytes": path.stat().st_size,
            }
        )
    return {"files": files, "counts": counts, "total": len(files)}


def write_summary(rows: list[dict[str, object]], file_rows: list[dict[str, object]]) -> None:
    manifest = {
        "created_at_unix": int(time.time()),
        "purpose": "Free art library for a top-down 2D automation/tower-defense game inspired by Mindustry-style play.",
        "selection_filter": "Top-down 2D first; adjacent genres allowed when useful for turrets, enemies, terrain, UI, props, projectiles, or effects.",
        "packs": rows,
        "recommended_asset_plan": {
            "world_tiles": "ground, path, rubble, roads, floors, ore overlays, walls, blockers, decals",
            "automation_blocks": "drills, conveyors, sorters, routers, storage, cores, power nodes, generators",
            "defense_blocks": "turrets, barrels, projectiles, muzzle flashes, walls, impact marks",
            "units": "ground drones, tank-like enemies, infantry placeholders, bosses, wreckage",
            "resources": "ore items, ammo icons, crates, pickups, particles",
            "ui": "toolbar icons, health/wave/resource symbols, build buttons, cursors",
            "vfx_audio": "explosions, hit flashes, smoke, laser/slug projectiles, build and combat sounds where present",
        },
    }
    (LIBRARY_ROOT / "free_asset_library_manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    with (LIBRARY_ROOT / "free_asset_file_catalog.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["pack_id", "file", "extension", "bytes"])
        writer.writeheader()
        writer.writerows(file_rows)

    readme_lines = [
        "# Free Online Asset Library",
        "",
        "A high-volume library of free assets for a top-down 2D automation and tower-defense game.",
        "",
        "## Selection Plan",
        "",
        "- Use top-down 2D packs first.",
        "- Pull adjacent genres when they provide useful industrial, combat, terrain, UI, enemy, projectile, or prop assets.",
        "- Keep each source in its own folder so licenses and attribution stay traceable.",
        "- Prefer CC0/public-domain packs for frictionless prototyping.",
        "",
        "## Asset Categories To Cover",
        "",
        "- World: terrain, roads, buildable ground, ore overlays, blockers, cliffs, decals.",
        "- Factory: drills, conveyors, routers, sorters, storage, core/base parts, power placeholders.",
        "- Defense: turrets, barrels, walls, bullets, lasers, muzzle flashes, impact effects.",
        "- Units: enemy vehicles, drones, walkers/infantry placeholders, bosses, wreckage.",
        "- Resources: ore chunks, ammo, crates, pickups, icons.",
        "- UI: toolbar icons, cursors, buttons, status symbols.",
        "- Polish: explosions, smoke, scorch marks, signs, props, audio when included.",
        "",
        "## Imported Packs",
        "",
    ]
    for row in rows:
        readme_lines.extend(
            [
                f"### {row['title']}",
                "",
                f"- Source: {row['source_url']}",
                f"- Publisher: {row['publisher']}",
                f"- License: {row['license']}",
                f"- Local folder: `{row['local_folder']}`",
                f"- Imported files: {row['total_files']}",
                f"- Why it fits: {row['fit']}",
                "",
            ]
        )
    (LIBRARY_ROOT / "README_FREE_ASSET_LIBRARY.md").write_text("\n".join(readme_lines), encoding="utf-8")


def main() -> None:
    LIBRARY_ROOT.mkdir(parents=True, exist_ok=True)
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    rows = []
    all_file_rows = []

    for pack in PACKS:
        if "download_url" in pack:
            zip_url = pack["download_url"]
        else:
            page = fetch(pack["source_url"]).decode("utf-8", "ignore")
            matches = re.findall(r"https://kenney\.nl/media/[^'\"<>]+?\.zip", page)
            if not matches:
                raise RuntimeError(f"No zip URL found for {pack['source_url']}")
            zip_url = matches[-1]
        zip_path = DOWNLOADS / f"{pack['id']}.zip"
        zip_path.write_bytes(fetch(zip_url))

        out_dir = LIBRARY_ROOT / pack["id"]
        if out_dir.exists():
            shutil.rmtree(out_dir)
        out_dir.mkdir(parents=True)
        safe_extract(zip_path, out_dir)

        catalog = catalog_pack(pack, out_dir)
        row = {
            **pack,
            "download_url": zip_url,
            "local_folder": str(out_dir.relative_to(TARGET)).replace("\\", "/"),
            "total_files": catalog["total"],
            "extension_counts": catalog["counts"],
        }
        rows.append(row)
        all_file_rows.extend(catalog["files"])

    write_summary(rows, all_file_rows)
    print(json.dumps({"library_root": str(LIBRARY_ROOT), "packs": rows, "total_imported_files": len(all_file_rows)}, indent=2))


if __name__ == "__main__":
    main()
