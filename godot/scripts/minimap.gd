class_name Minimap
extends Control
## Top-down track outline with a dot per kart (screen right = world -X, like the camera view).

var race: Race
var me: Kart
var _pts := PackedVector2Array()
var _for_size := Vector2.ZERO
var _sc := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _map(px: float, pz: float) -> Vector2:
	var tr := race.track
	return size * 0.5 - Vector2((px - tr.cx) * _sc, (pz - tr.cz) * _sc)


func _rebuild() -> void:
	var tr := race.track
	_for_size = size
	var pad := 12.0
	var s := minf(size.x, size.y)
	_sc = (s - 2.0 * pad) / maxf(tr.max_x - tr.min_x, tr.max_z - tr.min_z)
	_pts = PackedVector2Array()
	var i := 0
	while i <= tr.n:
		var j := i % tr.n
		_pts.append(_map(tr.x[j], tr.z[j]))
		i += 3
	_pts.append(_pts[0])


func _draw() -> void:
	if race == null or race.track == null:
		return
	if size != _for_size or _pts.is_empty():
		_rebuild()
	var tr := race.track
	if not tr.cut.is_empty():
		# the shortcut, dashed
		var c: Dictionary = tr.cut
		var k := 0
		while k + 3 < int(c.m):
			var p0 := _map(float(c.x[k]), float(c.z[k]))
			var p1 := _map(float(c.x[k + 3]), float(c.z[k + 3]))
			draw_line(p0, p1, Color(0.05, 0.07, 0.1, 0.5), 6.0, true)
			draw_line(p0, p1, Color(1.0, 0.77, 0.24, 0.95), 3.0, true)
			k += 6
	draw_polyline(_pts, Color(0.05, 0.07, 0.1, 0.6), 10.0, true)
	draw_polyline(_pts, Color(0.93, 0.95, 0.98, 0.92), 4.5, true)
	var st := _map(tr.x[0], tr.z[0])
	draw_rect(Rect2(st - Vector2(3, 3), Vector2(6, 6)), UI.KERB)
	for k in race.karts:
		if k == me:
			continue
		var p := _map(k.position.x, k.position.z)
		draw_circle(p, 4.5 if k.human else 4.0, k.ch.color)
		draw_arc(p, 4.5 if k.human else 4.0, 0, TAU, 16, Color(0.05, 0.07, 0.1, 0.8), 1.5, true)
	if me != null:
		var p := _map(me.position.x, me.position.z)
		draw_circle(p, 6.0, me.ch.color)
		draw_arc(p, 6.0, 0, TAU, 20, Color.WHITE, 2.5, true)
