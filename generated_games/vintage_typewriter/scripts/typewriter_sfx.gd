extends Node
## Mechanical typewriter SFX — prefer assets/audio/*.ogg, synthetic fallback.

var enabled: bool = true
var surround_max: bool = false
var reverb_amount: float = 0.18
var click_volume_db: float = -6.0
var mic_reverb_monitor: bool = false

const BUS_SFX := "TypeSFX"
const POOL := 6

const PATH_KEY := "res://assets/audio/key_strike.ogg"
const PATH_ERASE := "res://assets/audio/erase.ogg"
const PATH_BELL := "res://assets/audio/enter_bell.ogg"
const PATH_FEED := "res://assets/audio/page_feed.ogg"

var _keys: Array[AudioStreamPlayer] = []
var _key_i: int = 0
var _return: AudioStreamPlayer
var _platen: AudioStreamPlayer
var _bell: AudioStreamPlayer
var _erase: AudioStreamPlayer


func _ready() -> void:
	_setup_bus()
	var click := _load_or(_click_wav(980.0, 0.028), PATH_KEY)
	for i in POOL:
		_keys.append(_make_player(click, click_volume_db))
	_return = _make_player(_load_or(_clunk_wav(), PATH_FEED), -5.0)
	_platen = _make_player(_load_or(_click_wav(220.0, 0.04), PATH_FEED), -10.0)
	_bell = _make_player(_load_or(_bell_wav(), PATH_BELL), -4.0)
	_erase = _make_player(_load_or(_erase_wav(), PATH_ERASE), -5.5)


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		for p in _keys:
			if p and p.playing:
				p.stop()
		for p in [_return, _platen, _bell, _erase]:
			if p and p.playing:
				p.stop()


func apply_mix() -> void:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx == -1:
		return
	## Soft room only — no stereo widen / amplify noise
	for i in AudioServer.get_bus_effect_count(idx):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectReverb:
			var r := e as AudioEffectReverb
			r.room_size = 0.25
			r.damping = 0.7
			r.spread = 0.4
			r.dry = 0.92
			r.wet = clampf(reverb_amount, 0.0, 0.35)
	for p in _keys:
		if p:
			p.volume_db = click_volume_db


func play_key(letter_bias: float = 0.0) -> void:
	if not enabled or _keys.is_empty():
		return
	var p: AudioStreamPlayer = _keys[_key_i]
	_key_i = (_key_i + 1) % _keys.size()
	p.pitch_scale = clampf(0.96 + letter_bias * 0.04 + randf_range(-0.02, 0.03), 0.9, 1.1)
	p.volume_db = click_volume_db + randf_range(-0.4, 0.4)
	p.play()


func play_erase() -> void:
	if not enabled or _erase == null:
		return
	_erase.pitch_scale = randf_range(0.94, 1.06)
	_erase.volume_db = click_volume_db + 0.5 + randf_range(-0.3, 0.3)
	_erase.play()


func play_return() -> void:
	if not enabled:
		return
	_return.pitch_scale = randf_range(0.97, 1.03)
	_return.play()
	## Carriage return often rings the bell on mechanical machines
	if _bell and randf() > 0.35:
		_bell.pitch_scale = randf_range(0.98, 1.04)
		_bell.play()


func play_platen() -> void:
	if not enabled:
		return
	_platen.pitch_scale = randf_range(0.92, 1.08)
	_platen.play()


func play_bell() -> void:
	if not enabled:
		return
	_bell.play()


func set_flutter(_amount: float) -> void:
	## No continuous flutter bed — kept as no-op for callers.
	pass


func _load_or(fallback: AudioStream, path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStream:
			return stream as AudioStream
	return fallback


func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_mute(idx, false)
	## Strip old heavy FX from prior builds
	while AudioServer.get_bus_effect_count(idx) > 0:
		AudioServer.remove_bus_effect(idx, 0)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.25
	rev.damping = 0.7
	rev.wet = 0.15
	rev.dry = 0.92
	AudioServer.add_bus_effect(idx, rev)


func _make_player(stream: AudioStream, vol: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = vol
	p.bus = BUS_SFX
	p.max_polyphony = 1
	add_child(p)
	return p


func _click_wav(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 140.0)
		var s := sin(t * TAU * freq) * 0.55 * env
		s += (randf() * 2.0 - 1.0) * 0.12 * exp(-t * 280.0)
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _erase_wav() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.09)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 48.0)
		var s := (sin(t * TAU * 160.0) * 0.35 + (randf() * 2.0 - 1.0) * 0.28) * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _clunk_wav() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 22.0)
		var s := (sin(t * TAU * 110.0) * 0.5 + sin(t * TAU * 70.0) * 0.3) * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _bell_wav() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.22)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 8.0)
		var s := (sin(t * TAU * 1760.0) * 0.5 + sin(t * TAU * 2640.0) * 0.18) * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
