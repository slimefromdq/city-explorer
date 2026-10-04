extends CanvasLayer
## F3 debug overlay for the player hero. It only LISTENS (to the global Events
## bus and by reading the hero), so nothing in the game depends on it existing.
##
## Shows: speed and velocity, grounded state, the active movement state, jump
## and wall-kick timers, and the most recent movement events.
## It stays hidden in scenes that have no player hero (e.g. the old prototype).

const MAX_EVENTS := 10

var visible_wanted := true
var _panel := PanelContainer.new()
var _label := Label.new()
var _events: Array[String] = []
var _hero: Hero


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.72)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override(&"panel", style)
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Menlo", "monospace"])
	_label.add_theme_font_override(&"font", mono)
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color(0.85, 0.95, 1.0))
	_label.add_theme_constant_override(&"line_spacing", 1)
	_panel.add_child(_label)
	add_child(_panel)
	_panel.visible = false
	Events.movement_event.connect(_on_movement_event)
	Events.hero_state_changed.connect(_on_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dbg_overlay"):
		visible_wanted = not visible_wanted


func _on_movement_event(hero: Node3D, type: int, data: Dictionary) -> void:
	if hero != _hero:
		return
	var extra := ""
	for k in data:
		var v = data[k]
		extra += "  %s=%s" % [k, ("%.1f" % v) if v is float else str(v)]
	_push("%7.2fs  %s%s" % [_now(), MoveEvent.name_of(type), extra])


func _on_state_changed(hero: Node3D, from: StringName, to: StringName) -> void:
	if hero == _hero and from != &"":
		_push("%7.2fs    state %s -> %s" % [_now(), from, to])


func _push(line: String) -> void:
	_events.push_front(line)
	if _events.size() > MAX_EVENTS:
		_events.resize(MAX_EVENTS)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_dt: float) -> void:
	if _hero == null or not is_instance_valid(_hero) or not _hero.is_inside_tree():
		_hero = get_tree().get_first_node_in_group(&"player_hero") as Hero
		_events.clear()
	_panel.visible = visible_wanted and _hero != null
	if not _panel.visible:
		return
	var h := _hero
	var m := h.motor
	var t := h.tuning
	var v := h.velocity
	var lines := PackedStringArray()
	lines.append("MERIDIA DEBUG  (F3 hide)        %d fps" % Engine.get_frames_per_second())
	lines.append("state      %s   (%.2f s)" % [h.states.current_name, h.states.time_in_state])
	lines.append("speed      %5.1f m/s  horizontal    %+5.1f m/s  vertical" % [h.horizontal_speed(), v.y])
	lines.append("position   %7.1f %6.1f %7.1f" % [h.global_position.x, h.global_position.y, h.global_position.z])
	lines.append("grounded   %s     crouched %s" % [_yn(m.on_floor), _yn(m.crouched)])
	lines.append("jump       coyote %.2f   buffer %.2f" % [m.coyote_left, m.jump_buffer_left])
	lines.append("wall       %s   kicks used %d/%d" % ["touching" if m.wall_left > 0.0 else "-", m.wall_kicks_used, t.wall_kicks_per_air])
	lines.append("dash       not built yet (M1b)")
	lines.append("roll       not built yet (M1c)")
	lines.append("block      not built yet (M1c)")
	lines.append("")
	lines.append("recent events (newest first)")
	for e in _events:
		lines.append(e)
	_label.text = "\n".join(lines)


func _yn(b: bool) -> String:
	return "yes" if b else "no "
