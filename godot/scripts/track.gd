class_name Track
extends RefCounted
## Track centre line: a closed centripetal Catmull-Rom spline resampled at
## ~2 m spacing, with tangents, normals and curvature per sample, plus the
## height of the road (hills, banked corners, one jump ramp) and the shape
## of the land around it.

var def: Dictionary
var n := 0
var length := 0.0
var step := 0.0
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var tx := PackedFloat32Array()
var tz := PackedFloat32Array()
var nx := PackedFloat32Array()
var nz := PackedFloat32Array()
var curv := PackedFloat32Array()
var min_x := 0.0
var max_x := 0.0
var min_z := 0.0
var max_z := 0.0
var cx := 0.0
var cz := 0.0
var radius := 0.0
var lake := {}
var _grid := {}
const CELL := 24.0

# --- heights. The road surface at sample i, `la` metres to the right and
# `along` metres ahead: y[i] + la * bank[i] (+ the ramp), interpolated
# between samples (road_y).
var y := PackedFloat32Array()       # centre line height
var slope := PackedFloat32Array()   # height change per metre along the track
var bank := PackedFloat32Array()    # height change per metre to the right (+n)
var ramp := {}                      # the jump: {i: first sample, len: metres, h: lip height}
const FLAT_FROM := -90.0            # the start straight stays level (stands, grid, podium)
const FLAT_TO := 110.0
const BANK_K := 7.0                 # bank per unit of curvature
const BANK_MAX := 0.21              # about 12 degrees
const RAMP_LEN := 8.0
const RAMP_H := 1.3

# --- land around the track: a height grid every FCELL metres. Near the road
# it continues the road surface sideways, further out it blends into gentle
# natural rolls that fade to 0 at the edge (where the flat far ground starts).
var f_x0 := 0.0
var f_z0 := 0.0
var f_w := 0
var f_h := 0
var field := PackedFloat32Array()
var lake_y := 0.0
const FCELL := 6.0
const FMARGIN := 200.0


func _init(d: Dictionary) -> void:
	def = d
	var pts: Array = d.pts
	var dense := PackedVector2Array()
	var cnt := pts.size()
	for i in cnt:
		var p0: Vector2 = pts[(i - 1 + cnt) % cnt]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % cnt]
		var p3: Vector2 = pts[(i + 2) % cnt]
		for k in 100:
			dense.append(_catmull(p0, p1, p2, p3, k / 100.0))
	dense.append(dense[0])
	# cumulative length
	var cum := PackedFloat32Array()
	cum.resize(dense.size())
	var total := 0.0
	for i in range(1, dense.size()):
		total += dense[i].distance_to(dense[i - 1])
		cum[i] = total
	length = total
	n = int(round(length / 2.0))
	step = length / n
	x.resize(n); z.resize(n); tx.resize(n); tz.resize(n); nx.resize(n); nz.resize(n); curv.resize(n)
	var j := 0
	min_x = INF; max_x = -INF; min_z = INF; max_z = -INF
	for i in n:
		var target := i * step
		while j < dense.size() - 2 and cum[j + 1] < target:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var f := 0.0 if seg <= 0.0 else (target - cum[j]) / seg
		var p := dense[j].lerp(dense[j + 1], f)
		x[i] = p.x
		z[i] = p.y
		min_x = minf(min_x, p.x); max_x = maxf(max_x, p.x)
		min_z = minf(min_z, p.y); max_z = maxf(max_z, p.y)
	for i in n:
		var a := (i - 1 + n) % n
		var b := (i + 1) % n
		var d2 := Vector2(x[b] - x[a], z[b] - z[a]).normalized()
		tx[i] = d2.x; tz[i] = d2.y
		nx[i] = -d2.y; nz[i] = d2.x
	for i in n:
		var a := (i - 3 + n) % n
		var b := (i + 3) % n
		var ha := atan2(tx[a], tz[a])
		var hb := atan2(tx[b], tz[b])
		curv[i] = wrapf(hb - ha, -PI, PI) / (6.0 * step)
	cx = (min_x + max_x) * 0.5
	cz = (min_z + max_z) * 0.5
	radius = Vector2(max_x - min_x, max_z - min_z).length() * 0.5
	for i in n:
		var key := Vector2i(floori(x[i] / CELL), floori(z[i] / CELL))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(i)
	_find_lake()
	_profile()


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	# centripetal (alpha = 0.5), Barry–Goldman pyramid
	var t0 := 0.0
	var t1 := t0 + maxf(1e-4, pow(p0.distance_to(p1), 0.5))
	var t2 := t1 + maxf(1e-4, pow(p1.distance_to(p2), 0.5))
	var t3 := t2 + maxf(1e-4, pow(p2.distance_to(p3), 0.5))
	var t := lerpf(t1, t2, u)
	var a1 := p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
	var a2 := p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
	var b2 := a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
	return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))


