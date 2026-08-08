extends Control
## Ink blot soak/spread on paper at strike point.

var _life := 0.0
var _max_life := 0.55
var _radius := 4.0
var _color := Color("1a1a1a")
var _spread := 1.0


func setup(pos: Vector2, color: Color, radius: float = 4.0) -> void:
	position = pos
	_color = color
	_radius = radius
	_life = 0.0
	z_index = 5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_life += delta
	var t := clampf(_life / _max_life, 0.0, 1.0)
	_spread = lerpf(0.35, 1.65, ease(t, 0.45))
	modulate.a = lerpf(0.95, 0.0, ease(t, 2.2))
	queue_redraw()
	if t >= 1.0:
		queue_free()


func _draw() -> void:
	var r := _radius * _spread
	var a := modulate.a
	var c := _color
	c.a = 0.55 * a
	draw_circle(Vector2.ZERO, r, c)
	c.a = 0.32 * a
	draw_circle(Vector2(r * 0.22, r * 0.08), r * 0.72, c)
	c.a = 0.18 * a
	draw_circle(Vector2(-r * 0.18, r * 0.14), r * 0.95, c)
