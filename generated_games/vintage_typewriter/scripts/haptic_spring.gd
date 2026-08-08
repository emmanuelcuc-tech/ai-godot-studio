extends Node
## Spring haptic per key: hard trip → soft rebound (typewriter click feel).

@export var peak_ms: int = 8
@export var peak_amp: float = 1.0
@export var settle_ms: int = 22
@export var settle_amp: float = 0.16
@export var settle_delay_sec: float = 0.014
@export var intensity: float = 1.0

var _busy: bool = false


func spring_pulse() -> void:
	if not TwSettings.haptics_enabled:
		return
	# Letter trip: sharp peak then soft spring settle
	var p := peak_amp * intensity * (1.0 if TwSettings.surround_max else 0.75)
	_run_spring(peak_ms, p, settle_ms, settle_amp * intensity, settle_delay_sec)


func click_pulse() -> void:
	## Alias tuned for typed letters — same spring feel as a mechanical trip.
	spring_pulse()


func carriage_pulse() -> void:
	if not TwSettings.haptics_enabled:
		return
	_run_spring(14, 1.0 * intensity, 42, 0.24, 0.028)


func roller_pulse() -> void:
	if not TwSettings.haptics_enabled:
		return
	_vibrate(18, 0.5 * intensity)
	await get_tree().create_timer(0.04).timeout
	_vibrate(14, 0.22 * intensity)


func bell_pulse() -> void:
	if not TwSettings.haptics_enabled:
		return
	_vibrate(7, 0.85 * intensity)
	await get_tree().create_timer(0.045).timeout
	_vibrate(9, 0.5 * intensity)


func _run_spring(p_ms: int, p_amp: float, s_ms: int, s_amp: float, delay: float) -> void:
	if _busy:
		_vibrate(p_ms, p_amp)
		return
	_busy = true
	_vibrate(p_ms, p_amp)
	await get_tree().create_timer(delay).timeout
	_vibrate(s_ms, s_amp)
	# Tiny third tick — spring bounce-back
	await get_tree().create_timer(delay * 0.7).timeout
	_vibrate(maxi(4, int(s_ms * 0.35)), s_amp * 0.45)
	_busy = false


func _vibrate(ms: int, amp: float) -> void:
	var a := clampf(amp, 0.0, 1.0)
	Input.vibrate_handheld(ms, a)
	if OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux"):
		Input.start_joy_vibration(0, a, a * 0.45, ms / 1000.0)
