class_name KartModel
extends RefCounted
## The seven karts, one per driver (each in up to three paints), generated from rounded shapes (MeshKit).
## Only the look differs: every kart drives exactly as before.
##
## Kart space: +Z forward, +Y up, origin on the ground in the middle.
## A model is a Dictionary:
##   body        ArrayMesh with everything that does not move
##   front_mesh  one front wheel (outer face +X), mirrored for the left side
##   rear_mesh   both rear wheels on one axle
##   front/rear  {x, z, r, w}: wheel placement and size
##   seat        driver's hips, wheel: steering wheel centre, tilt: its angle
##   exhaust     right exhaust tip (the left one is mirrored)
##   size        footprint (width, length) for the blob shadow, top: height

const TIRE := Color("1d1e22")
const DARK := Color("2b2e36")
const STEEL := Color("aeb5c1")
const SHINE := Color("e3e8ef")
const INK := Color("15171c")
const LAMP := Color("fff3c9")
const TAIL := Color("ff2a2a")
const FLIP := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)
const I := Transform3D.IDENTITY
const FWD := Vector3(0, 0, 1)
const AFT := Vector3(0, 0, -1)

static var _cache := {}


static func get_model(driver: int, paint := 0) -> Dictionary:
	var key := driver * 10 + paint
	if not _cache.has(key):
		var m := _build(driver, paint, 1.0)
		var lo := _build(driver, paint, 0.5)
		m.body_low = lo.body
		m.front_low = lo.front_mesh
		m.rear_low = lo.rear_mesh
		_cache[key] = m
	return _cache[key]


## detail < 1 builds the simpler version shown on karts far from the camera.
static func _build(d: int, paint: float, detail: float) -> Dictionary:
	var ch: Dictionary = Game.look(d, int(paint))
	var kit := MeshKit.new()
	kit.detail = detail
	kit.shiny = ch.get("shiny", false)
	var num := d + 1
	var m: Dictionary
	match d:
		0: m = _formula(kit, ch, num)
		1: m = _bubble(kit, ch, num)
		2: m = _sports(kit, ch, num)
		3: m = _buggy(kit, ch, num)
		4: m = _tractor(kit, ch, num)
		5: m = _arrow(kit, ch, num)
		_: m = _roadster(kit, ch, num)
	# steering column from the wheel down into the dashboard
	var w: Vector3 = m.wheel
	var axis := Vector3(0.0, -sin(float(m.tilt)), cos(float(m.tilt)))
	kit.tube(I, w + axis * 0.04, w + axis * float(m.get("column", 0.42)), 0.035, DARK, MeshKit.MATTE, 6)
	m.body = kit.commit()
	m.tris = kit.triangles()
	var f: Dictionary = m.front
	var r: Dictionary = m.rear
	var fk := MeshKit.new()
	fk.detail = detail
	_wheel(fk, I, float(f.r), float(f.w), String(f.style), f.rim, f.cap)
	m.front_mesh = fk.commit()
	var rk := MeshKit.new()
	rk.detail = detail
	_wheel(rk, _t(Vector3(float(r.x), 0, 0)), float(r.r), float(r.w), String(r.style), r.rim, r.cap)
	_wheel(rk, _t(Vector3(-float(r.x), 0, 0)) * FLIP, float(r.r), float(r.w), String(r.style), r.rim, r.cap)
	m.rear_mesh = rk.commit()
	m.tris += fk.triangles() * 2 + rk.triangles()
	return m


