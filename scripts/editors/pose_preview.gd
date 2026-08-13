class_name PosePreview
extends Control
## Interactive photo / pose preview.
## - Pick a clip → frames play live
## - Click + pull up/down on the image → warp that region in real time
## - Drag left/right → scrub animation poses / frames
## - Right-click → reset pose pulls

signal pose_changed(points: Array)
signal frame_changed(index: int)
signal scrub_started
signal scrub_ended

const STRIPS := 28
const FALLOFF := 0.22
const MAX_PULL := 72.0
const SCRUB_PX := 14.0

var frames: Array = []
## Absolute disk paths aligned with `frames` (empty string if unknown).
var frame_paths: PackedStringArray = PackedStringArray()
var fps: float = 8.0
var loop_anim: bool = true
var playing: bool = false
var frame_index: int = 0
## Active pull points: { "u": 0..1, "v": 0..1, "dx": px, "dy": px }
var pull_points: Array = []

var texture: Texture2D:
	get:
		return _texture
	set(value):
		_texture = value
		if frames.is_empty():
			playing = false
		queue_redraw()

var _texture: Texture2D
var _t: float = 0.0
var _dragging: bool = false
var _grab_uv: Vector2 = Vector2(0.5, 0.5)
var _grab_point_idx: int = -1
var _last_mouse: Vector2 = Vector2.ZERO
var _scrub_accum: float = 0.0
var _was_playing: bool = false
var _hint: String = "Drag ↕ pull pose · ↔ scrub · right-click reset · Save over original"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	clip_contents = true
	queue_redraw()


func set_frames(new_frames: Array, new_fps: float = 8.0, new_loop: bool = true, autoplay: bool = true, paths: Array = []) -> void:
	frames = []
	frame_paths = PackedStringArray()
	for f in new_frames:
		if f is Texture2D:
			frames.append(f)
	for i in frames.size():
		var p := ""
		if i < paths.size():
			p = str(paths[i])
		frame_paths.append(p)
	fps = new_fps
	loop_anim = new_loop
	frame_index = 0
	_t = 0.0
	playing = autoplay and frames.size() > 1
	if frames.is_empty():
		_texture = null
	else:
		_texture = frames[0]
	queue_redraw()
	frame_changed.emit(frame_index)


func set_pull_points(points: Array) -> void:
	pull_points = []
	for p in points:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		pull_points.append({
			"u": clampf(float(p.get("u", 0.5)), 0.0, 1.0),
			"v": clampf(float(p.get("v", 0.5)), 0.0, 1.0),
			"dx": clampf(float(p.get("dx", 0.0)), -MAX_PULL, MAX_PULL),
			"dy": clampf(float(p.get("dy", 0.0)), -MAX_PULL, MAX_PULL),
		})
	queue_redraw()


func get_pull_points() -> Array:
	return pull_points.duplicate(true)


func reset_pose() -> void:
	pull_points.clear()
	queue_redraw()
	pose_changed.emit(get_pull_points())


func set_playing(on: bool) -> void:
	playing = on and frames.size() > 1


## Bake the current pose warp into the original image file(s) on disk.
## all_frames=true writes every clip frame; false writes only the current pose.
func save_over_original(all_frames: bool = true) -> Dictionary:
	if frames.is_empty():
		return {"ok": false, "error": "No frames to save", "saved": PackedStringArray()}
	if pull_points.is_empty():
		return {"ok": false, "error": "Nothing to bake — pull the image first", "saved": PackedStringArray()}
	var rect: Rect2 = _image_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		# Fallback scale if control not laid out yet.
		rect = Rect2(Vector2.ZERO, Vector2(256, 256))
	var saved: PackedStringArray = PackedStringArray()
	var indices: Array = []
	if all_frames:
		for i in frames.size():
			indices.append(i)
	else:
		indices.append(frame_index)
	for i in indices:
		if i < 0 or i >= frames.size():
			continue
		var tex: Texture2D = frames[i]
		if tex == null:
			continue
		var abs_path: String = frame_paths[i] if i < frame_paths.size() else ""
		if abs_path.is_empty() or not FileAccess.file_exists(abs_path):
			continue
		var baked: Image = bake_warped_image(tex, rect.size)
		if baked == null:
			continue
		var err: Error = baked.save_png(abs_path)
		if err != OK:
			continue
		saved.append(abs_path)
		# Reload texture from the overwritten original.
		var reloaded := Image.new()
		if reloaded.load(abs_path) == OK:
			frames[i] = ImageTexture.create_from_image(reloaded)
	if saved.is_empty():
		return {"ok": false, "error": "No writable original paths (need project frame files)", "saved": saved}
	# Pulls are now baked into the originals — clear handles.
	pull_points.clear()
	if frame_index >= 0 and frame_index < frames.size():
		_texture = frames[frame_index]
	queue_redraw()
	pose_changed.emit(get_pull_points())
	return {"ok": true, "saved": saved, "count": saved.size()}


