class_name MeshKit
extends RefCounted
## Builds rounded low-poly shapes (bevelled boxes, lofted bodies, lathed
## wheels, tubes, spheres, fenders, number strokes) into one ArrayMesh with
## vertex colours, so a whole kart body is a single draw call.
##
## Every part gets a finish. Its roughness rides in UV.x and is looked up in
## a tiny texture, and UV.y marks parts that light up while the star is on.
## LIGHT parts (lamps) go to a second, unshaded surface.

enum { GLOSS, SATIN, MATTE, CHROME, RUBBER, LIGHT }
const ROUGH := [0.3, 0.62, 0.85, 0.16, 0.95]
const GLOWS := [1.0, 1.0, 0.0, 0.0, 0.0]

## Below 1 every curved shape gets fewer segments and small boxes lose
## their rounding: used for the far-away (LOD) version of a kart.
var detail := 1.0

var _bv := PackedVector3Array()
var _bn := PackedVector3Array()
var _bc := PackedColorArray()
var _buv := PackedVector2Array()
var _lv := PackedVector3Array()
var _ln := PackedVector3Array()
var _lc := PackedColorArray()

static var _tex := {}


# ================================================================== output
## Bakes everything added so far into a mesh: lit parts first, lamps second.
## Identical vertices are merged, so smooth shapes share them.
func commit() -> ArrayMesh:
	var m := ArrayMesh.new()
	if not _bv.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = _bv
		arr[Mesh.ARRAY_NORMAL] = _bn
		arr[Mesh.ARRAY_COLOR] = _bc
		arr[Mesh.ARRAY_TEX_UV] = _buv
		_add_indexed(m, arr, shared_material())
	if not _lv.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = _lv
		arr[Mesh.ARRAY_NORMAL] = _ln
		arr[Mesh.ARRAY_COLOR] = _lc
		_add_indexed(m, arr, light_material())
	return m