static func _t(pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return MeshKit.at(pos, rot, scale)


static func _axle(x: float, z: float, r: float, w: float, style: String, rim: Color, cap: Color) -> Dictionary:
	return {"x": x, "z": z, "r": r, "w": w, "style": style, "rim": rim, "cap": cap}


# ================================================================== shared parts
## One wheel around the local X axis of t, outer face towards +X.
## style: slick, street, knobby, tractor, rib, whitewall, future.
static func _wheel(kit: MeshKit, t: Transform3D, r: float, w: float, style: String, rim: Color, cap: Color,
		both_sides := false) -> void:
	var hw := w * 0.5
	var lugs := style == "knobby" or style == "tractor"
	var rr := r * (0.55 if lugs else 0.63)
	var base := r - (0.085 * r if lugs else 0.0)
	var sh := minf(0.07, r * 0.17)
	var band: Variant = TIRE
	if style == "slick" or style == "whitewall":
		var bc: Color = cap if style == "slick" else Color("f2f2ee")
		band = func(i: int, _j: int, _c: Vector3) -> Color:
			return bc if i == 0 or i == 4 else TIRE
	elif style == "rib":
		band = func(i: int, j: int, _c: Vector3) -> Color:
			return TIRE.lightened(0.06) if i == 2 and j % 2 == 0 else TIRE
	elif style == "street":
		band = func(i: int, j: int, _c: Vector3) -> Color:
			return TIRE.lightened(0.07) if i == 2 and j % 3 == 0 else TIRE
	# sidewall, shoulder, tread, shoulder, sidewall
	var prof := PackedVector2Array([
		Vector2(-hw * 0.9, rr), Vector2(-hw, base - sh), Vector2(-hw + sh * 0.75, base),
		Vector2(hw - sh * 0.75, base), Vector2(hw, base - sh), Vector2(hw * 0.9, rr)])
	kit.lathe(t, prof, band, MeshKit.RUBBER, 16)
	# tread lugs (left out far away)
	if kit.detail < 1.0:
		pass
	elif style == "knobby":
		var n := 12
		for k in n:
			for sd in [-1.0, 1.0]:
				var ang := TAU * (k + (0.5 if sd > 0.0 else 0.0)) / n
				var depth := r - base + 0.03
				kit.rbox(t * _radial(ang, base + depth * 0.5 - 0.02, sd * hw * 0.45), Vector3(hw * 0.78, depth, r * 0.26),
					0.0, TIRE.lightened(0.03), MeshKit.RUBBER, 0)
	elif style == "tractor":
		var n := 10
		for k in n:
			for sd in [-1.0, 1.0]:
				var ang := TAU * (k + (0.5 if sd > 0.0 else 0.0)) / n
				var depth := r - base + 0.04
				var lt := t * _radial(ang, base + depth * 0.5 - 0.02, sd * hw * 0.5) * Transform3D(Basis(Vector3.UP, 0.55 * sd), Vector3.ZERO)
				kit.rbox(lt, Vector3(hw * 1.1, depth, r * 0.13), 0.0, TIRE.lightened(0.03), MeshKit.RUBBER, 0)
	# rim on the outer side (the inner one faces the chassis): dish, spokes, cap
	for sd in ([1.0, -1.0] if both_sides else [1.0]):
		var st := t if sd > 0.0 else t * FLIP
		kit.lathe(st, PackedVector2Array([Vector2(hw * 0.86, rr), Vector2(hw * 0.72, rr * 0.9),
			Vector2(hw * 0.56, rr * 0.45), Vector2(hw * 0.56, rr * 0.27)]), rim, MeshKit.CHROME, 15)
		kit.lathe(st, PackedVector2Array([Vector2(hw * 0.56, rr * 0.27), Vector2(hw * 0.64, rr * 0.21),
			Vector2(hw * 0.68, 0.0)]), cap, MeshKit.GLOSS, 10)
		for k in (5 if kit.detail >= 1.0 else 0):
			var ang := TAU * k / 5.0 + 0.3
			kit.rbox(st * _radial(ang, rr * 0.58, hw * 0.63), Vector3(hw * 0.14 + 0.02, rr * 0.6, r * 0.11),
				0.0, rim.darkened(0.12), MeshKit.CHROME, 0)
		if style == "future":
			kit.lathe(st, PackedVector2Array([Vector2(hw + 0.004, rr + (base - rr) * 0.62),
				Vector2(hw + 0.004, rr + (base - rr) * 0.4)]), cap, MeshKit.LIGHT, 16)


## Frame on a wheel: local Y points away from the axle at angle ang
## (0 = forward, PI/2 = up), at distance rad and axle offset x.
static func _radial(ang: float, rad: float, x: float) -> Transform3D:
	var radial := Vector3(0.0, sin(ang), cos(ang))
	var xa := Vector3.RIGHT
	return Transform3D(Basis(xa, radial, xa.cross(radial)), Vector3(x, 0.0, 0.0) + radial * rad)


## Start number: dark ring, white disc and the digits.
static func _roundel(kit: MeshKit, t: Transform3D, num: int, r := 0.19) -> void:
	kit.disc(t, r + 0.028, INK, MeshKit.GLOSS, 18)
	kit.disc(t * _t(Vector3(0, 0, 0.004)), r, Color.WHITE, MeshKit.GLOSS, 18)
	kit.number(t * _t(Vector3(0, 0, 0.008)), num, r * 1.1, INK)


## Numbers on both flat sides of the kart; pos is on the right (+X) side.
static func _side_numbers(kit: MeshKit, pos: Vector3, num: int, r := 0.19) -> void:
	_roundel(kit, MeshKit.decal(pos, Vector3.RIGHT), num, r)
	_roundel(kit, MeshKit.decal(Vector3(-pos.x, pos.y, pos.z), Vector3.LEFT), num, r)


## Numbers on both flanks of a loft (sections secs, exponent e) at length
## z and angle ang above the side line; offset moves the right one (the
## left one is mirrored).
static func _loft_numbers(kit: MeshKit, secs: Array, e: float, z: float, ang: float, num: int, r := 0.18,
		offset := Vector3.ZERO) -> void:
	_roundel(kit, _t(offset) * MeshKit.loft_decal(secs, z, ang, e), num, r)
	_roundel(kit, _t(Vector3(-offset.x, offset.y, offset.z)) * MeshKit.loft_decal(secs, z, PI - ang, e), num, r)


static func _seat(kit: MeshKit, hip: Vector3, back_h := 0.55, col := DARK) -> void:
	kit.rbox(_t(hip + Vector3(0, -0.06, 0.0)), Vector3(0.6, 0.1, 0.5), 0.04, col, MeshKit.MATTE, 1)
	kit.rbox(_t(hip + Vector3(0, back_h * 0.5 - 0.04, -0.29), Vector3(-0.2, 0, 0)), Vector3(0.64, back_h, 0.1), 0.045,
		col, MeshKit.MATTE, 1)


## Twin exhaust pipes running back to tip (the right one; left mirrored).
static func _pipes(kit: MeshKit, from_z: float, tip: Vector3, r := 0.075) -> void:
	for sx in [-1.0, 1.0]:
		var e := Vector3(tip.x * sx, tip.y, tip.z)
		kit.tube(I, Vector3(e.x, e.y, from_z), e, r, SHINE, MeshKit.CHROME, 10, r * 1.3)
		kit.disc(MeshKit.decal(e + Vector3(0, 0, -0.004), AFT), r * 1.05, Color("0d0d0f"), MeshKit.MATTE, 10)


## Round lamp with a chrome rim, facing `normal`.
static func _lamp(kit: MeshKit, pos: Vector3, normal: Vector3, r: float, col := LAMP) -> void:
	kit.disc(MeshKit.decal(pos, normal), r * 1.25, SHINE, MeshKit.CHROME, 14)
	kit.disc(MeshKit.decal(pos + normal.normalized() * 0.006, normal), r, col, MeshKit.LIGHT, 14)


static func _lamp_at(kit: MeshKit, t: Transform3D, r: float, col := LAMP) -> void:
	kit.disc(t, r * 1.25, SHINE, MeshKit.CHROME, 14)
	kit.disc(t * _t(Vector3(0, 0, 0.006)), r, col, MeshKit.LIGHT, 14)


## Legs for open karts: hip, knee and foot of the right leg (left mirrored).
static func _legs(kit: MeshKit, hip: Vector3, knee: Vector3, foot: Vector3, suit: Color) -> void:
	for sx in [-1.0, 1.0]:
		var h := Vector3(hip.x * sx, hip.y, hip.z)
		var k := Vector3(knee.x * sx, knee.y, knee.z)
		var f := Vector3(foot.x * sx, foot.y, foot.z)
		kit.tube(I, h, k, 0.095, suit, MeshKit.SATIN, 8)
		kit.sphere(_t(k), Vector3.ONE * 0.095, suit, MeshKit.SATIN, 8, 4)
		kit.tube(I, k, f, 0.085, suit, MeshKit.SATIN, 8)
		kit.rbox(_t(f + Vector3(0, 0.0, 0.06)), Vector3(0.16, 0.13, 0.28), 0.05, INK, MeshKit.MATTE, 1)


## Wing: a flat rounded plate.
static func _plate(kit: MeshKit, pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
	kit.rbox(_t(pos, rot), size, minf(size.y, minf(size.x, size.z)) * 0.48, col, MeshKit.GLOSS, 1)


# ================================================================== 1: Turbo Tonda – formula
static func _formula(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var front := _axle(1.0, 1.08, 0.42, 0.36, "slick", STEEL, a)
	var rear := _axle(1.0, -0.98, 0.5, 0.5, "slick", STEEL, a)
	var seat := Vector3(0, 0.66, -0.22)
	var stripe := func(ang: float, z: float, _p: Vector3) -> Color:
		return a if z > 0.15 and absf(ang - PI / 2.0) < 0.3 else c
	# monocoque from behind the seat to the nose tip
	kit.loft(I, [[-1.05, 0.55, 0.38, 0.24, 0.2], [-0.45, 0.56, 0.48, 0.28, 0.22], [0.45, 0.56, 0.44, 0.3, 0.22],
		[1.25, 0.5, 0.28, 0.21, 0.18], [2.0, 0.4, 0.15, 0.1, 0.1], [2.36, 0.36, 0.03, 0.03, 0.03]],
		stripe, MeshKit.GLOSS, 2.6, 20)
	# sidepods with radiator intakes
	var pod := [[-0.98, 0.5, 0.14, 0.12, 0.13], [-0.45, 0.5, 0.26, 0.21, 0.2], [0.25, 0.49, 0.24, 0.19, 0.18],
		[0.5, 0.48, 0.2, 0.15, 0.15]]
	for sx in [-1.0, 1.0]:
		kit.loft(_t(Vector3(0.62 * sx, 0, 0)), pod, c, MeshKit.GLOSS, 2.8, 14, true, false)
		kit.disc(MeshKit.decal(Vector3(0.62 * sx, 0.48, 0.505), FWD) * _t(Vector3.ZERO, Vector3.ZERO,
			Vector3(1.0, 0.75, 1.0)), 0.17, INK, MeshKit.MATTE, 14)
	_loft_numbers(kit, pod, 2.8, -0.35, 0.15, num, 0.16, Vector3(0.62, 0, 0))
	# number on the nose
	_roundel(kit, MeshKit.decal(Vector3(0, 0.665, 1.45), Vector3(0, 0.96, 0.27), FWD), num, 0.15)
	# engine cover rising behind the driver, with an accent spine
	var spine := func(ang: float, _z: float, _p: Vector3) -> Color:
		return a if absf(ang - PI / 2.0) < 0.25 else c
	kit.loft(I, [[-1.55, 0.72, 0.15, 0.1, 0.16], [-1.2, 0.8, 0.25, 0.24, 0.22], [-0.78, 0.88, 0.25, 0.38, 0.3],
		[-0.55, 0.9, 0.18, 0.38, 0.3], [-0.44, 0.92, 0.06, 0.22, 0.2]], spine, MeshKit.GLOSS, 2.4, 16)
	# gearbox, exhausts
	kit.rbox(_t(Vector3(0, 0.5, -1.42)), Vector3(0.55, 0.34, 0.5), 0.06, DARK, MeshKit.MATTE, 1)
	var ex := Vector3(0.3, 0.74, -1.78)
	_pipes(kit, -1.52, ex)
	# rear wing: main plane, accent flap, end plates, pylons
	_plate(kit, Vector3(0, 1.3, -1.62), Vector3(2.0, 0.07, 0.52), c, Vector3(-0.08, 0, 0))
	_plate(kit, Vector3(0, 1.43, -1.84), Vector3(1.94, 0.05, 0.26), a, Vector3(-0.38, 0, 0))
	for sx in [-1.0, 1.0]:
		_plate(kit, Vector3(1.02 * sx, 1.24, -1.7), Vector3(0.05, 0.52, 0.74), c)
		kit.rbox(_t(Vector3(0.2 * sx, 1.0, -1.56)), Vector3(0.05, 0.56, 0.16), 0.02, DARK, MeshKit.MATTE, 1)
	# front wing
	_plate(kit, Vector3(0, 0.2, 2.02), Vector3(2.2, 0.05, 0.44), c)
	_plate(kit, Vector3(0, 0.29, 1.9), Vector3(2.06, 0.04, 0.2), a, Vector3(-0.3, 0, 0))
	for sx in [-1.0, 1.0]:
		_plate(kit, Vector3(1.11 * sx, 0.27, 2.0), Vector3(0.04, 0.22, 0.5), a)
		kit.rbox(_t(Vector3(0.1 * sx, 0.28, 2.06)), Vector3(0.04, 0.16, 0.2), 0.015, DARK, MeshKit.MATTE, 0)
	# wishbones to the wheels
	for ax in [front, rear]:
		var wx: float = float(ax.x) - float(ax.w) * 0.5 - 0.02
		var wz: float = ax.z
		var wy: float = ax.r
		for sx in [-1.0, 1.0]:
			kit.tube(I, Vector3(0.3 * sx, 0.62, wz + 0.1), Vector3(wx * sx, wy + 0.06, wz), 0.028, DARK, MeshKit.MATTE, 6)
			kit.tube(I, Vector3(0.3 * sx, 0.4, wz - 0.1), Vector3(wx * sx, wy - 0.06, wz), 0.028, DARK, MeshKit.MATTE, 6)
	# mirrors and a headrest
	for sx in [-1.0, 1.0]:
		kit.tube(I, Vector3(0.36 * sx, 0.84, 0.32), Vector3(0.52 * sx, 0.98, 0.3), 0.018, DARK, MeshKit.MATTE, 5)
		kit.rbox(_t(Vector3(0.56 * sx, 1.0, 0.3)), Vector3(0.16, 0.09, 0.05), 0.02, c, MeshKit.GLOSS, 1)
	kit.rbox(_t(Vector3(0, 0.86, -0.5), Vector3(-0.2, 0, 0)), Vector3(0.62, 0.16, 0.16), 0.06, DARK, MeshKit.MATTE, 1)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.44, 0.52), "tilt": 0.62,
		"exhaust": ex, "size": Vector2(2.6, 4.4), "top": 2.15}


# ================================================================== 2: Zuzka Zběsilá – bubble
static func _bubble(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var front := _axle(0.9, 1.0, 0.34, 0.3, "whitewall", SHINE, c)
	var rear := _axle(0.92, -0.95, 0.36, 0.32, "whitewall", SHINE, c)
	var seat := Vector3(0, 0.82, -0.3)
	var belt := func(ang: float, _z: float, _p: Vector3) -> Color:
		return a if absf(sin(ang)) < 0.16 else c
	var egg := [[-1.6, 0.74, 0.45, 0.28, 0.25], [-1.35, 0.75, 0.92, 0.42, 0.38], [-0.7, 0.76, 1.1, 0.42, 0.4],
		[0.3, 0.73, 1.1, 0.38, 0.38], [1.15, 0.68, 0.95, 0.32, 0.33], [1.6, 0.62, 0.58, 0.2, 0.22],
		[1.78, 0.6, 0.2, 0.08, 0.09]]
	kit.loft(I, egg, belt, MeshKit.GLOSS, 2.2, 22)
	# bumpers
	kit.rbox(_t(Vector3(0, 0.52, -1.58)), Vector3(1.1, 0.16, 0.2), 0.07, a, MeshKit.GLOSS, 2)
	kit.rbox(_t(Vector3(0, 0.46, 1.72)), Vector3(0.9, 0.14, 0.18), 0.06, a, MeshKit.GLOSS, 2)
	# windscreen
	kit.rbox(_t(Vector3(0, 1.22, 0.62), Vector3(-0.5, 0, 0)), Vector3(1.24, 0.34, 0.05), 0.022, Color("c8ecff"), MeshKit.CHROME, 1)
	kit.rbox(_t(Vector3(0, 1.06, 0.7), Vector3(-0.5, 0, 0)), Vector3(1.3, 0.06, 0.08), 0.025, a, MeshKit.GLOSS, 1)
	# big round eyes for headlights, tail lights
	for ang in [0.62, PI - 0.62]:
		_lamp_at(kit, MeshKit.loft_decal(egg, 1.42, ang, 2.2, 0.01), 0.13)
		_lamp_at(kit, MeshKit.loft_decal(egg, -1.44, ang, 2.2, 0.01), 0.085, TAIL)
	# heart on the back
	var ht := MeshKit.decal(Vector3(0, 0.84, -1.608), AFT)
	kit.disc(ht * _t(Vector3(-0.07, 0.03, 0)), 0.085, a, MeshKit.GLOSS, 12)
	kit.disc(ht * _t(Vector3(0.07, 0.03, 0)), 0.085, a, MeshKit.GLOSS, 12)
	kit.polygon(ht, PackedVector2Array([Vector2(-0.152, 0.0), Vector2(0.152, 0.0), Vector2(0, -0.17)]), a)
	# whip antenna with a pompom
	kit.tube(I, Vector3(-0.62, 1.05, -1.18), Vector3(-0.74, 2.15, -1.36), 0.016, DARK, MeshKit.MATTE, 5)
	kit.sphere(_t(Vector3(-0.74, 2.2, -1.36)), Vector3.ONE * 0.1, c.lightened(0.25), MeshKit.GLOSS, 10, 6)
	var ex := Vector3(0.3, 0.42, -1.7)
	_pipes(kit, -1.4, ex, 0.065)
	_loft_numbers(kit, egg, 2.2, -0.3, 0.12, num, 0.19)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.42, 0.52), "tilt": 0.6,
		"exhaust": ex, "size": Vector2(2.6, 3.9), "top": 2.25}


