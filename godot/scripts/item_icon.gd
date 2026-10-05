class_name ItemIcon
extends Control
## Draws the held item: 1 turbo (lightning), 2 banana, 3 missile, 4 star.

var item := 0
var rolling := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.45
	var ink := Color(0.08, 0.08, 0.14)
	match item:
		1:
			var pts := PackedVector2Array([
				Vector2(0.15, -1.0), Vector2(-0.55, 0.12), Vector2(-0.05, 0.12),
				Vector2(-0.2, 1.0), Vector2(0.55, -0.15), Vector2(0.05, -0.15),
			])
			_poly(pts, c, r, Color("ffd43b"), ink)
		2:
			draw_arc(c + Vector2(r * 0.15, -r * 0.35), r * 0.8, 0.35, 2.75, 24, ink, r * 0.5, true)
			draw_arc(c + Vector2(r * 0.15, -r * 0.35), r * 0.8, 0.4, 2.7, 24, Color("ffd43b"), r * 0.36, true)
			draw_circle(c + Vector2(r * 0.15, -r * 0.35) + Vector2(cos(0.38), sin(0.38)) * r * 0.8, r * 0.1, Color("5b3a1a"))
		3:
			var body := PackedVector2Array([Vector2(-0.25, 0.75), Vector2(-0.25, -0.35), Vector2(0.0, -1.0),
				Vector2(0.25, -0.35), Vector2(0.25, 0.75)])
			_poly(PackedVector2Array([Vector2(-0.25, 0.25), Vector2(-0.6, 0.8), Vector2(-0.25, 0.75)]), c, r, Color("f5f5f5"), ink)
			_poly(PackedVector2Array([Vector2(0.25, 0.25), Vector2(0.6, 0.8), Vector2(0.25, 0.75)]), c, r, Color("f5f5f5"), ink)
			_poly(body, c, r, Color("e63946"), ink)
			_poly(PackedVector2Array([Vector2(-0.25, -0.35), Vector2(0.0, -1.0), Vector2(0.25, -0.35)]), c, r, Color("f5f5f5"), ink)
		4:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + i * PI / 5.0
				var rr := 1.0 if i % 2 == 0 else 0.45
				pts.append(Vector2(cos(a), sin(a)) * rr)
			_poly(pts, c, r, Color("ffc43d"), ink)
	if rolling:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.06))


func _poly(pts: PackedVector2Array, c: Vector2, r: float, fill: Color, ink: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + p * r)
	draw_colored_polygon(out, fill)
	var loop := out.duplicate()
	loop.append(out[0])
	draw_polyline(loop, ink, maxf(2.0, r * 0.1), true)
