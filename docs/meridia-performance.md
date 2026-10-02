# Meridia rendering profile — 2026-10-01

The initial landscape viewer profile has substantial rendering headroom on this machine. The station
view has the highest CPU submission time and draw-call count, so batching repeated
station geometry is the next useful optimization.

Measured with Godot 4.7.2, Vulkan Forward+, NVIDIA GeForce RTX 3080 and Intel
Core i7-12700. The window was 1600 × 900, with 4× MSAA, a 4096-pixel directional
shadow map and VSync disabled. The usual checkout preserves the owner's local
shadow setting; this profile uses the committed project settings in the worktree.
Each fixed camera warmed for 60 frames and then sampled 180 frames. Frame timings
are wall-clock frame intervals; CPU/GPU columns are Godot viewport render timings.

| View | Median frame (ms) | P95 frame (ms) | Render CPU median (ms) | Render GPU median (ms) | Mean draw calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| Overview | 4.06 | 4.85 | 2.68 | 1.74 | 7,147 |
| Skyline | 1.58 | 2.02 | 0.72 | 1.23 | 2,128 |
| Station | 5.08 | 5.88 | 3.46 | 1.81 | 10,925 |
| Park | 2.02 | 2.49 | 1.35 | 1.45 | 4,383 |
| Street | 4.82 | 5.43 | 3.07 | 1.49 | 7,490 |

Reported video memory rose from about 386 to 388 MiB across these views. Every
sampled P95 frame interval was below the 16.67 ms budget for 60 FPS on this machine.
These short fixed-camera samples do not establish performance on lower-end GPUs,
walking physics under load, startup smoothness or a full-city traversal budget.
CPU and GPU timings overlap and should not be added together.

The ground now has 91,392 vertices. Civic/roof detail remains grouped by primitive
shape; the library stair is one mesh per flight, while repeated terrace railing
posts currently use individual nodes. Station railings, arches, furniture and
shadow passes deserve a focused batching pass. Measure again after that change
before expanding interior detail.

Run `godot --path . --script res://tools/profile_meridia.gd` with a rendering
window. The default output is `tests/out/meridia-profile.json`; set `PROFILE_OUT`
to save elsewhere. [Raw measurements](meridia-performance.json) include hardware,
settings, generation time, memory and each camera sample.

## Station batching comparison

A subsequent pass grouped 360 static station boxes into 49 spatial/material
batches. It preserves full material properties, lighting layers, shadow modes,
world transforms and existing collision. Transparent surfaces, text and live
departure kiosks keep their original rendering. Existing meshes already batched
by the concourse remain as they were. Hidden source nodes remain available for
inspection; this pass reduces draw submissions rather than scene-node count.

The same five views were measured with batching disabled and enabled, using the
settings above. Both runs include the museum arrival added in this pass.

| View | Draw calls before | Draw calls after | Median frame before (ms) | Median frame after (ms) |
| --- | ---: | ---: | ---: | ---: |
| Overview | 7,345 | 6,412 | 4.12 | 3.72 |
| Skyline | 2,520 | 2,520 | 1.58 | 1.60 |
| Station | 11,220 | 9,665 | 5.17 | 4.83 |
| Park | 4,678 | 4,270 | 2.09 | 2.04 |
| Street | 7,494 | 6,291 | 3.79 | 3.38 |

The station view draws about 14% fewer calls. Its median CPU render time falls
from 3.51 to 3.21 ms, while P95 frame time changes only slightly, from 5.68 to
5.65 ms. The unchanged skyline view illustrates ordinary timing noise. This is
a useful first reduction, not evidence that all station rendering is optimized.
Further work should inspect custom arch meshes and shadow submissions.

[Unbatched measurements](meridia-performance-unbatched.json) and
[batched measurements](meridia-performance-batched.json) retain the full samples.
Set `STATION_UNBATCHED=1` for comparison; default rendering uses batching.
`tests/static_batch_test.gd` requires a rendering window to verify MultiMesh
transforms, equivalent/different materials, layers, glass and live-board exclusions.

## Connected slice review — 2026-10-01

The latest run includes the playable lake loop, library branch and hillside road
repair. Roads now sample across their width; they retain one surface per road kind.
The profiler adds five walking-height views derived from the civic arrival and
park bridge plans. The hardware, 1600 × 900 resolution, Forward+ renderer, disabled
VSync and 60/180 warmup/sample frame counts match the earlier measurements.

| View | Median frame (ms) | P95 frame (ms) | Mean draw calls |
| --- | ---: | ---: | ---: |
| Overview | 3.81 | 4.31 | 6,450 |
| Skyline | 1.68 | 1.95 | 2,566 |
| Station | 5.75 | 6.85 | 9,714 |
| Park | 2.58 | 2.91 | 4,314 |
| Street | 4.05 | 4.54 | 6,336 |
| Museum approach | 1.35 | 1.58 | 1,522 |
| Library stairs | 1.31 | 1.48 | 329 |
| Library street | 1.29 | 1.52 | 1,220 |
| Lake bridge 1 | 1.29 | 1.50 | 1,055 |
| Lake bridge 2 | 1.41 | 1.64 | 1,802 |

All ten sampled P95 frame intervals remain below 16.67 ms on this RTX 3080.
Station rendering remains the heaviest view. This run's station CPU render median
is 3.71 ms and GPU render median is 1.85 ms; frame time is higher than the previous
batching sample, so this is not a claimed speed improvement. Short fixed-camera
viewer measurements exclude walking physics, train interaction and the walking-map
overlay. They do not establish minimum hardware requirements.

Video memory is approximately 386–387 MiB. Runtime city construction remains a
multi-second synchronous startup task. Loading feedback and caching generated
static content are the next performance priorities before expanding scope.
[Raw connected-slice measurements](meridia-performance-connected.json) preserve
startup time, hardware and all render timings.

## Cached milestone

The finished milestone ships compressed terrain and road meshes, with digest-based
invalidation when layout, generating scripts or engine version change. Other layers
remain generated. Cached mesh geometry was checked against fresh generation.

The final run measured 4,597 ms of viewer construction, compared with 5,764 ms in
the preceding connected-slice run: an observed reduction of about 20%. This is a
single-machine comparison, not a guaranteed load time. Worst sampled P95 frame
interval remained 6.75 ms. [Final raw measurements](meridia-performance-release.json)
retain all ten views. The launch scene adds progress between generation stages;
it does not make each stage asynchronous or remove startup stalls entirely.
