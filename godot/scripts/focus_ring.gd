class_name FocusRing
extends Control
## The keyboard / gamepad cursor in menus: a thin white pulsing frame just
## outside the focused button, so it never mixes with the gold fill of the
## selected option. Hidden while the mouse or touch is used; an arrow key
## or the gamepad brings it back.

static var shown := false   # keys or a gamepad are in use

var _box := StyleBoxFlat.new()
var _drawn := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box.draw_center = false
	_box.set_border_width_all(2)
	_box.set_corner_radius_all(14)
	_box.anti_aliasing = true


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton or e is InputEventScreenTouch:
		shown = false
	elif (e is InputEventKey or e is InputEventJoypadButton) and e.is_pressed():
		shown = true
	elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.5:
		shown = true


func _process(_delta: float) -> void:
	if shown or _drawn:
		queue_redraw()


func _draw() -> void:
	_drawn = false
	if not shown:
		return
	var f := get_viewport().gui_get_focus_owner()
	if not (f is BaseButton) or not f.is_visible_in_tree() or (f as BaseButton).disabled:
		return
	var r := f.get_global_rect().grow(4.0)
	# inside a scrolled list only the visible part
	var p := f.get_parent()
	while p != null:
		if p is ScrollContainer:
			r = r.intersection((p as Control).get_global_rect())
			break
		p = p.get_parent()
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_box.border_color = Color(1, 1, 1, 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 6.0)))
	draw_style_box(_box, Rect2(r.position - global_position, r.size))
	_drawn = true
