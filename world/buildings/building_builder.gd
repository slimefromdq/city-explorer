class_name BuildingBuilder
extends RefCounted
## Turns a BuildingPlan into real nodes: one visible box per piece, and collision.
## It makes no decisions of its own; if the plan is right, the nodes are right.
##
## Visuals vs collision: every floor is its own visible box (so you can count
## floors and see alignment), but collision is merged into ONE box per section
## of the tower. Touching collision boxes can "snag" a walking player on the
## hairline between them, and fewer shapes are cheaper for physics.
##
## Reuses Kit, so the building is a StaticBody3D on the world layer like every
## other piece of the city.


## `at` is where the footprint's north-west corner goes, in metres. For a city
## lot (a Rect2) that is simply lot.position.
static func build(parent: Node, plan: BuildingPlan, at := Vector3.ZERO) -> Node3D:
	var k := Kit.new(parent, "Building_%d" % plan.seed_value, at)
	if not plan.ok():
		push_error("BuildingBuilder: plan is not valid: %s" % ", ".join(plan.errors))
		return k.root
	var wall: Color = BuildingStyle.get_style(plan.style_name).palette[plan.palette_index]
	for piece in plan.pieces:
		k.box(BuildingGrid.bottom_centre(piece.at, piece.size), BuildingGrid.to_vec(piece.size), _material(piece, wall), false)
	for block in collision_blocks(plan):
		k.collision_box(BuildingGrid.bottom_centre(block.at, block.size), BuildingGrid.to_vec(block.size))
	return k.root


## base, each tower section (all its floors as one block), roof, rooftop.
static func collision_blocks(plan: BuildingPlan) -> Array[BuildingPlan.Piece]:
	var blocks: Array[BuildingPlan.Piece] = []
	var by_tier := {}
	for p in plan.pieces:
		if p.is_decoration():
			continue   # windows/doors are dressing on the wall: no collision
		if p.kind != "floor":
			blocks.append(p)
		elif not by_tier.has(p.tier):
			by_tier[p.tier] = BuildingPlan.Piece.new("tier", p.at, p.size, p.tier)
		else:
			var b: BuildingPlan.Piece = by_tier[p.tier]
			b.size.y = maxi(b.top(), p.top()) - b.at.y
	blocks.append_array(by_tier.values())
	return blocks


static func _material(piece: BuildingPlan.Piece, wall: Color) -> Material:
	match piece.kind:
		"base": return Mats.toon(wall.darkened(0.35))
		"roof": return Mats.toon(wall.darkened(0.45))
		"parapet": return Mats.toon(wall.darkened(0.3))
		"roof_step": return Mats.toon(wall.darkened(0.38))
		"rooftop": return Mats.toon(Color(0.55, 0.56, 0.6))
		"door": return Mats.toon(Color(0.28, 0.18, 0.12))
		"window": return Mats.glow(Color(1.0, 0.85, 0.5), 1.6) if piece.variant == 1 else Mats.toon(Color(0.1, 0.16, 0.24))
	# Alternate floors light/dark so the storeys (and any misalignment) are visible.
	return Mats.toon(wall.darkened(0.08) if piece.floor_index % 2 == 1 else wall)
