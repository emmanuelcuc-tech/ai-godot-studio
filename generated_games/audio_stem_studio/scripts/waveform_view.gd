extends Control
## Simple waveform preview from WAV path.

var _path: String = ""
var _peaks: PackedFloat32Array = PackedFloat32Array()

func set_path(path: String) -> void:
	_path = path
	_peaks = PackedFloat32Array()
	_load_peaks()
	queue_redraw()


func _load_peaks() -> void:
	if _path.is_empty() or not FileAccess.file_exists(_path):
		return
	var f := FileAccess.open(_path, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_buffer(mini(f.get_length(), 4_000_000))
	f.close()
	if raw.size() < 44:
		return
	var data_start := 44
	var i := 12
	while i + 8 < raw.size():
		var id := raw.slice(i, i + 4).get_string_from_ascii()
		var sz := raw.decode_u32(i + 4)
		if id == "data":
			data_start = i + 8
			break
		i += 8 + int(sz)
	var samples: Array[float] = []
	var pos := data_start
	while pos + 2 < raw.size() and samples.size() < 4000:
		var s := raw.decode_s16(pos) / 32768.0
		samples.append(absf(s))
		pos += 8 # skip ahead for overview
	_peaks = PackedFloat32Array(samples)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.08, 0.09, 0.12))
	if _peaks.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(8, size.y * 0.55), "waveform", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.55, 0.6))
		return
	var mid := size.y * 0.5
	var n := _peaks.size()
	for x in range(int(size.x)):
		var idx := int(float(x) / size.x * n)
		var amp: float = _peaks[clampi(idx, 0, n - 1)]
		var h := amp * mid
		draw_line(Vector2(x, mid - h), Vector2(x, mid + h), Color(0.45, 0.85, 1.0, 0.85))
