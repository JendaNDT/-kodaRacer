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
const CREST_MAX := 0.008            # sharpest crest (1/m): even at 50 m/s under 0.7 g

# --- the racing line for the computer drivers (made on first use): how far
# right of the centre it runs at each sample, and how sharply it bends there
var _line := PackedFloat32Array()
var _line_c := PackedFloat32Array()
var _line_task := -1                # worker thread making the line
var _flat_line := PackedFloat32Array()   # the centre line, used until the racing line is ready
const LINE_W := Game.HW - 2.4       # how close to the edge of the road it may go

# --- the shortcut (Etapa E): a dirt path through the infield from the road
# at sample cut.a back to it at cut.b, made by _make_cut (empty when the
# track has no room for one)
var cut := {}
var _cgrid := {}
const CUT_W := 6.0                  # half width of the path
const CUT_IN := Game.HW * 0.45      # where on the road it starts and ends (from the centre)
## grip: how well the kart steers there, slow_add: faster (ice) than the
## usual dirt; the top speed itself depends on how much the path saves
const CUT_KINDS := {
	"dirt": {"grip": 1.0, "color": Color("8c6a46")},
	"sand": {"grip": 0.9, "color": Color("d6b47c")},
	"ice": {"grip": 0.5, "color": Color("d4ecf7")},
	"gravel": {"grip": 1.0, "color": Color("6e6873")},
}
const CUT_BY_TRACK := {"udoli": "dirt", "kanon": "sand", "laguna": "ice", "les": "dirt", "mesto": "gravel", "ostrov": "sand"}

# --- land around the track: a height grid every FCELL metres. Near the road
# it continues the road surface sideways, further out it blends into gentle
# natural rolls that fade to 0 at the edge (where the flat far ground starts).
var f_x0 := 0.0
var f_z0 := 0.0
var f_w := 0
var f_h := 0
var field := PackedFloat32Array()
var lake_y := 0.0
var edge_y := 0.0                   # height of the land at the grid edge (an island sinks into the sea)
const FCELL := 6.0
const FMARGIN := 200.0
const ISLAND_DEEP := -9.0
const SEA_Y := -0.5                 # the sea around an island


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
	_make_cut()


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
## The shortcut counts too, as if it were a road CUT_W wide: barriers open
## where it crosses them and trees keep clear of it.
func near(px: float, pz: float, r: float) -> bool:
	if not cut.is_empty():
		var rc := r - (Game.BAR - CUT_W - 1.5)
		if rc > 0.0 and _near_cut(px, pz, rc):
			return true
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
	_round_crests()
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


## Sharp tops of hills are smoothed a little more, only around them, until
## no crest is sharper than CREST_MAX. The start straight stays level.
func _round_crests() -> void:
	for _p in 60:
		var o := y.duplicate()
		var sharp := false
		for i in n:
			var c := -(o[(i + 1) % n] - 2.0 * o[i] + o[(i - 1 + n) % n]) / (step * step)
			if c <= CREST_MAX:
				continue
			sharp = true
			for k in range(-3, 4):
				var j := (i + k + n) % n
				if _flat(j) < 1.0:
					y[j] = (o[(j - 1 + n) % n] + 2.0 * o[j] + o[(j + 1) % n]) * 0.25
		if not sharp:
			return


## Starts making the racing line on a worker thread (a fraction of a second
## on a computer, longer on a phone), so a race never waits for it.
func prepare_line() -> void:
	if _line.is_empty() and _line_task < 0:
		_line_task = WorkerThreadPool.add_task(_make_line, false, "racing line")


func _line_ready() -> bool:
	if _line_task >= 0 and WorkerThreadPool.is_task_completed(_line_task):
		WorkerThreadPool.wait_for_task_completion(_line_task)
		_line_task = -2
	if _line_task == -2:
		return true
	prepare_line()
	return false


## The racing line: lateral offset from the centre at each sample (the
## centre line itself until the worker has finished).
func racing_line() -> PackedFloat32Array:
	if _line_ready():
		return _line
	if _flat_line.size() != n:
		_flat_line.resize(n)
		_flat_line.fill(0.0)
	return _flat_line


## Signed curvature of the racing line (1/m, same sign as `curv`).
func line_curv() -> PackedFloat32Array:
	return _line_c if _line_ready() else curv


## Waits for the racing line (tools and tests that need it right away).
func line_now() -> void:
	prepare_line()
	while not _line_ready():
		OS.delay_msec(5)


