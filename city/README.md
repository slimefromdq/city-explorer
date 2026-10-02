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

## Completion roadmap

See [`docs/meridia-roadmap.md`](../docs/meridia-roadmap.md) for the visual review,
district direction, prioritized milestones, and delivery log. Ordinary buildings
use `district_facade.gdshader` with one material and MultiMesh per group: windows
are measured in local metres, with different glass/masonry/cladding treatments.

## Silhouettes and civic architecture

`architecture_plan.gd` gives ordinary buildings deterministic crown/roof families:
stepped and lantern tower crowns, tile/slate pitches, flat garden parapets, and
sawtooth warehouse roofs with loading bays. Crown space is carved from the original
height envelope. Planted roofs retain full support; parapets stay below the existing
roof allowance. Signs use the reduced wall height so none float across a roof slope.

The same plan replaces three civic placeholders with a museum rotunda/colonnade,
library reading-room wings and central pediment, and a concert hall with folded
copper roofs. The library's `sites[].foundation = "terrace"` sets a datum above the
sampled hillside; its upper rooms adjust to preserve the west-shore tower view.
`architecture_builder.gd` batches parts into four shared primitive meshes.

`harbour_plan.gd` develops the existing pier reservations with deck slabs/piles,
container stacks and a cargo gantry, plus ferry shelters. `harbour.piers[].use`
selects `cargo` or `ferry`. Harbour boxes form one additional shared batch;
`harbour_builder.gd` joins both piers to the nearest coastal road with a shared
approach mesh that clears the sampled shoreline.
These additions are exteriors; civic interiors and harbour collision are future work.

`civic_access_builder.gd` adds the library's street approach, two stair flights,
rest landing and matching collision. ArchitecturePlan leaves an opening through
the front retaining wall and space in front of the reading rooms. A real capsule
ascends and returns without jumping in `tests/library_access_test.gd`. The arrival
has local ground collision; it is not yet connected to the station promenade.

The creek/lake use a stitched two-metre ground patch within the coarser terrain.
The park lawn is rendered by that terrain, rather than an overlapping lot mesh.
Ground and deep seabed share the same shader/color path to prevent an offshore
rectangle. `tests/terrain_detail_test.gd` checks coverage and boundary stitching.
See `docs/meridia-performance.md` for the measured viewer rendering budget.

City validation checks architecture bounds and the terrace's absolute sightline
height. `tests/architecture_test.gd` also checks determinism, planted-roof support,
sign mounting, roof winding, and separation of the station's two stair systems.

## Meridia Walk

Open `walk/StationWalk.tscn` for the first-person exploration scene. Follow the
teal inlay from Central Station's forecourt crossing over Core Bridge, around
Meridian Mall to the tower's west forecourt, then north of the museum to the lake.
The route is about 1.13 km (roughly four minutes at walking speed). It has decision
signs, five bench/lamp rest points, and bridge barriers. Trains remain available.

At the park arrival, follow the museum sign and teal branch to the front terrace.
`discovery_walk.spurs` owns branch points and signage; `replaces_path` prevents
duplicate paving over an existing park path. The museum's steps and gallery/rotunda
collision are built by `civic_access_builder.gd`. The regression walks this branch
and returns to the station without jumping. The museum interior remains closed.

Central Station batches static boxes through `station/static_box_batcher.gd`.
Batch groups preserve material values, lighting layers, shadows and local spatial
cells. Collision and live kiosks are independent. Set `STATION_UNBATCHED=1` when
profiling before/after rendering; see `docs/meridia-performance.md` for results.

`data/city.json` → `discovery_walk` owns the route, crossing approach, stop indices,
signs, and furniture. `discovery_walk_plan.gd` calculates bridge/ground elevations;
`discovery_walk_builder.gd` draws the promenade and matching collision. Dry shoulders
support stepping off the path; nearby walls and trunks are solid. Collision coverage
is limited to this corridor and the existing station areas.

City validation checks for water crossings, blocked building/civic footprints,
and steep grades. `tests/discovery_walk_test.gd` walks the real capsule in both
directions without jumps, rejects a mall shortcut, and tests benches and barriers.

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
