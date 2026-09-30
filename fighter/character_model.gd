class_name CharacterModel
extends Node3D
## Procedural stylized humanoid (no imported assets) + all body-level feedback:
## run/aim/block/slide/dash/dodge poses, guard bubble, hit flash, speed
## afterimages that scale with the fighter's bounty threat.

var fighter: Fighter
var holds_gun := false
var palette := {}

var _pivot: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _scarf: Node3D
var _muzzle: Marker3D
var _orb: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _shell: MeshInstance3D
var _shell_mat := ShaderMaterial.new()
var _mats: Array[ShaderMaterial] = []
var _trail: Trail3D

var _phase := 0.0
var _flash := 0.0
var _squash := 0.0
var _flip := 0.0
var _ghost_t := 0.0
var _orb_t := 0.0
var _orb_color := Color.WHITE
var _orb_dur := 0.0
var _orb_size := 0.0
var _shell_i := 0.0
var _dead_t := 0.0


func set_palette(p: Dictionary) -> void:
	palette = p


func _c(key: String, def: Color) -> Color:
	return palette.get(key, def)


func _ready() -> void:
	var coat := _c("coat", Color(0.16, 0.2, 0.38))
	var trim := _c("trim", Color(0.85, 0.3, 0.25))
	var skin := _c("skin", Color(0.95, 0.75, 0.62))
	var pants := _c("pants", Color(0.12, 0.12, 0.18))
	var hat := _c("hat", Color(0.2, 0.15, 0.13))
	var metal := Color(0.75, 0.78, 0.85)

	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0.95, 0)
	add_child(_pivot)

	_part(_pivot, _capsule(0.25, 0.78), _p(0, 1.28, 0), coat)
	_part(_pivot, _cyl(0.27, 0.42, 0.72), _p(0, 0.88, 0), coat)
	_part(_pivot, _cyl(0.285, 0.285, 0.07), _p(0, 1.0, 0), trim)
	_part(_pivot, _sphere(0.18), _p(0, 1.69, 0), skin)
	_part(_pivot, _cyl(0.38, 0.38, 0.03), _p(0, 1.8, 0), hat)
	_part(_pivot, _cyl(0.17, 0.2, 0.2), _p(0, 1.91, 0), hat)
	_part(_pivot, _cyl(0.205, 0.205, 0.045), _p(0, 1.85, 0), trim)

	_scarf = Node3D.new()
	_scarf.position = _p(0, 1.5, 0.12)
	_pivot.add_child(_scarf)
	_part(_scarf, _box(Vector3(0.2, 0.07, 0.6)), Vector3(0, 0, 0.3), trim)

	_leg_l = _limb(Vector3(-0.13, 0, 0), 0.11, 0.95, pants, hat)
	_leg_r = _limb(Vector3(0.13, 0, 0), 0.11, 0.95, pants, hat)
	_leg_l.position = _p(-0.13, 0.95, 0)
	_leg_r.position = _p(0.13, 0.95, 0)
	_pivot.add_child(_leg_l)
	_pivot.add_child(_leg_r)

	_arm_l = _limb(Vector3.ZERO, 0.08, 0.62, coat, skin)
	_arm_r = _limb(Vector3.ZERO, 0.08, 0.62, coat, skin)
	_arm_l.position = _p(-0.33, 1.47, 0)
	_arm_r.position = _p(0.33, 1.47, 0)
	_pivot.add_child(_arm_l)
	_pivot.add_child(_arm_r)

	if holds_gun:
		var gun := Node3D.new()
		gun.position = Vector3(0, -0.62, -0.05)
		gun.rotation.x = -PI * 0.5
		_arm_r.add_child(gun)
		_part(gun, _box(Vector3(0.07, 0.13, 0.22)), Vector3(0, -0.02, 0), metal)
		_part(gun, _box(Vector3(0.05, 0.05, 0.3)), Vector3(0, 0.03, -0.24), metal)
		_muzzle = Marker3D.new()
		_muzzle.position = Vector3(0, 0.03, -0.42)
		gun.add_child(_muzzle)
		# holster on the hip
		_part(_pivot, _box(Vector3(0.06, 0.18, 0.1)), _p(-0.3, 0.9, 0.06), metal)

	_orb = MeshInstance3D.new()
	_orb.mesh = _sphere(0.5)
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_orb.material_override = _orb_mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.visible = false
	(_muzzle if _muzzle != null else _pivot).add_child(_orb)

	_shell = MeshInstance3D.new()
	var sm := CapsuleMesh.new()
	sm.radius = 0.68
	sm.height = 2.15
	sm.radial_segments = 24
	sm.rings = 8
	_shell.mesh = sm
	_shell_mat.shader = load("res://shaders/shield.gdshader")
	_shell.material_override = _shell_mat
	_shell.position = Vector3(0, 1.0, 0)
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)

	_trail = Trail3D.new()
	_trail.color = _c("glow", Color(1.0, 0.8, 0.45, 0.8))
	add_child(_trail)

	fighter.loco.landed.connect(func(v: float) -> void: _squash = clampf(v / 30.0, 0.0, 0.32))
	fighter.loco.dashed.connect(_on_dashed)
	fighter.loco.mantled.connect(func() -> void: _squash = 0.12)
	fighter.respawned.connect(func() -> void:
		_trail.clear_points()
		_dead_t = 0.0)
	fighter.guard.broke.connect(func() -> void:
		VFX.ring_pulse(get_tree(), fighter.global_position + Vector3.UP * 0.1, Color(1.0, 0.35, 0.3), 3.2, 0.45))


