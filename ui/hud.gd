class_name Hud
extends CanvasLayer
## Code-built HUD. Deliberately sparse: the meters that matter are ALSO on the
## character (ring + bubble), so this is for exact numbers and cooldowns.

var fighter: Fighter
var game: Node

var _root := Control.new()
var _hp: ProgressBar
var _guard: ProgressBar
var _ammo: Label
var _slots: Array[Dictionary] = []
var _dodge_label: Label
var _dash_label: Label
var _streak: Label
var _feed: VBoxContainer
var _help: Label
var _mode: Label
var _center := Control.new()
var _hit_marker := 0.0
var _death: Label


func _ready() -> void:
	layer = 5
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# crosshair (drawn)
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.draw.connect(_draw_cross)
	_root.add_child(_center)

	var bl := VBoxContainer.new()
	bl.position = Vector2(24, 0)
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(24, -190)
	bl.custom_minimum_size = Vector2(330, 0)
	_root.add_child(bl)
	_hp = _bar(bl, "HP", Color(0.45, 1.0, 0.55))
	_guard = _bar(bl, "GUARD", Color(0.4, 0.85, 1.0))
	var row := HBoxContainer.new()
	bl.add_child(row)
	_dodge_label = _text(row, "", 16, Color(1.0, 0.9, 0.4))
	_dash_label = _text(row, "", 16, Color(0.85, 0.55, 1.0))
	_ammo = _text(bl, "", 22, Color(1.0, 0.95, 0.85))

	# ability slots, bottom centre
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb.position = Vector2(-260, -110)
	hb.add_theme_constant_override("separation", 10)
	_root.add_child(hb)
	var names := ["1", "2", "3", "4"]
	for i in 4:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(120, 64)
		hb.add_child(p)
		var n := _text(p, "", 14, Color.WHITE)
		n.position = Vector2(8, 4)
		var cd := ColorRect.new()
		cd.color = Color(0, 0, 0, 0.6)
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(cd)
		var t := _text(p, "", 20, Color(1, 1, 1))
		t.position = Vector2(8, 34)
		_slots.append({"panel": p, "name": n, "cd": cd, "time": t, "key": names[i]})

	_streak = _text(_root, "", 22, Color(1.0, 0.85, 0.35))
	_streak.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_streak.position = Vector2(-330, 20)
	_streak.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_streak.custom_minimum_size = Vector2(300, 0)

	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.position = Vector2(-380, 80)
	_root.add_child(_feed)
	Events.feed.connect(_on_feed)
	Events.hit_resolved.connect(_on_hit)

	_mode = _text(_root, "", 16, Color(0.8, 0.9, 1.0))
	_mode.position = Vector2(24, 20)
	_help = _text(_root, "", 15, Color(0.85, 0.9, 1.0))
	_help.position = Vector2(24, 50)
	_help.text = _help_text()

	_death = _text(_root, "", 48, Color(1.0, 0.4, 0.35))
	_death.set_anchors_preset(Control.PRESET_CENTER)
	_death.position = Vector2(-200, -60)
	_death.visible = false


func _help_text() -> String:
	return "\n".join([
		"WASD move  SHIFT sprint  SPACE jump (wall-kick on walls)",
		"E air-dash toward the CROSSHAIR (look up = rooftop)  Q dodge  F/RMB block",
		"LMB quickdraw combo  1 Burst  2 Slide-shot  3 Ricochet  4 Snapshot (hold, release)  R reload",
		"F1 help  F2 teleport  F5 reset meters/cooldowns  F6 respawn bots  F7 bot mode  F8 +streak  F9 rain",
	])


func _bar(parent: Control, label: String, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(320, 22)
	b.show_percentage = false
	b.max_value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	b.add_theme_stylebox_override("background", bg)
	parent.add_child(b)
	var l := _text(b, label, 13, Color(0, 0, 0, 0.8))
	l.position = Vector2(8, 2)
	return b


func _text(parent: Control, t: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _draw_cross() -> void:
	var f := fighter
	var gap := 6.0
	var c := Color(1, 1, 1, 0.9)
	if f != null and f.channel != null:
		c = Color(1.0, 0.35, 0.3, 0.95)
		gap = lerpf(26.0, 4.0, clampf(f.channel.charge_visual, 0.0, 1.0))
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_center.draw_line(d * gap, d * (gap + 7.0), c, 2.0)
	_center.draw_circle(Vector2.ZERO, 1.5, c)
	if _hit_marker > 0.0:
		var m := Color(1.0, 0.9, 0.4, _hit_marker)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_center.draw_line(d * 10.0, d * 18.0, m, 3.0)


func _on_hit(attacker: Node3D, _victim: Node3D, result: int, _amount: float, _pos: Vector3) -> void:
	if attacker == fighter and result != HitData.Result.DODGED:
		_hit_marker = 1.0


func _on_feed(text: String) -> void:
	var l := _text(_feed, text, 16, Color.WHITE)
	get_tree().create_timer(5.0).timeout.connect(l.queue_free)
	while _feed.get_child_count() > 6:
		_feed.get_child(0).queue_free()
		break


func set_mode_text(t: String) -> void:
	_mode.text = t


func toggle_help() -> void:
	_help.visible = not _help.visible


func _process(dt: float) -> void:
	if fighter == null:
		return
	var f := fighter
	_hit_marker = maxf(0.0, _hit_marker - dt * 4.0)
	_center.queue_redraw()
	_hp.value = f.health / f.max_health * 100.0
	_guard.value = f.guard.fraction() * 100.0
	(_guard.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color(1.0, 0.35, 0.3) if f.guard.fraction() < 0.3 else Color(0.4, 0.85, 1.0)
	_dodge_label.text = "DODGE %s   " % _pips(f.dodge.pool.available(), f.dodge.pool.max_charges)
	_dash_label.text = "DASH %s" % _pips(f.loco.dash_pool.available(), f.loco.dash_pool.max_charges)
	if f.gun != null:
		_ammo.text = "RELOADING..." if f.gun.reloading else "AMMO  %d / %d" % [f.gun.ammo, f.gun.mag_size]
	for i in 4:
		var a: Ability = f.kit[i + 1]
		var s: Dictionary = _slots[i]
		(s.name as Label).text = "%s  %s" % [s.key, a.ability_name]
		var frac := a.cooldown_fraction()
		var cd := s.cd as ColorRect
		cd.anchor_top = 1.0 - frac
		cd.offset_top = 0.0
		(s.time as Label).text = "%.1f" % a.cd_left if a.cd_left > 0.0 else "READY"
	_streak.text = "STREAK %d   BOUNTY $%d\nSCORE %d   K/D %d/%d" % [f.bounty.streak, f.bounty.value(), f.bounty.score, f.bounty.kills, f.bounty.deaths]
	_death.visible = not f.alive
	_death.text = "DOWN - respawning"


func _pips(n: int, m: int) -> String:
	var s := ""
	for i in m:
		s += "●" if i < n else "○"
	return s