static func _add_indexed(m: ArrayMesh, arr: Array, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.index()
	st.set_material(mat)
	st.commit(m)


func triangles() -> int:
	return (_bv.size() + _lv.size()) / 3


## Lit material with per-part roughness. Each kart gets its own copy so the
## star can tint it without touching the others.
static func body_material() -> StandardMaterial3D:
	if not _tex.has("rough"):
		var n := ROUGH.size()
		var ri := Image.create_empty(n, 1, false, Image.FORMAT_RGBA8)
		var gi := Image.create_empty(n, 1, false, Image.FORMAT_RGBA8)
		for i in n:
			ri.set_pixel(i, 0, Color(ROUGH[i], ROUGH[i], ROUGH[i]))
			gi.set_pixel(i, 0, Color(GLOWS[i], GLOWS[i], GLOWS[i]))
		_tex.rough = ImageTexture.create_from_image(ri)
		_tex.glow = ImageTexture.create_from_image(gi)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	m.roughness_texture = _tex.rough
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.metallic_specular = 0.65
	m.emission_texture = _tex.glow
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY   # only parts marked in the mask glow
	return m


static func shared_material() -> StandardMaterial3D:
	if not _tex.has("shared"):
		_tex.shared = body_material()
	return _tex.shared


static func light_material() -> StandardMaterial3D:
	if not _tex.has("light"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		_tex.light = m
	return _tex.light


# ================================================================== helpers
static func at(pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos)


## Mirror of a transform across the kart's centre plane (x → -x).
static func mirror_x(t: Transform3D) -> Transform3D:
	var f := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
	return f * t


func _tri(t: Transform3D, nb: Basis, fin: int, col: Color, a: Vector3, b: Vector3, c: Vector3,
		na: Vector3, nbb: Vector3, nc: Vector3) -> void:
	var pa := t * a
	var pb := t * b
	var pc := t * c
	var qa := (nb * na).normalized()
	var qb := (nb * nbb).normalized()
	var qc := (nb * nc).normalized()
	# Godot draws clockwise faces: flip any triangle that winds the other way
	if (pb - pa).cross(pc - pa).dot(qa + qb + qc) > 0.0:
		var tp := pb
		pb = pc
		pc = tp
		var tn := qb
		qb = qc
		qc = tn
	if fin == LIGHT:
		_lv.append(pa); _lv.append(pb); _lv.append(pc)
		_ln.append(qa); _ln.append(qb); _ln.append(qc)
		_lc.append(col); _lc.append(col); _lc.append(col)
		return
	var uv := Vector2((fin + 0.5) / ROUGH.size(), 0.5)
	_bv.append(pa); _bv.append(pb); _bv.append(pc)
	_bn.append(qa); _bn.append(qb); _bn.append(qc)
	_bc.append(col); _bc.append(col); _bc.append(col)
	_buv.append(uv); _buv.append(uv); _buv.append(uv)


func _n(seg: int, lo: int) -> int:
	return seg if detail >= 1.0 else maxi(lo, int(round(seg * detail)))


static func _nbasis(t: Transform3D) -> Basis:
	return t.basis.inverse().transposed()


static func _col(col: Variant, a: Variant = null, b: Variant = null, c: Variant = null) -> Color:
	if col is Callable:
		return (col as Callable).call(a, b, c)
	return col


## Quads between rows of points. P and N are Arrays of PackedVector3Array
## (one row per step), colf gets (row, column, centre) or is a plain Color.
func _grid(t: Transform3D, fin: int, P: Array, N: Array, col: Variant, wrap: bool) -> void:
	var nb := _nbasis(t)
	var rows := P.size()
	var cols: int = (P[0] as PackedVector3Array).size()
	var last := cols if wrap else cols - 1
	for i in rows - 1:
		var r0: PackedVector3Array = P[i]
		var r1: PackedVector3Array = P[i + 1]
		var n0: PackedVector3Array = N[i]
		var n1: PackedVector3Array = N[i + 1]
		for j in last:
			var j1 := (j + 1) % cols
			var a := r0[j]
			var b := r0[j1]
			var c := r1[j1]
			var d := r1[j]
			var cc := _col(col, i, j, (a + b + c + d) * 0.25)
			if a.distance_squared_to(b) > 1e-10:
				_tri(t, nb, fin, cc, a, b, c, n0[j], n0[j1], n1[j1])
			if c.distance_squared_to(d) > 1e-10:
				_tri(t, nb, fin, cc, a, c, d, n0[j], n1[j1], n1[j])


## Smooth normals for a grid: average of the neighbouring face normals,
## turned to point away from `inside(row, col)`.
static func _grid_normals(P: Array, wrap: bool, inside: Callable) -> Array:
	var rows := P.size()
	var cols: int = (P[0] as PackedVector3Array).size()
	var acc: Array = []
	for i in rows:
		var row := PackedVector3Array()
		row.resize(cols)
		acc.append(row)
	var last := cols if wrap else cols - 1
	for i in rows - 1:
		for j in last:
			var j1 := (j + 1) % cols
			var a: Vector3 = P[i][j]
			var b: Vector3 = P[i][j1]
			var c: Vector3 = P[i + 1][j1]
			var d: Vector3 = P[i + 1][j]
			var fn := (c - a).cross(d - b)
			if fn.length_squared() < 1e-14:
				continue
			fn = fn.normalized()
			var ctr := (a + b + c + d) * 0.25
			if fn.dot(ctr - (inside.call(i, j) as Vector3)) < 0.0:
				fn = -fn
			for q in [[i, j], [i, j1], [i + 1, j1], [i + 1, j]]:
				var r: PackedVector3Array = acc[q[0]]
				r[q[1]] += fn
				acc[q[0]] = r
	for i in rows:
		var r: PackedVector3Array = acc[i]
		for j in cols:
			r[j] = r[j].normalized() if r[j].length_squared() > 1e-12 else Vector3.UP
		acc[i] = r
	return acc


func _fan(t: Transform3D, fin: int, col: Color, ctr: Vector3, ring: PackedVector3Array, n: Vector3) -> void:
	var nb := _nbasis(t)
	for j in ring.size():
		var a := ring[j]
		var b := ring[(j + 1) % ring.size()]
		if a.distance_squared_to(b) > 1e-10:
			_tri(t, nb, fin, col, ctr, a, b, n, n, n)


# ================================================================== shapes
## Box with rounded edges and corners. r = corner radius, seg = steps per
## rounded edge (1 = a simple chamfer). col may be Callable(p, n, null).
func rbox(t: Transform3D, size: Vector3, r: float, col: Variant, fin := GLOSS, seg := 2) -> void:
	var h := size * 0.5
	r = clampf(r, 0.0, minf(h.x, minf(h.y, h.z)) - 0.001)
	if detail < 1.0:
		seg = 0 if maxf(size.x, maxf(size.y, size.z)) < 0.6 else mini(seg, 1)
	if r < 0.002:
		seg = 0
	var inner := h - Vector3.ONE * r
	var coords: Array = []
	for ax in 3:
		var c := PackedFloat32Array()
		var hi: float = inner[ax]
		if seg == 0:
			c.append_array([-h[ax], h[ax]])
		else:
			for k in range(seg, 0, -1):
				c.append(-hi - r * tan(PI / 4.0 * k / seg))
			c.append(-hi)
			c.append(hi)
			for k in range(1, seg + 1):
				c.append(hi + r * tan(PI / 4.0 * k / seg))
		coords.append(c)
	var nb := _nbasis(t)
	for ax in 3:
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		var cu: PackedFloat32Array = coords[u]
		var cv: PackedFloat32Array = coords[v]
		for sg in [-1.0, 1.0]:
			var pts: Array = []
			var nrm: Array = []
			for iu in cu.size():
				var prow := PackedVector3Array()
				var nrow := PackedVector3Array()
				for iv in cv.size():
					var q := Vector3.ZERO
					q[ax] = h[ax] * sg
					q[u] = cu[iu]
					q[v] = cv[iv]
					var cl := q.clamp(-inner, inner)
					var d := q - cl
					var n := d.normalized() if d.length_squared() > 1e-12 else Vector3.ZERO
					if n == Vector3.ZERO:
						n[ax] = sg
					prow.append(cl + n * r if seg > 0 else q)
					if seg == 0:
						n = Vector3.ZERO
						n[ax] = sg
					nrow.append(n)
				pts.append(prow)
				nrm.append(nrow)
			for iu in cu.size() - 1:
				for iv in cv.size() - 1:
					var a: Vector3 = pts[iu][iv]
					var b: Vector3 = pts[iu + 1][iv]
					var c: Vector3 = pts[iu + 1][iv + 1]
					var d: Vector3 = pts[iu][iv + 1]
					var na: Vector3 = nrm[iu][iv]
					var nbb: Vector3 = nrm[iu + 1][iv]
					var nc: Vector3 = nrm[iu + 1][iv + 1]
					var nd: Vector3 = nrm[iu][iv + 1]
					var cc := _col(col, (a + b + c + d) * 0.25, (na + nc).normalized())
					if a.distance_squared_to(c) < 1e-10:
						continue
					_tri(t, nb, fin, cc, a, b, c, na, nbb, nc)
					_tri(t, nb, fin, cc, a, c, d, na, nc, nd)


## Point on a loft's surface at length z and angle ang (0 = +X side,
## PI/2 = top), matching loft() for the same sections and exponent.
static func loft_point(secs: Array, z: float, ang: float, e := 2.6) -> Vector3:
	var k := 0
	while k < secs.size() - 2 and z > float(secs[k + 1][0]):
		k += 1
	var s0: Array = secs[k]
	var s1: Array = secs[k + 1]
	var f := clampf((z - float(s0[0])) / maxf(1e-4, float(s1[0]) - float(s0[0])), 0.0, 1.0)
	var cs := cos(ang)
	var sn := sin(ang)
	var w := lerpf(float(s0[2]), float(s1[2]), f)
	var hh := lerpf(float(s0[3]), float(s1[3]), f) if sn > 0.0 else lerpf(float(s0[4]), float(s1[4]), f)
	var cy := lerpf(float(s0[1]), float(s1[1]), f)
	return Vector3(w * signf(cs) * pow(absf(cs), 2.0 / e), cy + hh * signf(sn) * pow(absf(sn), 2.0 / e), z)


## Decal transform sitting on a loft (see loft_point), lifted a little off it.
static func loft_decal(secs: Array, z: float, ang: float, e := 2.6, lift := 0.015, up := Vector3.UP) -> Transform3D:
	var p := loft_point(secs, z, ang, e)
	var dz := loft_point(secs, z + 0.02, ang, e) - loft_point(secs, z - 0.02, ang, e)
	var da := loft_point(secs, z, ang + 0.02, e) - loft_point(secs, z, ang - 0.02, e)
	var n := da.cross(dz).normalized()
	if n.dot(Vector3(p.x, sin(ang), 0.0)) < 0.0:
		n = -n
	return decal(p + n * lift, n, up)


## Smooth body lofted along +Z through superellipse cross-sections.
## secs: Array of [z, centre_y, half_width, half_height_top, half_height_bottom].
## e: 2 = ellipse, higher = boxier. col may be Callable(angle, z, point).
func loft(t: Transform3D, secs: Array, col: Variant, fin := GLOSS, e := 2.6, seg := 18,
		cap_back := true, cap_front := true) -> void:
	seg = _n(seg, 8)
	var P: Array = []
	var ctrs: Array = []
	for s in secs:
		var row := PackedVector3Array()
		for j in seg:
			var ang := TAU * j / seg
			var cs := cos(ang)
			var sn := sin(ang)
			var px := float(s[2]) * signf(cs) * pow(absf(cs), 2.0 / e)
			var hh: float = float(s[3]) if sn > 0.0 else float(s[4])
			var py := float(s[1]) + hh * signf(sn) * pow(absf(sn), 2.0 / e)
			row.append(Vector3(px, py, float(s[0])))
		P.append(row)
		ctrs.append(Vector3(0.0, float(s[1]) + (float(s[3]) - float(s[4])) * 0.5, float(s[0])))
	var N := _grid_normals(P, true, func(i: int, _j: int) -> Vector3:
		return ((ctrs[i] as Vector3) + (ctrs[i + 1] as Vector3)) * 0.5)
	var cf: Variant = col
	if col is Callable:
		cf = func(i: int, j: int, c: Vector3) -> Color:
			return (col as Callable).call(TAU * (j + 0.5) / seg, c.z, c)
	_grid(t, fin, P, N, cf, true)
	var c0 := _col(col, -PI / 2.0, float(secs[0][0]), ctrs[0]) if col is Callable else col as Color
	var c1 := _col(col, -PI / 2.0, float(secs[-1][0]), ctrs[-1]) if col is Callable else col as Color
	if cap_back and float(secs[0][2]) > 0.01:
		_fan(t, fin, c0, ctrs[0], P[0], Vector3(0, 0, -1))
	if cap_front and float(secs[-1][2]) > 0.01:
		_fan(t, fin, c1, ctrs[-1], P[-1], Vector3(0, 0, 1))


## Ellipsoid with its poles on local Y. col may be Callable(direction, row,
## column), direction given in the space of t. lats: optional list of
## latitudes (radians, from -PI/2 up) instead of evenly spaced rings.
func sphere(t: Transform3D, radii: Vector3, col: Variant, fin := GLOSS, seg := 14, rings := 8,
		lat_from := -PI / 2.0, lat_to := PI / 2.0, lats := PackedFloat32Array(), lon_from := 0.0,
		lon_to := TAU) -> void:
	seg = _n(seg, 6)
	rings = _n(rings, 3)
	var whole := is_equal_approx(lon_to - lon_from, TAU)
	var cols := seg if whole else seg + 1
	var P: Array = []
	var N: Array = []
	var U: Array = []
	var L := PackedFloat32Array(lats)
	if L.is_empty():
		for i in rings + 1:
			L.append(lerpf(lat_from, lat_to, float(i) / rings))
	for i in L.size():
		var lat := L[i]
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		var urow := PackedVector3Array()
		for j in cols:
			var lon := lerpf(lon_from, lon_to, float(j) / seg)
			var un := Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))
			row.append(un * radii)
			nrow.append((un / radii).normalized())
			urow.append(un)
		P.append(row)
		N.append(nrow)
		U.append(urow)
	var cf: Variant = col
	if col is Callable:
		cf = func(i: int, j: int, _c: Vector3) -> Color:
			var j1 := (j + 1) % cols
			var un: Vector3 = ((U[i][j] as Vector3) + (U[i][j1] as Vector3) + (U[i + 1][j] as Vector3) + (U[i + 1][j1] as Vector3)).normalized()
			return (col as Callable).call((t.basis * un).normalized(), i, j)
	_grid(t, fin, P, N, cf, whole)