# ================================================================== 3: Pepa Plyn – long sports car
static func _sports(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var front := _axle(1.0, 1.25, 0.44, 0.42, "street", SHINE, c)
	var rear := _axle(1.02, -1.15, 0.48, 0.5, "street", SHINE, c)
	var seat := Vector3(0, 0.66, -0.35)
	var stripes := func(ang: float, _z: float, p: Vector3) -> Color:
		return a if sin(ang) > 0.35 and absf(p.x) > 0.09 and absf(p.x) < 0.27 else c
	var shell := [[-1.98, 0.62, 0.86, 0.28, 0.3], [-1.55, 0.6, 0.96, 0.33, 0.34], [-0.6, 0.58, 0.84, 0.32, 0.32],
		[0.6, 0.52, 0.8, 0.27, 0.27], [1.6, 0.45, 0.84, 0.2, 0.2], [2.2, 0.39, 0.7, 0.12, 0.13],
		[2.42, 0.37, 0.42, 0.05, 0.08]]
	kit.loft(I, shell, stripes, MeshKit.GLOSS, 3.2, 26)
	# flared fenders over all four wheels
	for ax in [front, rear]:
		for sx in [-1.0, 1.0]:
			kit.arch(_t(Vector3(float(ax.x) * sx, float(ax.r), float(ax.z))), float(ax.r) + 0.05, float(ax.r) + 0.17,
				float(ax.w) + 0.12, 0.2, PI - 0.2, c, MeshKit.GLOSS, 12)
	# side skirts between the wheels, vents on the rear flanks
	for sx in [-1.0, 1.0]:
		kit.rbox(_t(Vector3(0.86 * sx, 0.4, 0.05)), Vector3(0.2, 0.18, 1.5), 0.07, c.darkened(0.15), MeshKit.GLOSS, 1)
		kit.rbox(_t(Vector3(0.84 * sx, 0.68, -0.85)), Vector3(0.06, 0.14, 0.42), 0.03, INK, MeshKit.MATTE, 1)
	# hump behind the driver, windscreen
	kit.loft(I, [[-1.45, 0.86, 0.05, 0.03, 0.03], [-1.1, 0.88, 0.22, 0.2, 0.05], [-0.72, 0.9, 0.22, 0.24, 0.05],
		[-0.6, 0.9, 0.18, 0.18, 0.05], [-0.56, 0.9, 0.08, 0.08, 0.03]], a, MeshKit.GLOSS, 2.4, 14)
	kit.rbox(_t(Vector3(0, 1.0, 0.32), Vector3(-0.95, 0, 0)), Vector3(1.12, 0.3, 0.04), 0.02, Color("1d2a44"), MeshKit.CHROME, 1)
	# big rear wing on swan necks
	_plate(kit, Vector3(0, 1.46, -1.74), Vector3(2.24, 0.08, 0.62), a, Vector3(-0.07, 0, 0))
	_plate(kit, Vector3(0, 1.52, -2.02), Vector3(2.16, 0.09, 0.04), c)
	for sx in [-1.0, 1.0]:
		_plate(kit, Vector3(1.13 * sx, 1.37, -1.76), Vector3(0.05, 0.44, 0.8), c)
		kit.rbox(_t(Vector3(0.42 * sx, 1.18, -1.62), Vector3(0.18, 0, 0)), Vector3(0.06, 0.56, 0.14), 0.025, DARK, MeshKit.MATTE, 1)
	# lights: slim headlights, a red bar across the tail
	for sx in [-1.0, 1.0]:
		kit.rbox(_t(Vector3(0.48 * sx, 0.47, 2.27), Vector3(-0.35, -0.25 * sx, 0)), Vector3(0.3, 0.07, 0.04), 0.015,
			LAMP, MeshKit.LIGHT, 0)
	kit.rbox(_t(Vector3(0, 0.79, -1.985)), Vector3(1.3, 0.07, 0.025), 0.01, TAIL, MeshKit.LIGHT, 0)
	kit.rbox(_t(Vector3(0, 0.37, -1.93)), Vector3(1.2, 0.1, 0.18), 0.03, DARK, MeshKit.MATTE, 1)
	var ex := Vector3(0.3, 0.44, -2.06)
	_pipes(kit, -1.8, ex)
	_loft_numbers(kit, shell, 3.2, -0.25, 0.1, num, 0.17)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.42, 0.52), "tilt": 0.62,
		"exhaust": ex, "size": Vector2(2.7, 4.8), "top": 2.15}


