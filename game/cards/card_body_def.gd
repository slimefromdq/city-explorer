class_name CardBodyDef
extends Resource
## The physical thing a card throws, and the properties that change how it
## behaves. Each property has a visible tell so you can see WHY it acted that way:
##   bouncy - bounces `bounces` times (a soft "boing" per bounce), then expires
##   sticky - glues itself to the first thing it touches, blinks, then expires
##            after `stick_fuse` seconds
##   heavy  - darker and bigger, falls harder, and pushes things harder
##   spiky  - grows spikes and passes through targets instead of stopping

enum Shape {
	BALL,     ## a round ball
	GRENADE,  ## a ball with a cap, reads as "will explode"
	BUG,      ## a little crawler with legs
	BEAM,     ## no flying object: an instant ray (hitscan)
}

@export var shape: Shape = Shape.BALL
@export_range(0.05, 2.0, 0.01) var radius := 0.2
## Launch speed in m/s.
@export var speed := 25.0
## 0 = flies straight, 1 = normal gravity.
@export var gravity_scale := 1.0
## Seconds before it expires on its own.
@export var lifetime := 4.0
## BEAM only: how far the ray reaches.
@export var beam_range := 80.0

## A body ignores a target it already touched for this long, so a ball that
## bounces off a dummy (or gets pushed along with it) hits it once, not every
## frame they keep bumping.
@export var same_target_cooldown := 0.75

@export_group("Properties")
## Bounces before it expires. 0 = expires on its first contact (unless sticky).
@export_range(0, 20) var bounces := 0
@export_range(0.0, 1.0, 0.05) var bounciness := 0.7
@export var sticky := false
## Sticky only: seconds between sticking and expiring.
@export var stick_fuse := 0.4
@export var heavy := false
## Heavy only: how much harder it pushes and how much more gravity pulls it.
@export var heavy_mult := 1.8
@export var spiky := false
## Spiky only: how many targets it can pass through before stopping.
@export_range(1, 20) var spiky_pierce := 3
