extends Node
class_name TypewriterSfx
## Default: sliced Freesound typewriter clicks (one shot per keystroke).
## Optional: TypingSimulator packs under assets/audio/<pack>/press|release/.
## Mechanical extras (bell / return / erase) load from assets/audio/*.ogg when present.

const AUDIO_ROOT := "res://assets/audio/"
const FREESOUND_PACK := "freesound_typewriter"
const FREESOUND_CLICKS := "res://assets/audio/freesound_typewriter/clicks/"
const FREESOUND_FULL := "res://assets/audio/freesound_typewriter/type-writing-6834.mp3"
const PATH_BELL := "res://assets/audio/bell.ogg"
const PATH_RETURN := "res://assets/audio/return.ogg"
const PATH_ERASE := "res://assets/audio/erase.ogg"

var pack_name: String = FREESOUND_PACK
var _press: Dictionary = {}
var _release: Dictionary = {}
var _freesound_clicks: Array = [] ## Array[AudioStream]
var _use_freesound := true
var _player_press: AudioStreamPlayer
var _player_release: AudioStreamPlayer
var _player_mech: AudioStreamPlayer
var _bell: AudioStream
var _return_stream: AudioStream
var _erase_stream: AudioStream
var _rng := RandomNumberGenerator.new()
var _fallback_windows: Array = [] ## start_sec for full-mp3 one-shots
var _full_mp3: AudioStreamMP3


func _ready() -> void:
	_player_press = AudioStreamPlayer.new()
	_player_release = AudioStreamPlayer.new()
	_player_mech = AudioStreamPlayer.new()
	_player_press.volume_db = -4.0
	_player_release.volume_db = -6.0
	_player_mech.volume_db = -2.0
	add_child(_player_press)
	add_child(_player_release)
	add_child(_player_mech)
	_rng.randomize()
	_load_mechanical()
	load_pack(pack_name)


func load_pack(name: String) -> bool:
	pack_name = name
	_press.clear()
	_release.clear()
	_freesound_clicks.clear()
	_use_freesound = (name == FREESOUND_PACK) or name.begins_with("freesound")
	if _use_freesound:
		_load_freesound_clicks()
		return has_audio()
	var base := AUDIO_ROOT + pack_name + "/"
	_load_action(_press, base + "press/", "GENERIC", true)
	_load_action(_press, base + "press/", "SPACE", false)
	_load_action(_press, base + "press/", "ENTER", false)
	_load_action(_press, base + "press/", "BACKSPACE", false)
	_load_action(_release, base + "release/", "GENERIC", false)
	_load_action(_release, base + "release/", "SPACE", false)
	_load_action(_release, base + "release/", "ENTER", false)
	_load_action(_release, base + "release/", "BACKSPACE", false)
	return has_audio()


func has_audio() -> bool:
	if _use_freesound:
		return _freesound_clicks.size() > 0 or _full_mp3 != null
	return _press.has("GENERIC") and (_press["GENERIC"] as Array).size() > 0


func list_packs() -> PackedStringArray:
	var out: PackedStringArray = [FREESOUND_PACK]
	var dir := DirAccess.open(AUDIO_ROOT)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if dir.current_is_dir() and not n.begins_with(".") and n != FREESOUND_PACK:
			var press := AUDIO_ROOT + n + "/press"
			if DirAccess.open(press) != null:
				out.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	return out


func play_key(press: bool = true) -> void:
	if _use_freesound:
		if press:
			_play_freesound_click()
		return
	_play("GENERIC", press)


func play_space(press: bool = true) -> void:
	if _use_freesound:
		if press:
			_play_freesound_click()
		return
	_play("SPACE", press)


func play_return(press: bool = true) -> void:
	if press and _return_stream:
		_play_mech(_return_stream, randf_range(0.96, 1.04))
		return
	if _use_freesound:
		if press:
			_play_freesound_click()
		return
	_play("ENTER", press)


func play_backspace(press: bool = true) -> void:
	if press and _erase_stream:
		_play_mech(_erase_stream, randf_range(0.97, 1.03))
		if _use_freesound:
			# Soft click under the erase scrape
			_play_freesound_click()
		return
	if _use_freesound:
		if press:
			_play_freesound_click()
		return
	_play("BACKSPACE", press)


func play_bell() -> void:
	if _bell:
		_play_mech(_bell, randf_range(0.98, 1.03))
		return
	# Procedural margin bell fallback
	_play_mech(_make_bell_stream(), 1.0)


func _play_mech(stream: AudioStream, pitch: float) -> void:
	if stream == null:
		return
	_player_mech.stream = stream
	_player_mech.pitch_scale = pitch
	_player_mech.play()


func _load_mechanical() -> void:
	_bell = _try_ogg(PATH_BELL)
	if _bell == null:
		_bell = _try_ogg("res://assets/audio/enter_bell.ogg")
	_return_stream = _try_ogg(PATH_RETURN)
	_erase_stream = _try_ogg(PATH_ERASE)
	if _bell == null:
		_bell = _make_bell_stream()