## Surface of revolution around the local X axis. prof: Vector2(x, radius)
## points; walking along it, the outside is on the +radius side when x grows.
## Angle 0 points to +Z (forward), PI/2 to +Y (up). Normals are smooth around
## and hard between profile segments.
func lathe(t: Transform3D, prof: PackedVector2Array, col: Variant, fin := GLOSS, seg := 16,
		a0 := 0.0, a1 := TAU, close_ends := false) -> void:
	_lathe(t, prof, col, fin, _n(seg, 6), a0, a1, close_ends)


func _lathe(t: Transform3D, prof: PackedVector2Array, col: Variant, fin: int, steps: int,
		a0 := 0.0, a1 := TAU, close_ends := false) -> void:
	var nb := _nbasis(t)
	var full := is_equal_approx(a1 - a0, TAU)
	for i in prof.size() - 1:
		var p0 := prof[i]
		var p1 := prof[i + 1]
		var d := p1 - p0
		if d.length_squared() < 1e-12:
			continue
		var n2 := Vector2(-d.y, d.x).normalized()
		for j in steps:
			var aa := lerpf(a0, a1, float(j) / steps)
			var ab := lerpf(a0, a1, float(j + 1) / steps)
			var A := Vector3(p0.x, p0.y * sin(aa), p0.y * cos(aa))
			var B := Vector3(p0.x, p0.y * sin(ab), p0.y * cos(ab))
			var C := Vector3(p1.x, p1.y * sin(ab), p1.y * cos(ab))
			var D := Vector3(p1.x, p1.y * sin(aa), p1.y * cos(aa))
			var na := Vector3(n2.x, n2.y * sin(aa), n2.y * cos(aa))
			var nbb := Vector3(n2.x, n2.y * sin(ab), n2.y * cos(ab))
			var cc := _col(col, i, j, (A + C) * 0.5)
			if A.distance_squared_to(B) > 1e-10:
				_tri(t, nb, fin, cc, A, B, C, na, nbb, nbb)
			if C.distance_squared_to(D) > 1e-10:
				_tri(t, nb, fin, cc, A, C, D, na, nbb, na)
	if close_ends and not full:
		var ctr := Vector2.ZERO
		for p in prof:
			ctr += p
		ctr /= prof.size()
		for k in 2:
			var ang := a0 if k == 0 else a1
			var n := Vector3(0, cos(ang), -sin(ang)) * (-1.0 if k == 0 else 1.0)
			var ring := PackedVector3Array()
			for p in prof:
				ring.append(Vector3(p.x, p.y * sin(ang), p.y * cos(ang)))
			var cc := _col(col, -1, k, Vector3.ZERO)
			_fan(t, fin, cc, Vector3(ctr.x, ctr.y * sin(ang), ctr.y * cos(ang)), ring, n)


