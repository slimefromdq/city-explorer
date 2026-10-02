# Meridia V2 — visual review and completion roadmap

Review date: 2026-10-01. Scope: `city/city_view.tscn`, the second map,
and its station/walking experience. The older gunslinger map is a separate prototype.

## Direction

Meridia has a strong spatial framework: a river divides a dense skyline from lower
neighborhoods, bridges connect them, and Central Park balances the towers. Meridian
Tower provides orientation; Central Station provides the benchmark for architectural
detail. The next investment should make a connected journey feel finished before
adding more territory.

The owner's older district map is reference material, not a binding specification.
Preserve the current district identities and use `data/city.json` as the source of
truth for locations, boundaries, heights, and seed. Differences such as the older
map's wheel height should not silently overwrite current data.

## Review findings

1. **Overview:** the skyline, river, park, and neighborhoods are readable. Waterfront
   destinations need development. A rectangular change in ocean appearance is visible
   at the terrain mesh boundary and needs a rendering fix.
2. **Skyline:** Meridian Tower is the signature asset. Ordinary towers have mostly
   blank facades and repeated massing; distinct architectural treatments are needed.
3. **Station:** arches, clock, vaulted roof, and patterned plaza establish character.
   Extend that quality through crossings, storefronts, furniture, and arrival signage.
4. **Park:** creek, lake, footbridges, sports areas, and blossom grove offer useful
   destinations. Refine banks/path transitions and replace the museum's plain massing.
5. **Neighborhoods:** pale blocks, repeated green roofs, and scattered neon signs
   make streets interchangeable. Build district identity at the scale of a pedestrian.

These are visual observations, not proof of traversal quality or performance.

## District art direction

| District | Architectural direction | Next distinguishing features |
| --- | --- | --- |
| Midtown Core | Cool curtain walls, narrow mullions, restrained podiums | Tower entrances, terrace edges, polished public space |
| Marina Financial | Blue-green glazing, strong horizontal bands | Waterfront frontage and varied tower crowns |
| Riverside Midrise | Warm masonry, regular windows, active shop bases | Awnings, balconies, bridge approaches |
| Outer Quarters | Cream/terracotta masonry, smaller punched windows | Cornices, varied roofs, local shops and library approach |
| Harbour District | Industrial blue-gray cladding, broad bays | Loading doors, warehouses, quay activity |
| Central Park | Landscape first, clearly framed destinations | Museum architecture, bank transitions, planting clusters |

## Milestones and acceptance criteria

### 1. District facade identity — initial pass delivered

- Replace blank ordinary building walls with district-specific windows, materials,
  floor bands, and ground-floor treatments.
- Keep details at real-world scale on small, large, sloped, and rotated buildings.
- Preserve seeded variation, existing footprints/heights, sightlines, signs, roof
  gardens, station reservations, and batched rendering.
- Validate city data and generated geometry; inspect matching rendered views at
  overview, district, and pedestrian scales. Record results below.

### 2. A finished station → bridge → tower → park journey — playable route delivered

- Establish a continuous walkable route, including crossings and readable entrances.
- Add intentional wayfinding, street furniture, and several memorable local cues.
- Test the route with the player capsule and inspect it from pedestrian height.
- Keep existing train/walk tests passing. Extend walking coverage to the route.

### 3. District silhouettes and civic destinations — exterior pass delivered

- Add roof/crown families compatible with rooftop planting and tower sightlines.
- Develop the museum, library, and performance hall beyond placeholder boxes.
- Give the harbour recognizable warehouse and waterfront activity.
- Validate all added geometry against lot boundaries and entrance reservations.

### 4. Landscape and presentation — initial polish delivered

- Remove the offshore rectangular seam without hiding land or stair openings.
- Refine creek banks, path joins, planting composition, and waterfront edges.
- Establish repeatable screenshots with the viewer's actual lighting.

### 5. Completion gate

- Agree the playable scope; full-city collision and combat integration are separate
  work from a city viewer. The current walking scene supports selected station areas.
- Run city/route validation, generation smoke checks, and relevant walking tests.
- Profile real rendering performance and memory; record hardware and camera route.
- Review district and pedestrian views before calling the map complete.

## Delivery log

- **2026-10-01: station batching and museum connection.** Grouped 360 static
  station boxes into 49 batches, keeping material properties, light layers,
  transforms and collision. Glass, signage and live departure boards remain
  independent. The matching station profile shows 11,220 → 9,665 draw calls
  (about 14% fewer), and median frame time of 5.17 → 4.83 ms on the RTX 3080.
  Raw enabled/disabled profiles are linked from the performance report.
- Added a signed 52 m museum spur from the park arrival, replacing the former
  visual-only Museum Walk paving. It reaches an eight-step terrace approach and
  the museum's entrance. Actual gallery/rotunda collision replaces the old
  conservative reservation box near this destination. The central colonnade bay
  is open and terrace edges have guardrails. Trees keep clear of the branch.
- The player completed station → park → museum → park → station without jumping,
  with benches and bridge barriers checked separately (559 simulated seconds).
  All four train journeys, the station wings/balcony tour, architecture envelopes
  and the real-renderer batch regression passed. This opens the exterior terrace;
  civic interiors, the park loop and library connection remain later work.