# ------------------------------------------------------------------ building

func _p(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y - 0.95, z)


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 7
	return m


func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := Mats.toon_unique(color, 0.0, true, 0.014)
	mi.material_override = mat
	_mats.append(mat)
	mi.position = pos
	parent.add_child(mi)
	return mi


## A limb hangs down from its pivot: capsule + a cap (hand/boot).
func _limb(offset: Vector3, r: float, length: float, color: Color, cap: Color) -> Node3D:
	var n := Node3D.new()
	_part(n, _capsule(r, length), Vector3(offset.x * 0.0, -length * 0.5, 0), color)
	_part(n, _sphere(r * 1.15), Vector3(0, -length, 0), cap)
	return n


# ------------------------------------------------------------------ hooks

func muzzle_global_position() -> Vector3:
	if _muzzle != null and _muzzle.is_inside_tree():
		return _muzzle.global_position
	return fighter.global_position + Vector3.UP * 1.4


func flash_hit() -> void:
	_flash = 1.0


func muzzle_flash(color: Color) -> void:
	_orb_color = color
	_orb_t = 0.06
	_orb_dur = 0.06
	_orb_size = 0.16


func charge_glow(color: Color, duration: float) -> void:
	_orb_color = color
	_orb_t = duration
	_orb_dur = duration
	_orb_size = 0.32


func _on_dashed(_dir: Vector3, chain: int) -> void:
	VFX.ring_pulse(get_tree(), fighter.global_position + Vector3.UP * 1.0, _c("glow", Color(1.0, 0.8, 0.45)), 2.0 + 0.4 * chain, 0.25)


# ------------------------------------------------------------------ animation

func _process(dt: float) -> void:
	if fighter == null or _pivot == null:
		return
	var f := fighter
	rotation.y = f.face_yaw
	var hv := Vector2(f.velocity.x, f.velocity.z)
	var sp := hv.length()
	var grounded := f.is_on_floor()
	var threat := f.bounty.threat()

	# death: topple backwards and sink
	if not f.alive:
		_dead_t += dt
		_pivot.rotation.x = lerpf(_pivot.rotation.x, PI * 0.5, minf(1.0, dt * 6.0))
		_pivot.position.y = lerpf(_pivot.position.y, 0.3, minf(1.0, dt * 6.0))
		_shell_mat.set_shader_parameter("intensity", 0.0)
		_orb.visible = false
		return
	_pivot.position.y = lerpf(_pivot.position.y, 0.95, minf(1.0, dt * 14.0))

	var drive := f.loco.drive
	var target_rx := 0.0
	var target_rz := 0.0
	var swing_amp := clampf(sp / 9.0, 0.0, 1.2) if grounded else 0.0
	_phase += sp * dt * 0.7
	var swing := sin(_phase) * 0.85 * swing_amp
	var leg_l := swing
	var leg_r := -swing
	var arm_l := -swing * 0.8
	var arm_r := swing * 0.8
	var aim_blend := 0.0
	if f.engage_left > 0.0 or f.channel != null:
		aim_blend = 1.0
	var pitch := asin(clampf(f.aim_dir.y, -1.0, 1.0))

	if not grounded and drive == Locomotion.Drive.NONE:
		leg_l = -0.5
		leg_r = 0.35
		arm_l = -0.5
		arm_r = 0.5
		target_rx = -0.1
	target_rx += -clampf(sp / 15.0, 0.0, 1.0) * 0.28 if grounded else 0.0

	match drive:
		Locomotion.Drive.DASH:
			var p := asin(clampf(f.loco.drive_dir.y, -1.0, 1.0))
			target_rx = -(PI * 0.5 - p) * 0.8
			leg_l = 0.5
			leg_r = 0.9
			arm_l = -0.4
			arm_r = -0.9
			aim_blend = 0.0
		Locomotion.Drive.DODGE:
			_flip += dt * TAU / 0.3
			target_rx = -_flip
			leg_l = -0.9
			leg_r = -0.9
			arm_l = -1.2
			arm_r = -1.2
			aim_blend = 0.0
		Locomotion.Drive.SLIDE:
			target_rx = 1.05
			_pivot.position.y = lerpf(_pivot.position.y, 0.62, minf(1.0, dt * 30.0))
			leg_l = 1.35
			leg_r = 1.1
			arm_l = 0.9
			aim_blend = 1.0
		_:
			_flip = 0.0
	if f.loco.mantling:
		arm_l = -PI + 0.3
		arm_r = -PI + 0.3
		leg_l = 0.4
		leg_r = -0.2
		target_rx = -0.3
		aim_blend = 0.0

	if f.guard.blocking:
		# forearms up in front of the face
		arm_l = PI * 0.5 + 0.9
		arm_r = PI * 0.5 + 0.9
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -0.55, minf(1.0, dt * 20.0))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.55, minf(1.0, dt * 20.0))
		aim_blend = 0.0
	else:
		_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.0, minf(1.0, dt * 20.0))
		_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.0, minf(1.0, dt * 20.0))

	if f.stun_left > 0.0:
		target_rx = -0.35
		target_rz = sin(Time.get_ticks_msec() * 0.03) * 0.12
		arm_l = -0.3
		arm_r = 0.3
		aim_blend = 0.0

	if aim_blend > 0.0 and holds_gun:
		arm_r = lerpf(arm_r, PI * 0.5 + pitch, aim_blend)
		arm_l = lerpf(arm_l, PI * 0.5 + pitch - 0.25, aim_blend * 0.85)

	var k := minf(1.0, dt * 22.0)
	_pivot.rotation.x = lerpf(_pivot.rotation.x, target_rx, k) if drive != Locomotion.Drive.DODGE else target_rx
	_pivot.rotation.z = lerpf(_pivot.rotation.z, target_rz, k)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, leg_l, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, leg_r, k)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, arm_l, k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, arm_r, k)
	_scarf.rotation.x = -0.15 - clampf(sp / 30.0, 0.0, 0.7) * 0.9 + sin(_phase * 0.8) * 0.06

	# landing squash
	_squash = maxf(0.0, _squash - dt * 1.6)
	scale = Vector3(1.0 + _squash * 0.5, 1.0 - _squash, 1.0 + _squash * 0.5)

	_update_feedback(dt, sp, threat)


