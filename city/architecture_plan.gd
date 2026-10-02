extends RefCounted
## Presentation geometry inside the existing footprint/height envelope. Ordinary
## walls remain batched; planted roofs retain their full, level garden support.
const BuildingPlan := preload("res://city/building_plan.gd")
const STONE := Color(0.78, 0.73, 0.62)
const LIGHT_STONE := Color(0.90, 0.86, 0.76)
const GLASS := Color(0.16, 0.34, 0.40)
const METAL := Color(0.30, 0.39, 0.43)
const COPPER := Color(0.36, 0.54, 0.48)
const TILE := Color(0.55, 0.29, 0.21)
const DARK := Color(0.16, 0.20, 0.23)

var buildings: Array = []  # ordinary body copies, with render_height
var parts: Array = []      # local boxes / roof prisms / cylinders
var civic: Array = []
var families := {}
var _roof_allowance := 0.0
var _terrain
var _sightlines

func _init(building_plan, greenery_plan, city: Dictionary, terrain = null, sightlines = null) -> void:
	_terrain = terrain
	_sightlines = sightlines
	_roof_allowance = float(city["greenery"]["roof_garden_height"])
	var planted := {}
	for roof in greenery_plan.roofs:
		planted[roof["building"]] = true
	for b in building_plan.buildings:
		if b["group"] == "civic":
			_civic(b, city)
			continue
		var body: Dictionary = b.duplicate()
		var h := float(b["height"])
		var size: Vector2 = b["size"]
		var seed := absi(hash("architecture:%s" % b["id"]))
		var family := "garden_parapet" if planted.has(b["id"]) else "flat_parapet"
		body["render_height"] = h
		if b["group"] == "harbour":
			# Recess the warehouse wall by 2 cm behind the loading-door panels.
			body["render_size"] = size - Vector2(0, 0.04)
		if planted.has(b["id"]) or seed % 4 == 0:
			_parapet(b)
		else:
			match b["group"]:
				"core", "financial":
					family = "stepped_crown" if seed % 2 == 0 else "lantern_crown"
					var crown := minf(h * 0.12, 12.0 if b["group"] == "core" else 16.0)
					body["render_height"] = h - crown
					_add(b, "box", Vector3(0, h - crown * 0.70, 0), Vector3(size.x * 0.84, crown * 0.60, size.y * 0.84), METAL)
					_add(b, "box", Vector3(0, h - crown * 0.20, 0), Vector3(size.x * (0.60 if seed % 2 == 0 else 0.44), crown * 0.40, size.y * 0.60), COPPER if b["group"] == "financial" else GLASS)
				"midrise", "lowrise":
					family = "pitched_tile" if seed % 2 == 0 else "pitched_slate"
					var rise := minf(h * 0.18, minf(4.0, size.y * 0.26))
					body["render_height"] = h - rise
					_add(b, "gable", Vector3(0, h - rise * 0.5, 0), Vector3(size.x, rise, size.y), TILE if seed % 2 == 0 else METAL)
				"harbour":
					family = "sawtooth_warehouse"
					var rise := minf(3.5, h * 0.20)
					body["render_height"] = h - rise
					var bays := maxi(2, ceili(size.y / 10.0))
					for i in bays:
						var bay := size.y / bays
						var z := -size.y * 0.5 + bay * (i + 0.5)
						_add(b, "shed", Vector3(0, h - rise * 0.5, z), Vector3(size.x, rise, bay), METAL)
						_add(b, "box", Vector3(0, h - rise * 0.38, z + bay * 0.5 - 0.06), Vector3(size.x * 0.96, rise * 0.65, 0.10), GLASS)
		body["roof_family"] = family
		families[family] = int(families.get(family, 0)) + 1
		buildings.append(body)
		if b["group"] == "harbour":
			_loading_bays(b)

func _parapet(b: Dictionary) -> void:
	var s: Vector2 = b["size"]
	var tall := minf(0.85, _roof_allowance)
	var t := minf(0.45, minf(s.x, s.y) * 0.05)
	for sign in [-1.0, 1.0]:
		_add(b, "box", Vector3(0, b["height"] + tall * 0.5, sign * (s.y - t) * 0.5), Vector3(s.x, tall, t), METAL)
		_add(b, "box", Vector3(sign * (s.x - t) * 0.5, b["height"] + tall * 0.5, 0), Vector3(t, tall, s.y - t * 2), METAL)

func _loading_bays(b: Dictionary) -> void:
	var s: Vector2 = b["size"]
	var count := maxi(1, floori(s.x / 14.0))
	var door_h := minf(4.0, b["height"] * 0.45)
	for sign in [-1.0, 1.0]:
		for i in count:
			var x := (i - (count - 1) * 0.5) * s.x / count
			_add(b, "box", Vector3(x, door_h * 0.5, sign * (s.y * 0.5 - 0.03)), Vector3(minf(5.0, s.x / count * 0.6), door_h, 0.06), DARK)
			_add(b, "box", Vector3(x, door_h + 0.18, sign * (s.y * 0.5 - 0.35)), Vector3(minf(6.0, s.x / count * 0.8), 0.30, 0.70), COPPER)