## Like a stiff wire laid along the road: each point moves to where the bend
## through its neighbours is smoothest (within the road), first over long
## stretches, then shorter ones. That gives "wide in, clip the apex, wide out"
## by itself and keeps the sharpest bend as gentle as the road allows.
func _make_line() -> void:
	# worked on in local arrays: the race reads them only once both are done
	var line := PackedFloat32Array()
	line.resize(n)
	line.fill(0.0)
	for pass_ in [[8, 120], [4, 100], [2, 80]]:
		var span: int = pass_[0]
		for it in int(pass_[1]):
			for i in n:
				# where the point would make the bend smoothest: (-P[i-2] + 4P[i-1] + 4P[i+1] - P[i+2]) / 6
				var a := (i - span + n) % n
				var b := (i + span) % n
				var a2 := (i - 2 * span + n) % n
				var b2 := (i + 2 * span) % n
				var mx := (4.0 * (x[a] + nx[a] * line[a] + x[b] + nx[b] * line[b])
					- (x[a2] + nx[a2] * line[a2] + x[b2] + nx[b2] * line[b2])) / 6.0
				var mz := (4.0 * (z[a] + nz[a] * line[a] + z[b] + nz[b] * line[b])
					- (z[a2] + nz[a2] * line[a2] + z[b2] + nz[b2] * line[b2])) / 6.0
				var off := (mx - x[i]) * nx[i] + (mz - z[i]) * nz[i]
				line[i] = clampf(lerpf(line[i], off, 0.5), -LINE_W, LINE_W)
	# a few gentle smoothing passes so the steering stays calm
	for _p in 3:
		var o := line.duplicate()
		for i in n:
			line[i] = clampf((o[(i - 1 + n) % n] + 2.0 * o[i] + o[(i + 1) % n]) * 0.25, -LINE_W, LINE_W)
	var lc := PackedFloat32Array()
	lc.resize(n)
	for i in n:
		var a := (i - 3 + n) % n
		var b := (i + 3) % n
		var c := (i - 1 + n) % n
		var d := (i + 1) % n
		var ha := atan2(x[c] + nx[c] * line[c] - x[a] - nx[a] * line[a], z[c] + nz[c] * line[c] - z[a] - nz[a] * line[a])
		var hb := atan2(x[b] + nx[b] * line[b] - x[d] - nx[d] * line[d], z[b] + nz[b] * line[b] - z[d] - nz[d] * line[d])
		var len := Vector2(x[b] + nx[b] * line[b] - x[a] - nx[a] * line[a], z[b] + nz[b] * line[b] - z[a] - nz[a] * line[a]).length()
		lc[i] = wrapf(hb - ha, -PI, PI) / maxf(len * 0.67, 0.1)
	_line_c = lc
	_line = line


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
	var pc := cut_at(px, pz, 3.0)
	if not pc.is_empty():
		return cut_ground(px, pz, pc[0], pc[2])
	var pj := project(px, pz, hint if hint >= 0 else nearest(px, pz))
	return road_y(pj[0], clampf(pj[1], -Game.BAR - 6.0, Game.BAR + 6.0), pj[2])


