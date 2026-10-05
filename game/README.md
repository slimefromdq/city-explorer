# Meridia Hero Sandbox (`res://game/`)

The hero sandbox lives in this folder. The Meridia city (`city/`, `walk/`) and
the old Gunslinger prototype (`main.tscn`, `fighter/`, `abilities/`) are left as
they are. The architecture plan this follows is in the project's
`meridia/architecture-proposal.md`.

## Run it (M1 movement and defense, M2 cards)

Open `game/levels/test_arena/test_arena.tscn` and press **F6** (Run Current Scene).
F5 still runs the old prototype.

| Input | Action |
|---|---|
| WASD | move |
| Shift | sprint |
| Space | jump (hold for full height, tap for a hop); against a wall in the air = wall kick (3 per airtime) |
| C or Ctrl (hold) | crouch; while moving fast (sprinting, or landing from a leap) it becomes a slide that keeps your speed, speeds up downhill, and can be jumped out of |
| E | sigil leap toward the crosshair (look up to leap up; 2 charges) |
| Q or Alt | dodge roll (ground only; i-frames; 2 charges that refill over 2.5 s each; rolls backwards if no direction held) |
| F or right mouse (hold) | block (front arc; first 0.15 s = perfect block) |
| run + jump into a ledge | mantle up (ledges 0.35 to 2.5 m above your feet) |
| Left mouse (hold) | primary card (Pulse Pistol) |
| R / G / V (or 1 / 2 / 3) | ability cards 1 to 3 |
| Tab | next test loadout: basic kit, rocket kit, proc chains + movement events, status / modifier / transform |
| F4 | reload every card file from disk |
| F5 | respawn and reset the target dummies |
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
MoveStateMachine -> runs one state at a time: Ground, Air, Crouch, Slide, Mantle, DashStartup, DashLaunch, Roll, Block, Hitstun
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

## Cards (M2)

A card is a `.tres` file in `cards/library/`. It holds no code, only data:
- **Trigger:** press, hold (automatic fire), release (hold to charge; the charge scales body speed and damage), movement event (fires by itself on e.g. OnDashLaunch), proc only (only other cards cast it), or passive (always on while equipped).
- **Cost:** cooldown, charges and energy.
- **Body (optional):** what the card throws (`CardBodyDef`): a ball, grenade, bug or beam, plus bouncy / sticky / heavy / spiky.
- **Effect lists:** five lists of effect blocks, run at five moments: **on cast**, **on contact**, **on hit**, **on kill** and **on expire**.

`cards/ability_runner.gd` on the hero reads the card and runs those lists. The eight blocks are in `cards/effects/`:

| Block | What it does |
|---|---|
| Spawn body | throws the card's body (count, spread, lob angle) |
| Damage area | damages a radius, or just what was touched; feeds ON HIT / ON KILL |
| Apply impulse | pushes targets, the caster, or an area (rocket jumps) |
| Teleport | moves the caster, stopping at walls |
| Status effect | slow or burn, with a tint and a label on the target |
| Modifier | +damage, +area, +bounces, faster cooldowns...; lasts while a PASSIVE card is equipped, otherwise timed |
| Cast card | casts another card here: the proc chain |
| Transform | the thrown body becomes another card's body and takes over its lists |

**Proc chains:** every Cast card or Transform adds 1 to the chain depth. The runner (PlayerHero > Runner) stops anything deeper than `max_proc_depth` (4), and caps casts at `max_casts_per_frame` (64), so a chain can't run away. Either limit prints a warning. A card that casts itself is safe.

**Example cards:**
- **Basic:** Pulse Pistol, Ball Kick, Bug Grenade, Blink, Rocket Jump.
- **Proc chain:** Splitter Shot, which casts Shrapnel on hit.
- **Movement events:** Sigil Volley fires on OnDashLaunch, and Riposte on OnPerfectBlock.
- **Status, modifier, transform:** Ember Bomb (release trigger, burn), Overclock (passive modifiers), Hatchling Ball (a bouncy ball that turns into a Bug Grenade after its last bounce).

**Make a new card:**
1. In the FileSystem dock, duplicate a card in `cards/library/`.
2. Select the copy, change its fields in the Inspector, and save.
3. Put it in a loadout: one of `cards/loadouts/*.tres`, or the arena's Loadouts list.
4. Press F4 in-game after any edit.

Mistakes print to the Output panel and name the card and the list entry. Examples are an empty effect slot, a body with no "Spawn body", or a passive card with a non-modifier block.

The card range is north-east of spawn. It has six target dummies (floating damage numbers, a health bar, knockback, a status tint, and they fall over at 0 HP and get back up), in front of a wall and a pillar for bouncing and sticking things.

## Tests

```
godot --headless --fixed-fps 60 res://game/tests/m1a_movement_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m1b_sigil_leap_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m1c_defense_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m2a_cards_test.tscn
godot --headless --fixed-fps 60 res://game/tests/m2b_proc_chains_test.tscn
```
Drives the hero through the real arena by writing its intent (no keyboard), and
checks walk/sprint/stop speeds, jump height, short hop, coyote time, mantles,
the crouch tunnel, sliding, ramps, stairs, curbs, wall kicks, respawn, and the overlay.
