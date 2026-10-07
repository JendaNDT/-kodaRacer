class_name DriverRig
extends Node3D
## The driver: torso, helmeted head, two-part arms and the steering wheel.
## Hands stay on the wheel while it turns (two-bone IK), the head looks
## into the corner, the body leans, both arms go up at the finish and the
## head wobbles after a hit. Sits at the hips; +Z is forward.

const SHOULDER := Vector3(0.27, 0.54, 0.0)
const NECK := Vector3(0.0, 0.66, 0.02)
const UPPER := 0.31
const FORE := 0.33
const WHEEL_R := 0.2

var torso: MeshInstance3D
var head: Node3D
var upper: Array = []
var fore: Array = []
var steer_node: Node3D
var steer_spin: MeshInstance3D
var cheer := 0.0
var dizzy := 0.0
var lean := 0.0
var look := 0.0

static var _cache := {}


## driver: index into Game.CHARS, wheel_pos: steering wheel centre relative
## to the hips, tilt: how far the wheel leans back towards the driver,
## lod: beyond this distance from the camera the arms and the steering
## wheel are not drawn (too small to see).
func setup(driver: int, wheel_pos: Vector3, tilt: float, mat: Material, lod: float, paint := 0) -> void:
	var m := _meshes(driver, paint)
	torso = _mi(m.torso, mat, self)
	head = Node3D.new()
	head.position = NECK
	torso.add_child(head)
	for mi in Kart._lod_pair(head, m.head, m.head_low, lod / 1.3):
		mi.material_override = mat
	for i in 2:
		upper.append(_mi(m.upper, mat, self))
		fore.append(_mi(m.fore, mat, self))
	steer_node = Node3D.new()
	steer_node.position = wheel_pos
	steer_node.rotation.x = tilt
	add_child(steer_node)
	steer_spin = _mi(m.wheel, MeshKit.shared_material(), steer_node)
	for mi in upper + fore + [steer_spin]:
		(mi as GeometryInstance3D).visibility_range_end = lod
		# too thin to matter in the sun's shadow
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reset()


func reset() -> void:
	cheer = 0.0
	dizzy = 0.0
	lean = 0.0
	look = 0.0