# ================================================================== shortcut
## Picks the shortcut: a path from the road at sample a, through the infield,
## back to the road at sample b, much shorter than the road between them and
## clear of every other part of the track, the lake, the start straight, the
## ramp and the item boxes. Every track gets one if there is room.
func _make_cut() -> void:
	var kind: String = CUT_BY_TRACK.get(def.id, "")
	if kind == "":
		return
	var stored: Dictionary = def.get("cut", {})
	if not stored.is_empty() and not Game.cmd_args.has("findcuts"):
		# found once by --findcuts and kept in Game.TRACKS: building it is instant
		var a := int(stored.a)
		var b := int(stored.b)
		_build_cut(_cut_path(a, b, float(stored.sa), float(stored.sb), float(stored.bow), float(stored.get("hand", 0.38))), a, b,
			float(stored.sa), float(stored.sb), kind)
		return
	var cands: Array = []
	for a in range(0, n, 3):
		if not _cut_end_ok(a):
			continue
		for span in range(int(180.0 / step), int(n * 0.45), 3):
			if a + span >= n:
				break                    # never across the start and finish line
			var b := a + span
			if not _cut_end_ok(b):
				continue
			var dx := x[b] - x[a]
			var dz := z[b] - z[a]
			var sa := signf(dx * nx[a] + dz * nz[a])
			var sb := signf(-dx * nx[b] - dz * nz[b])
			var e := Vector2(x[a] + nx[a] * sa * CUT_IN, z[a] + nz[a] * sa * CUT_IN)
			var f := Vector2(x[b] + nx[b] * sb * CUT_IN, z[b] + nz[b] * sb * CUT_IN)
			var c := e.distance_to(f)
			var main_len := span * step
			if c < 50.0 or c > 380.0 or c / main_len > 0.66 or c / main_len < 0.38:
				continue
			# the most road saved, but not a path so long the dirt eats it all
			cands.append([main_len - c * 1.7, a, b, sa, sb])
	cands.sort_custom(func(p, q): return p[0] > q[0])
	var dbg := {"cands": cands.size(), "len": 0, "clear": 0}
	for ci in mini(cands.size(), 2500):
		var cd: Array = cands[ci]
		var main_len := float((int(cd[2]) - int(cd[1]) + n) % n) * step
		# the straight-ish path first, then ones bowed to either side (around a lake or a hill)
		for variant in _CUT_SHAPES:
			var bow: float = variant[0]
			var hand: float = variant[1]
			var pts := _cut_path(int(cd[1]), int(cd[2]), float(cd[3]), float(cd[4]), bow, hand)
			var plen := 0.0
			for k in range(1, pts.size()):
				plen += pts[k].distance_to(pts[k - 1])
			if plen / main_len > 0.72 or plen / main_len < 0.45:
				dbg.len += 1
				continue
			if not _cut_smooth(pts) or not _cut_clear(pts, int(cd[1]), int(cd[2]), kind == "ice"):
				dbg.clear += 1
				continue
			_build_cut(pts, int(cd[1]), int(cd[2]), float(cd[3]), float(cd[4]), kind)
			print("FOUND CUT \"%s\": {\"a\": %d, \"b\": %d, \"sa\": %.0f, \"sb\": %.0f, \"bow\": %.0f, \"hand\": %.2f}" % [def.id, int(cd[1]), int(cd[2]), float(cd[3]), float(cd[4]), bow, hand])
			return
	print("NO CUT for %s: %d candidates, %d too short or long, %d too close to the road or the lake" % [def.id, dbg.cands, dbg.len, dbg.clear])


## Ends of a shortcut stay off the start straight and away from the ramp and the item boxes.
func _cut_end_ok(i: int) -> bool:
	if _flat(i) > 0.0:
		return false
	if not ramp.is_empty() and _arc(i, int(ramp.i)) < 50.0:
		return false
	for fb in def.boxes:
		if _arc(i, int(float(fb) * n)) < 24.0:
			return false
	return true


## A smooth curve leaving the road at a along its direction and joining it at b, every ~2 m.
## Shapes tried for each candidate: [how far it bows out (m), how long the
## curve keeps the road's direction at its ends (share of the distance)].
const _CUT_SHAPES := [[0.0, 0.38], [0.0, 0.25], [0.0, 0.55], [25.0, 0.38], [-25.0, 0.38], [50.0, 0.3], [-50.0, 0.3],
	[80.0, 0.3], [-80.0, 0.3], [110.0, 0.25], [-110.0, 0.25], [140.0, 0.2], [-140.0, 0.2]]


func _cut_path(a: int, b: int, sa: float, sb: float, bow := 0.0, hand := 0.38) -> PackedVector2Array:
	var p0 := Vector2(x[a] + nx[a] * sa * CUT_IN, z[a] + nz[a] * sa * CUT_IN)
	var p3 := Vector2(x[b] + nx[b] * sb * CUT_IN, z[b] + nz[b] * sb * CUT_IN)
	var c := p0.distance_to(p3)
	var p1 := p0 + Vector2(tx[a], tz[a]) * c * hand
	var p2 := p3 - Vector2(tx[b], tz[b]) * c * hand
	var side := (p3 - p0).normalized().orthogonal()
	var dense := PackedVector2Array()
	for k in 201:
		var t := k / 200.0
		var u := 1.0 - t
		# bow: pushed this many metres sideways in the middle, the ends stay put
		dense.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t
			+ side * bow * 16.0 * t * t * u * u)
	# even spacing
	var out := PackedVector2Array([dense[0]])
	var acc := 0.0
	for k in range(1, dense.size()):
		acc += dense[k].distance_to(dense[k - 1])
		if acc >= 2.0:
			out.append(dense[k])
			acc = 0.0
	if out[out.size() - 1].distance_to(p3) > 0.5:
		out.append(p3)
	return out


