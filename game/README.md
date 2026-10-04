# Meridia Hero Sandbox (`res://game/`)

The hero sandbox lives in this folder. The Meridia city (`city/`, `walk/`) and
the old Gunslinger prototype (`main.tscn`, `fighter/`, `abilities/`) are left as
they are. The architecture plan this follows is in the project's
`meridia/architecture-proposal.md`.

## Run it (M1a + M1b)

Open `game/levels/test_arena/test_arena.tscn` and press **F6** (Run Current Scene).
F5 still runs the old prototype.

| Input | Action |
|---|---|
| WASD | move |
| Shift | sprint |
| Space | jump (hold for full height, tap for a hop); against a wall in the air = wall kick (3 per airtime) |
| C or Ctrl (hold) | crouch |
| E | sigil leap toward the crosshair (look up to leap up; 2 charges) |
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
MoveStateMachine -> runs one state at a time: Ground, Air, Crouch, Mantle, DashStartup, DashLaunch
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

## Tests

```
godot --headless --fixed-fps 60 res://game/tests/m1a_movement_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m1b_sigil_leap_test.tscn
```
Drives the hero through the real arena by writing its intent (no keyboard), and
checks walk/sprint/stop speeds, jump height, short hop, coyote time, mantles,
the crouch tunnel, ramps, stairs, curbs, wall kicks, respawn, and the overlay.
