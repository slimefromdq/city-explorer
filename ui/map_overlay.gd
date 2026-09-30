class_name MapOverlay
extends Control
## Full-screen map (M). Drawn straight from CityLayout so it can never drift
## from the real city: district-coloured cells, the two elevated roads, the
## sky rail, landmarks and your position/heading.

var rig: CameraRig
var player: Fighter
var landmarks: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.03, 0.08, 0.86))
	var world := Vector2(CityLayout.PLAY_X * 2.0, CityLayout.PLAY_Z * 2.0)
	var sc := minf(vp.x * 0.86 / world.x, vp.y * 0.82 / world.y)
	var origin := vp * 0.5
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(origin - world * sc * 0.5, world * sc), Color(0.12, 0.13, 0.18))
	# cells
	for r in CityLayout.ROWS:
		for c in CityLayout.COLS:
			var id: String = CityLayout.GRID[r][c]
			var ctr := CityLayout.cell_center(c, r)
			var col: Color = CityLayout.DISTRICT_COLORS[CityLayout.district_of(id)]
			var rect := Rect2(origin + (ctr - Vector2(CityLayout.HALF, CityLayout.HALF)) * sc, Vector2(CityLayout.BLOCK, CityLayout.BLOCK) * sc)
			draw_rect(rect, col.darkened(0.35))
	var park := CityLayout.park_rect()
	draw_rect(Rect2(origin + park.position * sc, park.size * sc), CityLayout.DISTRICT_COLORS["park"].darkened(0.25))
	# elevated roads
	draw_line(origin + Vector2(-CityLayout.PLAY_X, 41.0) * sc, origin + Vector2(CityLayout.PLAY_X, 41.0) * sc, Color(1.0, 0.75, 0.3), 3.0)
	draw_line(origin + Vector2(205.0, -CityLayout.PLAY_Z) * sc, origin + Vector2(205.0, CityLayout.PLAY_Z) * sc, Color(1.0, 0.55, 0.3), 3.0)
	var rail := PackedVector2Array([Vector2(-CityLayout.PLAY_X, -123), Vector2(123, -123), Vector2(123, 123), Vector2(CityLayout.PLAY_X, 123)])
	for i in rail.size() - 1:
		draw_line(origin + rail[i] * sc, origin + rail[i + 1] * sc, Color(0.5, 0.8, 1.0), 2.0)
	for lm in landmarks:
		var pos: Vector3 = lm[1]
		var p := origin + Vector2(pos.x, pos.z) * sc
		draw_circle(p, 3.5, Color(1.0, 0.9, 0.4))
		draw_string(font, p + Vector2(6, 4), lm[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
	if player != null and rig != null:
		var pp := origin + Vector2(player.global_position.x, player.global_position.z) * sc
		var fwd := Vector2(-sin(rig.yaw), -cos(rig.yaw))
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pp + fwd * 11.0, pp - fwd * 7.0 + side * 6.0, pp - fwd * 7.0 - side * 6.0]), Color(0.3, 1.0, 0.6))
	draw_string(font, Vector2(24, 34), "CITY MAP   (M to close)   N is up", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var y := 62.0
	for k in CityLayout.DISTRICT_COLORS.keys():
		draw_rect(Rect2(24, y - 11, 14, 14), CityLayout.DISTRICT_COLORS[k])
		draw_string(font, Vector2(46, y), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		y += 22.0
