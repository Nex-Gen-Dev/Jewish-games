extends Control
## Tiny vector icons (no emoji / font dependence).

var kind := "play"
var color := Color.WHITE


func setup(k: String, c: Color, s: float = 24.0) -> Control:
	kind = k
	color = c
	custom_minimum_size = Vector2(s, s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	var c := size / 2.0
	match kind:
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * .4, -r * .65), c + Vector2(r * .7, 0), c + Vector2(-r * .4, r * .65)]), color)
		"coin":
			draw_circle(c, r * .9, color)
			draw_arc(c, r * .55, 0, TAU, 24, Color(0, 0, 0, .3), maxf(r * .16, 1.5), true)
		"shop":
			draw_rect(Rect2(c + Vector2(-r * .7, -r * .2), Vector2(r * 1.4, r * .95)), color, true)
			draw_arc(c + Vector2(0, -r * .2), r * .38, PI, TAU, 16, color, maxf(r * .16, 1.8), true)
		"gear":
			draw_arc(c, r * .52, 0, TAU, 24, color, r * .26, true)
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8.0)
				draw_line(c + d * r * .55, c + d * r * .92, color, r * .3)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * .6, 0), c + Vector2(-r * .15, r * .45), c + Vector2(r * .65, -r * .45)]), color, maxf(r * .22, 2.0), true)
		"lock":
			draw_rect(Rect2(c + Vector2(-r * .55, -r * .05), Vector2(r * 1.1, r * .85)), color, true)
			draw_arc(c + Vector2(0, -r * .05), r * .38, PI, TAU, 16, color, maxf(r * .16, 1.8), true)
		"chev":
			draw_polyline(PackedVector2Array([c + Vector2(-r * .25, -r * .6), c + Vector2(r * .35, 0), c + Vector2(-r * .25, r * .6)]), color, maxf(r * .2, 2.0), true)
		"star":
			var up := PackedVector2Array()
			var dn := PackedVector2Array()
			for i in 3:
				up.append(c + Vector2.from_angle(-PI / 2 + i * TAU / 3) * r * .95)
				dn.append(c + Vector2.from_angle(PI / 2 + i * TAU / 3) * r * .95)
			up.append(up[0])
			dn.append(dn[0])
			draw_polyline(up, color, maxf(r * .14, 1.5), true)
			draw_polyline(dn, color, maxf(r * .14, 1.5), true)
		"user":
			draw_circle(c + Vector2(0, -r * .3), r * .38, color)
			draw_arc(c + Vector2(0, r * .85), r * .75, PI, TAU, 16, color, r * .3, true)
		"bell":
			draw_arc(c + Vector2(0, -r * .1), r * .55, PI, TAU, 18, color, maxf(r * .22, 2.0), true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * .55, -r * .1), c + Vector2(r * .55, -r * .1), c + Vector2(r * .8, r * .5), c + Vector2(-r * .8, r * .5)]), color)
			draw_circle(c + Vector2(0, r * .72), r * .2, color)
		"help":
			draw_arc(c + Vector2(0, -r * .2), r * .45, PI * 1.05, TAU + PI * .35, 16, color, maxf(r * .2, 2.0), true)
			draw_circle(c + Vector2(0, r * .8), r * .13, color)
		_:
			draw_circle(c, r * .4, color)
