# DebugDraw - drawing helpers shared by the debug map layers.
#
# One job: draw text labels. Godot draws text through a specific CanvasItem, so
# the surface map and the underground layer both call this instead of each
# keeping their own copy.
extends RefCounted


static func label(canvas: CanvasItem, pos: Vector2, text: String, size: int, color: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var font := ThemeDB.fallback_font
	if outline.a > 0.0:
		for off in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			canvas.draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
	canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