- **2026-10-01: landscape and library arrival.** Ground and outer seabed now use
  the same vertex colors and shader, removing the rectangular offshore seam.
  Creek/lake terrain uses a stitched two-metre detail patch while the rest keeps
  its eight-metre grid (91,392 vertices, about 21% more than the original grid).
  Removed the duplicate park lawn mesh that crossed the finely sampled banks.
  Garden patches sit below paths; footbridge decks meet paths with a two-centimetre
  offset rather than a conspicuous step.
- The library has a wide street approach, two stair flights and a rest landing.
  Its retaining wall has a real stair opening; narrower reading rooms leave space
  for the terrace arrival. The stair clears the hillside across its full width,
  has protective side barriers, and uses one continuous collision surface through
  the landing. The actual Walker reached the upper landing and returned to the
  street without jumping. This is an exterior arrival, not an accessible civic
  interior or a connected extension of Meridia Walk.
- Validation and generation smoke checks passed. Architecture bounds, terrain
  patch coverage/stitching, library traversal and the full promenade regression
  were checked. Twenty-three repeatable viewer screenshots now cover the library
  arrival and park water as well as the existing district/station views.
- Actual Forward+ rendering measurements are saved in
  [the performance report](meridia-performance.md) and
  [raw results](meridia-performance.json). The station has the highest measured
  draw-call count; batch its repeated detail before adding more interior objects.
  Remaining landscape work includes waterfront furniture and planting composition.

- Initial review and district reference incorporated. No district layout changes.
- **2026-10-01: facade pass.** One shared shader/material per building group adds
  metre-scaled windows, glass curtain walls, masonry shop bases, floor bands, and
  industrial ribbing. Cream/terracotta variation distinguishes the Outer Quarters.
  Per-building pane variation is deterministic. Window detail fades with its pixel
  footprint to reduce distant aliasing. Planned footprints/heights, rooftop planting,
  signs, sightlines, and the MultiMesh instance count are preserved.
- Verified with city validation (zero failures/warnings), route validation, and the
  generation smoke test (491 buildings, zero failures). Rendered seven repeatable
  views in Forward+ and inspected skyline, neighborhood, financial, and station
  pedestrian views. These checks do not establish a performance budget or full-city
  walkability. Next: district roof/massing variation and the connected walking route.
- **2026-10-01: Meridia Walk.** Added a 1,129 m, four-metre-wide pedestrian
  promenade from the station's forecourt crossing over Core Bridge, around the mall
  to the tower's west forecourt, and north of the museum to the park lake. A teal
  inlay, seven two-sided decision signs, and five bench/lamp rest points establish
  the route. The station crossing, park arrival, and bench spurs have graded joins.
- Collision follows the bridge's actual sampled arch. Both sides of the bridge
  walkway have barriers. Dry ground shoulders and nearby buildings/trunks are
  solid; stairwell/trench holes stay open and no river floor is synthesized.
  Trees keep clear of the route. All route/furniture positions live in city JSON.
- The real Walker capsule completed the route in both directions without jumping;
  bench access/return and both bridge barriers were separately tested. All four
  train journeys, station wing/mezzanine tour, city validation, and generation smoke
  checks passed. The tour's diagonal approach grazed a floor cutout after the changed
  crossing; aligning its waypoints on the hall axis fixed the test without altering
  station geometry. Rendered the journey at pedestrian height in the actual viewer.
- **Scope:** this is a supported exploration corridor, not complete city collision.
  Tower/museum interiors, the whole park path network, district roof families,
  additional civic architecture, offshore presentation, and performance profiling
  remain future work. Next milestone is district silhouettes and civic destinations.
- **2026-10-01: station stair corrections.** Balcony flights now start 0.6 m
  outside the platform shaft boundaries, clearing their walls and guardrails on all
  four sides. Platform ceiling light strips stop at each shaft opening instead of
  crossing the descending stairs. Matched before/after renders confirm both fixes.
- **2026-10-01: silhouettes and civic exteriors.** Seven deterministic roof families
  distinguish planted/flat parapets, stepped/lantern crowns, tile/slate pitches and
  sawtooth warehouses. Ordinary wall bodies retain their batched rendering. Planted
  roofs remain fully supported; unplanted crowns occupy the original height envelope.
  Warehouse loading bays have recessed walls to avoid coplanar panel flicker. Neon
  signs are capped at the new wall height, below roof transitions.
- Museum of Meridia now has stone gallery wings, a copper rotunda and a colonnade.
  Meridian Library has reading-room wings and a central pediment on a retaining
  terrace. That terrace fixes the hillside rising through the original placeholder;
  its roof height responds to the protected west-shore tower view. Opera & Concert
  Hall has three folded copper roof volumes over a glazed foyer. All three retain
  their reserved footprints and have mounted name boards.
- The two authored harbour piers now have supported decks, container stacks and
  a cargo gantry, or passenger shelters/benches. Both connect to the nearest coastal
  road with approach slabs over the bank. Pier roles live in city JSON.
  No new district lots or playable interior space were introduced.
