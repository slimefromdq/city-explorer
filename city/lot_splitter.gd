# LotSplitter - cuts one block into building lots.
#
# One job: the cutting rule. Take the block's smallest enclosing rectangle, cut it
# across its LONG side (so every lot keeps a street frontage), and repeat on each
# half until every piece is small enough. The cut is not always dead centre: a seeded
# random nudge makes lots uneven in a natural way, yet identical on every run.
extends RefCounted

const Geo2D := preload("res://city/geo2d.gd")

const MAX_DEPTH := 14  # safety net against runaway splitting
const BIG := 100000.0  # a "half-plane" is a huge rectangle


# Returns the lot polygons. max_area/min_width come from the district type in the JSON.
static func split(poly: PackedVector2Array, max_area: float, min_width: float, jitter: float, rng: RandomNumberGenerator, depth: int = 0) -> Array:
	var area := Geo2D.polygon_area(poly)
	if area <= max_area or depth >= MAX_DEPTH:
		return [poly]
	var rect := Geo2D.min_area_rect(poly)
	if rect.is_empty():
		return [poly]
	var half_long: float = rect["half"].x
	# Too narrow to cut into two lots of at least min_width: keep it as one lot.
	if half_long * 2.0 < min_width * 2.0:
		return [poly]
	# Where along the long side to cut: near the middle, nudged by the seed.
	var fraction := 0.5 + (rng.randf() * 2.0 - 1.0) * jitter
	var cut: float = (fraction - 0.5) * 2.0 * half_long
	if half_long + cut < min_width or half_long - cut < min_width:
		cut = 0.0
	var result: Array = []
	for side in [-1.0, 1.0]:
		for piece in Geometry2D.intersect_polygons(poly, _half_plane(rect, cut, side)):
			result.append_array(split(piece, max_area, min_width, jitter, rng, depth + 1))
	return result


# A huge rectangle covering everything on one side of the cut line.
static func _half_plane(rect: Dictionary, cut: float, side: float) -> PackedVector2Array:
	var u: Vector2 = rect["u"]
	var v := u.orthogonal()
	var c: Vector2 = rect["center"] + u * cut
	var far := c + u * side * BIG
	return PackedVector2Array([c + v * BIG, far + v * BIG, far - v * BIG, c - v * BIG])