## Nearest centre sample. hint < 0 searches the whole track.
## Returns [idx, lateral offset, offset along the tangent].
func project(px: float, pz: float, hint: int) -> Array:
	var best := 0
	var bd := INF
	if hint < 0:
		for i in n:
			var dx := px - x[i]
			var dz := pz - z[i]
			var d := dx * dx + dz * dz
			if d < bd:
				bd = d
				best = i
	else:
		for k in range(-30, 31):
			var i := (hint + k + n) % n
			var dx := px - x[i]
			var dz := pz - z[i]
			var d := dx * dx + dz * dz
			if d < bd:
				bd = d
				best = i
	var ex := px - x[best]
	var ez := pz - z[best]
	return [best, ex * nx[best] + ez * nz[best], ex * tx[best] + ez * tz[best]]


func arc_pos(idx: int, along: float) -> float:
	return fposmod(idx * step + along, length)


func heading(i: int) -> float:
	return atan2(tx[i], tz[i])


func min_dist(px: float, pz: float) -> float:
	var bd := INF
	for i in range(0, n, 2):
		var dx := px - x[i]
		var dz := pz - z[i]
		bd = minf(bd, dx * dx + dz * dz)
	return sqrt(bd)


## True when any centre sample lies within r of the point (spatial hash).
func near(px: float, pz: float, r: float) -> bool:
	var r2 := r * r
	for gx in range(floori((px - r) / CELL), floori((px + r) / CELL) + 1):
		for gz in range(floori((pz - r) / CELL), floori((pz + r) / CELL) + 1):
			var cell = _grid.get(Vector2i(gx, gz))
			if cell == null:
				continue
			for i in cell:
				var dx := px - x[i]
				var dz := pz - z[i]
				if dx * dx + dz * dz < r2:
					return true
	return false


func inside(px: float, pz: float) -> bool:
	var c := false
	var j := n - 1
	for i in n:
		var xi := x[i]
		var zi := z[i]
		var xj := x[j]
		var zj := z[j]
		if (zi > pz) != (zj > pz) and px < (xj - xi) * (pz - zi) / (zj - zi) + xi:
			c = not c
		j = i
	return c


# ================================================================== lake
## The lake goes into the infield where there is the most room.
func _find_lake() -> void:
	lake = {}
	if def.theme.get("lake") == null:
		return
	var bx := 0.0
	var bz := 0.0
	var bd := 0.0
	var gx := min_x
	while gx <= max_x:
		var gz := min_z
		while gz <= max_z:
			if inside(gx, gz):
				var d := min_dist(gx, gz)
				if d > bd:
					bd = d
					bx = gx
					bz = gz
			gz += 16.0
		gx += 16.0
	var r := minf(70.0, bd - Game.BAR - 8.0)
	if r > 12.0:
		lake = {"x": bx, "z": bz, "r": r + 3.0, "water": r}


# ================================================================== heights
## Arc distance from the start line, -length/2 .. length/2.
func _from_start(i: int) -> float:
	var d := i * step
	return d - length if d > length * 0.5 else d


## 1 on the level start straight, fading to 0 over 80 m on either side.
func _flat(i: int) -> float:
	var d := _from_start(i)
	if d >= FLAT_FROM and d <= FLAT_TO:
		return 1.0
	var out := FLAT_FROM - d if d < FLAT_FROM else d - FLAT_TO
	return 1.0 - smoothstep(0.0, 80.0, out)


func _arc(i: int, j: int) -> float:
	var d := absi(i - j)
	return mini(d, n - d) * step


