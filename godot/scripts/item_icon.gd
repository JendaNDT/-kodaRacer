class_name ItemIcon
extends Control
## Draws the held item: 1 turbo (lightning), 2 banana, 3 missile, 4 star.
## While an item is being drawn it is a slot-machine reel: icons run down,
## slow down and the won item clicks into place (Hud drives `reel`).

var item := 0
var spinning := false       # show the reel instead of a single icon
var reel := 0.0             # reel position in cells; cell n is centred at reel == n
var blur := 0.0             # 0..1: icons stretch while the reel runs fast
var win_cell := -999999     # the cell that holds the won item
var win_item := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Icon on reel cell c: a fixed shuffle of the four items, the win on its cell.
func cell_item(c: int) -> int:
	if c == win_cell:
		return win_item
	return 1 + posmod(c * 7 + (c >> 2) * 3, 4)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	if not spinning:
		_item(item, c, r, 1.0)
		return
	var h := size.y + 8.0
	var base := floori(reel)
	for cell in range(base - 1, base + 2):
		var y := (reel - cell) * h
		draw_set_transform(c + Vector2(0, y), 0.0, Vector2(1.0, 1.0 + blur * 0.55))
		_item(cell_item(cell), Vector2.ZERO, r, 1.0 - blur * 0.25)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# glass of the slot window
	draw_rect(Rect2(Vector2(-8, -8), size + Vector2(16, 16)), Color(1, 1, 1, 0.05))


func _item(it: int, c: Vector2, r: float, alpha: float) -> void:
	var ink := Color(0.08, 0.08, 0.14, alpha)
	match it:
		1:
			var pts := PackedVector2Array([
				Vector2(0.15, -1.0), Vector2(-0.55, 0.12), Vector2(-0.05, 0.12),
				Vector2(-0.2, 1.0), Vector2(0.55, -0.15), Vector2(0.05, -0.15),
			])
			_poly(pts, c, r, Color("ffd43b", alpha), ink)
		2:
			draw_arc(c + Vector2(r * 0.15, -r * 0.35), r * 0.8, 0.35, 2.75, 24, ink, r * 0.5, true)
			draw_arc(c + Vector2(r * 0.15, -r * 0.35), r * 0.8, 0.4, 2.7, 24, Color("ffd43b", alpha), r * 0.36, true)
			draw_circle(c + Vector2(r * 0.15, -r * 0.35) + Vector2(cos(0.38), sin(0.38)) * r * 0.8, r * 0.1, Color("5b3a1a", alpha))
		3:
			var body := PackedVector2Array([Vector2(-0.25, 0.75), Vector2(-0.25, -0.35), Vector2(0.0, -1.0),
				Vector2(0.25, -0.35), Vector2(0.25, 0.75)])
			_poly(PackedVector2Array([Vector2(-0.25, 0.25), Vector2(-0.6, 0.8), Vector2(-0.25, 0.75)]), c, r, Color("f5f5f5", alpha), ink)
			_poly(PackedVector2Array([Vector2(0.25, 0.25), Vector2(0.6, 0.8), Vector2(0.25, 0.75)]), c, r, Color("f5f5f5", alpha), ink)
			_poly(body, c, r, Color("e63946", alpha), ink)
			_poly(PackedVector2Array([Vector2(-0.25, -0.35), Vector2(0.0, -1.0), Vector2(0.25, -0.35)]), c, r, Color("f5f5f5", alpha), ink)
		4:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var rr := 1.0 if i % 2 == 0 else 0.45
				pts.append(Vector2(cos(a), sin(a)) * rr)
			_poly(pts, c, r, Color("ffc43d", alpha), ink)


func _poly(pts: PackedVector2Array, c: Vector2, r: float, fill: Color, ink: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * r)
	draw_colored_polygon(out, fill)
	var loop := out.duplicate()
	loop.append(out[0])
	draw_polyline(loop, ink, maxf(2.0, r * 0.1), true)
