class_name CardEffect
extends Resource
## Base for the effect blocks. Each block is one small, general action
## (throw a body, damage an area, push, teleport...). Cards are made by listing
## blocks; blocks never know which card they belong to.
##
## To add a block: extend this, override apply() (and validate() if some field
## combinations make no sense), and it appears in the Inspector's "New ..." list.


## Do the thing. `ctx` says who, where, which way and what was touched.
func apply(_ctx: CastContext) -> void:
	push_error("Effect block %s has no apply(); it does nothing" % block_name())


## Problems with this block's settings on `card` (empty = fine).
func validate(_card: AbilityCard) -> PackedStringArray:
	return PackedStringArray()


func block_name() -> String:
	var s: Script = get_script()
	return s.get_global_name() if s != null else "CardEffect"


# ------------------------------------------------------------- shared helpers

const LAYER_WORLD := 1
const LAYER_CHARACTER := 2


## Everything in a sphere that can be hit (has take_hit) or pushed (has push,
## or is a physics body). Each node appears once.
static func find_in_radius(ctx: CastContext, pos: Vector3, radius: float, mask: int = LAYER_CHARACTER) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if radius <= 0.0 or ctx.caster == null or not ctx.caster.is_inside_tree():
		return out
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.collision_mask = mask
	for r in ctx.caster.get_world_3d().direct_space_state.intersect_shape(q, 64):
		var n := r.collider as Node3D
		if n != null and not out.has(n):
			out.append(n)
	return out


## The point of a node we measure distances and directions to (its chest for
## characters, its centre for everything else).
static func center_of(n: Node3D) -> Vector3:
	if n is CharacterBody3D:
		return n.global_position + Vector3.UP * 1.0
	return n.global_position