# ================================================================== 4: Máňa Motor – buggy
static func _buggy(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var spring: Color = ch.helmet
	var front := _axle(1.08, 1.12, 0.56, 0.5, "knobby", Color("4a4f5c"), c)
	var rear := _axle(1.1, -1.0, 0.56, 0.5, "knobby", Color("4a4f5c"), c)
	var seat := Vector3(0, 0.98, -0.3)
	var tub := func(ang: float, _z: float, _p: Vector3) -> Color:
		return a if sin(ang) < -0.25 else c
	var hull := [[-1.3, 0.92, 0.5, 0.2, 0.22], [-0.85, 0.92, 0.62, 0.26, 0.26], [0.5, 0.9, 0.58, 0.24, 0.26],
		[1.35, 0.86, 0.48, 0.14, 0.2], [1.72, 0.82, 0.36, 0.06, 0.12]]
	kit.loft(I, hull, tub, MeshKit.GLOSS, 3.0, 18)
	kit.rbox(_t(Vector3(0, 0.66, 1.55), Vector3(0.3, 0, 0)), Vector3(0.72, 0.08, 0.52), 0.03, STEEL, MeshKit.CHROME, 1)
	_seat(kit, seat, 0.62)
	# front bumper bar
	kit.tube(I, Vector3(-0.55, 0.78, 1.92), Vector3(0.55, 0.78, 1.92), 0.05, DARK, MeshKit.MATTE, 8)
	for sx in [-1.0, 1.0]:
		kit.tube(I, Vector3(0.42 * sx, 0.78, 1.92), Vector3(0.32 * sx, 0.86, 1.6), 0.04, DARK, MeshKit.MATTE, 6)
	# roll cage over the driver
	var top := 2.42
	var cage: Array = []
	for sx in [-1.0, 1.0]:
		cage.append([Vector3(0.52 * sx, 1.1, -0.74), Vector3(0.42 * sx, top, -0.74)])
		cage.append([Vector3(0.54 * sx, 1.12, 0.58), Vector3(0.42 * sx, top, 0.05)])
		cage.append([Vector3(0.42 * sx, top, 0.05), Vector3(0.42 * sx, top, -0.74)])
		cage.append([Vector3(0.42 * sx, top, -0.74), Vector3(0.34 * sx, 1.12, -1.28)])
	cage.append([Vector3(-0.42, top, -0.74), Vector3(0.42, top, -0.74)])
	cage.append([Vector3(-0.42, top, 0.05), Vector3(0.42, top, 0.05)])
	for b in cage:
		kit.tube(I, b[0], b[1], 0.045, DARK, MeshKit.MATTE, 7)
	for p in [Vector3(0.42, top, 0.05), Vector3(-0.42, top, 0.05), Vector3(0.42, top, -0.74), Vector3(-0.42, top, -0.74)]:
		kit.sphere(_t(p), Vector3.ONE * 0.06, DARK, MeshKit.MATTE, 8, 4)
	# light bar
	kit.rbox(_t(Vector3(0, top + 0.1, 0.06)), Vector3(1.0, 0.13, 0.12), 0.03, DARK, MeshKit.MATTE, 1)
	for k in 4:
		_lamp(kit, Vector3(-0.36 + 0.24 * k, top + 0.1, 0.125), FWD, 0.06)
	# engine with a spare wheel on the back
	kit.rbox(_t(Vector3(0, 0.96, -1.18)), Vector3(0.7, 0.42, 0.5), 0.05, DARK, MeshKit.MATTE, 1)
	for k in 4:
		kit.rbox(_t(Vector3(0, 1.2, -1.0 - 0.1 * k)), Vector3(0.62, 0.05, 0.03), 0.0, STEEL, MeshKit.CHROME, 0)
	_wheel(kit, _t(Vector3(0, 1.32, -1.52), Vector3(0, PI / 2.0, 0)), 0.4, 0.3, "street", Color("4a4f5c"), c)
	var ex := Vector3(0.3, 0.68, -1.74)
	_pipes(kit, -1.3, ex)
	# suspension arms and coil-over shocks
	for ax in [front, rear]:
		var wx: float = float(ax.x) - float(ax.w) * 0.5 - 0.02
		var wz: float = ax.z
		var wy: float = ax.r
		for sx in [-1.0, 1.0]:
			kit.tube(I, Vector3(0.45 * sx, 0.8, wz + 0.15), Vector3(wx * sx, wy, wz), 0.035, DARK, MeshKit.MATTE, 6)
			kit.tube(I, Vector3(0.45 * sx, 0.8, wz - 0.15), Vector3(wx * sx, wy, wz), 0.035, DARK, MeshKit.MATTE, 6)
			kit.tube(I, Vector3(0.45 * sx, 1.22, wz), Vector3((wx - 0.08) * sx, wy + 0.08, wz), 0.065, spring, MeshKit.GLOSS, 8)
	_loft_numbers(kit, hull, 3.0, -0.2, 0.25, num, 0.16)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.42, 0.52), "tilt": 0.62,
		"exhaust": ex, "size": Vector2(3.0, 4.2), "top": 2.6}


