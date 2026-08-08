extends RefCounted
## Normalized (0–1) key centers on royal_machine.png (1024² top-down Royal QD).
## Calibrated to photo: wall/desk around machine; keyboard in lower body.

static func rows() -> Array:
	var out: Array = []
	# Number / symbol row (MAR REL left, BACK SPACE right on real machine)
	var r0 := ["1","2","3","4","5","6","7","8","9","0","-","="]
	var r1 := ["q","w","e","r","t","y","u","i","o","p"]
	var r2 := ["a","s","d","f","g","h","j","k","l",";","'"]
	var r3 := ["z","x","c","v","b","n","m",",",".","/"]
	_add_row(out, r0, 0.548, 0.255, 0.70, 0.034)
	_add_row(out, r1, 0.598, 0.270, 0.66, 0.036)
	_add_row(out, r2, 0.648, 0.280, 0.64, 0.036)
	_add_row(out, r3, 0.698, 0.295, 0.60, 0.036)
	out.append(["backspace", "BK", 0.855, 0.548, 0.075, 0.038, false])
	out.append(["tab", "TAB", 0.855, 0.598, 0.070, 0.036, false])
	out.append([" ", "SPC", 0.50, 0.785, 0.38, 0.040, false])
	out.append(["\n", "RET", 0.82, 0.755, 0.090, 0.048, false])
	out.append(["shift", "SH", 0.195, 0.755, 0.080, 0.044, false])
	return out


static func _add_row(out: Array, keys: Array, ny: float, start_x: float, span: float, nh: float) -> void:
	var n := keys.size()
	var step := span / float(maxi(1, n - 1))
	var nw := clampf(step * 0.78, 0.026, 0.040)
	for i in n:
		var nx := start_x + step * float(i)
		out.append([str(keys[i]), str(keys[i]).to_upper(), nx, ny, nw, nh, true])


static func paper_uv() -> Rect2:
	## Carriage paper window over the photo sheet
	return Rect2(0.28, 0.05, 0.44, 0.28)


static func typebar_uv() -> Rect2:
	return Rect2(0.30, 0.38, 0.40, 0.14)


static func carriage_uv() -> Rect2:
	## Full carriage band (for horizontal slide feel)
	return Rect2(0.18, 0.02, 0.64, 0.34)