func _play_freesound_click() -> void:
	if _freesound_clicks.size() > 0:
		_player_press.stream = _freesound_clicks[_rng.randi_range(0, _freesound_clicks.size() - 1)]
		_player_press.pitch_scale = randf_range(0.97, 1.04)
		_player_press.play()
		return
	if _full_mp3 == null:
		return
	_player_press.stream = _full_mp3
	_player_press.pitch_scale = 1.0
	_player_press.play()
	var start := 0.0
	if _fallback_windows.size() > 0:
		start = float(_fallback_windows[_rng.randi_range(0, _fallback_windows.size() - 1)])
	_player_press.seek(start)
	get_tree().create_timer(0.09).timeout.connect(func() -> void:
		if _player_press.playing and _player_press.stream == _full_mp3:
			_player_press.stop()
	, CONNECT_ONE_SHOT)


func _load_freesound_clicks() -> void:
	_freesound_clicks.clear()
	var abs_dir := ProjectSettings.globalize_path(FREESOUND_CLICKS)
	if DirAccess.dir_exists_absolute(abs_dir):
		var d := DirAccess.open(FREESOUND_CLICKS)
		if d:
			var names: PackedStringArray = []
			d.list_dir_begin()
			var fn := d.get_next()
			while fn != "":
				if not d.current_is_dir() and (fn.ends_with(".wav") or fn.ends_with(".mp3")):
					names.append(fn)
				fn = d.get_next()
			d.list_dir_end()
			names.sort()
			for fn2 in names:
				var s := _try_stream_any(FREESOUND_CLICKS + fn2)
				if s:
					_freesound_clicks.append(s)
	_full_mp3 = _try_mp3(FREESOUND_FULL) as AudioStreamMP3
	_fallback_windows = [
		0.05, 0.18, 0.32, 0.45, 0.58, 0.72, 0.88, 1.05, 1.22, 1.40,
		1.58, 1.75, 1.95, 2.15, 2.35, 2.55, 2.78, 3.00, 3.25, 3.50,
		3.75, 4.00, 4.28, 4.55, 4.85, 5.15, 5.45, 5.80, 6.15, 6.50
	]


func _play(action: String, press: bool) -> void:
	var table: Dictionary = _press if press else _release
	if not table.has(action):
		action = "GENERIC"
	if not table.has(action):
		return
	var arr: Array = table[action]
	if arr.is_empty():
		return
	var stream: AudioStream = arr[_rng.randi_range(0, arr.size() - 1)]
	var p := _player_press if press else _player_release
	p.stream = stream
	p.pitch_scale = randf_range(0.98, 1.03)
	p.play()


func _load_action(into: Dictionary, folder: String, action: String, variants: bool) -> void:
	var streams: Array = []
	if variants:
		for i in range(5):
			var s := _try_mp3(folder + "GENERIC_R%d.mp3" % i)
			if s:
				streams.append(s)
	var s2 := _try_mp3(folder + action + ".mp3")
	if s2:
		streams.append(s2)
	if streams.size() > 0:
		into[action] = streams


func _try_stream_any(path: String) -> AudioStream:
	if path.ends_with(".wav"):
		return _try_wav(path)
	if path.ends_with(".ogg"):
		return _try_ogg(path)
	return _try_mp3(path)


func _try_ogg(path: String) -> AudioStream:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	# Prefer raw decode — .import sidecars can be stale after checkout
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f:
		var data := f.get_buffer(f.get_length())
		if not data.is_empty():
			var stream: AudioStream = AudioStreamOggVorbis.load_from_buffer(data)
			if stream:
				return stream
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is AudioStream:
			return res
	return null


func _try_mp3(path: String) -> AudioStream:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	if data.is_empty():
		return null
	var stream := AudioStreamMP3.new()
	stream.data = data
	return stream


func _try_wav(path: String) -> AudioStream:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is AudioStream:
			return res
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	if data.size() < 44:
		return null
	if data[0] != 82 or data[1] != 73: # RIFF
		return null
	var channels := data[22] + data[23] * 256
	var rate := data[24] + data[25] * 256 + data[26] * 65536 + data[27] * 16777216
	var bits := data[34] + data[35] * 256
	var data_ofs := 44
	var i := 12
	while i + 8 < data.size():
		var id := char(data[i]) + char(data[i + 1]) + char(data[i + 2]) + char(data[i + 3])
		var sz := data[i + 4] + data[i + 5] * 256 + data[i + 6] * 65536 + data[i + 7] * 16777216
		if id == "data":
			data_ofs = i + 8
			break
		i += 8 + sz
	var stream := AudioStreamWAV.new()
	stream.data = data.slice(data_ofs)
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.stereo = channels > 1
	return stream


func _make_bell_stream() -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(sample_rate * 0.45)
	var pcm := PackedByteArray()
	pcm.resize(n * 2)
	for i in n:
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 4.5)
		var tone := sin(t * TAU * 1240.0) * 0.45 + sin(t * TAU * 1860.0) * 0.22 + sin(t * TAU * 2480.0) * 0.08
		var s := clampf(tone * env, -1.0, 1.0)
		var v := int(s * 32767.0)
		pcm[i * 2] = v & 0xFF
		pcm[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = pcm
	return wav