## No loops or hairpins on the path: no bend tighter than a 15 m radius
## (the path is driven slowly, a turbo is only fired on its straighter parts).
func _cut_smooth(pts: PackedVector2Array) -> bool:
	for k in range(2, pts.size()):
		var h0 := (pts[k - 1] - pts[k - 2]).angle()
		var h1 := (pts[k] - pts[k - 1]).angle()
		if absf(wrapf(h1 - h0, -PI, PI)) > pts[k].distance_to(pts[k - 1]) / 15.0:
			return false
	return true


## The path must keep its distance from every other part of the track (it
## may touch the road only where it leaves and joins it) and from the lake.
func _cut_clear(pts: PackedVector2Array, a: int, b: int, over_ice := false) -> bool:
	var far_r := Game.BAR + CUT_W + 3.0
	var hug_r := Game.BAR + CUT_W + 0.5
	var total := 0.0
	var cum := PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		total += pts[k].distance_to(pts[k - 1])
		cum.append(total)
	for k in pts.size():
		var p := pts[k]
		var mid := cum[k] > total * 0.3 and cum[k] < total * 0.7   # well away from the road it leaves
		if not lake.is_empty() and not over_ice and p.distance_to(Vector2(float(lake.x), float(lake.z))) < float(lake.r) + CUT_W + 5.0:
			return false
		var cx0 := floori(p.x / CELL)
		var cz0 := floori(p.y / CELL)
		for gx in range(cx0 - 2, cx0 + 3):
			for gz in range(cz0 - 2, cz0 + 3):
				var cell = _grid.get(Vector2i(gx, gz))
				if cell == null:
					continue
				for j in cell:
					var d := p.distance_to(Vector2(x[j], z[j]))
					if mid and d < hug_r:
						return false
					if d < far_r and _arc(j, a) > 50.0 and _arc(j, b) > 50.0:
						return false
	return true


func _build_cut(pts: PackedVector2Array, a: int, b: int, sa: float, sb: float, kind: String) -> void:
	var m := pts.size()
	var cx_ := PackedFloat32Array()
	var cz_ := PackedFloat32Array()
	var ctx := PackedFloat32Array()
	var ctz := PackedFloat32Array()
	var cy := PackedFloat32Array()
	var cs := PackedFloat32Array()
	var total := 0.0
	for k in m:
		var p := pts[k]
		cx_.append(p.x)
		cz_.append(p.y)
		if k > 0:
			total += p.distance_to(pts[k - 1])
		cs.append(total)
		var d := (pts[mini(k + 1, m - 1)] - pts[maxi(k - 1, 0)]).normalized()
		ctx.append(d.x)
		ctz.append(d.y)
	var ya := road_y(a, sa * CUT_IN, 0.0, false)
	var yb := road_y(b, sb * CUT_IN, 0.0, false)
	# for each point the road sample beside it, or -1 where the road is too far
	# to share its surface anywhere across the path (see cut_ground)
	var road_at := PackedInt32Array()
	for k in m:
		var base := lerpf(ya, yb, smoothstep(0.0, 1.0, cs[k] / total))
		# where it runs beside the road the path lies on the road's own surface
		var pj := project(cx_[k], cz_[k], a if cs[k] < total * 0.5 else b)
		road_at.append(int(pj[0]) if absf(float(pj[1])) < Game.BAR + 8.0 + CUT_W + 4.0 else -1)
		var road := road_y(pj[0], clampf(pj[1], -Game.BAR - 6.0, Game.BAR + 6.0), pj[2], false)
		var yy := lerpf(base, road, _road_share(absf(float(pj[1]))))
		if not lake.is_empty() and Vector2(cx_[k] - float(lake.x), cz_[k] - float(lake.z)).length() < float(lake.r) + 4.0:
			yy = maxf(yy, lake_y + 0.08)   # across the frozen lake: on top of the ice
		cy.append(yy)
	var kd: Dictionary = CUT_KINDS[kind]
	# as slow as it takes for the path to lose about 10 % against the road
	# without a turbo: with a turbo or the star it wins clearly. Only the part
	# away from the road slows (beside the road the kart is still on it).
	var span_m := float((b - a + n) % n) * step
	var off_m := 0.0
	for k in range(1, m):
		var pj := project(cx_[k], cz_[k], a if cs[k] < total * 0.5 else b)
		if absf(float(pj[1])) > Game.HW + Game.KERB:
			off_m += cs[k] - cs[k - 1]
	# one per difficulty (Easy / Normal / Hard): the faster the karts, the more
	# the path's tight bends and poor grip cost, so one number cannot fit all
	var guess := clampf(off_m / maxf(1.1 * span_m - (total - off_m), 1.0), 0.3, 0.75)
	var slow: Array = [guess, guess, guess]
	if def.get("cut", {}).has("slow"):
		slow = (def.cut.slow as Array).duplicate()   # measured by --cutcal (entry, bends and all)
	cut = {"a": a, "b": b, "sa": sa, "sb": sb, "m": m, "x": cx_, "z": cz_, "tx": ctx, "tz": ctz, "y": cy, "s": cs,
		"len": total, "arc_a": a * step, "arc_span": span_m, "kind": kind,
		"slow": slow, "grip": float(kd.grip), "color": kd.color, "road_at": road_at}
	_cgrid = {}
	for k in m:
		var key := Vector2i(floori(cx_[k] / CELL), floori(cz_[k] / CELL))
		if not _cgrid.has(key):
			_cgrid[key] = []
		_cgrid[key].append(k)