- Verified: city validation (zero failures/warnings), generation smoke, architecture
  regression checks (including oversized-part rejection and roof face winding), all
  four train journeys, station wing/balcony tour, and the full discovery walk in both
  directions. Generation renders 488 ordinary bodies plus three civic exteriors,
  approximately 2,000 architecture parts in four shape batches, one shared harbour box batch,
  and one shared pier approach mesh.
  Twenty repeatable viewer captures cover station defects, civic buildings, roofs,
  and piers. Batching is preserved; performance has not yet been profiled.
- **Remaining:** civic interiors, access to the library terrace, harbour traversal,
  landscape/path refinement, the offshore water seam, and performance profiling.
  Next milestone is landscape and presentation.

## Visual references

The owner's earlier district map (context, not a specification):

![Earlier district reference](images/meridia-district-reference.png)

Skyline at the initial review:

![Skyline before facade pass](images/meridia-skyline-before.png)

Same viewpoint after the first facade pass:

![Skyline after facade pass](images/meridia-skyline-after.png)

The station crossing now connects to the signed promenade:

![Meridia Walk station crossing](images/meridia-walk-station.png)

Core Bridge carries the protected walking route toward Midtown:

![Meridia Walk on Core Bridge](images/meridia-walk-bridge.png)

Station stair separation before and after correction:

![Station stairs before correction](images/station-stairs-before.png)

![Station stairs after correction](images/station-stairs-after.png)

Skyline before and after the silhouette pass:

![Skyline before roof variation](images/meridia-silhouettes-before.png)

![Skyline with district roof families](images/meridia-silhouettes-after.png)

The museum's park-facing galleries and rotunda:

![Museum of Meridia exterior](images/meridia-museum.png)

The library's reading rooms on their hillside terrace:

![Meridian Library exterior](images/meridia-library.png)

The concert hall's folded copper roofs:

![Opera and Concert Hall exterior](images/meridia-concert-hall.png)

Cargo and ferry pier development:

![Meridia Harbour piers](images/meridia-harbour.png)

Warehouse roof profiles and loading bays:

![Harbour sawtooth roofs](images/meridia-warehouse-roofs.png)

## Working commands

```text
godot --headless --path . --script res://tools/validate_city.gd
godot --headless --path . --script res://tools/smoke_generate.gd
godot --headless --path . --script res://tools/validate_routes.gd
godot --path . res://city/city_view.tscn
godot --path . res://walk/StationWalk.tscn
godot --path . --script res://tools/capture_meridia.gd
godot --headless --fixed-fps 60 --path . --script res://tests/discovery_walk_test.gd
godot --headless --path . --script res://tests/architecture_test.gd
godot --headless --path . --script res://tests/terrain_detail_test.gd
godot --headless --fixed-fps 60 --path . --script res://tests/library_access_test.gd
godot --path . --script res://tools/profile_meridia.gd
godot --path . --script res://tests/static_batch_test.gd
```

The capture tool writes twenty-eight 1600 × 900 images to `tests/out/meridia` (ignored by
Git). Set `OUT` to choose another output directory. It uses the viewer scene's
actual lighting and suppresses only the camera-control help overlay. Set `ONLY`
to a comma-separated list of capture names to render selected views.

## Landscape review

Ocean appearance before the seabed shader correction:

![Offshore seam before correction](images/meridia-landscape-before.png)

Matching overview after correction:

![Consistent ocean appearance](images/meridia-landscape-after.png)

Creek banks without the overlapping lawn mesh:

![Refined park water and bridge join](images/meridia-park-banks.png)

Library arrival from the street:

![Library arrival stair and terrace](images/meridia-library-arrival.png)

## Proposed completion scope

Finish Meridia as a city exploration vertical slice: Central Station, the trains,
and the signed station–bridge–tower–park journey, with civic exteriors visible from
that journey. The library arrival is an additional isolated traversal test area;
its district still needs connected ground collision before walking there from the
station. The museum approach, first station batching pass and playable park loop
are now delivered. Prioritize a library connection before adding
full-city collision, civic interiors, harbour traversal or combat.
This scope is a recommendation for the next completion gate, not a claim that the
entire city is playable.

Museum terrace reached from the signed park branch:

![Museum arrival from Meridia Walk](images/meridia-museum-arrival.png)

## Playable lake loop — 2026-10-01

The existing Pond Loop is now a connected 436 m walk from the promenade's park
arrival, with a teal trail, a junction sign, dry shoulders and solid nearby trunks.
Both footbridges follow the path bends and extend onto dry banks; their visible
decks and guardrails also provide collision. Water crossings are checked across
the full path width, including clearance for the player capsule.

The walking regression completed station → museum → lake loop clockwise and
counterclockwise → station without jumping (752 simulated seconds). Both bridge
rails restrained the capsule. Removing the bridges made validation fail, and a
physics ray confirmed there is no invisible floor across the lake. City validation
and generated-scene smoke checks passed. Three new viewer captures were inspected.

![Connected lake loop and footbridges](images/meridia-lake-loop.png)

![Footbridge at walking height](images/meridia-lake-bridge.png)
