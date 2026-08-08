extends Node
## Mechanical typewriter SFX — drop-in oggs under assets/audio/, silent when missing.

var enabled: bool = true
var use_asset_sounds: bool = true
var erase_enabled: bool = true
var surround_max: bool = false
var reverb_amount: float = 0.18
var click_volume_db: float = -6.0
## Ambient removed for fresh-start; kept as no-ops for settings compat.
var ambient_enabled: bool = false
var ambient_volume_db: float = -28.0
var mic_reverb_monitor: bool = false

const BUS_SFX := "TypeSFX"
const POOL := 6

## Conventional drop-in names (add files later — machine stays quiet until then).
const PATH_KEY := "res://assets/audio/key.ogg"
const PATH_ERASE := "res://assets/audio/erase.ogg"
const PATH_RETURN := "res://assets/audio/return.ogg"
const PATH_BELL := "res://assets/audio/bell.ogg"
const PATH_FEED := "res://assets/audio/feed.ogg"

var _keys: Array[AudioStreamPlayer] = []
var _key_i: int = 0
var _return: AudioStreamPlayer
var _platen: AudioStreamPlayer
var _bell: AudioStreamPlayer
var _erase: AudioStreamPlayer


func _ready() -> void:
	_setup_bus()
	for i in POOL:
		_keys.append(_make_player(null, click_volume_db))
	_return = _make_player(null, -5.0)
	_platen = _make_player(null, -10.0)
	_bell = _make_player(null, -4.0)
	_erase = _make_player(null, -5.5)
	reload_streams(use_asset_sounds)


func reload_streams(prefer_assets: bool = true) -> void:
	use_asset_sounds = prefer_assets
	## Missing assets → null stream (silent). Prefer canonical names; accept aliases.
	var click: AudioStream = _load_first([PATH_KEY, "res://assets/audio/key_strike.ogg"]) if prefer_assets else null
	var erase: AudioStream = _load_stream(PATH_ERASE) if prefer_assets else null
	var feed: AudioStream = _load_first([PATH_FEED, "res://assets/audio/page_feed.ogg"]) if prefer_assets else null
	var ret: AudioStream = _load_first([PATH_RETURN, "res://assets/audio/enter_bell.ogg"]) if prefer_assets else null
	if ret == null:
		ret = feed
	var bell: AudioStream = _load_first([PATH_BELL, "res://assets/audio/enter_bell.ogg"]) if prefer_assets else null
	for p in _keys:
		if p:
			p.stream = click
	if _return:
		_return.stream = ret
	if _platen:
		_platen.stream = feed
	if _bell:
		_bell.stream = bell
	if _erase:
		_erase.stream = erase


func _load_first(paths: Array) -> AudioStream:
	for p in paths:
		var s := _load_stream(str(p))
		if s:
			return s
	return null


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		for p in _keys:
			if p and p.playing:
				p.stop()
		for p in [_return, _platen, _bell, _erase]:
			if p and p.playing:
				p.stop()
	apply_ambient()


func apply_ambient() -> void:
	## No ambient room bed in this build.
	pass


func apply_mix() -> void:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx == -1:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		var e := AudioServer.get_bus_effect(idx, i)
		if e is AudioEffectReverb:
			var r := e as AudioEffectReverb
			r.room_size = 0.25
			r.damping = 0.7
			r.spread = 0.4
			r.dry = 0.92
			r.wet = clampf(reverb_amount, 0.0, 0.35) if surround_max or reverb_amount > 0.01 else 0.0
	for p in _keys:
		if p:
			p.volume_db = click_volume_db
	apply_ambient()


func play_key(letter_bias: float = 0.0) -> void:
	if not enabled or _keys.is_empty():
		return
	var p: AudioStreamPlayer = _keys[_key_i]
	_key_i = (_key_i + 1) % _keys.size()
	if p.stream == null:
		return
	p.pitch_scale = clampf(0.96 + letter_bias * 0.04 + randf_range(-0.02, 0.03), 0.9, 1.1)
	p.volume_db = click_volume_db + randf_range(-0.4, 0.4)
	p.play()


func play_erase() -> void:
	if not enabled or not erase_enabled or _erase == null or _erase.stream == null:
		return
	_erase.pitch_scale = randf_range(0.94, 1.06)
	_erase.volume_db = click_volume_db + 0.5 + randf_range(-0.3, 0.3)
	_erase.play()


func play_return() -> void:
	if not enabled:
		return
	if _return and _return.stream:
		_return.pitch_scale = randf_range(0.97, 1.03)
		_return.play()
	if _bell and _bell.stream and randf() > 0.35:
		_bell.pitch_scale = randf_range(0.98, 1.04)
		_bell.play()


func play_platen() -> void:
	if not enabled or _platen == null or _platen.stream == null:
		return
	_platen.pitch_scale = randf_range(0.92, 1.08)
	_platen.play()


func play_bell() -> void:
	if not enabled or _bell == null or _bell.stream == null:
		return
	_bell.play()


func set_flutter(_amount: float) -> void:
	pass


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStream:
			return stream as AudioStream
	return null


func _setup_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS_SFX)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
	AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_mute(idx, false)
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