## Cylinder (or cone) from a to b, with flat caps.
func tube(t: Transform3D, a: Vector3, b: Vector3, r: float, col: Color, fin := MATTE, seg := 8,
		r2 := -1.0, caps := true) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 1e-5:
		return
	var x := d / ln
	var up := Vector3.UP if absf(x.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var y := up - x * up.dot(x)
	y = y.normalized()
	var z := x.cross(y)
	var lt := t * Transform3D(Basis(x, y, z), a)
	var rb := r if r2 < 0.0 else r2
	seg = _n(seg, 5)
	_lathe(lt, PackedVector2Array([Vector2(0, r), Vector2(ln, rb)]), col, fin, seg)
	if caps:
		var ring0 := PackedVector3Array()
		var ring1 := PackedVector3Array()
		for j in seg:
			var ang := TAU * j / seg
			ring0.append(Vector3(0, r * sin(ang), r * cos(ang)))
			ring1.append(Vector3(ln, rb * sin(ang), rb * cos(ang)))
		_fan(lt, fin, col, Vector3.ZERO, ring0, Vector3(-1, 0, 0))
		if rb > 0.001:
			_fan(lt, fin, col, Vector3(ln, 0, 0), ring1, Vector3(1, 0, 0))


## Thick curved fender around the local X axis (a wheel's axle): from angle
## a0 to a1 (0 = forward, PI/2 = up), between radii r_in and r_out.
func arch(t: Transform3D, r_in: float, r_out: float, width: float, a0: float, a1: float, col: Color,
		fin := GLOSS, seg := 12) -> void:
	var w := width * 0.5
	var bev := minf(0.05, (r_out - r_in) * 0.3)
	var prof := PackedVector2Array([Vector2(-w, r_in), Vector2(-w, r_out - bev), Vector2(-w + bev, r_out),
		Vector2(w - bev, r_out), Vector2(w, r_out - bev), Vector2(w, r_in), Vector2(-w, r_in)])
	lathe(t, prof, col, fin, seg, a0, a1, true)


## Flat round disc facing +Z of t.
func disc(t: Transform3D, r: float, col: Color, fin := GLOSS, seg := 16) -> void:
	seg = _n(seg, 8)
	var ring := PackedVector3Array()
	for j in seg:
		var ang := TAU * j / seg
		ring.append(Vector3(cos(ang) * r, sin(ang) * r, 0.0))
	_fan(t, fin, col, Vector3.ZERO, ring, Vector3(0, 0, 1))


## Flat-shaded convex face through pts (in the space of t), its normal
## turned to point away from `inside`. For faceted shapes such as rocks.
func face(t: Transform3D, pts: PackedVector3Array, inside: Vector3, col: Color, fin := MATTE) -> void:
	var n := (pts[1] - pts[0]).cross(pts[2] - pts[0])
	if n.length_squared() < 1e-12 and pts.size() > 3:
		n = (pts[2] - pts[0]).cross(pts[3] - pts[0])
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var ctr := Vector3.ZERO
	for p in pts:
		ctr += p
	ctr /= pts.size()
	if n.dot(ctr - inside) < 0.0:
		n = -n
	var nb := _nbasis(t)
	for k in range(1, pts.size() - 1):
		_tri(t, nb, fin, col, pts[0], pts[k], pts[k + 1], n, n, n)


## Flat convex polygon in the XY plane of t, facing +Z.
func polygon(t: Transform3D, pts: PackedVector2Array, col: Color, fin := GLOSS) -> void:
	var ring := PackedVector3Array()
	var ctr := Vector3.ZERO
	for p in pts:
		ring.append(Vector3(p.x, p.y, 0.0))
		ctr += Vector3(p.x, p.y, 0.0)
	_fan(t, fin, col, ctr / pts.size(), ring, Vector3(0, 0, 1))


## Transform for a decal sitting on a surface: +Z along the surface normal,
## +Y towards `up`, so text reads correctly from outside.
static func decal(pos: Vector3, normal: Vector3, up := Vector3.UP) -> Transform3D:
	var n := normal.normalized()
	var u := (up - n * up.dot(n)).normalized()
	return Transform3D(Basis(u.cross(n), u, n), pos)


const DIGITS := {
	0: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]],
	1: [[[0.25, 0.75], [0.55, 1], [0.55, 0]], [[0.2, 0], [0.9, 0]]],
	2: [[[0, 0.78], [0.22, 1], [0.8, 1], [1, 0.8], [1, 0.62], [0, 0], [1, 0]]],
	3: [[[0, 1], [0.78, 1], [1, 0.86], [1, 0.66], [0.8, 0.52], [0.3, 0.52]],
		[[0.8, 0.52], [1, 0.38], [1, 0.14], [0.78, 0], [0, 0]]],
	4: [[[0.78, 0], [0.78, 1], [0, 0.32], [1, 0.32]]],
	5: [[[1, 1], [0, 1], [0, 0.56], [0.8, 0.56], [1, 0.38], [1, 0.18], [0.8, 0], [0, 0]]],
	6: [[[0.95, 1], [0.2, 1], [0, 0.8], [0, 0], [1, 0], [1, 0.56], [0, 0.56]]],
	7: [[[0, 1], [1, 1], [0.35, 0]]],
	8: [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]], [[0, 0.52], [1, 0.52]]],
	9: [[[0.05, 0], [0.8, 0], [1, 0.2], [1, 1], [0, 1], [0, 0.44], [1, 0.44]]],
}


