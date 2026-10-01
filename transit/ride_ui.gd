class_name RideUI
extends CanvasLayer
## The rider's panel. While the player is on a train that stands at a stop with its doors open, it
## offers the destinations of that line (a button per stop, and a strip map of the line you can click, or
## press 1-9). While the train runs it shows the next stop and the time left. It is created by whoever
## builds the walk scene: RideUI.new().bind(transit, walker).

static var blocking := false      # true while the chooser wants the mouse

var transit: TransitSystem
var walker: Walker
var _panel: PanelContainer
var _title: Label
var _info: Label
var _buttons: VBoxContainer
var _strip: Control
var _bar: ProgressBar
var _service: LineService
var _chooser_shown := false


func bind(p_transit: TransitSystem, p_walker: Walker) -> RideUI:
	transit = p_transit
	walker = p_walker
	layer = 20
	_build()
	for id in transit.services:
		var svc: LineService = transit.services[id]
		svc.departed.connect(_on_departed)
		svc.arrived.connect(_on_arrived)
	return self


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -300.0
	_panel.offset_right = 300.0
	_panel.offset_top = -250.0
	_panel.offset_bottom = -20.0
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	box.add_child(_title)
	_strip = LineStrip.new()
	_strip.custom_minimum_size = Vector2(580, 64)
	box.add_child(_strip)
	_info = Label.new()
	box.add_child(_info)
	_buttons = VBoxContainer.new()
	box.add_child(_buttons)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(580, 12)
	_bar.show_percentage = false
	box.add_child(_bar)


func _process(_delta: float) -> void:
	if walker == null:
		return
	var svc := _service_of_player()
	if svc != _service:
		_service = svc
		_chooser_shown = false
	if svc == null:
		_panel.visible = false
		_set_blocking(false)
		return
	_panel.visible = true
	var line: Dictionary = svc.line
	var here: Dictionary = transit.routes.stop(svc.line["stops"][svc.stop_index]["stop"])
	_title.text = "%s" % line["name"]
	(_strip as LineStrip).setup(transit.routes, svc)
	if svc.state == LineService.State.RUN:
		var nxt: Dictionary = transit.routes.stop(line["stops"][svc.target_index]["stop"])
		_info.text = "Next stop: %s    (%d s)" % [nxt["name"], int(ceil(svc.run_time_left()))]
		_bar.visible = true
		_bar.value = svc.progress_fraction() * 100.0
		_clear_buttons()
		_set_blocking(false)
	else:
		_bar.visible = false
		var chooser := svc.state == LineService.State.DWELL and svc.train.player_inside
		_info.text = "%s - doors %s" % [here["name"], "open" if chooser else "closing"] if chooser else "%s" % here["name"]
		if chooser and not _chooser_shown:
			_show_chooser(svc)
		if not chooser:
			_clear_buttons()
			_set_blocking(false)


func _service_of_player() -> LineService:
	for id in transit.services:
		var svc: LineService = transit.services[id]
		if svc.train.player_inside or walker.riding == svc.train:
			return svc
	return null


func _show_chooser(svc: LineService) -> void:
	_chooser_shown = true
	_clear_buttons()
	var hint := Label.new()
	hint.text = "Choose a destination (click, or press the number):"
	_buttons.add_child(hint)
	var n := 1
	for i in svc.line["stops"].size():
		if i == svc.stop_index:
			continue
		var stop: Dictionary = transit.routes.stop(svc.line["stops"][i]["stop"])
		var b := Button.new()
		b.text = "%d   %s  (%s)" % [n, stop["name"], stop["district"]]
		b.pressed.connect(_choose.bind(svc, i))
		_buttons.add_child(b)
		n += 1
	_set_blocking(true)


func _choose(svc: LineService, index: int) -> void:
	svc.request_departure(index)
	_clear_buttons()
	_set_blocking(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if _service == null or not (event is InputEventKey) or not event.pressed:
		return
	if _service.state != LineService.State.DWELL or not _service.train.player_inside:
		return
	var n: int = int(event.keycode) - KEY_1 + 1
	var k := 1
	for i in _service.line["stops"].size():
		if i == _service.stop_index:
			continue
		if k == n:
			_choose(_service, i)
			return
		k += 1


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		c.queue_free()


func _set_blocking(on: bool) -> void:
	if on == blocking:
		return
	blocking = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif walker != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_departed(svc: LineService, _from: int, _to: int, with_player: bool) -> void:
	if with_player:
		walker.begin_ride(svc.train)


func _on_arrived(svc: LineService, _stop: int, with_player: bool) -> void:
	if with_player and walker.riding == svc.train:
		walker.end_ride()
		_chooser_shown = false


## A strip map of the line: a coloured bar, a dot per stop, the current stop ringed.
class LineStrip extends Control:
	var routes: RouteData
	var svc: LineService

	func setup(p_routes: RouteData, p_svc: LineService) -> void:
		routes = p_routes
		svc = p_svc
		queue_redraw()

	func _draw() -> void:
		if svc == null:
			return
		var color: Color = svc.line["color"]
		var n: int = svc.line["stops"].size()
		var y := 22.0
		var x0 := 50.0
		var x1 := size.x - 50.0
		draw_line(Vector2(x0, y), Vector2(x1, y), color, 8.0)
		for i in n:
			var x := lerpf(x0, x1, float(i) / maxf(n - 1, 1))
			draw_circle(Vector2(x, y), 11.0, Color.WHITE)
			draw_circle(Vector2(x, y), 7.0, color if i != svc.stop_index else Color(0.9, 0.2, 0.2))
			var nm: String = routes.stop(svc.line["stops"][i]["stop"])["name"]
			draw_string(ThemeDB.fallback_font, Vector2(x - 55.0, y + 34.0), nm, HORIZONTAL_ALIGNMENT_CENTER, 110.0, 14, Color.WHITE)
		# the train, while it runs
		if svc.state == LineService.State.RUN:
			var f := svc.progress_fraction()
			var a := float(svc.stop_index)
			var b := float(svc.target_index)
			var p := lerpf(a, b, f) / maxf(n - 1, 1)
			draw_rect(Rect2(lerpf(x0, x1, p) - 9.0, y - 7.0, 18.0, 14.0), Color(1, 1, 1))
