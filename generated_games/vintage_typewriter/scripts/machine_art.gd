extends Control
class_name MachineArt
## Draws 1935 Royal Quiet De Luxe chassis: charcoal crinkle, chrome, ribbon, badge.

@export var crinkle_path: String = "res://assets/images/crinkle.png"

var _crinkle: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(crinkle_path):
		_crinkle = load(crinkle_path) as Texture2D
	elif FileAccess.file_exists(ProjectSettings.globalize_path(crinkle_path)):
		var img := Image.load_from_file(ProjectSettings.globalize_path(crinkle_path))
		if img:
			_crinkle = ImageTexture.create_from_image(img)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	# Outer charcoal body
	_draw_rounded(r.grow(-2), Color(0.16, 0.16, 0.17), 28)
	if _crinkle:
		draw_texture_rect(_crinkle, r.grow(-6), true, Color(1, 1, 1, 0.35))
	# Ribbon cover shelf
	var cover := Rect2(r.position + Vector2(40, 8), Vector2(r.size.x - 80, r.size.y * 0.28))
	_draw_rounded(cover, Color(0.14, 0.14, 0.15), 22)
	# Chrome trim line
	draw_line(Vector2(50, cover.end.y - 2), Vector2(r.size.x - 50, cover.end.y - 2), Color(0.75, 0.76, 0.78), 2.0)
	# Typebasket well
	var well := Rect2(r.position + Vector2(90, cover.end.y - 6), Vector2(r.size.x - 180, 70))
	_draw_rounded(well, Color(0.08, 0.08, 0.09), 10)
	# Platen cylinder hint
	var platen := Rect2(r.position + Vector2(70, 4), Vector2(r.size.x - 140, 36))
	_draw_rounded(platen, Color(0.05, 0.05, 0.05), 14)
	# Knobs
	_draw_knob(Vector2(52, 22), 18)
	_draw_knob(Vector2(r.size.x - 52, 22), 18)
	# Carriage return lever (left chrome)
	_draw_lever(Vector2(28, 50))
	# Two-tone ribbon strip
	var rx := r.size.x * 0.5 - 40
	draw_rect(Rect2(rx, cover.end.y - 18, 80, 7), Color(0.04, 0.04, 0.04))
	draw_rect(Rect2(rx, cover.end.y - 11, 80, 6), Color(0.7, 0.11, 0.11))
	# ROYAL badge
	var badge := Rect2(r.size.x * 0.5 - 36, cover.end.y + 4, 72, 18)
	_draw_rounded(badge, Color(0.78, 0.78, 0.8), 3)
	draw_rect(badge.grow(-2), Color(0.08, 0.08, 0.08))
	draw_string(ThemeDB.fallback_font, badge.position + Vector2(10, 14), "ROYAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.92, 0.9))
	# Keyboard deck (slightly warmer under keys)
	var deck := Rect2(50, r.size.y * 0.42, r.size.x - 100, r.size.y * 0.52)
	_draw_rounded(deck, Color(0.18, 0.14, 0.12), 16)


func _draw_rounded(rect: Rect2, color: Color, radius: float) -> void:
	var pts := PackedVector2Array()
	var colors := PackedColorArray()
	# Approximate with filled rects + circles for speed
	draw_rect(Rect2(rect.position + Vector2(radius, 0), rect.size - Vector2(radius * 2, 0)), color)
	draw_rect(Rect2(rect.position + Vector2(0, radius), Vector2(rect.size.x, rect.size.y - radius * 2)), color)
	draw_circle(rect.position + Vector2(radius, radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(rect.end - Vector2(radius, radius), radius, color)


func _draw_knob(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color(0.07, 0.07, 0.07))
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var p0 := center + Vector2(cos(a), sin(a)) * (radius * 0.55)
		var p1 := center + Vector2(cos(a), sin(a)) * (radius * 0.92)
		draw_line(p0, p1, Color(0.2, 0.2, 0.2), 1.5)
	draw_arc(center, radius, 0, TAU, 24, Color(0.35, 0.35, 0.36), 2.0)


func _draw_lever(base: Vector2) -> void:
	var chrome := Color(0.82, 0.83, 0.85)
	var pts := PackedVector2Array([
		base,
		base + Vector2(-6, 30),
		base + Vector2(-18, 70),
		base + Vector2(-10, 95),
		base + Vector2(8, 88),
		base + Vector2(4, 55),
		base + Vector2(10, 20),
	])
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], chrome, 5.0)
	draw_circle(pts[pts.size() - 1], 8.0, chrome)
	draw_circle(pts[pts.size() - 1], 5.0, Color(0.65, 0.66, 0.68))