func bake_warped_image(tex: Texture2D, display_size: Vector2 = Vector2.ZERO) -> Image:
	if tex == null:
		return null
	var src: Image = tex.get_image()
	if src == null:
		return null
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var w: int = src.get_width()
	var h: int = src.get_height()
	if w <= 0 or h <= 0:
		return null
	var disp: Vector2 = display_size
	if disp.x <= 1.0 or disp.y <= 1.0:
		disp = Vector2(float(w), float(h))
	var sx: float = float(w) / disp.x
	var sy: float = float(h) / disp.y
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for i in STRIPS:
		var v_mid: float = (float(i) + 0.5) / float(STRIPS)
		var offset: Vector2 = _sample_pull(v_mid)
		var ox: int = int(round(offset.x * sx))
		var oy: int = int(round(offset.y * sy))
		var y0: int = int(float(i) * float(h) / float(STRIPS))
		var y1: int = int(float(i + 1) * float(h) / float(STRIPS))
		for y in range(y0, y1):
			var dy: int = y + oy
			if dy < 0 or dy >= h:
				continue
			for x in range(w):
				var dx: int = x + ox
				if dx < 0 or dx >= w:
					continue
				out.set_pixel(dx, dy, src.get_pixel(x, y))
	return out


func _process(delta: float) -> void:
	if _dragging or not playing or frames.size() <= 1:
		return
	_t += delta
	var dur: float = 1.0 / maxf(fps, 0.01)
	var advanced := false
	while _t >= dur:
		_t -= dur
		frame_index += 1
		if frame_index >= frames.size():
			if loop_anim:
				frame_index = 0
			else:
				frame_index = frames.size() - 1
				playing = false
				break
		advanced = true
	if advanced:
		_texture = frames[frame_index]
		queue_redraw()
		frame_changed.emit(frame_index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			reset_pose()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_drag(mb.position)
			else:
				_end_drag()
			accept_event()
			return
	elif event is InputEventMouseMotion and _dragging:
		_drag_to((event as InputEventMouseMotion).position)
		accept_event()


func _begin_drag(local_pos: Vector2) -> void:
	var rect: Rect2 = _image_rect()
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return
	if not rect.has_point(local_pos):
		# Still allow drag if click is inside control — map to nearest UV.
		pass
	_dragging = true
	_was_playing = playing
	playing = false
	_last_mouse = local_pos
	_scrub_accum = 0.0
	_grab_uv = Vector2(
		clampf((local_pos.x - rect.position.x) / maxf(rect.size.x, 1.0), 0.0, 1.0),
		clampf((local_pos.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)
	)
	_grab_point_idx = _find_or_create_point(_grab_uv)
	scrub_started.emit()
	queue_redraw()


func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	playing = _was_playing and frames.size() > 1
	pose_changed.emit(get_pull_points())
	scrub_ended.emit()
	queue_redraw()


func _drag_to(local_pos: Vector2) -> void:
	var delta: Vector2 = local_pos - _last_mouse
	_last_mouse = local_pos
	# Vertical pull manipulates the picture (pose warp) in real time.
	if _grab_point_idx >= 0 and _grab_point_idx < pull_points.size():
		var p: Dictionary = pull_points[_grab_point_idx]
		p["dx"] = clampf(float(p.get("dx", 0.0)) + delta.x * 0.35, -MAX_PULL, MAX_PULL)
		p["dy"] = clampf(float(p.get("dy", 0.0)) + delta.y, -MAX_PULL, MAX_PULL)
		pull_points[_grab_point_idx] = p
	# Horizontal drag scrubs animation poses / frames.
	_scrub_accum += delta.x
	while absf(_scrub_accum) >= SCRUB_PX and frames.size() > 1:
		var step: int = 1 if _scrub_accum > 0.0 else -1
		_scrub_accum -= float(step) * SCRUB_PX
		frame_index = posmod(frame_index + step, frames.size())
		_texture = frames[frame_index]
		frame_changed.emit(frame_index)
	queue_redraw()
	pose_changed.emit(get_pull_points())


func _find_or_create_point(uv: Vector2) -> int:
	var best: int = -1
	var best_d: float = 0.08
	for i in pull_points.size():
		var p: Dictionary = pull_points[i]
		var d: float = Vector2(float(p.get("u", 0.5)), float(p.get("v", 0.5))).distance_to(uv)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		return best
	pull_points.append({"u": uv.x, "v": uv.y, "dx": 0.0, "dy": 0.0})
	return pull_points.size() - 1


func _image_rect() -> Rect2:
	if _texture == null:
		return Rect2(Vector2.ZERO, size)
	var tex_size: Vector2 = Vector2(_texture.get_width(), _texture.get_height())
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var scale: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var drawn: Vector2 = tex_size * scale
	var origin: Vector2 = (size - drawn) * 0.5
	return Rect2(origin, drawn)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.12, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.24, 0.86, 0.59, 0.25), false, 1.0)
	if _texture == null:
		draw_string(ThemeDB.fallback_font, Vector2(10, 22), "No image — pick a clip / texture", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.68, 0.75))
		return
	var rect: Rect2 = _image_rect()
	var tex_w: float = float(_texture.get_width())
	var tex_h: float = float(_texture.get_height())
	var strip_h: float = tex_h / float(STRIPS)
	var dest_strip_h: float = rect.size.y / float(STRIPS)
	for i in STRIPS:
		var v0: float = float(i) / float(STRIPS)
		var v1: float = float(i + 1) / float(STRIPS)
		var v_mid: float = (v0 + v1) * 0.5
		var offset: Vector2 = _sample_pull(v_mid)
		var src := Rect2(0.0, strip_h * float(i), tex_w, strip_h)
		var dst := Rect2(
			rect.position.x + offset.x,
			rect.position.y + dest_strip_h * float(i) + offset.y,
			rect.size.x,
			dest_strip_h + 0.75
		)
		draw_texture_rect_region(_texture, dst, src)
	# Grab handles
	for p in pull_points:
		var uv := Vector2(float(p.get("u", 0.5)), float(p.get("v", 0.5)))
		var base: Vector2 = rect.position + Vector2(uv.x * rect.size.x, uv.y * rect.size.y)
		var tip: Vector2 = base + Vector2(float(p.get("dx", 0.0)), float(p.get("dy", 0.0)))
		draw_line(base, tip, Color(0.96, 0.64, 0.28, 0.9), 2.0)
		draw_circle(tip, 5.0, Color(0.24, 0.86, 0.59, 0.95))
		draw_circle(base, 3.0, Color(0.95, 0.95, 0.95, 0.7))
	var caption := _hint
	if frames.size() > 0:
		caption = "pose %d/%d  ·  %s" % [frame_index + 1, frames.size(), _hint]
	draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 8), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.9, 0.93, 0.9))


func _sample_pull(v: float) -> Vector2:
	var total := Vector2.ZERO
	var weight_sum: float = 0.0
	for p in pull_points:
		var pv: float = float(p.get("v", 0.5))
		var d: float = absf(v - pv)
		var w: float = exp(-(d * d) / maxf(FALLOFF * FALLOFF, 0.0001))
		total += Vector2(float(p.get("dx", 0.0)), float(p.get("dy", 0.0))) * w
		weight_sum += w
	if weight_sum <= 0.0001:
		return Vector2.ZERO
	return total / maxf(weight_sum, 1.0)
