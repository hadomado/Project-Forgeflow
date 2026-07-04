# Mindustry-Like Asset Library Plan

This project now has a comprehensive free art library for building a top-down 2D automation and tower-defense prototype.

## Current Library Size

- Total files under `assets/`: 3106
- PNG image assets under `assets/`: 3025
- Imported free online library files: 3020
- Imported online PNGs: 2956

## Source Packs

### Tower Defense (Top-Down)

- Source: https://kenney.nl/assets/tower-defense-top-down
- Downloaded from: https://kenney.nl/media/pages/assets/tower-defense-top-down/729844df28-1677693738/kenney_tower-defense-top-down.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_tower_defense_top_down`
- Imported files: 606
- Extension counts: {'.txt': 1, '.png': 603, '.svg': 1, '.swf': 1}
- Use it for: Directly useful for turrets, tower defense props, projectiles, and defensive game readability.

### Top-down Shooter

- Source: https://kenney.nl/assets/top-down-shooter
- Downloaded from: https://kenney.nl/media/pages/assets/top-down-shooter/230204340a-1677694684/kenney_top-down-shooter.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_top_down_shooter`
- Imported files: 601
- Extension counts: {'.txt': 1, '.png': 587, '.db': 8, '.xml': 1, '.svg': 2, '.swf': 2}
- Use it for: Adjacent top-down tiles, characters, props, effects, furniture, decals, and enemy placeholders.

### Top-Down Tanks

- Source: https://kenney.nl/assets/top-down-tanks
- Downloaded from: https://kenney.nl/media/pages/assets/top-down-tanks/0385fcb3e0-1677699019/kenney_top-down-tanks.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_top_down_tanks`
- Imported files: 93
- Extension counts: {'.txt': 1, '.png': 89, '.xml': 1, '.svg': 1, '.swf': 1}
- Use it for: Useful for vehicle enemies, armored drones, turrets, barrels, shells, tracks, and battlefield props.

### Racing Pack

- Source: https://kenney.nl/assets/racing-pack
- Downloaded from: https://kenney.nl/media/pages/assets/racing-pack/c4cd68480a-1677662443/kenney_racing-pack.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_racing_pack`
- Imported files: 442
- Extension counts: {'.url': 2, '.txt': 1, '.png': 429, '.xml': 4, '.svg': 3, '.swf': 3}
- Use it for: Top-down roads, vehicle silhouettes, track pieces, barriers, signs, and terrain transitions for map dressing.

### Space Shooter Extension

- Source: https://kenney.nl/assets/space-shooter-extension
- Downloaded from: https://kenney.nl/media/pages/assets/space-shooter-extension/d0bd70032c-1677693518/kenney_space-shooter-extension.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_space_shooter_extension`
- Imported files: 566
- Extension counts: {'.txt': 1, '.png': 561, '.xml': 2, '.svg': 1, '.swf': 1}
- Use it for: Adjacent 2D weapons, lasers, ships, debris, effects, and sci-fi silhouettes for enemies and projectiles.

### Simple Space

- Source: https://kenney.nl/assets/simple-space
- Downloaded from: https://kenney.nl/media/pages/assets/simple-space/b9b0968a6b-1677578143/kenney_simple-space.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_simple_space`
- Imported files: 109
- Extension counts: {'.url': 2, '.txt': 1, '.png': 102, '.xml': 2, '.svg': 1, '.swf': 1}
- Use it for: Simple sci-fi map objects, backgrounds, and ship shapes useful for drone and map-theme variants.

### Alien UFO Pack

- Source: https://kenney.nl/assets/alien-ufo-pack
- Downloaded from: https://kenney.nl/media/pages/assets/alien-ufo-pack/6bc775e714-1677667399/kenney_alien-ufo-pack.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_alien_ufo_pack`
- Imported files: 57
- Extension counts: {'.url': 2, '.txt': 1, '.png': 50, '.xml': 2, '.svg': 1, '.swf': 1}
- Use it for: Adjacent character and vehicle sprites for flying-drone placeholders, elite enemies, and quirky boss variants.

### Sci-Fi RTS

- Source: https://kenney.nl/assets/sci-fi-rts
- Downloaded from: https://kenney.nl/media/pages/assets/sci-fi-rts/792bcb9cd5-1677693650/kenney_sci-fi-rts.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_sci_fi_rts`
- Imported files: 265
- Extension counts: {'.txt': 2, '.png': 259, '.xml': 2, '.svg': 1, '.swf': 1}
- Use it for: RTS-style sci-fi buildings, map tiles, structures, and base components that map well to factory blocks.

### Road Textures

- Source: https://kenney.nl/assets/road-textures
- Downloaded from: https://kenney.nl/media/pages/assets/road-textures/dbe293b0ed-1677578348/kenney_road-textures.zip
- Publisher: Kenney
- License: Creative Commons CC0
- Local folder: `assets/free_online_asset_library/kenney_road_textures`
- Imported files: 281
- Extension counts: {'.url': 2, '.png': 276, '.svg': 2, '.txt': 1}
- Use it for: Tileable 64x64 roads and industrial ground textures for paths, lanes, and enemy approach routes.

## Build Coverage Plan

### Terrain And Map Tiles

Use the custom `cc0_factory_defense_pack/art/tiles` set for ore, buildable ground, walls, pathing, and spawn markers. Add Kenney top-down shooter floor, wall, road, rubble, furniture, and decal sprites for richer map variety.

### Factory Blocks

Use the custom generated animated drills, conveyors, core, walls, router placeholder, and power-node placeholder as the first playable factory visual set. Add Kenney machinery-like props, crates, barrels, barricades, and tile details as alternate skins or environment dressing.

### Defense Blocks

Use Kenney Tower Defense (Top-Down) for turrets, tower bases, barrels, muzzle/projectile language, and defense silhouettes. Mix the custom turret and projectile sheets where a more factory-like look is useful.

### Enemies And Vehicles

Use Kenney Top-Down Tanks for armored ground enemies, vehicle bosses, wreckage, treads, shells, and battlefield props. Use Top-down Shooter characters/zombies as placeholder humanoid or organic enemies if you want variety beyond vehicles.

### Resources And Logistics

Use the custom ore item sprites for conveyor payloads and storage counts. Use Kenney crates, barrels, pickups, and icons as alternate resources, ammo crates, supply drops, or decoration.

### Projectiles And Effects

Use custom projectiles and hit effects for immediate gameplay readability. Use Kenney tower-defense and shooter effects for bullets, lasers, explosions, decals, and impact variation.

### UI And HUD

Use the custom toolbar icons for drill, conveyor, turret, wall, delete, ore, health, and waves. Use any Kenney SVG/PNG UI-like symbols as secondary icons, minimap markers, or build-category art.

## Suggested Folder Usage In Godot

- `assets/cc0_factory_defense_pack`: original small coherent prototype set.
- `assets/free_online_asset_library`: high-volume source library from free online packs.
- `assets/free_online_asset_library/free_asset_file_catalog.csv`: searchable asset file list.
- `assets/free_online_asset_library/free_asset_library_manifest.json`: source, license, download, and category metadata.

## License Notes

The imported Kenney pages list these packs as Creative Commons CC0. Keep the source folders and manifests in the project so provenance remains clear. The generated factory-defense pack is also CC0 and intentionally does not copy Mindustry art, names, sprites, UI, or sounds.
