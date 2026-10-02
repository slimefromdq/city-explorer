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
The museum and concert hall remain exteriors; harbour collision is future work.

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

Road surfaces sample terrain across their width at intervals of at most 2 m,
instead of holding both edges at the centreline height. This keeps hillside ground
from cutting through the road. Shared bend sections and one surface per road kind
are preserved; normals come from adjacent mesh vertices. Bridge decks retain their
existing arch geometry. `tests/road_drape_test.gd` checks a curved hillside's edge
clearance, footprint, winding and normals.

City validation checks architecture bounds and the terrace's absolute sightline
height. `tests/architecture_test.gd` also checks determinism, planted-roof support,
sign mounting, roof winding, and separation of the station's two stair systems.

## Meridia Walk

For the finished exploration entry point, run `walk/Meridia.tscn`. It adds a
launch screen, controls, staged loading and F1 return to the menu. See
`docs/meridia-release.md` for the portable Windows package and completion checks.

Open `walk/StationWalk.tscn` for the first-person exploration scene. Follow the
teal inlay from Central Station's forecourt crossing over Core Bridge, around
Meridian Mall to the tower's west forecourt, then north of the museum to the lake.
The route is about 1.13 km (roughly four minutes at walking speed). It has decision
signs, five bench/lamp rest points, and bridge barriers. Trains remain available.

Press **M** to open or close the walking map. It shows the connected promenade,
lake loop and civic branches, six numbered destinations, and your live location
and facing direction. North stays at the top. Its geometry comes from the generated
route plans and civic arrival metadata; the map is limited to this connected slice.
Travel outside its bounds reports that you are outside the map. The overlay scales
with the viewport and leaves mouse capture and the train destination panel alone.
`walk/route_guide.gd` owns the display. `tests/route_guide_test.gd` checks keyboard
toggle/repeat handling, resized canvas bounds and global orientation after reparenting.

At the park arrival, follow the museum sign and teal branch to the front terrace.
`discovery_walk.spurs` owns branch points and signage; `replaces_path` prevents
duplicate paving over an existing park path. The museum's steps and gallery/rotunda
collision are built by `civic_access_builder.gd`. The regression walks this branch
and returns to the station without jumping. The museum interior remains closed.

The park arrival also connects to the 436 m Pond Loop. Follow its teal inlay around
the lake and across two wooden footbridges. `discovery_walk.park_paths` selects
existing greenery paths for traversal; `park_signs` supplies wayfinding.
`park_walk_plan.gd` validates the connection and full-width water crossings;
`park_walk_builder.gd` adds matching path collision, dry shoulders and nearby trunks.
Footbridge decks and rails follow the path bends, with identical visible and
collision meshes. Shoulders stop at water. The walking regression completes the
museum branch and lake loop in both directions before returning to the station,
checks both bridge barriers, and rejects missing bridges and an invisible lake floor.

At the loop's west bank, the signed library branch follows the park edge and then
the street to Meridian Library. This adds about 380 m to reach its existing graded
street approach and two stair flights. `discovery_walk.library_walk` owns its
points and signs. `library_walk_plan.gd` checks the level park junction, full-width
dry-land coverage, building clearance and grades below 20%; the generator also
checks that its endpoint matches the civic approach. Trees reserve clearance for
this branch. Civic wall collision preserves the open stair entrance. The connected
walking regression reaches the library terrace and returns through the park to
the station without jumping. The library opens into a furnished civic interior.

Central Station batches static boxes through `station/static_box_batcher.gd`.
Batch groups preserve material values, lighting layers, shadows and local spatial
cells. Collision and live kiosks are independent. Set `STATION_UNBATCHED=1` when
profiling before/after rendering; see `docs/meridia-performance.md` for results.

`data/city.json` → `discovery_walk` owns the route, crossing approach, stop indices,
signs, and furniture. `discovery_walk_plan.gd` calculates bridge/ground elevations;
`discovery_walk_builder.gd` draws the promenade and matching collision. Dry shoulders
support stepping off the path; nearby walls and trunks are solid. Collision coverage
is limited to this corridor, the Pond Loop, the library branch and existing station areas.

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

## Meridian Library and Institute

The existing library terrace opens through both central portals into a public
reading hall, information desk, book stacks, city archive displays and a seminar
room for public lectures and workshops. `library_interior_builder.gd` builds the
furniture and matching collision; repeated books and furniture use static box
batches. Windows occupy openings in the shell and use transparent glazing.
The library access regression tours both wings and the seminar room, then returns
to the street without jumping and checks shelf/table collision.

Lawn stripes and the cherry garden color are now painted on the actual terrain
vertices. They follow every terrain triangle with no second surface to clip.
