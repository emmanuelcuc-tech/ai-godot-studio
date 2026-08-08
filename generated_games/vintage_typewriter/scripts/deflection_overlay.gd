extends Control
## Live Bernoulli / cantilever curve for A4 paper on the platen.

var aero: Node
var show_hud: bool = true
var samples: int = 48


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40


func bind_aero(node: Node) -> void:
	aero = node


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not show_hud or aero == null or size.x < 40.0 or size.y < 40.0:
		return
	var pts: PackedVector2Array = aero.call("deflection_polyline", samples, size) as PackedVector2Array
	if pts.is_empty():
		return
	var extrema: Dictionary = aero.call("curve_extrema", samples, size) as Dictionary
	var strongest: Vector2 = extrema.get("strongest", pts[0]) as Vector2
	var weakest: Vector2 = extrema.get("weakest", pts[pts.size() - 1]) as Vector2
	var fastest: Vector2 = extrema.get("fastest", weakest) as Vector2
	var softest: Vector2 = extrema.get("softest", strongest) as Vector2

	var panel := Rect2(8, 8, mini(240.0, size.x * 0.46), size.y - 16.0)
	draw_rect(panel, Color(0.05, 0.07, 0.1, 0.74), true)
	draw_rect(panel, Color(0.55, 0.7, 0.85, 0.35), false, 1.0)

	var origin := pts[0]
	var tip0 := Vector2(origin.x, pts[pts.size() - 1].y)
	draw_dashed_line(origin, tip0, Color(0.75, 0.78, 0.82, 0.4), 1.5, 6.0)

	if pts.size() >= 2:
		draw_polyline(pts, Color(1.0, 0.55, 0.2, 0.22), 6.0, true)
		draw_polyline(pts, Color(0.95, 0.82, 0.35, 0.95), 2.5, true)

	_draw_marker(strongest, Color(0.95, 0.28, 0.22), "STRONG\nclamp")
	_draw_marker(softest, Color(0.95, 0.7, 0.25), "stiff\nnear clip")
	_draw_marker(fastest, Color(0.45, 1.0, 0.55), "FAST\nfree edge")
	_draw_marker(weakest, Color(0.35, 0.85, 1.0), "WEAK\nmax δ")
	if bool(extrema.get("grab_active", false)):
		var gp: Vector2 = extrema.get("grab", Vector2.ZERO) as Vector2
		_draw_marker(gp, Color(1.0, 0.4, 0.85), "GRAB")

	var tip_mm := float(aero.tip) * 1000.0
	var vp := float(aero.vp)
	var ang := float(aero.blow_angle_deg)
	var dp := float(aero.delta_p)
	var fn := float(aero.force_n)
	var f0 := float(aero.f_nat)
	var mode := str(aero.call("mode_name"))
	var grab_line := ""
	if aero.grab and aero.grab.active:
		grab_line = "\ngrab ξ=%.2f η=%.2f" % [aero.grab.xi, aero.grab.eta]
	var text := "vp %.1f m/s  θ %.0f°\n%s\nΔP %.1f Pa  F %.3f N\nδ %.1f mm  f₀ %.0f Hz%s" % [
		vp, ang, mode, dp, fn, tip_mm, f0, grab_line
	]
	draw_string(
		ThemeDB.fallback_font,
		panel.position + Vector2(10, 20),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(0.85, 0.9, 0.95)
	)


func _draw_marker(p: Vector2, col: Color, label: String) -> void:
	draw_circle(p, 5.5, col)
	draw_arc(p, 8.5, 0.0, TAU, 22, col.lightened(0.35), 1.4)
	var lp := p + Vector2(11, -3)
	if lp.x > size.x - 72.0:
		lp.x = p.x - 68.0
	draw_string(ThemeDB.fallback_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
