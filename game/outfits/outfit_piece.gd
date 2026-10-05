class_name OutfitPiece
extends Resource
## One primitive mesh of an outfit part: a shape, its size, where it sits on
## the body (metres, feet at y = 0, facing -Z) and how it's coloured.

enum Shape {BOX, SPHERE, CYLINDER, CAPSULE}
enum ColorMode {
	TINT,     ## the outfit tint (or the hero's accent colour if no tint is picked)
	BODY,     ## the hero's body colour
	FIXED,    ## always `color`
}

@export var shape := Shape.BOX
## BOX: full size. SPHERE: x = diameter. CYLINDER: x = top diameter,
## z = bottom diameter, y = height. CAPSULE: x = diameter, y = height.
@export var size := Vector3(0.2, 0.2, 0.2)
@export var offset := Vector3.ZERO
@export var rotation_degrees := Vector3.ZERO
@export var color_mode := ColorMode.TINT
@export var color := Color.WHITE
## Darken (positive) or lighten (negative) the chosen colour a little, for contrast.
@export_range(-1.0, 1.0) var shade := 0.0
