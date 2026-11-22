extends Control
## App background: near-black with a faint diagonal pattern and a warm glow.
## Drawn once (and again only if the size changes), so it costs almost nothing.

var top := Color("#17181b")
var bottom := Color("#08090a")
var accent := Color("#f5b027")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, bottom, bottom]))
	var x := -h
	while x < w:
		draw_line(Vector2(x, h), Vector2(x + h, 0), Color(1, 1, 1, 0.016), 2.0)
		x += 30.0
	for i in 7:
		draw_circle(Vector2(w * 0.08, -h * 0.04), 80.0 + i * 55.0, Color(accent.r, accent.g, accent.b, 0.016))