func _update_feedback(dt: float, sp: float, threat: float) -> void:
	var f := fighter
	# hit flash + threat rim
	_flash = maxf(0.0, _flash - dt * 6.0)
	var rim := 0.25 + threat * 1.3
	for m in _mats:
		m.set_shader_parameter("flash", _flash * 0.8)
		m.set_shader_parameter("rim_amount", rim)
		m.set_shader_parameter("rim_color", _c("glow", Color(1.0, 0.8, 0.45)))

	# guard bubble: brightness = guard left, red when low, pulses on impact
	var g := f.guard.fraction()
	var target := 0.0
	if f.guard.blocking:
		target = 0.55 + 0.4 * g
	target += f.guard.flash * 0.9
	if f.stun_left > 0.0:
		target = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
	_shell_i = lerpf(_shell_i, target, minf(1.0, dt * 25.0))
	var gc := Color(1.0, 0.3, 0.25).lerp(Color(0.35, 0.85, 1.0), smoothstep(0.1, 0.5, g))
	if f.stun_left > 0.0:
		gc = Color(1.0, 0.3, 0.2)
	_shell_mat.set_shader_parameter("intensity", _shell_i)
	_shell_mat.set_shader_parameter("color", gc)

	# muzzle orb: flash / windup / snapshot charge
	var o := 0.0
	var oc := _orb_color
	if f.channel != null and f.channel.charge_visual > 0.0:
		o = 0.25 + f.channel.charge_visual * 0.9
		oc = Color(1.0, 0.35, 0.3)
	elif _orb_t > 0.0:
		_orb_t -= dt
		var prog := 1.0 - _orb_t / maxf(_orb_dur, 0.001)
		o = _orb_size * (0.6 + prog * 1.4 if _orb_dur > 0.1 else 1.0)
	_orb.visible = o > 0.0
	if o > 0.0:
		_orb.scale = Vector3.ONE * o
		_orb_mat.albedo_color = Color(oc.r, oc.g, oc.b, 0.85)

	# speed streaks + afterimages scale with threat level
	var glow := _c("glow", Color(1.0, 0.8, 0.45))
	var fast := f.loco.drive == Locomotion.Drive.DASH or sp > 14.0
	_trail.lifetime = 0.16 + threat * 0.7
	_trail.width = 0.3 + threat * 0.7
	_trail.color = Color(glow.r, glow.g, glow.b, 0.5 + threat * 0.4)
	if fast and f.alive:
		_trail.push(f.global_position + Vector3.UP * 1.0)
		_ghost_t -= dt
		if _ghost_t <= 0.0:
			_ghost_t = lerpf(0.06, 0.025, threat)
			var xf := Transform3D(Basis(Vector3.UP, f.face_yaw), f.global_position + Vector3.UP * 0.95)
			var col := Color(glow.r, glow.g, glow.b, 0.35)
			VFX.ghost(get_tree(), xf, col, 0.2 + threat * 0.55)
	elif f.alive:
		_trail.push(f.global_position + Vector3.UP * 1.0)
