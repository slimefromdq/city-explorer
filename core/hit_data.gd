class_name HitData
extends RefCounted
## Everything a hit carries. The combat triangle lives in three fields:
##   weight     - HEAVY hits drain guard hard (heavies beat block)
##   dodgeable  - false means i-frames don't help (beats dodge)
##   blockable  - false means guard doesn't help (beats block)

enum Weight { LIGHT, HEAVY }
enum Result { NONE, HIT, BLOCKED, GUARD_BREAK, DODGED, PERFECT_BLOCK }

var attacker: Node3D
var damage := 5.0
var guard_damage := 5.0
var weight: Weight = Weight.LIGHT
var blockable := true
var dodgeable := true
var flinch := 0.0
var knockback := Vector3.ZERO
## Unit vector pointing from the victim back toward where the hit came from.
## Block only works when this is inside the victim's front arc.
var from_dir := Vector3.BACK
var position := Vector3.ZERO
var tag: StringName = &""