func _civic(b: Dictionary, city: Dictionary) -> void:
	b = b.duplicate()
	var title := String(b["site_kind"]).capitalize()
	var foundation := "embedded"
	for site in city["sites"]:
		if site["kind"] == b["site_kind"]:
			title = site["name"]
			foundation = site.get("foundation", "embedded")
	var first := parts.size()
	var s: Vector2 = b["size"]
	var h := float(b["height"])
	# Full foundation and a lower solid plinth hide slope gaps and retain the
	# conservative footprint used by the discovery walk's existing collision.
	var foundation_depth := 3.0
	if foundation == "terrace" and _terrain != null:
		var low := BuildingPlan.base_elevation(b["center"], b["u"], s, _terrain)
		var high := low
		for x in 9:
			for z in 9:
				var p: Vector2 = b["center"] + b["u"] * s.x * (float(x) / 8 - 0.5) + b["u"].orthogonal() * s.y * (float(z) / 8 - 0.5)
				high = maxf(high, _terrain.height_at(p))
		b["base_y"] = high + 0.15
		foundation_depth += high + 0.15 - low
		if _sightlines != null and b["site_kind"] == "library":
			# Raising the datum can consume the west-shore view corridor's height
			# allowance. Keep the reading rooms lower instead of losing the view.
			var central_ceiling: float = _sightlines.ceiling_over(b["center"], b["u"], s * Vector2(0.28, 0.84) * 0.5)
			h = minf(h, central_ceiling - b["base_y"] - 0.05)
			var axis: Vector2 = b["u"]
			for sign in [-1.0, 1.0]:
				var front: Vector2 = b["center"] + Vector2(-axis.y, axis.x) * sign * s.y * 0.46
				var beam_ceiling: float = _sightlines.ceiling_over(front, axis, s * Vector2(0.96, 0.07) * 0.5)
				h = minf(h, (beam_ceiling - b["base_y"] - 2.35) / 0.55)
	if b["site_kind"] == "library" and foundation == "terrace":
		# Leave an opening through the retaining wall for the arrival stair.
		for sign in [-1.0, 1.0]:
			_add(b, "box", Vector3(sign * (s.x * 0.25 + 2.5), (1.5 - foundation_depth) * 0.5, 0), Vector3(s.x * 0.5 - 5, foundation_depth + 1.5, s.y - 0.04), STONE)
		_add(b, "box", Vector3(0, (1.5 - foundation_depth) * 0.5, -s.y * 0.09), Vector3(10, foundation_depth + 1.5, s.y * 0.82 - 0.04), STONE)
	else:
		_add(b, "box", Vector3(0, (1.5 - foundation_depth) * 0.5, 0), Vector3(s.x, foundation_depth + 1.5, s.y - 0.04 if foundation == "terrace" else s.y), STONE)
	if foundation == "terrace":
		# Stone courses break up the exposed retaining face on the downhill side.
		for i in ceili(foundation_depth / 3.4):
			var y := -i * 3.4
			for sign in [-1.0, 1.0]:
				if b["site_kind"] == "library" and sign > 0:
					for side in [-1.0, 1.0]:
						_add(b, "box", Vector3(side * (s.x * 0.25 + 2.5), y, sign * (s.y * 0.5 - 0.01)), Vector3(s.x * 0.5 - 5, 0.18, 0.02), STONE.darkened(0.18))
				else:
					_add(b, "box", Vector3(0, y, sign * (s.y * 0.5 - 0.01)), Vector3(s.x, 0.18, 0.02), STONE.darkened(0.18))
	match b["site_kind"]:
		"museum":
			# A copper rotunda between two stone galleries; a park-facing colonnade.
			var r := minf(s.x * 0.22, s.y * 0.30)
			for sign in [-1.0, 1.0]:
				_add(b, "box", Vector3(sign * s.x * 0.34, h * 0.37, 0), Vector3(s.x * 0.30, h * 0.74, s.y * 0.72), LIGHT_STONE)
				_add(b, "box", Vector3(sign * s.x * 0.34, h * 0.76, 0), Vector3(s.x * 0.31, h * 0.04, s.y * 0.74), COPPER)
			_add(b, "cylinder", Vector3(0, h * 0.40, 0), Vector3(r * 2, h * 0.80, r * 2), LIGHT_STONE)
			_add(b, "cylinder", Vector3(0, h * 0.87, 0), Vector3(r * 2.08, h * 0.14, r * 2.08), COPPER)
			_add(b, "cylinder", Vector3(0, h * 0.97, 0), Vector3(r * 1.35, h * 0.06, r * 1.35), GLASS)
			_colonnade(b, h * 0.38, LIGHT_STONE)
		"library":
			# Long reading-room wings, rhythmic glazing, a raised central entrance.
			_add(b, "box", Vector3(0, h * 0.38, 0), Vector3(s.x * 0.97, h * 0.76, s.y * 0.60), STONE)
			_add(b, "gable", Vector3(0, h * 0.84, 0), Vector3(s.x * 0.96, h * 0.16, s.y * 0.58), TILE)
			_add(b, "box", Vector3(0, h * 0.82, 0), Vector3(s.x * 0.26, h * 0.16, s.y * 0.64), LIGHT_STONE)
			_add(b, "gable", Vector3(0, h * 0.95, 0), Vector3(s.x * 0.28, h * 0.10, s.y * 0.64), LIGHT_STONE)
			_colonnade(b, h * 0.55, LIGHT_STONE)
		"performance_hall":
			# Three folded copper roof volumes above a glazed foyer.
			_add(b, "box", Vector3(0, h * 0.30, 0), Vector3(s.x * 0.96, h * 0.60, s.y * 0.84), DARK)
			for i in 3:
				var tall := h * (0.40 if i == 1 else 0.30)
				_add(b, "gable", Vector3((i - 1) * s.x * 0.31, h * 0.60 + tall * 0.5, 0), Vector3(s.x * 0.31, tall, s.y * 0.84), COPPER)
			_colonnade(b, h * 0.30, LIGHT_STONE)
	# Repeated tall windows between piers, on both long facades.
	var bays := maxi(3, floori(s.x / 7.0))
	for sign in [-1.0, 1.0]:
		for i in bays:
			var x := (i - (bays - 1) * 0.5) * s.x * 0.90 / bays
			_add(b, "box", Vector3(x, h * 0.28, sign * s.y * (0.305 if b["site_kind"] == "library" else 0.405)), Vector3(s.x * 0.90 / bays * 0.68, h * 0.36, s.y * 0.015), GLASS)
		# Entrance portal sits inside the plinth, not across a sidewalk or path.
		_add(b, "box", Vector3(0, 2.8, sign * s.y * (0.33 if b["site_kind"] == "library" else 0.455)), Vector3(minf(8.0, s.x * 0.20), 3.6, s.y * 0.02), DARK)
		_add(b, "box", Vector3(0, 6, sign * s.y * (0.375 if b["site_kind"] == "library" else 0.49)), Vector3(minf(22.0, s.x * 0.40), 1.6, s.y * 0.015), DARK)
	civic.append({"building": b, "name": title, "first": first, "count": parts.size() - first})

