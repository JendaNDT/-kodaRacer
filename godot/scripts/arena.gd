class_name Arena
extends RefCounted
## A battle arena (Etapa H): a closed floor the karts roam freely, no laps
## and no centre line. Everything solid (the edge, the fountain, low walls,
## snow banks) is one distance field: space(x, z) is how far it is to the
## nearest solid surface, so keeping karts in, the computer drivers' eyes
## and placing things all ask the same question.
##
## The floor is flat (y = 0) except the ramps: wedges that rise towards a
## lip and drop off it, so a kart takes off there like on a track's ramp.
## A step up higher than STEP_UP stops a kart like a wall (the back of a
## ramp, its high sides).

const STEP_UP := 0.45       # a kart rolls up a step this high, a higher one is a wall
const EDGE_TOP := 1.0e6     # nothing flies over the edge
const ICE_GRIP := 0.5       # steering on the ice (as on the Ice Lagoon's shortcut)

var def: Dictionary
var id := ""
var round_shape := false
var half := 0.0             # square: half its side; round: its radius
var corner := 0.0           # square: radius of the rounded corners
var radius := 0.0           # how far from the centre the edge reaches (sky, minimap)
var cx := 0.0
var cz := 0.0
var min_x := 0.0
var max_x := 0.0
var min_z := 0.0
var max_z := 0.0
var circles: Array = []     # {x, z, r, top}: fountain, planters
var caps: Array = []        # {x0, z0, x1, z1, r, top}: low walls, snow banks (a segment with a radius)
var ramps: Array = []       # {x, z, h, len, w, top}: wedge rising along heading h, lip at the far end
var ice := {}               # {x, z, r}: slippery disc
var starts: Array = []      # Vector3(x, z, heading), facing the middle
var boxes: Array = []       # Vector2: item boxes, scattered over the floor


func _init(d: Dictionary) -> void:
	def = d
	id = String(d.id)
	match id:
		"namesti":
			_square_layout()
		_:
			_round_layout()
	_ramp_sides()
	radius = half if round_shape else half * sqrt(2.0) - corner * (sqrt(2.0) - 1.0)
	min_x = -half
	max_x = half
	min_z = -half
	max_z = half
	_place_starts()
	_place_boxes()


## Náměstí: a square with rounded corners, a fountain in the middle, four
## planters around it, a low wall in front of each side and a ramp in each
## of the lanes along the edge.
func _square_layout() -> void:
	round_shape = false
	half = 66.0
	corner = 16.0
	circles.append({"x": 0.0, "z": 0.0, "r": 8.0, "top": 1.0})
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			circles.append({"x": 21.0 * sx, "z": 21.0 * sz, "r": 2.6, "top": 1.0})
	for k in 4:
		var a := k * PI * 0.5
		var n := Vector2(sin(a), cos(a))          # out from the middle
		var t := Vector2(n.y, -n.x)               # along the side
		var c := n * 38.0
		caps.append({"x0": c.x - t.x * 12.0, "z0": c.y - t.y * 12.0, "x1": c.x + t.x * 12.0, "z1": c.y + t.y * 12.0,
			"r": 0.8, "top": 1.0})
		# the ramp in the lane between the wall and the edge, driven along the side
		var rc := n * 52.0
		ramps.append({"x": rc.x, "z": rc.y, "h": atan2(t.x, t.y), "len": 10.0, "w": 8.0, "top": 1.5})


## Ledový stadion: a round rink, slippery ice in the middle, a ring of snow
## banks to hide behind and three ramps near the boards.
func _round_layout() -> void:
	round_shape = true
	half = 70.0
	ice = {"x": 0.0, "z": 0.0, "r": 26.0}
	for k in 6:
		var a := (k + 0.5) * TAU / 6.0
		var n := Vector2(sin(a), cos(a))
		var t := Vector2(n.y, -n.x)
		var c := n * 44.0
		caps.append({"x0": c.x - t.x * 6.0, "z0": c.y - t.y * 6.0, "x1": c.x + t.x * 6.0, "z1": c.y + t.y * 6.0,
			"r": 2.4, "top": 2.0})
	for k in 3:
		var a := k * TAU / 3.0 + PI / 6.0
		var n := Vector2(sin(a), cos(a))
		var t := Vector2(n.y, -n.x)
		var rc := n * 58.0
		ramps.append({"x": rc.x, "z": rc.y, "h": atan2(t.x, t.y), "len": 10.0, "w": 8.0, "top": 1.5})