## Rolling hills from two waves along the lap, the start straight level, a
## hill with a ramp on the straightest stretch, close parts of the track
## pulled to similar heights, corners banked by their curvature.
func _profile() -> void:
	var hp: Dictionary = def.get("hills", {})
	var amp := float(hp.get("amp", 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def.seed) * 7919 + 17
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	y.resize(n)
	slope.resize(n)
	bank.resize(n)
	for i in n:
		var u := float(i) / n
		y[i] = amp * (0.65 * sin(TAU * 3.0 * u + ph1) + 0.35 * sin(TAU * 5.0 * u + ph2)) * (1.0 - _flat(i))
	# the jump: a hill on the straightest stretch, the ramp just past its top
	var ji := _pick_jump()
	if ji >= 0 and amp > 0.0:
		var hill := float(hp.get("jump_hill", 2.5))
		for i in n:
			var d := _from_start(i) - _from_start(ji)
			if d > length * 0.5:
				d -= length
			elif d < -length * 0.5:
				d += length
			var b := smoothstep(-80.0, -6.0, d) if d < 0.0 else 1.0 - smoothstep(4.0, 70.0, d)
			y[i] += hill * b * (1.0 - _flat(i))
		ramp = {"i": ji, "len": RAMP_LEN, "h": RAMP_H}
	_relax()
	for _p in 6:
		var o := y.duplicate()
		for i in n:
			y[i] = (o[(i - 1 + n) % n] + 2.0 * o[i] + o[(i + 1) % n]) * 0.25
	for i in n:
		y[i] *= 1.0 - _flat(i)
	for i in n:
		slope[i] = (y[(i + 1) % n] - y[(i - 1 + n) % n]) / (2.0 * step)
	# banked corners: the outside of a bend is higher
	var cs := PackedFloat32Array()
	cs.resize(n)
	for i in n:
		var acc := 0.0
		for k in range(-8, 9):
			acc += curv[(i + k + n) % n]
		cs[i] = acc / 17.0
	for i in n:
		var b := clampf(cs[i] * BANK_K, -BANK_MAX, BANK_MAX) * (1.0 - _flat(i))
		if not ramp.is_empty() and _arc(i, int(ramp.i)) < 30.0:
			b = 0.0
		bank[i] = b
	for _p in 4:
		var o := bank.duplicate()
		for i in n:
			bank[i] = (o[(i - 1 + n) % n] + 2.0 * o[i] + o[(i + 1) % n]) * 0.25


## Where the ramp goes: the straightest stretch away from the start and the
## item boxes (30 m of run-up and 40 m of landing).
func _pick_jump() -> int:
	var best := -1
	var bv := INF
	for i in range(int(n * 0.2), int(n * 0.88)):
		var ok := true
		for f in def.boxes:
			if _arc(i, int(float(f) * n)) < 40.0:
				ok = false
		if not ok or _flat(i) > 0.0:
			continue
		var v := 0.0
		for k in range(-15, 21):
			v = maxf(v, absf(curv[(i + k + n) % n]))
		if v < bv:
			bv = v
			best = i
	return best


## Parts of the lap that run close to each other (far apart along the lap)
## get similar heights, so the land between them is not a cliff.
func _relax() -> void:
	var pairs: Array = []
	for i in range(0, n, 2):
		var cx0 := floori(x[i] / CELL)
		var cz0 := floori(z[i] / CELL)
		for gx in range(cx0 - 3, cx0 + 4):
			for gz in range(cz0 - 3, cz0 + 4):
				var cell = _grid.get(Vector2i(gx, gz))
				if cell == null:
					continue
				for j in cell:
					if j <= i or j % 2 == 1 or _arc(i, j) < 140.0:
						continue
					var d := Vector2(x[i] - x[j], z[i] - z[j]).length()
					if d < 72.0:
						pairs.append([i, j, 1.0 - d / 72.0])
	if pairs.is_empty():
		return
	for it in 40:
		for p in pairs:
			var i: int = p[0]
			var j: int = p[1]
			var w: float = p[2] * 0.25
			var diff := y[j] - y[i]
			y[i] += diff * w
			y[j] -= diff * w
		var o := y.duplicate()
		for i in n:
			y[i] = (o[(i - 1 + n) % n] + 2.0 * o[i] + o[(i + 1) % n]) * 0.25


## Height of the lip of the ramp at arc offset d metres past its start.
func _ramp_at(i: int, along: float) -> float:
	var d := (i - int(ramp.i) + n) % n * step + along
	if d > length * 0.5:
		d -= length
	if d < 0.0 or d >= float(ramp.len):
		return 0.0
	return float(ramp.h) * d / float(ramp.len)


## Road surface height at sample i, la metres right of the centre line and
## along metres ahead of the sample. The ramp only covers the road itself.
func road_y(i: int, la: float, along: float, with_ramp := true) -> float:
	var j := (i + 1) % n if along >= 0.0 else (i - 1 + n) % n
	var t := clampf(absf(along) / step, 0.0, 1.0)
	var h := lerpf(y[i], y[j], t) + la * lerpf(bank[i], bank[j], t)
	if with_ramp and not ramp.is_empty() and absf(la) <= Game.HW:
		h += _ramp_at(i, along)
	return h


## The ground under a point at sample i, `off` metres out: the banked road
## surface up to a little past the barriers, the land further out.
func surface(i: int, off: float) -> float:
	if absf(off) <= Game.BAR + 6.0:
		return road_y(i, off, 0.0, false)
	return terrain(x[i] + nx[i] * off, z[i] + nz[i] * off)


## Up direction of the road surface there (tilted by slope, bank and ramp).
func normal(i: int, la: float, along: float, with_ramp := true) -> Vector3:
	var sl := slope[i]
	if with_ramp and not ramp.is_empty() and absf(la) <= Game.HW and _ramp_at(i, along) > 0.0:
		sl += float(ramp.h) / float(ramp.len)
	var b := bank[i]
	return Vector3(b * tz[i] - nz[i] * sl, 1.0, nx[i] * sl - b * tx[i]).normalized()


## Nearest centre sample through the spatial hash (whole-track search if
## nothing is within two cells).
func nearest(px: float, pz: float) -> int:
	var cx0 := floori(px / CELL)
	var cz0 := floori(pz / CELL)
	var best := -1
	var bd := INF
	for gx in range(cx0 - 2, cx0 + 3):
		for gz in range(cz0 - 2, cz0 + 3):
			var cell = _grid.get(Vector2i(gx, gz))
			if cell == null:
				continue
			for i in cell:
				var dx := px - x[i]
				var dz := pz - z[i]
				var d := dx * dx + dz * dz
				if d < bd:
					bd = d
					best = i
	return best if best >= 0 else int(project(px, pz, -1)[0])


## Road surface height under a point near the track (beside the road the
## banked surface carries on to the barriers). hint: a nearby sample or -1.
func ground(px: float, pz: float, hint := -1) -> float:
	var pj := project(px, pz, hint if hint >= 0 else nearest(px, pz))
	return road_y(pj[0], clampf(pj[1], -Game.BAR - 6.0, Game.BAR + 6.0), pj[2])


# ================================================================== land
## Height of the land (bilinear in the grid; 0 outside it).
func terrain(px: float, pz: float) -> float:
	if field.is_empty():
		_build_field()
	var fx := (px - f_x0) / FCELL
	var fz := (pz - f_z0) / FCELL
	if fx < 0.0 or fz < 0.0 or fx >= f_w - 1 or fz >= f_h - 1:
		return 0.0
	var ix := int(fx)
	var iz := int(fz)
	var ux := fx - ix
	var uz := fz - iz
	var o := iz * f_w + ix
	return lerpf(lerpf(field[o], field[o + 1], ux), lerpf(field[o + f_w], field[o + f_w + 1], ux), uz)


## Height of grid node (ix, iz) – the terrain mesh uses the nodes directly.
func node_y(ix: int, iz: int) -> float:
	if field.is_empty():
		_build_field()
	return field[iz * f_w + ix]


## Builds the land grid now (f_w, f_h are set after this).
func land() -> void:
	if field.is_empty():
		_build_field()


## Gentle rolls of the land far from the road, 0 at the grid edge.
func _natural(px: float, pz: float) -> float:
	var amp := float(def.get("hills", {}).get("land", 0.0))
	var a := float(def.seed) * 0.37
	var h := amp * (sin(px * 0.011 + a) * sin(pz * 0.013 - a * 0.6) + 0.45 * sin(px * 0.029 + pz * 0.023 + a * 1.7))
	var edge := minf(minf(px - f_x0, f_x0 + (f_w - 1) * FCELL - px), minf(pz - f_z0, f_z0 + (f_h - 1) * FCELL - pz))
	return h * smoothstep(0.0, 90.0, edge)


func _build_field() -> void:
	f_x0 = min_x - FMARGIN
	f_z0 = min_z - FMARGIN
	f_w = int(ceil((max_x - min_x + 2.0 * FMARGIN) / FCELL)) + 1
	f_h = int(ceil((max_z - min_z + 2.0 * FMARGIN) / FCELL)) + 1
	var cnt := f_w * f_h
	var dmin := PackedFloat32Array()
	dmin.resize(cnt)
	dmin.fill(1e9)
	var near_i := PackedInt32Array()
	near_i.resize(cnt)
	near_i.fill(-1)
	var sw := PackedFloat32Array()
	sw.resize(cnt)
	var sh := PackedFloat32Array()
	sh.resize(cnt)
	# nearest sample within the corridor
	var rn := Game.BAR + 32.0
	var rc := int(ceil(rn / FCELL))
	for i in n:
		var cx0 := int((x[i] - f_x0) / FCELL)
		var cz0 := int((z[i] - f_z0) / FCELL)
		for iz in range(maxi(0, cz0 - rc), mini(f_h, cz0 + rc + 2)):
			var dz := f_z0 + iz * FCELL - z[i]
			for ix in range(maxi(0, cx0 - rc), mini(f_w, cx0 + rc + 2)):
				var dx := f_x0 + ix * FCELL - x[i]
				var d := dx * dx + dz * dz
				var o := iz * f_w + ix
				if d < dmin[o]:
					dmin[o] = d
					near_i[o] = i
	# smooth average of the road heights around, for the land between
	var R := 90.0
	var rw := int(ceil(R / FCELL))
	for i in range(0, n, 3):
		var cx0 := int((x[i] - f_x0) / FCELL)
		var cz0 := int((z[i] - f_z0) / FCELL)
		for iz in range(maxi(0, cz0 - rw), mini(f_h, cz0 + rw + 2)):
			var dz := f_z0 + iz * FCELL - z[i]
			for ix in range(maxi(0, cx0 - rw), mini(f_w, cx0 + rw + 2)):
				var dx := f_x0 + ix * FCELL - x[i]
				var q := 1.0 - (dx * dx + dz * dz) / (R * R)
				if q <= 0.0:
					continue
				var o := iz * f_w + ix
				var w := q * q * q
				sw[o] += w
				sh[o] += w * y[i]
	field.resize(cnt)
	var lake_r := float(lake.get("r", 0.0))
	if not lake.is_empty():
		var lo := int((float(lake.z) - f_z0) / FCELL) * f_w + int((float(lake.x) - f_x0) / FCELL)
		lake_y = sh[lo] / sw[lo] if sw[lo] > 0.0 else 0.0
	for iz in f_h:
		var pz := f_z0 + iz * FCELL
		for ix in f_w:
			var px := f_x0 + ix * FCELL
			var o := iz * f_w + ix
			var nat := _natural(px, pz)
			var h := nat
			if sw[o] > 0.0:
				var d := sqrt(dmin[o]) if near_i[o] >= 0 else 1e9
				var avg := sh[o] / sw[o]
				h = lerpf(avg, nat, smoothstep(Game.BAR + 14.0, R - 6.0, d))
				if near_i[o] >= 0:
					var i := near_i[o]
					var ex := px - x[i]
					var ez := pz - z[i]
					var la := ex * nx[i] + ez * nz[i]
					var al := ex * tx[i] + ez * tz[i]
					var plane := y[i] + slope[i] * al + clampf(la, -Game.BAR - 6.0, Game.BAR + 6.0) * bank[i]
					h = lerpf(h, plane, 1.0 - smoothstep(Game.BAR + 3.0, Game.BAR + 26.0, d))
					if absf(la) < Game.HW + Game.KERB + 0.8:
						h -= 0.3   # tucked under the road and kerbs
			if lake_r > 0.0:
				var dl := Vector2(px - float(lake.x), pz - float(lake.z)).length()
				h = lerpf(lake_y - 0.05, h, smoothstep(lake_r, lake_r + 16.0, dl))
			field[o] = h
