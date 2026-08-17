extends RefCounted
## UV layouts for the three reference photos:
## - full_machine.png (zoom-out body)
## - keys_closeup.png (keyboard art + atlas crops)
## - striker.png (typebar / platen close-up)
## Normalized 0–1 within each image.


static func rows() -> Array:
	## Each entry:
	## [id, label, mx, my, mw, mh, circular, kx, ky, kw, kh]
	## m* = full_machine hotspot center/size; k* = keys_closeup atlas rect.
	var out: Array = []
	var r0 := ["2", "3", "4", "5", "6", "7", "8", "9", "0", "-"]
	var r1 := ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
	var r2 := ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";"]
	var r3 := ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
	# Machine keyboard band (lower half of full_machine)
	_add_row(out, r0, 0.560, 0.22, 0.68, 0.036, 0.20, 0.10, 0.80, 0.085)
	_add_row(out, r1, 0.615, 0.24, 0.64, 0.038, 0.36, 0.12, 0.76, 0.090)
	_add_row(out, r2, 0.670, 0.25, 0.62, 0.038, 0.52, 0.13, 0.74, 0.090)
	_add_row(out, r3, 0.725, 0.27, 0.58, 0.038, 0.68, 0.14, 0.72, 0.090)
	# Specials — machine UV + keys atlas
	out.append(["backspace", "BK", 0.155, 0.560, 0.085, 0.040, false, 0.08, 0.16, 0.10, 0.10])
	out.append(["1", "1", 0.205, 0.560, 0.034, 0.036, true, 0.16, 0.18, 0.065, 0.09])
	out.append(["=", "=", 0.845, 0.560, 0.034, 0.036, true, 0.86, 0.18, 0.065, 0.09])
	out.append(["tab", "TAB", 0.88, 0.615, 0.070, 0.038, false, 0.90, 0.34, 0.08, 0.10])
	out.append(["shift", "SH", 0.16, 0.725, 0.090, 0.042, false, 0.08, 0.66, 0.12, 0.10])
	out.append(["shift_r", "SH", 0.86, 0.725, 0.090, 0.042, false, 0.90, 0.66, 0.10, 0.10])
	out.append([" ", "SPC", 0.50, 0.810, 0.42, 0.042, false, 0.50, 0.88, 0.46, 0.09])
	out.append(["\n", "RET", 0.88, 0.780, 0.080, 0.048, false, 0.92, 0.80, 0.07, 0.12])
	return out


static func _add_row(
	out: Array,
	keys: Array,
	my: float,
	m_start: float,
	m_span: float,
	mh: float,
	ky: float,
	k_start: float,
	k_span: float,
	kh: float
) -> void:
	var n := keys.size()
	var m_step := m_span / float(maxi(1, n - 1))
	var k_step := k_span / float(maxi(1, n - 1))
	var mw := clampf(m_step * 0.78, 0.026, 0.042)
	var kw := clampf(k_step * 0.82, 0.045, 0.075)
	for i in n:
		var mx := m_start + m_step * float(i)
		var kx := k_start + k_step * float(i)
		out.append([str(keys[i]), str(keys[i]).to_upper(), mx, my, mw, mh, true, kx, ky, kw, kh])


static func paper_uv() -> Rect2:
	## Width matches Quiet De Luxe / platen top rail on full_machine (between knobs).
	## Height taller so paper can feed up past the carriage window.
	return Rect2(0.14, 0.02, 0.72, 0.34)


static func typebar_uv() -> Rect2:
	## Striker / typebasket window on full_machine.
	return Rect2(0.22, 0.34, 0.56, 0.16)


static func carriage_uv() -> Rect2:
	return Rect2(0.12, 0.02, 0.76, 0.36)


static func keyboard_uv() -> Rect2:
	## Lower keyboard deck on full_machine (Keys view zoom target).
	return Rect2(0.10, 0.48, 0.80, 0.48)
