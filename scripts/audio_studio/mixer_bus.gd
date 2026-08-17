class_name MixerBus
extends RefCounted
## Fruity Loops–style volume bus for the desktop Audio Studio.

const UNITY := 0.8
const MAX := 1.25
const CHANNELS: PackedStringArray = ["input", "output", "fire", "hit", "glass"]
const STRIPS: PackedStringArray = ["input", "output", "fire", "hit", "glass", "master"]
const VERSION := "1.0.0"
const RELEASE := "final"
const DESCRIBE_PLACEHOLDER := "Describe to song or audio"
const KNOB_MIN := -2.356194490192345
const KNOB_MAX := 2.356194490192345


static func final_label() -> String:
	return "%s %s" % [VERSION, RELEASE]


static func defaults() -> Dictionary:
	var o := {}
	for k in STRIPS:
		o[k] = UNITY
	return o


static func clamp_vol(v: float) -> float:
	return clampf(v, 0.0, MAX)


static func copy_vols(vols: Dictionary) -> Dictionary:
	var o := defaults()
	for k in STRIPS:
		if vols.has(k):
			o[k] = clamp_vol(float(vols[k]))
	return o


static func effective(channel: String, vols: Dictionary) -> float:
	var master := clamp_vol(float(vols.get("master", UNITY)))
	if channel == "master":
		return master
	var ch := clamp_vol(float(vols.get(channel, UNITY)))
	return master * ch / UNITY


static func to_gain(channel: String, vols: Dictionary) -> float:
	return effective(channel, vols) / UNITY


static func from_gain(gain: float) -> float:
	return clamp_vol(gain * UNITY)


static func describe_to_song(prompt: String) -> String:
	return prompt.strip_edges()


static func set_all(vols: Dictionary, value: float) -> Dictionary:
	var v := clamp_vol(value)
	var o := copy_vols(vols)
	for k in STRIPS:
		o[k] = v
	return o


static func any_changed(prev: Dictionary, now: Dictionary, epsilon: float = 0.008) -> Array:
	for k in STRIPS:
		if absf(float(prev.get(k, 0.0)) - float(now.get(k, 0.0))) > epsilon:
			return [true, k]
	return [false, ""]


static func volume_from_fader_y(y: float, y0: float, y1: float) -> float:
	if is_equal_approx(y1, y0):
		return 0.0
	var t := clampf((y - y0) / (y1 - y0), 0.0, 1.0)
	return clamp_vol(t * MAX)


static func fader_y_from_volume(vol: float, y0: float, y1: float) -> float:
	var t := clamp_vol(vol) / MAX
	return y0 + t * (y1 - y0)


static func knob_angle_from_volume(vol: float) -> float:
	var t := clamp_vol(vol) / MAX
	return KNOB_MIN + t * (KNOB_MAX - KNOB_MIN)


static func volume_from_knob_angle(ang: float) -> float:
	var span := KNOB_MAX - KNOB_MIN
	var t := clampf((ang - KNOB_MIN) / span, 0.0, 1.0)
	return clamp_vol(t * MAX)


static func twist_volume(vol: float, prev_ang: float, new_ang: float) -> float:
	var d := new_ang - prev_ang
	while d > PI:
		d -= TAU
	while d < -PI:
		d += TAU
	var span := KNOB_MAX - KNOB_MIN
	return clamp_vol(vol + d / span * MAX)


static func hsv(h: float, s: float = 1.0, v: float = 1.0) -> Color:
	h = fposmod(h, 360.0)
	s = clampf(s, 0.0, 1.0)
	v = clampf(v, 0.0, 1.0)
	var c := v * s
	var hp := h / 60.0
	var x := c * (1.0 - absf(fmod(hp, 2.0) - 1.0))
	var m := v - c
	var r := 0.0
	var g := 0.0
	var b := 0.0
	if hp < 1.0:
		r = c
		g = x
	elif hp < 2.0:
		r = x
		g = c
	elif hp < 3.0:
		g = c
		b = x
	elif hp < 4.0:
		g = x
		b = c
	elif hp < 5.0:
		r = x
		b = c
	else:
		r = c
		b = x
	return Color(r + m, g + m, b + m, 1.0)


static func neon_hue(elapsed: float, speed: float = 0.2) -> float:
	var wave := 0.5 + 0.5 * sin(elapsed * speed)
	return 205.0 + 155.0 * wave


static func neon_rgb(elapsed: float, value: float = 1.0) -> Color:
	return hsv(neon_hue(elapsed), 1.0, value)


static func hz_to_midi(hz: float) -> float:
	if hz < 20.0:
		return -1.0
	return 69.0 + 12.0 * log(hz / 440.0) / log(2.0)


static func midi_to_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


static func sample_note(amp: float, freq: float, floor_amp: float = 0.03) -> int:
	var midi := hz_to_midi(freq)
	if midi < 0.0:
		if amp < floor_amp:
			return -1
		var t := clampf((amp - floor_amp) / maxf(0.001, 1.0 - floor_amp), 0.0, 1.0)
		midi = 48.0 + t * 36.0
	return clampi(int(round(midi)), 36, 96)


static func quantize_melody(samples: Array, min_dur: float = 0.08) -> Array:
	var notes: Array = []
	var cur := -1
	var start_t := 0.0
	var last_t := 0.0
	for s in samples:
		var t := float(s.get("t", 0.0))
		last_t = t
		var n := sample_note(float(s.get("amp", 0.0)), float(s.get("freq", 0.0)))
		if n != cur:
			if cur >= 0:
				var dur := t - start_t
				if dur >= min_dur:
					notes.append({"midi": cur, "t": start_t, "dur": dur})
			cur = n
			start_t = t
	if cur >= 0:
		notes.append({"midi": cur, "t": start_t, "dur": maxf(min_dur, last_t - start_t)})
	return notes


static func hum_instrument(samples: Array) -> Dictionary:
	var sum := 0.0
	var n := 0
	var peak := 0.0
	var midi_sum := 0.0
	var midi_n := 0
	for s in samples:
		var a := float(s.get("amp", 0.0))
		sum += a
		n += 1
		peak = maxf(peak, a)
		var m := sample_note(a, float(s.get("freq", 0.0)))
		if m >= 0:
			midi_sum += m
			midi_n += 1
	return {
		"avg": (sum / n) if n > 0 else 0.0,
		"peak": peak,
		"midi": int(round(midi_sum / midi_n)) if midi_n > 0 else 60,
		"samples": n,
	}


static func strip_label(id: String) -> String:
	var names := {
		"master": "MASTER",
		"input": "IN",
		"output": "OUT",
		"fire": "FIRE",
		"hit": "HIT",
		"glass": "GLASS",
	}
	return str(names.get(id, id.to_upper()))


static func volume_height(level: float, max_h: float) -> float:
	return clampf(level, 0.0, 1.0) * max_h
