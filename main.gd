extends Node3D
## Test bench composition root. Builds sky, city, player, bots, HUD and the
## debug tools. Nothing here is gameplay logic - that lives in the components.

const BOT_SPECS := [
	{"name": "Dummy", "marker": "bot_dummy", "mode": BotBrain.Mode.DUMMY, "coat": Color(0.55, 0.55, 0.6)},
	{"name": "Blocker", "marker": "bot_blocker", "mode": BotBrain.Mode.BLOCKER, "coat": Color(0.25, 0.5, 0.35)},
	{"name": "Dodger", "marker": "bot_dodger", "mode": BotBrain.Mode.DODGER, "coat": Color(0.6, 0.4, 0.15)},
	{"name": "Aggressor", "marker": "bot_aggressor", "mode": BotBrain.Mode.AGGRESSOR, "coat": Color(0.5, 0.15, 0.2)},
	{"name": "Terrace Dummy", "marker": "bot_terrace", "mode": BotBrain.Mode.DUMMY, "coat": Color(0.5, 0.5, 0.65)},
]

var city: CityBuilder
var player: Fighter
var rig: CameraRig
var controller: PlayerController
var hud: Hud
var bots: Array[Fighter] = []
var brains: Array[BotBrain] = []
var rain: Rain
var _tp_index := 0
var headless_test := false


func _ready() -> void:
	SkyEnv.build(self)
	city = CityBuilder.new()
	city.name = "City"
	add_child(city)
	city.build()
	_spawn_player()
	_spawn_bots()
	add_child(DamageNumbers.new())
	hud = Hud.new()
	hud.fighter = player
	hud.game = self
	add_child(hud)
	rain = Rain.new()
	rain.follow = rig.camera
	add_child(rain)
	_update_mode_text()


func _spawn_player() -> void:
	player = Gunslinger.create("You", {
		"coat": Color(0.16, 0.22, 0.42), "trim": Color(0.95, 0.35, 0.3),
		"glow": Color(1.0, 0.75, 0.35),
	})
	player.add_to_group(&"local_player")
	add_child(player)
	player.global_position = city.markers["player"]
	player.spawn_transform = player.global_transform
	player.face_yaw = -PI * 0.5
	rig = CameraRig.new()
	rig.target = player
	rig.yaw = -PI * 0.5
	add_child(rig)
	rig.snap_to_target()
	controller = PlayerController.new()
	controller.fighter = player
	controller.rig = rig
	add_child(controller)
	player.respawned.connect(func() -> void: rig.snap_to_target())
	Events.fighter_died.connect(_on_died)


func _spawn_bots() -> void:
	for spec in BOT_SPECS:
		var b := Gunslinger.create(spec.name, {"coat": spec.coat, "trim": Color(0.9, 0.9, 0.5), "glow": Color(0.7, 0.9, 1.0)})
		b.respawn_delay = 2.5
		add_child(b)
		b.global_position = city.markers[spec.marker]
		b.spawn_transform = b.global_transform
		var brain := BotBrain.new()
		brain.fighter = b
		brain.target = player
		brain.mode = spec.mode
		b.add_child(brain)
		bots.append(b)
		brains.append(brain)


func _on_died(victim: Node3D, _killer: Node3D) -> void:
	if victim == player:
		player.respawn_delay = Fighter.RESPAWN_DELAY


func _unhandled_input(event: InputEvent) -> void:
	if headless_test:
		return
	if event.is_action_pressed(&"dbg_help"):
		hud.toggle_help()
	elif event.is_action_pressed(&"dbg_teleport"):
		teleport_next()
	elif event.is_action_pressed(&"dbg_reset"):
		reset_all()
	elif event.is_action_pressed(&"dbg_respawn_bots"):
		for b in bots:
			b.alive = false
			b.respawn()
	elif event.is_action_pressed(&"dbg_bot_mode"):
		cycle_bot_mode()
	elif event.is_action_pressed(&"dbg_streak"):
		player.bounty.add_streak(3)
	elif event.is_action_pressed(&"dbg_rain"):
		rain.visible = not rain.visible
		rain.emitting = rain.visible


func reset_all() -> void:
	player.reset_meters()
	for b in bots:
		if b.alive:
			b.reset_meters()
	Events.popup.emit("RESET", player.global_position + Vector3.UP * 2.4, Color(0.6, 1.0, 0.8))


func cycle_bot_mode() -> void:
	# Cycle every bot except the fixed dummies through Blocker/Dodger/Aggressor.
	var next := (brains[1].mode + 1) % 4
	if next == 0:
		next = 1
	for i in bots.size():
		if i == 0 or i == 4:
			continue
		brains[i].set_mode(next)
	_update_mode_text()


func _update_mode_text() -> void:
	hud.set_mode_text("Bots (F7): %s" % BotBrain.MODE_NAMES[brains[1].mode])


func teleport_next() -> void:
	var tps: Array = city.markers["tp"]
	var t: Array = tps[_tp_index % tps.size()]
	_tp_index += 1
	teleport_player(t[1], t[2])
	Events.popup.emit(t[0], player.global_position + Vector3.UP * 2.6, Color(0.7, 0.9, 1.0))


func teleport_player(pos: Vector3, yaw: float) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.loco.reset()
	player.face_yaw = yaw
	rig.yaw = yaw
	player.reset_physics_interpolation()
	rig.snap_to_target()
