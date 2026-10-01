# HeightRule - "how tall is a building here?"
#
# One job: the height formula, kept apart so it is easy to read and to change. The
# idea in plain words:
#   - each district type has a TALLEST and a SHORTEST height it can reach;
#   - the closer a lot is to the core centre, the nearer its height is to the tallest;
#   - a small seeded random nudge makes neighbours differ a little;
#   - the result snaps to a whole number of floors, so buildings look built, not stretched.
# So height is NOT random: randomness only adds a little variety on top of the rule.
extends RefCounted


# `roll` is a random number in [-1, 1] (from the lot's own seeded generator).
# Returns {"floors": int, "height": float}.
static func compute(distance_to_core: float, type_rules: Dictionary, shared: Dictionary, roll: float) -> Dictionary:
	var closeness := 1.0 - clampf(distance_to_core / float(type_rules["reach"]), 0.0, 1.0)  # 1 at the core, 0 at/after reach
	var span := float(type_rules["max_height"]) - float(type_rules["min_height"])
	var height := float(type_rules["min_height"]) + span * pow(closeness, float(shared["falloff_power"]))
	height *= 1.0 + float(shared["variation"]) * roll
	var floor_height := float(shared["floor_height"])
	var floors := maxi(int(shared["min_floors"]), roundi(height / floor_height))
	return {"floors": floors, "height": floors * floor_height}