# ================================================================== 5: Karel Kolo – little tractor
static func _tractor(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var front := _axle(0.78, 1.45, 0.38, 0.28, "rib", a, c)
	var rear := _axle(1.0, -0.7, 0.72, 0.55, "tractor", a, c)
	var seat := Vector3(0, 1.14, -0.6)
	# bonnet with grille, lamps and chimney
	kit.rbox(_t(Vector3(0, 0.98, 0.98)), Vector3(0.86, 0.62, 1.55), 0.14, c, MeshKit.GLOSS, 2)
	kit.rbox(_t(Vector3(0, 0.95, 1.765)), Vector3(0.66, 0.46, 0.05), 0.02, INK, MeshKit.MATTE, 1)
	for k in 4:
		kit.rbox(_t(Vector3(0, 0.79 + 0.105 * k, 1.795)), Vector3(0.6, 0.035, 0.03), 0.01, SHINE, MeshKit.CHROME, 0)
	for sx in [-1.0, 1.0]:
		_lamp(kit, Vector3(0.33 * sx, 1.2, 1.755), FWD, 0.07)
		kit.rbox(_t(Vector3(0.435 * sx, 1.05, 0.62)), Vector3(0.02, 0.2, 0.42), 0.0, INK, MeshKit.MATTE, 0)
	kit.tube(I, Vector3(-0.22, 1.25, 1.22), Vector3(-0.22, 1.95, 1.22), 0.055, SHINE, MeshKit.CHROME, 8)
	kit.rbox(_t(Vector3(-0.22, 1.98, 1.2), Vector3(0.45, 0, 0)), Vector3(0.15, 0.025, 0.16), 0.01, DARK, MeshKit.MATTE, 0)
	# frame, front axle and weights
	kit.rbox(_t(Vector3(0, 0.6, 0.35)), Vector3(0.56, 0.28, 2.3), 0.05, DARK, MeshKit.MATTE, 1)
	kit.tube(I, Vector3(-0.66, 0.38, 1.45), Vector3(0.66, 0.38, 1.45), 0.06, DARK, MeshKit.MATTE, 8)
	kit.rbox(_t(Vector3(0, 0.52, 1.45)), Vector3(0.3, 0.32, 0.3), 0.04, DARK, MeshKit.MATTE, 1)
	kit.rbox(_t(Vector3(0, 0.52, 1.93)), Vector3(0.8, 0.3, 0.2), 0.05, INK, MeshKit.MATTE, 1)
	# fuel tank, rear housing, fenders
	kit.rbox(_t(Vector3(0, 1.12, 0.02)), Vector3(0.7, 0.42, 0.5), 0.12, c, MeshKit.GLOSS, 2)
	kit.rbox(_t(Vector3(0, 0.78, -0.7)), Vector3(0.8, 0.62, 0.9), 0.1, DARK, MeshKit.MATTE, 1)
	for sx in [-1.0, 1.0]:
		kit.tube(I, Vector3(0.38 * sx, 0.72, -0.7), Vector3(0.74 * sx, 0.72, -0.7), 0.12, DARK, MeshKit.MATTE, 10)
		kit.arch(_t(Vector3(1.0 * sx, 0.72, -0.7)), 0.79, 0.88, 0.66, 0.35, 2.75, c, MeshKit.GLOSS, 14)
		kit.rbox(_t(Vector3(0.53 * sx, 1.28, -0.7)), Vector3(0.3, 0.06, 0.9), 0.025, c, MeshKit.GLOSS, 1)
		_lamp(kit, Vector3(1.0 * sx, 1.07, -1.505), Vector3(0, 0.38, -1.0), 0.06, TAIL)
	# seat on the housing, footplate and legs
	kit.rbox(_t(seat + Vector3(0, -0.06, 0)), Vector3(0.6, 0.1, 0.5), 0.04, INK, MeshKit.MATTE, 1)
	kit.rbox(_t(seat + Vector3(0, 0.26, -0.32), Vector3(-0.2, 0, 0)), Vector3(0.62, 0.48, 0.1), 0.045, INK, MeshKit.MATTE, 1)
	kit.rbox(_t(Vector3(0, 0.74, 0.04)), Vector3(1.0, 0.05, 0.42), 0.02, STEEL, MeshKit.CHROME, 1)
	_legs(kit, seat + Vector3(0.14, 0.04, 0.05), Vector3(0.2, 1.18, -0.08), Vector3(0.22, 0.83, 0.02), a)
	# drawbar
	kit.rbox(_t(Vector3(0, 0.5, -1.3)), Vector3(0.26, 0.08, 0.5), 0.02, DARK, MeshKit.MATTE, 1)
	var ex := Vector3(0.3, 0.58, -1.42)
	_pipes(kit, -1.1, ex, 0.065)
	_side_numbers(kit, Vector3(0.435, 1.0, 1.15), num, 0.17)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.5, 0.48), "tilt": 1.05,
		"column": 0.56, "exhaust": ex, "size": Vector2(2.9, 4.2), "top": 2.55}