## Nearest shortcut sample to a point (hint: a nearby one, or -1 to look everywhere).
## Returns [sample, metres to the right of the path, metres ahead of the sample].
func cut_project(px: float, pz: float, hint: int) -> Array:
	var m: int = cut.m
	var cxs: PackedFloat32Array = cut.x
	var czs: PackedFloat32Array = cut.z
	var best := 0
	var bd := INF
	var lo := 0 if hint < 0 else maxi(0, hint - 14)
	var hi := m if hint < 0 else mini(m, hint + 15)
	for k in range(lo, hi):
		var d := (px - cxs[k]) * (px - cxs[k]) + (pz - czs[k]) * (pz - czs[k])
		if d < bd:
			bd = d
			best = k
	var ex := px - cxs[best]
	var ez := pz - czs[best]
	var ttx: float = cut.tx[best]
	var ttz: float = cut.tz[best]
	return [best, ex * -ttz + ez * ttx, ex * ttx + ez * ttz]


## The shortcut under a point, as cut_project, or [] when the point is not on it
## (`extra` metres wider than the path; past its ends never).
func cut_at(px: float, pz: float, extra := 0.0) -> Array:
	if cut.is_empty():
		return []
	var hint := -1
	var bd := INF
	var cx0 := floori(px / CELL)
	var cz0 := floori(pz / CELL)
	for gx in range(cx0 - 1, cx0 + 2):
		for gz in range(cz0 - 1, cz0 + 2):
			var cell = _cgrid.get(Vector2i(gx, gz))
			if cell == null:
				continue
			for k in cell:
				var d := Vector2(px - float(cut.x[k]), pz - float(cut.z[k])).length_squared()
				if d < bd:
					bd = d
					hint = k
	if hint < 0:
		return []
	var pc := cut_project(px, pz, hint)
	var last: int = int(cut.m) - 1
	if absf(float(pc[1])) > CUT_W + extra or (int(pc[0]) == 0 and float(pc[2]) < 0.0) or (int(pc[0]) == last and float(pc[2]) > 0.0):
		return []
	return pc


## How much the shortcut takes the road's surface at this distance from the
## road's centre: fully up to the barriers, none 10 m past them.
static func _road_share(la: float) -> float:
	return 1.0 - smoothstep(Game.BAR - 2.0, Game.BAR + 8.0, la)


## The ground under a point on the shortcut: beside the road it is the road's
## own (banked) surface exactly where the kart is, so getting on and off is smooth.
func cut_ground(px: float, pz: float, k: int, along: float) -> float:
	var yc := cut_y(k, along)
	var hint: int = cut.road_at[k]
	if hint < 0:
		return yc                        # far from the road: the share is nothing anywhere here
	var pj := project(px, pz, hint)
	var w := _road_share(absf(float(pj[1])))
	if w <= 0.0:
		return yc
	return lerpf(yc, road_y(pj[0], clampf(pj[1], -Game.BAR - 6.0, Game.BAR + 6.0), pj[2], false), w)


## Height of the shortcut's surface at sample k, `along` metres ahead.
func cut_y(k: int, along: float) -> float:
	var ys: PackedFloat32Array = cut.y
	var j := clampi(k + (1 if along >= 0.0 else -1), 0, int(cut.m) - 1)
	if j == k:
		return ys[k]
	var gap := absf(float(cut.s[j]) - float(cut.s[k]))
	return lerpf(ys[k], ys[j], clampf(absf(along) / maxf(gap, 0.01), 0.0, 1.0))


