class_name BalloonIcons
extends Control
## A row of balloons (Etapa H): how many a kart still has, in its colour;
## the ones already lost as faint outlines. HUD and battle results.

var count := Game.BALLOONS
var total := Game.BALLOONS
var color := Color.WHITE
var px := 24.0


func _init(c: Color, size_px: float) -> void:
	color = c
	px = size_px
	custom_minimum_size = Vector2(px * 0.86 * total + 4.0, px * 1.4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(n: int) -> void:
	if n != count:
		count = n
		queue_redraw()


func _draw() -> void:
	var r := px * 0.36
	for i in total:
		var c := Vector2(r + 2.0 + i * px * 0.86, r * 1.18 + 2.0)
		if i < count:
			draw_line(c + Vector2(0, r * 1.15), c + Vector2(r * 0.25, r * 2.5), Color(1, 1, 1, 0.75), maxf(1.0, px / 16.0), true)
			draw_set_transform(c, 0.0, Vector2(1.0, 1.18))
			draw_circle(Vector2.ZERO, r + 1.5, Color(0.05, 0.07, 0.1, 0.55))
			draw_circle(Vector2.ZERO, r, color)
			draw_circle(Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.55))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_set_transform(c, 0.0, Vector2(1.0, 1.18))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(1, 1, 1, 0.3), maxf(1.0, px / 14.0), true)
			draw_set_transform(Vector2.ZERO)