## Where a ramp's side is higher than a kart can roll up, it is a thin wall
## (part of the solid shape, so karts slide along it and the computer
## drivers see it); the low start of the sides can be driven over. So is
## its back, just past the lip, a little lower than the top: a kart rolling
## off the lip is higher than that and flies over it.
func _ramp_sides() -> void:
	for r in ramps:
		var h := float(r.h)
		var f := Vector2(sin(h), cos(h))
		var right := Vector2(cos(h), -sin(h))
		var ln := float(r.len)
		var a0 := STEP_UP / float(r.top) * ln + 0.5
		for sx: float in [-1.0, 1.0]:
			var p0 := Vector2(float(r.x), float(r.z)) + f * (a0 - ln * 0.5) + right * sx * float(r.w) * 0.5
			var p1 := Vector2(float(r.x), float(r.z)) + f * (ln * 0.5) + right * sx * float(r.w) * 0.5
			caps.append({"x0": p0.x, "z0": p0.y, "x1": p1.x, "z1": p1.y, "r": 0.3, "top": float(r.top), "ramp": true})
		var c := Vector2(float(r.x), float(r.z)) + f * (ln * 0.5 + 0.35)
		var hw := float(r.w) * 0.5
		caps.append({"x0": c.x - right.x * hw, "z0": c.y - right.y * hw, "x1": c.x + right.x * hw, "z1": c.y + right.y * hw,
			"r": 0.3, "top": float(r.top) - 0.5, "ramp": true})


# ------------------------------------------------------------------ the solid parts
## Distance from the edge inwards (negative outside).
func _edge(px: float, pz: float) -> float:
	var dx := px - cx
	var dz := pz - cz
	if round_shape:
		return half - sqrt(dx * dx + dz * dz)
	var qx := absf(dx) - (half - corner)
	var qz := absf(dz) - (half - corner)
	var out := Vector2(maxf(qx, 0.0), maxf(qz, 0.0)).length() + minf(maxf(qx, qz), 0.0) - corner
	return -out


static func _seg(px: float, pz: float, c: Dictionary) -> float:
	var ax := float(c.x0)
	var az := float(c.z0)
	var bx := float(c.x1) - ax
	var bz := float(c.z1) - az
	var u := clampf(((px - ax) * bx + (pz - az) * bz) / (bx * bx + bz * bz), 0.0, 1.0)
	return Vector2(px - ax - bx * u, pz - az - bz * u).length() - float(c.r)


## How far it is from (px, pz) to the nearest solid surface; negative inside
## one. Something higher than `above` passes over the low things; without
## the ramps' sides and backs when `no_ramps` (the computer's look ahead
## judges ramps by the way it is heading).
func space(px: float, pz: float, above := -INF, no_ramps := false) -> float:
	var d := _edge(px, pz)
	for c in circles:
		if float(c.top) > above:
			d = minf(d, Vector2(px - float(c.x), pz - float(c.z)).length() - float(c.r))
	for c in caps:
		if float(c.top) > above and not (no_ramps and c.has("ramp")):
			d = minf(d, _seg(px, pz, c))
	return d


## Direction (unit) in which space() grows fastest: away from the nearest solid.
func away(px: float, pz: float, above := -INF) -> Vector2:
	var e := 0.05
	var g := Vector2(space(px + e, pz, above) - space(px - e, pz, above), space(px, pz + e, above) - space(px, pz - e, above))
	if g.length_squared() < 1e-10:
		return Vector2(-px, -pz).normalized() if px * px + pz * pz > 1e-6 else Vector2(0, 1)
	return g.normalized()


func inside(px: float, pz: float) -> bool:
	return _edge(px, pz) > 0.0


# ------------------------------------------------------------------ ground
## Where (px, pz) is on a ramp: [ramp, along 0..len from the low end, across] or [] when not.
func _on_ramp(px: float, pz: float) -> Array:
	for r in ramps:
		var h := float(r.h)
		var fx := sin(h)
		var fz := cos(h)
		var dx := px - float(r.x)
		var dz := pz - float(r.z)
		var a := dx * fx + dz * fz + float(r.len) * 0.5
		var b := dx * fz - dz * fx
		if a >= 0.0 and a <= float(r.len) and absf(b) <= float(r.w) * 0.5:
			return [r, a, b]
	return []


func ground(px: float, pz: float) -> float:
	var on := _on_ramp(px, pz)
	if on.is_empty():
		return 0.0
	return float(on[0].top) * float(on[1]) / float(on[0].len)


func normal(px: float, pz: float) -> Vector3:
	var on := _on_ramp(px, pz)
	if on.is_empty():
		return Vector3.UP
	var r: Dictionary = on[0]
	var slope := float(r.top) / float(r.len)
	return Vector3(-sin(float(r.h)) * slope, 1.0, -cos(float(r.h)) * slope).normalized()


## How well the tyres steer here (the ice in the middle of the stadium).
func grip(px: float, pz: float) -> float:
	if not ice.is_empty() and Vector2(px - float(ice.x), pz - float(ice.z)).length() < float(ice.r):
		return ICE_GRIP
	return 1.0