func _colonnade(b: Dictionary, tall: float, color: Color) -> void:
	var s: Vector2 = b["size"]
	var bays := maxi(4, floori(s.x / 8.0))
	for sign in [-1.0, 1.0]:
		var z: float = sign * s.y * (0.35 if b["site_kind"] == "library" else 0.46)
		_add(b, "box", Vector3(0, tall + 1.9, z), Vector3(s.x * 0.96, 0.8, s.y * 0.07), color)
		for i in bays + 1:
			var x := -s.x * 0.45 + s.x * 0.90 * i / bays
			if b["site_kind"] == "library" and absf(x) < 5:
				continue
			_add(b, "box", Vector3(x, (tall + 1.5) * 0.5, z), Vector3(0.65, tall + 1.5, 0.65), color)

func _add(b: Dictionary, kind: String, center: Vector3, size: Vector3, color: Color) -> void:
	parts.append({"building": b, "kind": kind, "center": center, "size": size, "color": color})

func validate() -> Array[String]:
	var errors: Array[String] = []
	for part in parts:
		var b: Dictionary = part["building"]
		var c: Vector3 = part["center"]
		var half: Vector3 = part["size"] * 0.5
		var extra := _roof_allowance if b["group"] != "civic" else 0.0
		if half.x <= 0 or half.y <= 0 or half.z <= 0 or absf(c.x) + half.x > b["size"].x * 0.5 + 0.001 or absf(c.z) + half.z > b["size"].y * 0.5 + 0.001 or c.y + half.y > b["height"] + extra + 0.001:
			errors.append("Architecture leaves envelope: %s (%s)" % [b["id"], part["kind"]])
		if b.has("base_y") and _sightlines != null:
			var axis: Vector2 = b["u"]
			var position: Vector2 = b["center"] + axis * c.x + Vector2(-axis.y, axis.x) * c.z
			var ceiling: float = _sightlines.ceiling_over(position, axis, Vector2(half.x, half.z))
			if b["base_y"] + c.y + half.y > ceiling:
				errors.append("Terraced civic part %s at %s reaches %.1f m; ceiling %.1f m" % [b["id"], c, b["base_y"] + c.y + half.y, ceiling])
	return errors
