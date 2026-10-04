# Modular action controller

Open `action/traversal_lab.tscn` in Godot 4.7.x and press **F6**. This course has
low and high ledges, long wall-run surfaces, a downhill ramp and a low ceiling.
The cyan capsule is a placeholder. Movement uses capsule physics and timed
states; it requires neither imported animation nor root motion.

```powershell
godot --path . res://action/traversal_lab.tscn
# Same controller in the existing large CityBuilder map:
godot --path . res://action/traversal_lab.tscn -- --city
# Controller regression checks (real physics fixtures):
godot --headless --path . --fixed-fps 60 res://tests/action_controller_test.tscn
```

The existing gunslinger scene remains the project's F5 entry point. It has its
own weapon, damage, pickup and three-dash balance rules. The new scene is the
requested action prototype; `--city` loads city geometry without the gunslinger
combat kit. Its lower mantle limits and single air dash intentionally give it
different traversal reach.

## Controls and behavior

| Input | Behavior |
|---|---|
| WASD, mouse | Camera-relative movement and third-person orbit |
| Shift | Sprint; while airborne alongside a vertical wall, wall run |
| Space | Jump; during wall run, launch away, up and along the wall |
| Ctrl or C, held | Crouch; above the configured speed threshold, slide |
| Q | Immediate ground dodge in input direction, or facing if idle |
| E | One air dash per airtime, toward the camera aim direction |
| RMB or F, held | Block; slow movement and face aim |
| LMB, clicks | Timed three-hit melee combo; click in each combo window |
| F3 | Toggle all debug text and probe geometry |
| F5 | Reset position, charges, action state and cooldowns |
| Esc, then click | Release, then recapture the pointer |

Walking accelerates and brakes smoothly; air control is weaker. Jump includes
coyote time, an input buffer and a shorter hop on release. Releasing crouch under
a low ceiling keeps the actual capsule low until standing space is clear.

Slide entry keeps existing speed, with friction, limited steering and downhill
acceleration. Faster entries cover greater distance. Releasing crouch, slowing
below the end threshold, leaving the floor, jumping or dodging ends the slide.
Dodge starts immediately and fixes its direction during its short window.
Each of the three dodge slots regenerates on its own deadline. No invulnerability
is applied; dodge start/end signals are available for a future policy.

Mantling requires an airborne character with forward intent or a jump/mantle
request, a front obstruction, free overhead approach, a walkable top inside the
height limits, full standing capsule clearance and a clear lift-then-forward
path. Low vaults and high mantles use separate durations. Each movement segment
is swept against collisions, so newly introduced geometry aborts the mantle.

Wall runs require side-probe contact and sufficient speed along a vertical
wall. They preserve entry momentum, offer limited along-wall speed control and
use reduced gravity rather than perfect suspension. Duration, leaving the wall,
landing or releasing sprint ends them. The wall's physics RID and shape index
identify a surface: landing, reaching a different surface or waiting for the
reattachment delay permits another run. Wall jumps use the detected normal and
begin that delay too.

Air dash stores its direction and a small momentum contribution at activation.
Startup slows/suspends movement for 0.28s and requests the occult-circle effect.
The placeholder braces low against two violet rings and radial marks. Launch
then bursts at 36m/s for 0.18s with limited steering, followed by normal air
control. Landing restores the airtime allowance, while the cooldown still
applies. A ground press is rejected. Wall-run dash cancellation is an explicit
tuning option, disabled by default.

## Components and integration

| Component | Responsibility |
|---|---|
| `ActionPlayerController` | CharacterBody3D, intent priority, composition, telemetry and action lifecycle |
| `ActionPlayerStateMachine` | Named state, elapsed time and centralized action eligibility |
| `ActionMovementController` | Free, slide, wall-run, dodge/dash velocity data and solvers |
| `ActionParkourController` | Physics probes, full-capsule clearance, surface identity and mantle sweeps |
| `ActionDodgeChargeController` | Three independent slot timers, availability and UI events |
| `ActionCombatController` | Block query/events, three-hit attack startup/active/recovery and queuing |
| `ActionPlayerInput` | Keyboard/mouse adapter and spring-arm camera |
| `ActionPlaceholderView` | Replaceable capsule poses, shield, attack swings and circle geometry |
| `ActionControllerDebugView` | Optional telemetry, rays, target and normals |

Instance `action/player.tscn` into any scene with world collision geometry.
Its `tuning` resource exposes speeds, acceleration, dimensions, collision mask,
slide friction, wall-run gravity/duration, launch forces, mantle height bands,
dodge cooldown, dash startup/launch/steering and per-hit combat timing in the
Inspector. Create or duplicate a resource preset to tune each archetype.
Use positive durations, capsule heights at least twice the radius, and exactly
three entries for each attack/combo timing array. Combo windows are measured
from the start of their hit, not from animation playback.

Controllers write `move_input` (positive Y means forward), `camera_yaw`,
`aim_direction`, and held intents, and submit input edges through `request(Action)`.
The body consumes these on physics ticks. Priority is **mantle, wall jump/jump,
dodge, air dash, attack, block, crouch**. A winning action's state then rejects
lower-priority incompatible inputs. Parkour can interrupt normal air movement;
mantle, dodge and dash phases lock combat; attacks reject block/dodge/jump until
recovery finishes. Blocking permits jump/dodge cancellation according to tuning.
Late combo clicks are rejected; a click after recovery starts hit one again.

Public telemetry includes `current_velocity`, `horizontal_speed`, `grounded`,
`surface_normal`, `current_movement_state`, both airborne/jump timers,
`against_runnable_wall`, `mantle_target_available`, `air_dash_available` and
`is_blocking`. Query `states.state_name()` for a readable name. UI can read
`dodge_charges.available()` and each slot in `dodge_charges.remaining`.

Presentation can subscribe to `animation_requested`, `vfx_requested`, `landed`,
mantle/wall-jump lifecycle, dodge lifecycle and separate air-dash startup/launch/end
signals. `combat.on_block_started` and `combat.on_block_ended` support shield
presentation. `combat.attack_started`, `attack_phase_changed`,
`attack_active_started`, `attack_active_ended` and `attack_ended` report hit numbers
**1–3**. A hit-detection component can open a sweep/hitbox between the active
signals, deduplicate victims, then hand results to separate damage logic.

Example integration:

```gdscript
player.combat.attack_active_started.connect(weapon_sweeps.begin_hit)
player.combat.attack_active_ended.connect(weapon_sweeps.end_hit)
player.vfx_requested.connect(effects.handle_request)
player.dodge_started.connect(dodge_policy.begin_window)
player.dodge_ended.connect(dodge_policy.end_window)
```

The new controller does not resolve damage, stamina, perfect blocks or network
replication. Multiplayer can reuse the intent boundary and telemetry, but still
needs server authority, prediction/reconciliation and replicated action events.

## Verification

The controller test covers camera-relative movement, jump/fall/landing, air
control, real crouch clearance, slide distance/friction, instant directional
dodges, independent regeneration, overlapping-input rules, dash anticipation and
airtime limits, blocking, combo windows and active-event pairing, both mantle
height bands, blocked/dynamic mantle geometry, wall detection, gravity, jumping,
duration and reattachment. Exit code 1 means a failed assertion.
Downhill speed gain and switching between batched wall shapes are also covered.

For optional rendered captures:

```powershell
godot --path . --rendering-method gl_compatibility --fixed-fps 60 --script res://tools/capture_action_controller.gd
```

Images are saved under the ignored `tests/out/` directory. F3 disables the debug
display and drawing; physics probes remain active because traversal uses them.