## Up direction of the shortcut's surface (it only slopes along the way).
func cut_normal(k: int) -> Vector3:
	var ys: PackedFloat32Array = cut.y
	var m: int = cut.m
	var k0 := maxi(k - 1, 0)
	var k1 := mini(k + 1, m - 1)
	var sl := (ys[k1] - ys[k0]) / maxf(float(cut.s[k1]) - float(cut.s[k0]), 0.1)
	var ttx: float = cut.tx[k]
	var ttz: float = cut.tz[k]
	return Vector3(-ttx * sl, 1.0, -ttz * sl).normalized()


## Where on the lap a point of the shortcut counts: its share of the path
## mapped onto the stretch of road it skips (laps and places stay right).
func cut_arc(k: int, along: float) -> float:
	var sc := clampf(float(cut.s[k]) + along, 0.0, float(cut.len))
	return fposmod(float(cut.arc_a) + float(cut.arc_span) * sc / float(cut.len), length)


func cut_heading(k: int) -> float:
	return atan2(float(cut.tx[k]), float(cut.tz[k]))


## True when the shortcut's centre line comes within r of the point.
func _near_cut(px: float, pz: float, r: float) -> bool:
	var r2 := r * r
	for gx in range(floori((px - r) / CELL), floori((px + r) / CELL) + 1):
		for gz in range(floori((pz - r) / CELL), floori((pz + r) / CELL) + 1):
			var cell = _cgrid.get(Vector2i(gx, gz))
			if cell == null:
				continue
			for k in cell:
				var dx := px - float(cut.x[k])
				var dz := pz - float(cut.z[k])
				if dx * dx + dz * dz < r2:
					return true
	return false


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


## Gentle rolls of the land far from the road, edge_y at the grid edge. On
## an island the land past an oval around the track sinks below the sea.
func _natural(px: float, pz: float) -> float:
	var hp: Dictionary = def.get("hills", {})
	var amp := float(hp.get("land", 0.0))
	var a := float(def.seed) * 0.37
	var h := amp * (sin(px * 0.011 + a) * sin(pz * 0.013 - a * 0.6) + 0.45 * sin(px * 0.029 + pz * 0.023 + a * 1.7))
	var edge := minf(minf(px - f_x0, f_x0 + (f_w - 1) * FCELL - px), minf(pz - f_z0, f_z0 + (f_h - 1) * FCELL - pz))
	h *= smoothstep(0.0, 90.0, edge)
	if hp.get("island", false):
		var e := Vector2((px - cx) / ((max_x - min_x) * 0.5 + 125.0), (pz - cz) / ((max_z - min_z) * 0.5 + 125.0)).length()
		h = lerpf(h + 1.5, ISLAND_DEEP, maxf(smoothstep(0.92, 1.18, e), 1.0 - smoothstep(0.0, 60.0, edge)))
	return h


func _build_field() -> void:
	edge_y = ISLAND_DEEP if def.get("hills", {}).get("island", false) else 0.0
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
	# the land lies level with the shortcut along it and blends back beside it
	if not cut.is_empty():
		var wmax := PackedFloat32Array()
		wmax.resize(cnt)
		var tgt := PackedFloat32Array()
		tgt.resize(cnt)
		var rr := CUT_W + 12.0
		var rcell := int(ceil(rr / FCELL))
		for k in int(cut.m):
			var sx: float = cut.x[k]
			var sz: float = cut.z[k]
			var c0 := int((sx - f_x0) / FCELL)
			var r0 := int((sz - f_z0) / FCELL)
			for iz in range(maxi(0, r0 - rcell), mini(f_h, r0 + rcell + 2)):
				for ix in range(maxi(0, c0 - rcell), mini(f_w, c0 + rcell + 2)):
					var d := Vector2(f_x0 + ix * FCELL - sx, f_z0 + iz * FCELL - sz).length()
					var w := 1.0 - smoothstep(CUT_W + 1.0, rr, d)
					var o := iz * f_w + ix
					if w > wmax[o]:
						wmax[o] = w
						tgt[o] = float(cut.y[k]) - 0.15
		for o in cnt:
			if wmax[o] > 0.0:
				field[o] = lerpf(field[o], tgt[o], wmax[o])
