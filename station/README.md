# Central Station (Meridia)

The concourse hall, hooked into the city: shell, forecourt, platform level, four shuttle lines with
trains and tunnels, four destination stations. Everything is built at run time from primitives and
from `data/routes.json`; nothing is hand-placed in a scene.

Try it: open `walk/StationWalk.tscn` (WASD, Shift, Space, mouse; Esc frees the mouse). You start at
the end of the main street. Walk to the station, down a stairwell, board a train; a panel offers the
destinations. Doors open on the platform side, the train waits until you pick one, then runs 25 s.

## Where things are

| Piece | File | What it is |
|---|---|---|
| Frame, constants | `station/station_layout.gd` | Station frame: origin = hall centre ON the hall floor, +X east, +Z south. World = `HUB (762, 3.75, 850)` + frame. |
| Orchestrator | `station/station_complex.gd` | Builds the hall (8 bays, doors, skylight, collision), shell, forecourt, platform level, signs. |
| Shell | `station/terminal_shell.gd` | Main facade (7 bays, gate, pediment, clock, flag), pavilions, west portal, two low ticket halls (4.5 m ceilings), wings: waiting room, garden court, shop arcade. |
| Forecourt | `station/forecourt.gd`, `plaza_stone.gdshader` | 64 x 85 m paving (the hall's two-tone tiles, continuous with the hall floor), border, compass inlay, steps + ramp, apron to the avenue, zebra crossing, trees, lamps, benches, kiosk, sign pillar; a small west court. |
| Data | `data/routes.json`, `transit/route_data.gd` | Lines, stops, paths. The boards, maps, tunnels, trains and stations all read this. `tools/validate_routes.gd` checks grade, cover under the ground/river bed, level track at stops. |
| Platform level | `transit/platform_level.gd` | 8 m under the hall: island platform, four colour-coded berths (floor stripe, pillars, wall band, hanging sign, a map stand, a mood per district), four switchback stairwells (holes in the hall floor), chamber with tunnel portals. |
| Tunnels | `transit/tunnel_builder.gd` | Sweeps a dark tunnel along a path: rails, sleepers, lamps, wall glow, trimesh collision. |
| Trains | `transit/train.gd`, `line_service.gd` | A 24 m car: livery, windows, sliding doors (one side at a time), benches, headlight; a Path3D/PathFollow3D per line; a timetable state machine (dwell -> close -> run -> open). |
| Destinations | `transit/destination_station.gd` | Underground platform, level corridor, solid stair, open trench + hood, plaza; styled `hill`, `harbour`, `tower`, `park`. |
| Network | `transit/transit_system.gd` | Owns lines, tunnels, stations, aprons; feeds the departures/arrivals boards (countdowns from the live timetable). |
| Signs | `transit/route_map.gd`, `wayfinding.gd` | Route maps painted from the data with "you are here"; exit signs, hanging train signs, door signs. |
| Walking | `transit/walker.gd`, `ride_ui.gd`, `terrain_apron.gd` | First-person capsule (PlayerScale), the rider's chooser, terrain collision where it is needed. |
| City hooks | `city/city_generator.gd`, `building_plan.gd`, `greenery_plan.gd`, `surface_holes.gd` | Station site no longer gets a placeholder building; entrances reserve their footprint (buildings/trees stay out); ground, lot patches and water get holes where stairs pass through. |

## One sun

The hall has no sun of its own any more (`lighting_enabled = false`): the city's `DirectionalLight3D`
lights it. The beams on the hall floor are that sun shining through the hall's window openings and
the skylight and being shadowed by the piers, vault and mezzanine, so they move with the city's sun
(from the south-east in `city_view.tscn`). The hall's two soft fill lights stay (`interior_fill_only`),
but their light cull mask is restricted to the hall's own meshes (visual layer 2), so they brighten
the interior without lighting the city. Underground the only light is the lamps (plus the sky's
ambient term, which Godot does not occlude; the underground materials are dark for that reason).

## Collision

Hall floor (with the stairwell holes), piers, kiosks, props, mezzanine (one ramp per flight, a wedge
under the solid part, balustrade walls), the shell, forecourt, platforms, stairs, tunnels, the trains
(an `AnimatableBody3D` the line service moves) and a terrain apron (a trimesh of the height function,
at road level, with holes at stairwells) round the hub and each entrance. Meridia Walk adds collision
along a marked station → Core Bridge → tower → park corridor, with dry shoulders and nearby walls/trunks.
Other city areas still have no general collision.
Stair collision is always a ramp along the nosing line (a 0.2 m riser stops a 0.25 m-radius capsule).

## Tests

* `godot --headless --path . --script res://tools/validate_routes.gd` - route data against the terrain.
* `godot --headless --fixed-fps 60 --path . res://tests/walk_test.tscn` (`LINE=east|west|tower|park`) -
  walks the capsule plaza -> hall -> stairwell -> platform -> train -> ride -> destination -> street with
  real physics; fails when stuck. `TOUR=1` visits the wings, climbs the mezzanine, crosses a bridge and
  leaves by the west portal.
* `xvfb-run godot --path . res://tests/station_shots.tscn` - the ten verification shots to `tests/out/`.
* `tools/validate_city.gd`, `tools/smoke_generate.gd` still pass.

## Adding a stop or a line

Edit `data/routes.json`: add a stop (id, name, district, `platform` = train centre at the stop,
`entrance` = stair-top at street level, `stairs_dir`, `platform_side`, `style`) and a line whose path
passes through it. Run `validate_routes.gd`. A second destination per line needs a second
`DestinationStation` (the data model allows more stops per line; the builders currently assume
hub + one destination).
