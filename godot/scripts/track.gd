class_name Track
extends RefCounted
## Track centre line: a closed centripetal Catmull-Rom spline resampled at
## ~2 m spacing, with tangents, normals and curvature per sample.

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
