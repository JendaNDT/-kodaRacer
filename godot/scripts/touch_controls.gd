class_name TouchControls
extends Control
## On-screen controls for phones: steering pad on the left, drift / item /
## brake on the right. Gas is automatic. Multi-touch aware.

var touches := {}   # touch index -> zone name
var knob := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pad_rect() -> Rect2:
	var w := minf(size.x * 0.4, 300.0)
	return Rect2(Vector2(20, size.y - 126), Vector2(w, 106))


func _buttons() -> Dictionary:
	return {
		"drift": [Vector2(size.x - 96, size.y - 92), 66.0, "DRIFT"],
		"item": [Vector2(size.x - 232, size.y - 150), 44.0, "PŘEDMĚT"],
		"brake": [Vector2(size.x - 226, size.y - 52), 34.0, "BRZDA"],
	}


func _zone_at(p: Vector2) -> String:
	if _pad_rect().grow(18).has_point(p):
		return "pad"
	var b := _buttons()
	for k in b.keys():
		if p.distance_to(b[k][0]) <= float(b[k][1]) + 12.0:
			return k
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e: InputEventScreenTouch = make_input_local(event)
		if e.pressed:
			var z := _zone_at(e.position)
			if z == "":
				return
			touches[e.index] = z
			if z == "pad":
				_steer(e.position)
			elif z == "item":
				Game.touch.item = true
			get_viewport().set_input_as_handled()
		else:
			var z: String = touches.get(e.index, "")
			touches.erase(e.index)
			if z == "pad":
				Game.touch.steer = 0.0
				knob = 0.0
		_sync()
		queue_redraw()
	elif event is InputEventScreenDrag:
		var e: InputEventScreenDrag = make_input_local(event)
		if touches.get(e.index, "") == "pad":
			_steer(e.position)
			queue_redraw()


func _steer(p: Vector2) -> void:
	var r := _pad_rect()
	var rel := (p.x - r.get_center().x) / (r.size.x * 0.5)
	knob = clampf(rel, -1.0, 1.0)
	Game.touch.steer = clampf(signf(rel) * clampf((absf(rel) - 0.08) / 0.55, 0.0, 1.0), -1.0, 1.0)


func _sync() -> void:
	var held := {}
	for z in touches.values():
		held[z] = true
	Game.touch.drift = held.has("drift")
	Game.touch.brake = held.has("brake")


func _draw() -> void:
	var font := UI.bold_font
	var line := Color(0.93, 0.95, 0.98, 0.45)
	var fill := Color(0.05, 0.07, 0.1, 0.38)
	var r := _pad_rect()
	var sb := UI.box(fill, int(r.size.y * 0.5), 2, line)
	draw_style_box(sb, r)
	var cy := r.get_center().y
	var lx := r.position.x + 26
	var rx := r.end.x - 26
	draw_colored_polygon(PackedVector2Array([Vector2(lx, cy), Vector2(lx + 18, cy - 13), Vector2(lx + 18, cy + 13)]), line)
	draw_colored_polygon(PackedVector2Array([Vector2(rx, cy), Vector2(rx - 18, cy - 13), Vector2(rx - 18, cy + 13)]), line)
	var kc := r.get_center() + Vector2(knob * (r.size.x * 0.5 - 36), 0)
	draw_circle(kc, 32, Color(0.93, 0.95, 0.98, 0.25))
	draw_arc(kc, 32, 0, TAU, 32, Color(0.93, 0.95, 0.98, 0.6), 2.0, true)
	var held := {}
	for z in touches.values():
		held[z] = true
	var b := _buttons()
	for k in b.keys():
		var c: Vector2 = b[k][0]
		var rad: float = b[k][1]
		var on := held.has(k)
		draw_circle(c, rad, Color(1.0, 0.77, 0.24, 0.45) if on else fill)
		draw_arc(c, rad, 0, TAU, 40, UI.GOLD if on else line.lightened(0.2), 2.0, true)
		var fs := 18 if k == "drift" else 12
		draw_string(font, c + Vector2(-rad, fs * 0.35), b[k][2], HORIZONTAL_ALIGNMENT_CENTER, rad * 2.0, fs, UI.PAPER)
