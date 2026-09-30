class_name Compass
extends Control
## Top-centre bearing strip: cardinal letters plus every landmark that is in
## front of you, with distance. Orientation in a big vertical city comes from
## silhouettes first and this second.

var rig: CameraRig
var player: Fighter
var landmarks: Array = []
const FOV_DEG := 110.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(720, 44)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if rig == null or player == null:
		return
	var w := size.x
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, w, 46), Color(0, 0, 0, 0.35))
	draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, 30), Color(1, 1, 1, 0.8), 2.0)
	var cams := rig.yaw
	for c in [["N", 0.0], ["E", -PI * 0.5], ["S", PI], ["W", PI * 0.5]]:
		_mark(font, c[0], c[1] - cams, w, Color(1, 1, 1, 0.9), 0.0)
	var p := player.global_position
	var marks: Array = []
	for lm in landmarks:
		var pos: Vector3 = lm[1]
		var d := Vector2(pos.x - p.x, pos.z - p.z)
		if d.length() < 6.0:
			continue
		var diff := wrapf(atan2(-d.x, -d.y) - cams, -PI, PI)
		if absf(rad_to_deg(diff)) <= FOV_DEG * 0.5:
			marks.append([diff, lm[0], d.length()])
	marks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var row_end := [-1e9, -1e9]
	for m in marks:
		var x := w * 0.5 + rad_to_deg(m[0]) / (FOV_DEG * 0.5) * (w * 0.5)
		var label := "%s %dm" % [m[1], int(m[2])]
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		var row := 0 if x - sz.x * 0.5 > row_end[0] else (1 if x - sz.x * 0.5 > row_end[1] else -1)
		if row < 0:
			continue
		row_end[row] = x + sz.x * 0.5 + 6.0
		draw_string(font, Vector2(x - sz.x * 0.5, 20 + row * 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.4, 0.95))
		draw_line(Vector2(x, 24 + row * 14), Vector2(x, 30 + row * 14), Color(1.0, 0.85, 0.4), 1.5)


func _mark(font: Font, text: String, diff: float, w: float, color: Color, dist: float) -> void:
	diff = wrapf(diff, -PI, PI)
	var deg := rad_to_deg(diff)
	if absf(deg) > FOV_DEG * 0.5:
		return
	var x := w * 0.5 + deg / (FOV_DEG * 0.5) * (w * 0.5)
	var label := text if dist <= 0.0 else "%s %dm" % [text, int(dist)]
	var fs := 14 if dist <= 0.0 else 12
	var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(x - sz.x * 0.5, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	draw_line(Vector2(x, 24), Vector2(x, 30), color, 1.5)