## Number painted on a surface: strokes in the XY plane of t, facing +Z,
## centred, h tall.
func number(t: Transform3D, n: int, h: float, col: Color, fin := GLOSS) -> void:
	var digits := str(n)
	var w := h * 0.55
	var gap := h * 0.22
	var total := digits.length() * w + (digits.length() - 1) * gap
	var sw := h * 0.17
	for k in digits.length():
		var ox := -total * 0.5 + k * (w + gap)
		for line in DIGITS[int(digits[k])]:
			for i in line.size() - 1:
				var p := Vector2(ox + float(line[i][0]) * w, (float(line[i][1]) - 0.5) * h)
				var q := Vector2(ox + float(line[i + 1][0]) * w, (float(line[i + 1][1]) - 0.5) * h)
				_stroke(t, p, q, sw, col, fin)


func _stroke(t: Transform3D, p: Vector2, q: Vector2, w: float, col: Color, fin: int) -> void:
	var d := (q - p).normalized()
	var s := Vector2(-d.y, d.x) * w * 0.5
	p -= d * w * 0.5
	q += d * w * 0.5
	var a := Vector3(p.x + s.x, p.y + s.y, 0)
	var b := Vector3(q.x + s.x, q.y + s.y, 0)
	var c := Vector3(q.x - s.x, q.y - s.y, 0)
	var e := Vector3(p.x - s.x, p.y - s.y, 0)
	var n := Vector3(0, 0, 1)
	var nb := _nbasis(t)
	_tri(t, nb, fin, col, a, b, c, n, n, n)
	_tri(t, nb, fin, col, a, c, e, n, n, n)
