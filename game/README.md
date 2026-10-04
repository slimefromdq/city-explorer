# Meridia Hero Sandbox (`res://game/`)

The hero sandbox lives in this folder. The Meridia city (`city/`, `walk/`) and
the old Gunslinger prototype (`main.tscn`, `fighter/`, `abilities/`) are left as
they are. The architecture plan this follows is in the project's
`meridia/architecture-proposal.md`.

## Run it (M1: movement, sigil leap, defense)

Open `game/levels/test_arena/test_arena.tscn` and press **F6** (Run Current Scene).
F5 still runs the old prototype.

| Input | Action |
|---|---|
| WASD | move |
| Shift | sprint |
| Space | jump (hold for full height, tap for a hop); against a wall in the air = wall kick (3 per airtime) |
| C or Ctrl (hold) | crouch |
| E | sigil leap toward the crosshair (look up to leap up; 2 charges) |
| Q or Alt | dodge roll (ground only; i-frames; rolls backwards if no direction held) |
| F or right mouse (hold) | block (front arc; first 0.15 s = perfect block) |
| run + jump into a ledge | mantle up (ledges 0.35 to 2.5 m above your feet) |
| F5 | respawn |
| F3 | toggle the debug overlay |
| Esc | free the mouse (click to capture again) |

## Tune it

Every movement number is in `hero/movement/default_tuning.tres`. Select it in
the FileSystem dock and edit it in the Inspector. The arena geometry is plain
CSG boxes under `Geometry/` in the arena scene, so you can move or add them in the editor.

## How the pieces connect

```
HeroPlayerInput  -> writes Hero.intent (what you want; no rules)
Hero             -> each physics tick: motor timers -> active state -> facing
MoveStateMachine -> runs one state at a time: Ground, Air, Crouch, Mantle, DashStartup, DashLaunch, Roll, Block, Hitstun
HeroDefense      -> health, guard, and what a hit does (DODGED / PERFECT_BLOCK / BLOCKED / GUARD_BREAK / HIT)
HeroMotor        -> the only code that moves the body (velocity parts, step-up, ledge checks)
ShoulderCamera   -> mouse look + aim ray; never moves the hero
movement events  -> Hero.movement_event signal + Events.movement_event (overlay listens)
```

## The sigil leap

E locks the direction (camera aim), spends a charge and enters DashStartup:
~0.2 s where you hang nearly still and can't cancel, while `vfx/sigil/sigil.tscn`
draws itself in behind you (flattened onto a wall if one is there). Then
DashLaunch carries you `dash_distance` metres. Events: OnDashStart (press),
OnSigilFormed (end of windup), OnDashLaunch (leaving the sigil). The sigil is a
visual only and frees itself after fading. Restyle it in `sigil.tscn` /
`sigil.gdshader`; sounds are synthesized placeholders (`audio/placeholder_sfx.gd`).

## Defense and the combat yard

Attacks build a `HitData` (core/hit_data.gd) and call `hero.take_hit(hit)`;
`hero/defense/hero_defense.gd` decides the result and shows it (floating text,
flash, sound, camera shake). The combat yard (south-west of spawn) has
`enemies/training_dummy.tscn` instances; pick each one's attack in the Inspector:
SWING (orange, blockable), SHOOT (yellow orbs), SLAM (purple, unblockable: roll
it), NONE (punching bag). A perfect block staggers the dummy.

## Tests

```
godot --headless --fixed-fps 60 res://game/tests/m1a_movement_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m1b_sigil_leap_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m1c_defense_test.tscn
```
Drives the hero through the real arena by writing its intent (no keyboard), and
checks walk/sprint/stop speeds, jump height, short hop, coyote time, mantles,
the crouch tunnel, ramps, stairs, curbs, wall kicks, respawn, and the overlay.
