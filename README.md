# City Explorer - Gunslinger prototype (Godot 4.7.2)

One gunslinger, one small slice of a big vertical city, and a test bench for
making movement + combat feel right before anything else gets built.

Open the folder in Godot 4.7.x (Forward+ renderer) and press F5.
First open imports scripts (`class_name`s); if you run from CLI do
`godot --headless --import` once.

## Controls

| Input | Action |
|---|---|
| WASD / Shift / Space | move / sprint / jump (jump on a wall = wall-kick, 3 per air-time) |
| **E** | **air-dash** toward the crosshair (3 charges; look up = go up) |
| Q | dodge (3 charges, i-frames) |
| F or RMB (hold) | block (guard meter, front arc only) |
| LMB (hold) | Quickdraw M1 combo: single, single, double-tap |
| 1 / 2 / 3 / 4 | Burst Shot / Slide-Shot / Ricochet Round / Snapshot (hold, release) |
| R | reload |
| F1 help, F2 teleport tour, F5 reset meters+cooldowns, F6 respawn bots, F7 cycle bot mode, F8 +3 streak, F9 rain |

Bots (F7 cycles Blocker / Dodger / Aggressor): Dummy (street), Blocker
(underpass), Dodger (alley), Aggressor (avenue), Terrace Dummy (tower terrace).
Bots use exactly the same Fighter rules as the player.

## The combat triangle (all in `HitData` flags)

* **Heavy** hits drain guard fast -> heavies beat block (Ricochet direct hit, Snapshot).
* **Dodge** i-frames beat anything `dodgeable`. Only 3 charges: an empty pool = light pressure wins.
* `blockable=false` beats block; `dodgeable=false` beats dodge (a *bounced* Ricochet round can't be dodged).
* Guard covers the **front arc only** - bounces and flanks slip past.
* Guard break = 1.8 s stun, +25% damage taken.
* Meters are readable on the body: ground ring (outer arc = guard, middle pips = dodges, inner pips = dashes), guard bubble, health bar over the head.

## Kit balance rule: every shot costs something

| Move | Cost |
|---|---|
| Quickdraw | 4-round combo, 0.5 s finisher recovery, slows you, no sprint |
| Burst Shot | 3 rounds, recovery window, 3.5 s cd, falls off past 18 m |
| Slide-Shot | 2 rounds, committed straight line, 6 s cd, falls off past 8 m |
| Ricochet | 0.28 s glowing windup (interrupted by a hit), 7 s cd |
| Snapshot | 2 rounds, slow + can't block while charging, visible laser, cancelled by hits/dodge; a **miss** = ~1.6 s no actions and 1.25 s no dash/jump |
| Magazine | 12 rounds; empty = 1.35 s reload with no shots |

## Architecture (built to grow)

```
core/          HitData (the combat vocabulary), ChargePool (regen charges)
fighter/       Fighter = archetype-agnostic shared layer:
               Locomotion (velocity = run + gravity + impulse, "drives" for dash/dodge/slide, mantle, wall-kick)
               GuardComponent, DodgeComponent, BountyComponent, GunComponent, Hurtbox
               CharacterModel (procedural rig, poses, afterimages), MeterRing, Nameplate, Trail3D, VFX
abilities/     Ability base (cooldown, scheduler, channel) + gunslinger/ (one script per move)
control/       PlayerController / BotBrain fill Fighter intents; CameraRig owns the aim ray
world/         Kit (box/ramp/stairs builder), Props, BuildingFactory (style recipes),
               HighwayBuilder, CityBuilder (layout as data), SkyEnv, Mats
shaders/       cel bands, facade (windows in world space), mural, ring, shield, outline
ui/            Hud, DamageNumbers (Events-driven)
tests/         smoke_test (headless rules), screenshot (renders viewpoints)
```

New archetype = a factory like `Gunslinger.create()` that adds Ability nodes and a
palette. Controllers never touch physics; they set `move_input`, `aim_*` and call
`press_ability / try_dash / try_dodge`, so a network client slots in the same way.

Bounty/threat: `BountyComponent.threat()` (0..1, streak based) already scales the rim glow,
speed trail width/length and afterimage density. F8 adds streak so you can see it.

## Tests

```
godot --headless --fixed-fps 60 res://tests/smoke_test.tscn                  # rules
xvfb-run -a godot --rendering-driver vulkan res://tests/screenshot.tscn      # PNGs in tests/out
```

## Not built yet (deliberately)

Ultimate, alternate move variants, cosmetics, leaderboard murals, other districts
(transit station, park, stadium...), other archetypes, netcode, crowds, subway trains.
The layout in `CityBuilder.BLOCKS` and the recipes in `BuildingFactory` are where districts grow.