# ================================================================== 6: Bára Brzda – low futuristic arrow
static func _arrow(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var front := _axle(0.98, 1.12, 0.38, 0.32, "future", Color("3a3f4f"), a)
	var rear := _axle(1.02, -1.0, 0.42, 0.4, "future", Color("3a3f4f"), a)
	var seat := Vector3(0, 0.6, -0.3)
	var lower := c.darkened(0.4)
	var two_tone := func(ang: float, _z: float, _p: Vector3) -> Color:
		return lower if sin(ang) < -0.15 else c
	var dart := [[-1.75, 0.55, 0.62, 0.2, 0.24], [-1.3, 0.55, 0.78, 0.27, 0.28], [-0.4, 0.52, 0.68, 0.3, 0.28],
		[0.7, 0.45, 0.48, 0.22, 0.22], [1.7, 0.36, 0.28, 0.12, 0.14], [2.45, 0.3, 0.05, 0.03, 0.04]]
	kit.loft(I, dart, two_tone, MeshKit.GLOSS, 2.3, 22)
	# neon strips along the sides
	for sx in [-1.0, 1.0]:
		var pts := [Vector3(0.795 * sx, 0.55, -1.3), Vector3(0.695 * sx, 0.52, -0.4), Vector3(0.495 * sx, 0.45, 0.7),
			Vector3(0.29 * sx, 0.36, 1.68)]
		for k in pts.size() - 1:
			kit.tube(I, pts[k], pts[k + 1], 0.022, a, MeshKit.LIGHT, 6)
	# covered wheels: pods with a strake to the nose
	for ax in [front, rear]:
		for sx in [-1.0, 1.0]:
			kit.arch(_t(Vector3(float(ax.x) * sx, float(ax.r), float(ax.z))), float(ax.r) + 0.04, float(ax.r) + 0.13,
				float(ax.w) + 0.1, 0.12, PI - 0.12, c, MeshKit.GLOSS, 12)
	for sx in [-1.0, 1.0]:
		kit.rbox(_t(Vector3(0.6 * sx, 0.42, 1.12)), Vector3(0.44, 0.05, 0.4), 0.02, c, MeshKit.GLOSS, 1)
	# swept tail fins with glowing tips
	for sx in [-1.0, 1.0]:
		var ft := _t(Vector3(0.42 * sx, 0.98, -1.45), Vector3(-0.42, 0, -0.32 * sx))
		kit.rbox(ft, Vector3(0.05, 0.62, 0.72), 0.022, c, MeshKit.GLOSS, 1)
		kit.tube(ft, Vector3(0, 0.32, -0.33), Vector3(0, 0.32, 0.33), 0.03, a, MeshKit.LIGHT, 6)
	# canopy, headrest hump
	kit.sphere(_t(Vector3(0, 0.76, 0.42)), Vector3(0.4, 0.24, 0.5), Color("2a5470"), MeshKit.CHROME, 16, 5, 0.0, PI / 2.0)
	kit.loft(I, [[-1.25, 0.8, 0.04, 0.02, 0.02], [-0.92, 0.82, 0.2, 0.22, 0.05], [-0.62, 0.82, 0.18, 0.26, 0.05],
		[-0.52, 0.82, 0.08, 0.12, 0.03]], c, MeshKit.GLOSS, 2.4, 12)
	# lights and thrusters
	kit.rbox(_t(Vector3(0, 0.62, -1.765)), Vector3(1.0, 0.05, 0.03), 0.01, a, MeshKit.LIGHT, 0)
	for sx in [-1.0, 1.0]:
		kit.rbox(_t(Vector3(0.18 * sx, 0.43, 1.93), Vector3(-0.3, 0.32 * sx, 0)), Vector3(0.24, 0.035, 0.04), 0.01, a, MeshKit.LIGHT, 0)
	var ex := Vector3(0.3, 0.55, -1.86)
	for sx in [-1.0, 1.0]:
		kit.tube(I, Vector3(0.3 * sx, 0.55, -1.55), Vector3(0.3 * sx, 0.55, -1.86), 0.11, SHINE, MeshKit.CHROME, 12, 0.13)
		kit.disc(MeshKit.decal(Vector3(0.3 * sx, 0.55, -1.864), AFT), 0.09, a, MeshKit.LIGHT, 12)
	_loft_numbers(kit, dart, 2.3, 0.1, 0.45, num, 0.15)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.4, 0.55), "tilt": 0.66,
		"exhaust": ex, "size": Vector2(2.6, 4.4), "top": 2.05}


