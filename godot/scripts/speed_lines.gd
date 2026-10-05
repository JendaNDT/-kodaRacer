class_name SpeedLines
extends Control
## White streaks rushing along the screen edges while a kart boosts or has a
## star. Each split-screen pane has its own; strength follows the speed.

const COUNT := 36

var kart: Kart
var strength := 0.0
var _lines: Array = []   # [angle, travel 0..1, length, rate, width]


func setup(k: Kart) -> void:
	kart = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in COUNT:
		_lines.append(_new_line(randf()))


func _new_line(travel: float) -> Array:
	return [randf() * TAU, travel, 0.1 + randf() * 0.22, 1.6 + randf() * 1.6, 1.2 + randf() * 2.6]


## Called by the race every frame (dt is 0 while paused).
func update_lines(dt: float) -> void:
	var want := 0.0
	if kart.boost > 0.0 or kart.star > 0.0:
		want = clampf(absf(kart.speed) / maxf(1.0, kart.max_speed()), 0.25, 1.3) / 1.3
	var was := strength
	strength = move_toward(strength, want, dt * (5.0 if want > strength else 2.2))
	if strength <= 0.0:
		if was > 0.0:
			queue_redraw()
		return
	for i in _lines.size():
		var l: Array = _lines[i]
		l[1] += dt * float(l[3])
		if l[1] > 1.0:
			_lines[i] = _new_line(0.0)
	queue_redraw()


func _draw() -> void:
	if strength <= 0.0:
		return
	var c := size * 0.5
	for l in _lines:
		var a: float = l[0]
		var t: float = l[1]
		var dir := Vector2(cos(a), sin(a))
		# inner tip starts halfway out and the streak slides past the corner
		var r0 := lerpf(0.55, 1.25, t)
		var r1 := r0 + float(l[2]) * (0.6 + strength)
		var p0 := c + dir * c * r0
		var p1 := c + dir * c * r1
		var n := Vector2(-dir.y, dir.x) * float(l[4]) * (0.6 + strength * 0.8)
		var alpha := strength * 0.55 * sin(t * PI)
		draw_colored_polygon(PackedVector2Array([p0, p1 + n, p1 - n]), Color(1, 1, 1, alpha))