static func _mi(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# ================================================================== meshes
static func _meshes(driver: int, kart_paint := 0) -> Dictionary:
	var key := driver * 10 + kart_paint
	if _cache.has(key):
		return _cache[key]
	var ch: Dictionary = Game.look(driver, kart_paint)
	var suit: Color = ch.accent
	var trim: Color = ch.color
	var helm: Color = ch.helmet
	var glove := KartModel.INK if suit.get_luminance() > 0.45 else Color("f1f1ee")
	var out := {}
	var up := MeshKit.at(Vector3.ZERO, Vector3(-PI / 2.0, 0, 0))   # loft Z → up, loft Y → back

	# torso: suit with coloured side panels and collar
	var k := MeshKit.new()
	var panels := func(ang: float, z: float, _p: Vector3) -> Color:
		return trim if z > 0.6 or absf(cos(ang)) > 0.9 else suit
	k.loft(up, [[-0.1, 0.0, 0.25, 0.17, 0.17], [0.22, 0.0, 0.27, 0.17, 0.17], [0.45, 0.01, 0.31, 0.17, 0.15],
		[0.58, 0.01, 0.29, 0.15, 0.13], [0.66, 0.0, 0.13, 0.09, 0.09], [0.74, 0.0, 0.1, 0.07, 0.07]],
		panels, MeshKit.SATIN, 2.4, 16)
	out.torso = k.commit()

	# helmet: poles on the X axis so the stripes follow the rings exactly
	var lats := PackedFloat32Array([-PI / 2.0, -1.15, -0.8, -0.52, -0.37, -0.27, -0.17, 0.17, 0.27, 0.37, 0.52, 0.8,
		1.15, PI / 2.0])
	var paint := func(d: Vector3, row: int, _col: int) -> Color:
		var on_top := d.y > -0.2 or d.z < -0.3
		if on_top and row == 6:
			return trim
		if on_top and (row == 4 or row == 8):
			return suit if suit.get_luminance() > 0.2 or helm.get_luminance() < 0.25 else Color.WHITE
		return helm
	var ht := MeshKit.at(Vector3(0, 0.31, 0.03), Vector3(0, 0, -PI / 2.0))
	# visor: a shell just outside the helmet; light and mirrored on dark helmets
	var visor := Color("9cc4ea") if helm.get_luminance() < 0.3 else Color("161b26")
	for detail in [1.0, 0.5]:
		k = MeshKit.new()
		k.detail = detail
		k.sphere(ht, Vector3(0.35, 0.33, 0.37), paint, MeshKit.GLOSS, 18, 0, 0.0, 0.0, lats)
		k.sphere(MeshKit.at(Vector3(0, 0.31, 0.03)), Vector3(0.338, 0.358, 0.382), visor, MeshKit.CHROME, 10, 4,
			-0.36, 0.3, PackedFloat32Array(), -0.95, 0.95)
		out["head" if detail >= 1.0 else "head_low"] = k.commit()

	# arms: shoulder ball + upper arm, elbow ball + forearm + cuff + glove
	k = MeshKit.new()
	k.sphere(MeshKit.at(Vector3.ZERO), Vector3.ONE * 0.105, trim, MeshKit.SATIN, 10, 6)
	k.tube(MeshKit.at(Vector3.ZERO), Vector3.ZERO, Vector3(0, 0, UPPER), 0.088, suit, MeshKit.SATIN, 8, 0.08, false)
	k.sphere(MeshKit.at(Vector3(0, 0, UPPER)), Vector3.ONE * 0.082, suit, MeshKit.SATIN, 8, 4)
	out.upper = k.commit()
	k = MeshKit.new()
	k.tube(MeshKit.at(Vector3.ZERO), Vector3.ZERO, Vector3(0, 0, FORE - 0.1), 0.078, suit, MeshKit.SATIN, 8, 0.07, false)
	k.tube(MeshKit.at(Vector3.ZERO), Vector3(0, 0, FORE - 0.11), Vector3(0, 0, FORE - 0.05), 0.085, trim, MeshKit.SATIN, 8)
	k.sphere(MeshKit.at(Vector3(0, 0, FORE)), Vector3(0.085, 0.075, 0.1), glove, MeshKit.MATTE, 8, 5)
	out.fore = k.commit()

	# steering wheel: rim, three spokes, a marker at the top, coloured hub
	k = MeshKit.new()
	var rim := PackedVector2Array()
	for i in 9:
		var a := -TAU * i / 8.0
		rim.append(Vector2(cos(a) * 0.032, WHEEL_R + sin(a) * 0.032))
	k.lathe(MeshKit.at(Vector3.ZERO, Vector3(0, -PI / 2.0, 0)), rim, KartModel.INK, MeshKit.MATTE, 18)
	k.rbox(MeshKit.at(Vector3(0.1, 0, 0)), Vector3(0.18, 0.045, 0.025), 0.01, KartModel.DARK, MeshKit.MATTE, 0)
	k.rbox(MeshKit.at(Vector3(-0.1, 0, 0)), Vector3(0.18, 0.045, 0.025), 0.01, KartModel.DARK, MeshKit.MATTE, 0)
	k.rbox(MeshKit.at(Vector3(0, -0.1, 0)), Vector3(0.045, 0.18, 0.025), 0.01, KartModel.DARK, MeshKit.MATTE, 0)
	k.rbox(MeshKit.at(Vector3(0, WHEEL_R, 0)), Vector3(0.05, 0.075, 0.075), 0.02, ch.accent, MeshKit.GLOSS, 1)
	k.lathe(MeshKit.at(Vector3.ZERO, Vector3(0, PI / 2.0, 0)), PackedVector2Array([Vector2(0.03, 0.075),
		Vector2(0.045, 0.05), Vector2(0.05, 0.0)]), trim, MeshKit.GLOSS, 12)
	out.wheel = k.commit()
	_cache[key] = out
	return out


# ================================================================== animation
func update(k: Kart, delta: float, t: float) -> void:
	var sr := clampf(absf(k.speed) / maxf(1.0, k.max_speed()), 0.0, 1.0)
	pose(k.steer, k.slip, k.drift_dir if k.drift_active else 0.0, k.boost > 0.0, k.finished or k.trick > 0.0, k.spin > 0.0,
		sr, delta, t)


## The whole pose from a few numbers, so menus and the podium can animate a
## driver without a kart: steer -1..1, slip (drift angle), drift -1/0/1,
## cheering at the finish, spinning after a hit, sr = speed share 0..1.
func pose(steer: float, slip: float, drift: float, boosting: bool, cheering: bool, spinning: bool, sr: float,
		delta: float, t: float) -> void:
	cheer = move_toward(cheer, 1.0 if cheering else 0.0, delta * 2.2)
	if spinning:
		dizzy = maxf(dizzy, 1.4)
	dizzy = maxf(0.0, dizzy - delta)
	var dz := clampf(dizzy, 0.0, 1.0)
	var cw := cheer * cheer * (3.0 - 2.0 * cheer)
	var sm := 1.0 - exp(-9.0 * delta)

	# steering wheel follows the steering (and shakes while dizzy)
	steer_spin.rotation.z = steer * 1.15 * (1.0 - cw) + sin(t * 24.0) * 0.35 * dz

	# lean into the corner, a bit more while drifting; back at the finish
	var want_lean := steer * 0.17 * sr + drift * 0.1
	lean = lerpf(lean, want_lean * (1.0 - cw), sm)
	var bob := sin(t * 9.0) * 0.03 * cw
	torso.position.y = bob
	torso.rotation = Vector3(0.1 - (0.07 if boosting else 0.0) - 0.16 * cw, 0.0, lean)

	# head looks where the kart is going
	var want_look := clampf(slip * 0.9 - steer * 0.38, -0.8, 0.8)
	look = lerpf(look, want_look * (1.0 - cw), sm)
	head.rotation = Vector3(-0.28 * cw + cos(t * 10.0) * 0.22 * dz,
		look + sin(t * 10.0) * 0.45 * dz + sin(t * 4.0) * 0.25 * cw,
		-lean * 0.6 + sin(t * 10.0 + 1.3) * 0.32 * dz)

	# hands: on the rim at ten to two, or waving above the head
	var wheel_xf := steer_node.transform * steer_spin.transform
	for i in 2:
		var sx := 1.0 if i == 0 else -1.0
		var on_wheel := wheel_xf * Vector3(sx * WHEEL_R * 0.87, WHEEL_R * 0.5, -0.03)
		var wave := sin(t * 9.0 + (0.0 if i == 0 else 2.2))
		var up_high := Vector3(sx * (0.4 + 0.07 * wave), 1.18 + 0.05 * wave + bob, 0.1)
		var hand := on_wheel.lerp(up_high, cw)
		var sh := torso.transform * Vector3(sx * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		_arm(i, sh, hand, Vector3(sx, -0.6, -0.35).lerp(Vector3(sx, 0.0, -0.6), cw))


## Two-bone IK: places upper arm and forearm between shoulder and hand,
## with the elbow pushed towards `pole`.
func _arm(i: int, sh: Vector3, hand: Vector3, pole: Vector3) -> void:
	var d := hand - sh
	var dist := clampf(d.length(), 0.08, UPPER + FORE - 0.002)
	var dir := d.normalized() if d.length_squared() > 1e-8 else Vector3.FORWARD
	var a := (UPPER * UPPER - FORE * FORE + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(0.0, UPPER * UPPER - a * a))
	var pv := pole - dir * pole.dot(dir)
	pv = pv.normalized() if pv.length_squared() > 1e-8 else Vector3.UP
	var elbow := sh + dir * a + pv * h
	(upper[i] as Node3D).transform = Transform3D(_aim(elbow - sh, pv), sh)
	(fore[i] as Node3D).transform = Transform3D(_aim(sh + dir * dist - elbow, pv), elbow)


## Basis with +Z along v and +Y as close to `up` as possible.
static func _aim(v: Vector3, up: Vector3) -> Basis:
	var z := v.normalized()
	var x := up.cross(z)
	if x.length_squared() < 1e-8:
		x = Vector3.RIGHT
	x = x.normalized()
	return Basis(x, z.cross(x), z)