# ================================================================== 7: Profesor Píst – vintage roadster (secret)
static func _roadster(kit: MeshKit, ch: Dictionary, num: int) -> Dictionary:
	var c: Color = ch.color
	var a: Color = ch.accent
	var front := _axle(0.96, 1.3, 0.44, 0.26, "whitewall", SHINE, a)
	var rear := _axle(1.0, -1.0, 0.48, 0.3, "whitewall", SHINE, a)
	var seat := Vector3(0, 0.66, -0.5)
	# long bonnet, open cockpit and a boat tail, an accent line along the top
	var stripe := func(ang: float, _z: float, _p: Vector3) -> Color:
		return a if absf(ang - PI / 2.0) < 0.16 else c
	var hull := [[-2.05, 0.74, 0.04, 0.04, 0.04], [-1.75, 0.74, 0.36, 0.26, 0.24], [-1.1, 0.72, 0.56, 0.32, 0.3],
		[-0.3, 0.7, 0.6, 0.3, 0.3], [0.5, 0.76, 0.5, 0.3, 0.3], [1.3, 0.8, 0.44, 0.3, 0.28], [1.82, 0.8, 0.4, 0.28, 0.27]]
	kit.loft(I, hull, stripe, MeshKit.GLOSS, 2.7, 20)
	# chrome grille with dark slats, round lamps on a bar
	kit.rbox(_t(Vector3(0, 0.8, 1.86)), Vector3(0.74, 0.58, 0.08), 0.05, SHINE, MeshKit.CHROME, 1)
	for k in 5:
		kit.rbox(_t(Vector3(-0.24 + 0.12 * k, 0.8, 1.905)), Vector3(0.05, 0.46, 0.02), 0.01, INK, MeshKit.MATTE, 0)
	kit.tube(I, Vector3(-0.62, 0.98, 1.72), Vector3(0.62, 0.98, 1.72), 0.025, SHINE, MeshKit.CHROME, 6)
	for sx in [-1.0, 1.0]:
		kit.sphere(_t(Vector3(0.64 * sx, 1.0, 1.7)), Vector3(0.15, 0.15, 0.13), SHINE, MeshKit.CHROME, 12, 6)
		_lamp(kit, Vector3(0.64 * sx, 1.0, 1.825), FWD, 0.11)
	# bonnet louvres
	for sx in [-1.0, 1.0]:
		for k in 4:
			kit.rbox(_t(Vector3(0.43 * sx, 0.84, 0.7 + 0.16 * k)), Vector3(0.02, 0.14, 0.06), 0.01, a, MeshKit.GLOSS, 0)
	# cycle fenders over all four wheels, a running board between them
	for ax in [front, rear]:
		for sx in [-1.0, 1.0]:
			kit.arch(_t(Vector3(float(ax.x) * sx, float(ax.r), float(ax.z))), float(ax.r) + 0.05, float(ax.r) + 0.12,
				float(ax.w) + 0.12, 0.25, PI - 0.15, c, MeshKit.GLOSS, 12)
	for sx in [-1.0, 1.0]:
		kit.rbox(_t(Vector3(0.78 * sx, 0.36, 0.15)), Vector3(0.3, 0.05, 1.5), 0.02, DARK, MeshKit.MATTE, 1)
	# little windscreen in a chrome frame, padded rim round the cockpit
	kit.rbox(_t(Vector3(0, 1.17, 0.12), Vector3(-0.25, 0, 0)), Vector3(0.82, 0.3, 0.025), 0.02, Color("9cc4ea"), MeshKit.CHROME, 1)
	kit.tube(I, Vector3(-0.42, 1.03, 0.16), Vector3(-0.42, 1.31, 0.08), 0.02, SHINE, MeshKit.CHROME, 5)
	kit.tube(I, Vector3(0.42, 1.03, 0.16), Vector3(0.42, 1.31, 0.08), 0.02, SHINE, MeshKit.CHROME, 5)
	kit.tube(I, Vector3(-0.42, 1.31, 0.08), Vector3(0.42, 1.31, 0.08), 0.02, SHINE, MeshKit.CHROME, 5)
	kit.rbox(_t(Vector3(0, 1.0, -0.98)), Vector3(0.7, 0.1, 0.12), 0.05, Color("5a2a1a"), MeshKit.SATIN, 1)
	# side exhaust running back along the right flank
	kit.tube(I, Vector3(0.62, 0.68, 1.0), Vector3(0.68, 0.5, 0.6), 0.06, SHINE, MeshKit.CHROME, 8)
	kit.tube(I, Vector3(0.68, 0.5, 0.6), Vector3(0.68, 0.5, -1.4), 0.065, SHINE, MeshKit.CHROME, 8)
	var ex := Vector3(0.3, 0.55, -2.0)
	_pipes(kit, -1.7, ex, 0.06)
	for sx in [-1.0, 1.0]:
		_lamp(kit, Vector3(0.3 * sx, 0.86, -1.86), AFT, 0.06, TAIL)
	_side_numbers(kit, Vector3(0.6, 0.78, -1.05), num, 0.2)
	_roundel(kit, MeshKit.decal(Vector3(0, 1.075, -1.5), Vector3(0, 1.0, -0.2), AFT), num, 0.15)
	return {"front": front, "rear": rear, "seat": seat, "wheel": seat + Vector3(0, 0.46, 0.5), "tilt": 0.72,
		"exhaust": ex, "size": Vector2(2.5, 4.5), "top": 2.0}
