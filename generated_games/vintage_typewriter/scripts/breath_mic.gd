extends Node
## Microphone → breath flow rate Q and air speed v0 / vp.

signal breath_updated(level: float, q: float, v0: float, vp: float)

const RHO_AIR := 1.225
const MOUTH_AREA := 0.0001 ## m²
const Q_MAX := 0.0010 ## m³/s strong blow → v0≈10 m/s
const SPREAD_KS := 0.7 ## at paper ~20 cm → vp ≈ 5–8 m/s when exhaling hard

var enabled: bool = true
var sensitivity: float = 2.8
var noise_gate: float = 0.02
var level: float = 0.0 ## smoothed 0..1
var q: float = 0.0
var v0: float = 0.0
var vp: float = 0.0
var mic_ok: bool = false

var _player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _bus_name := "BreathMic"
var _smooth: float = 0.0
var _manual_blow: float = 0.0


func _ready() -> void:
	_ensure_bus()
	_start_mic()


func _process(delta: float) -> void:
	if not enabled:
		level = move_toward(level, _manual_blow, delta * 4.0)
		_recompute()
		breath_updated.emit(level, q, v0, vp)
		return
	var rms := _read_rms()
	if _manual_blow > rms:
		rms = _manual_blow
	_smooth = lerpf(_smooth, rms, clampf(delta * 14.0, 0.0, 1.0))
	level = clampf((_smooth - noise_gate) * sensitivity, 0.0, 1.0)
	_recompute()
	breath_updated.emit(level, q, v0, vp)
	_manual_blow = move_toward(_manual_blow, 0.0, delta * 1.6)


func blow_impulse(amount: float = 0.85) -> void:
	_manual_blow = clampf(maxi(_manual_blow, amount), 0.0, 1.0)


func _recompute() -> void:
	q = Q_MAX * level * level ## quadratic: soft breath barely moves paper
	v0 = 0.0 if MOUTH_AREA <= 0.0 else q / MOUTH_AREA
	vp = SPREAD_KS * v0


func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(_bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, _bus_name)
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.set_bus_mute(idx, true) ## don't hear raw mic
	# Ensure capture effect
	var has_cap := false
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectCapture:
			_capture = AudioServer.get_bus_effect(idx, i)
			has_cap = true
			break
	if not has_cap:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = 0.1
		AudioServer.add_bus_effect(idx, _capture)


func _start_mic() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = _bus_name
	add_child(_player)
	var err := OK
	_player.play()
	mic_ok = true
	# Give AudioServer a frame
	await get_tree().process_frame
	if _player.playing:
		mic_ok = true
	else:
		mic_ok = false
		_player.play()
	if err != OK:
		pass


func _read_rms() -> float:
	if _capture == null:
		return 0.0
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return _smooth * 0.9
	var buf := _capture.get_buffer(frames)
	if buf.is_empty():
		return 0.0
	var acc := 0.0
	var n := mini(buf.size(), 2048)
	for i in n:
		var s: Vector2 = buf[i]
		var m := (s.x + s.y) * 0.5
		acc += m * m
	return sqrt(acc / float(n))
