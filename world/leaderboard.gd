class_name Leaderboard
extends Node3D
## Giant rooftop billboard that doubles as the leaderboard: top bounties in the
## match, refreshed once a second. Prototype version is text over a mural; the
## full version swaps the text for painted portraits of the top fighters.

var size := Vector2(24.0, 11.0)
var _title: Label3D
var _rows: Label3D
var _t := 0.0


func _ready() -> void:
	var legs := Kit.new(self, "Frame")
	var steel := Mats.toon(Color(0.14, 0.15, 0.19))
	for sx in [-size.x * 0.4, size.x * 0.4]:
		legs.box(Vector3(sx, 0.0, -0.4), Vector3(0.6, 3.0, 0.6), steel, false)
	legs.box(Vector3(0, 3.0, 0), Vector3(size.x + 0.8, size.y + 0.8, 0.5), steel, false)
	var m := Mats.mural(Color(0.15, 0.1, 0.45), Color(0.02, 0.02, 0.15), Color(1.0, 0.4, 0.6), 3.0, size.x / size.y, 1.0)
	legs.mural_quad(Vector3(0, 3.0 + size.y * 0.5 + 0.4, 0.28), size, 0.0, m)
	_title = _label(Vector3(0, 3.0 + size.y - 1.6, 0.32), 2.6, Color(1.0, 0.85, 0.35))
	_title.text = "MOST WANTED"
	_rows = _label(Vector3(0, 3.0 + size.y * 0.5 - 0.6, 0.32), 1.6, Color.WHITE)
	_rows.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _label(pos: Vector3, px: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.font_size = 96
	l.pixel_size = px / 96.0
	l.modulate = color
	l.shaded = false
	l.outline_size = 0
	l.position = pos
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	var list: Array = get_tree().get_nodes_in_group(&"fighters")
	list.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.bounty.value() > b.bounty.value())
	var lines := PackedStringArray()
	for i in mini(3, list.size()):
		var f: Fighter = list[i]
		lines.append("%d.  %s   $%d" % [i + 1, f.display_name, f.bounty.value()])
	_rows.text = "\n".join(lines)
