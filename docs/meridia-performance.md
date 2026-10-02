# Meridia rendering profile — 2026-10-01

The current viewer has substantial rendering headroom on this machine. The station
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
