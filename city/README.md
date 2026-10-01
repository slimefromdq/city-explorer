# Meridia - procedural city (data -> generator)

The whole layout lives in **`res://data/city.json`**. Scripts in `res://city/` read it and build
the city; change the JSON and the city changes, with the same seed (`meta.seed`) giving the same
result every time.

## Run it
| What | How |
|---|---|
| 3D city (fly camera: WASD, Q/E, hold right mouse, Shift, wheel) | open `res://city/city_view.tscn`, press F6 |
| 2D debug map (keys: S surface, M metro, U sewers, L lots) | open `res://city/debug_map_2d.tscn`, press F6 |
| Validate the data and every rule | `godot --headless --path . --script res://tools/validate_city.gd` (add `-- res://other.json` to check another file) |
| Build the 3D city headless and sanity-check it | `godot --headless --path . --script res://tools/smoke_generate.gd` |

(The repo's `main.tscn` is the older gunslinger prototype and is untouched.)

## Layers, in the order they are built
| Phase | Layer | Main scripts |
|---|---|---|
| 1 | data + 2D map + validator | `city_data`, `geo2d`, `debug_map_2d`, `tools/validate_city` |
| 2 | terrain height, water | `terrain_height`, `terrain_builder` |
| 3 | roads and bridges | `road_network` (the rules), `ribbon_mesh`, `road_builder` |
| 4 | blocks and lots | `block_map`, `lot_splitter`, `lot_plan`, `lot_builder` |
| 5 | buildings (MultiMesh) | `height_rule`, `building_plan`, `building_builder` |
| 6 | landmarks, sightlines | `tower_builder`, `landmark_builder`, `sightlines` |
| 7 | square, greenery, signs | `precinct_builder`, `greenery_plan`/`_builder`, `sign_plan`/`_builder` |
| 7+ | park creek, zones, footbridges | `terrain_height` (creeks, ponds), `greenery_plan`, `park_builder` |

`city_generator.gd` conducts them; each `*_plan` script decides (pure rules, no nodes) and each
`*_builder` script draws. The validator checks the plans, so rules are tested without rendering.

## Ideas the code follows
- Layout is data; rendering is generated; every random choice is seeded per object.
- Building height = district type + distance from the core, plus small seeded variation.
- Nothing is placed on a road, in the water or over a line of sight to the tower.