func on_ice(px: float, pz: float) -> bool:
	return grip(px, pz) < 1.0


## True when (px, pz) is on a ramp or within `gap` metres of it and heading h
## is not the way up it: from the side or the back a ramp is a wall.
func ramp_blocks(px: float, pz: float, h: float, gap: float) -> bool:
	for r in ramps:
		var rh := float(r.h)
		var dx := px - float(r.x)
		var dz := pz - float(r.z)
		var a := absf(dx * sin(rh) + dz * cos(rh))
		var b := absf(dx * cos(rh) - dz * sin(rh))
		if a <= float(r.len) * 0.5 + gap and b <= float(r.w) * 0.5 + gap and absf(Game.wrap_angle(h - rh)) > 0.6:
			return true
	return false


## Near a ramp (for placing things): within `gap` metres of its footprint.
func near_ramp(px: float, pz: float, gap: float) -> bool:
	for r in ramps:
		if Vector2(px - float(r.x), pz - float(r.z)).length() < float(r.len) * 0.5 + float(r.w) * 0.5 + gap:
			return true
	return false


# ------------------------------------------------------------------ keeping a kart in
## Keeps kart k out of everything solid (walls slide it along like the
## track's tyre barriers, with the same bump) and stops it at a step up
## (back to ox, oz where it came from).
func constrain(k: Kart, ox: float, oz: float) -> void:
	var above := k.y - 0.3
	for it in 3:
		var d := space(k.x, k.z, above)
		if d >= Game.KART_R:
			break
		var n := away(k.x, k.z, above)
		var push := Game.KART_R - d
		k.x += n.x * push
		k.z += n.y * push
		var into := -(sin(k.heading) * n.x + cos(k.heading) * n.y)
		if into * k.speed > 0.0:
			var tang := atan2(n.y, -n.x)
			var facing := tang if cos(Game.wrap_angle(k.heading - tang)) >= 0.0 else tang + PI
			k.heading += Game.wrap_angle(facing - k.heading) * 0.5
			var loss := absf(into)
			k.speed *= 1.0 - 0.55 * loss
			if k.bump_cd <= 0.0 and loss > 0.2 and absf(k.speed) > 4.0:
				k.bump_cd = 0.4
				k.race.on_bump(k, loss)
	if not k.air and ground(k.x, k.z) > k.y + STEP_UP:
		# the back or a high side of a ramp: like running into a low wall
		k.x = ox
		k.z = oz
		if absf(k.speed) > 4.0 and k.bump_cd <= 0.0:
			k.bump_cd = 0.4
			k.race.on_bump(k, 0.8)
		k.speed *= -0.25


# ------------------------------------------------------------------ places
## Six starting places on a ring, all facing the middle.
func _place_starts() -> void:
	var r := 30.0 if not round_shape else 34.0
	for k in Game.MAX_KARTS:
		var a := k * TAU / Game.MAX_KARTS
		var px := sin(a) * r
		var pz := cos(a) * r
		starts.append(Vector3(px, pz, atan2(-px, -pz)))


## Item boxes all over the floor, not in rows: random spots (the same every
## time) with room around them, off the ramps, away from the starts and
## from each other.
func _place_boxes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def.seed)
	var want := 14
	var tries := 0
	while boxes.size() < want and tries < 5000:
		tries += 1
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if space(p.x, p.y) < 6.0 or near_ramp(p.x, p.y, 3.0) or not inside(p.x, p.y):
			continue
		var ok := true
		for s in starts:
			if p.distance_to(Vector2(s.x, s.y)) < 10.0:
				ok = false
		for b in boxes:
			if p.distance_to(b) < 14.0:
				ok = false
		if ok:
			boxes.append(p)


## The edge as a closed polygon (minimap, building the walls).
func outline(step := 4.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if round_shape:
		var n := maxi(24, int(TAU * half / step))
		for i in n + 1:
			var a := i * TAU / n
			pts.append(Vector2(cx + sin(a) * half, cz + cos(a) * half))
		return pts
	var inner := half - corner
	var arc_n := maxi(4, int(PI * 0.5 * corner / step))
	# corners counter-clockwise from +x +z, each a quarter circle
	for q in 4:
		var sx := 1.0 if q == 0 or q == 3 else -1.0
		var sz := 1.0 if q < 2 else -1.0
		var a0 := q * PI * 0.5
		for i in arc_n + 1:
			var a := a0 + i * PI * 0.5 / arc_n
			pts.append(Vector2(cx + sx * inner + cos(a) * corner, cz + sz * inner + sin(a) * corner))
	pts.append(pts[0])
	return pts
