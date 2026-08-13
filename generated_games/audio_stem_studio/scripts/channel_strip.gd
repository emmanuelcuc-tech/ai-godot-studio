extends PanelContainer
class_name ChannelStrip
## Stem channel strip with spectrum, play, format, Level/Gain/Volume/Pan/Amount/Reverb.

signal play_pressed(index: int)
signal save_pressed(index: int)
signal mix_changed(index: int)

var channel_index: int = 0
var enabled: bool = false
var stem_path: String = ""
var label_text: String = "Channel"

var level_db: float = 0.0
var gain_db: float = 0.0
var volume: float = 100.0
var pan: float = 0.0
var amount: float = 100.0
var reverb: float = 0.0

var _player: AudioStreamPlayer
var _bus_name: String = ""
var title_label: Label
var status_label: Label
var media_info_label: Label
var play_btn: Button
var save_btn: Button
var format_option: OptionButton
var bitrate_option: OptionButton
var waveform: Control
var spectrum: Control
## Stem file meta shown under the title (codec / bits / bitrate / type).
var stem_codec: String = ""
var stem_bit_depth: int = 0
var stem_bitrate_kbps: int = 0
var stem_file_type: String = ""
var stem_sample_rate: int = 0
var level_spin: SpinBox
var gain_spin: SpinBox
var volume_slider: HSlider
var volume_label: Label
var pan_slider: HSlider
var pan_label: Label
var amount_slider: HSlider
var amount_label: Label
var reverb_slider: HSlider
var reverb_label: Label


func setup(index: int) -> void:
	channel_index = index
	_bus_name = "Stem%d" % channel_index
	_build_ui()
	_ensure_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = _bus_name
	add_child(_player)
	_refresh_enabled()


func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 228)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	title_label = Label.new()
	title_label.text = "%d · Channel" % (channel_index + 1)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	status_label = Label.new()
	status_label.text = "Empty"
	head.add_child(status_label)

	media_info_label = Label.new()
	media_info_label.text = "Codec: — | Bits: — | Bitrate: — | Type: —"
	media_info_label.add_theme_font_size_override("font_size", 12)
	media_info_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	root.add_child(media_info_label)

	var viz := HBoxContainer.new()
	viz.custom_minimum_size.y = 56
	root.add_child(viz)
	waveform = Control.new()
	waveform.set_script(load("res://scripts/waveform_view.gd"))
	waveform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	waveform.custom_minimum_size = Vector2(120, 56)
	viz.add_child(waveform)
	spectrum = Control.new()
	spectrum.set_script(load("res://scripts/spectrum_view.gd"))
	spectrum.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spectrum.custom_minimum_size = Vector2(120, 56)
	viz.add_child(spectrum)

	var mix := GridContainer.new()
	mix.columns = 6
	root.add_child(mix)

	level_spin = _make_spin(-60, 12, 0)
	gain_spin = _make_spin(-60, 12, 0)
	_add_pair(mix, "Level (dB)", level_spin)
	_add_pair(mix, "Gain (dB)", gain_spin)

	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 200
	volume_slider.value = 100
	volume_slider.custom_minimum_size.x = 90
	volume_label = Label.new()
	volume_label.text = "Volume 100%"
	_add_pair(mix, "Volume", volume_slider)
	mix.add_child(volume_label)
	mix.add_child(Control.new())

	pan_slider = HSlider.new()
	pan_slider.min_value = -1
	pan_slider.max_value = 1
	pan_slider.step = 0.01
	pan_slider.value = 0
	pan_label = Label.new()
	pan_label.text = "Pan 0.00"
	_add_pair(mix, "Pan", pan_slider)

	amount_slider = HSlider.new()
	amount_slider.min_value = 0
	amount_slider.max_value = 200
	amount_slider.value = 100
	amount_label = Label.new()
	amount_label.text = "Amount 100%"
	_add_pair(mix, "Amount", amount_slider)

	reverb_slider = HSlider.new()
	reverb_slider.min_value = 0
	reverb_slider.max_value = 100
	reverb_slider.value = 0
	reverb_label = Label.new()
	reverb_label.text = "Reverb 0%"
	_add_pair(mix, "Reverb", reverb_slider)
	mix.add_child(reverb_label)
	mix.add_child(Control.new())

	var row := HBoxContainer.new()
	root.add_child(row)
	play_btn = Button.new()
	play_btn.text = "Play"
	row.add_child(play_btn)
	format_option = OptionButton.new()
	for f in ["WAV", "MP3", "MPEG", "M4A", "FLAC", "OGG", "AC3"]:
		format_option.add_item(f)
	row.add_child(format_option)
	bitrate_option = OptionButton.new()
	for b in ["128 kbps", "256 kbps", "512 kbps"]:
		bitrate_option.add_item(b)
	bitrate_option.select(1)
	row.add_child(bitrate_option)
	save_btn = Button.new()
	save_btn.text = "Save"
	row.add_child(save_btn)

	level_spin.value_changed.connect(func(v):
		level_db = v
		_apply_live_mix()
		mix_changed.emit(channel_index)
	)
	gain_spin.value_changed.connect(func(v):
		gain_db = v
		_apply_live_mix()
		mix_changed.emit(channel_index)
	)
	volume_slider.value_changed.connect(func(v):
		volume = v
		volume_label.text = "Volume %d%%" % int(v)
		_apply_live_mix()
		mix_changed.emit(channel_index)
	)
	pan_slider.value_changed.connect(func(v):
		pan = v
		pan_label.text = "Pan %.2f" % v
		mix_changed.emit(channel_index)
	)
	amount_slider.value_changed.connect(func(v):
		amount = v
		amount_label.text = "Amount %d%%" % int(v)
		_apply_live_mix()
		mix_changed.emit(channel_index)
	)
	reverb_slider.value_changed.connect(func(v):
		reverb = v
		reverb_label.text = "Reverb %d%%" % int(v)
		_apply_live_mix()
		mix_changed.emit(channel_index)
	)
	play_btn.pressed.connect(func(): play_pressed.emit(channel_index))
	save_btn.pressed.connect(func(): save_pressed.emit(channel_index))


func _make_spin(mn: float, mx: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.1
	s.value = val
	s.suffix = " dB"
	return s


func _add_pair(grid: GridContainer, title: String, control: Control) -> void:
	var l := Label.new()
	l.text = title
	grid.add_child(l)
	grid.add_child(control)


func _ensure_bus() -> void:
	var idx := AudioServer.get_bus_index(_bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, _bus_name)
		AudioServer.set_bus_send(idx, "Master")
	var has_spec := false
	var has_rev := false
	for i in AudioServer.get_bus_effect_count(idx):
		var fx = AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectSpectrumAnalyzer:
			has_spec = true
		if fx is AudioEffectReverb:
			has_rev = true
	if not has_spec:
		AudioServer.add_bus_effect(idx, AudioEffectSpectrumAnalyzer.new())
	if not has_rev:
		var rev := AudioEffectReverb.new()
		rev.wet = 0.0
		AudioServer.add_bus_effect(idx, rev)


func configure(data: Dictionary) -> void:
	stem_path = str(data.get("path", ""))
	label_text = str(data.get("label", "Channel %d" % (channel_index + 1)))
	enabled = bool(data.get("enabled", stem_path != ""))
	level_db = float(data.get("level_db", 0.0))
	gain_db = float(data.get("gain_db", 0.0))
	volume = float(data.get("volume", 100.0))
	pan = float(data.get("pan", 0.0))
	amount = float(data.get("amount", 100.0))
	reverb = float(data.get("reverb", 0.0))
	title_label.text = "%d · %s" % [channel_index + 1, label_text]
	level_spin.value = level_db
	gain_spin.value = gain_db
	volume_slider.value = volume
	pan_slider.value = pan
	amount_slider.value = amount
	reverb_slider.value = reverb
	_refresh_enabled()
	_apply_live_mix()
	if enabled and stem_path != "" and FileAccess.file_exists(stem_path):
		_load_stream()
		if waveform and waveform.has_method("set_path"):
			waveform.call("set_path", stem_path)
		_detect_stem_media_info(data)
	else:
		stem_codec = ""
		stem_bit_depth = 0
		stem_bitrate_kbps = 0
		stem_file_type = ""
		stem_sample_rate = 0
		_refresh_media_info_label()


func set_media_info(info: Dictionary) -> void:
	stem_codec = str(info.get("codec", stem_codec))
	stem_bit_depth = int(info.get("bit_depth", stem_bit_depth))
	stem_bitrate_kbps = int(info.get("bitrate_kbps", stem_bitrate_kbps))
	stem_file_type = str(info.get("file_type", stem_file_type))
	stem_sample_rate = int(info.get("sample_rate", stem_sample_rate))
	_refresh_media_info_label()


func _detect_stem_media_info(data: Dictionary = {}) -> void:
	var ext := stem_path.get_extension().to_lower()
	stem_file_type = str(data.get("file_type", ext if ext != "" else "wav"))
	stem_codec = str(data.get("codec", ""))
	stem_bit_depth = int(data.get("bit_depth", 0))
	stem_bitrate_kbps = int(data.get("bitrate_kbps", 0))
	stem_sample_rate = int(data.get("sample_rate", 0))
	if stem_codec == "" or stem_bit_depth <= 0:
		match ext:
			"wav", "aiff", "aif":
				var wav_meta := _read_wav_meta(stem_path)
				if stem_codec == "":
					stem_codec = str(wav_meta.get("codec", "pcm"))
				if stem_bit_depth <= 0:
					stem_bit_depth = int(wav_meta.get("bit_depth", 16))
				if stem_sample_rate <= 0:
					stem_sample_rate = int(wav_meta.get("sample_rate", 44100))
				if stem_bitrate_kbps <= 0:
					stem_bitrate_kbps = int(wav_meta.get("bitrate_kbps", 0))
			"mp3":
				if stem_codec == "":
					stem_codec = "mp3"
			"flac":
				if stem_codec == "":
					stem_codec = "flac"
			"ogg", "opus":
				if stem_codec == "":
					stem_codec = "vorbis" if ext == "ogg" else "opus"
			"m4a", "aac":
				if stem_codec == "":
					stem_codec = "aac"
			_:
				if stem_codec == "":
					stem_codec = ext if ext != "" else "pcm"
	if stem_bitrate_kbps <= 0 and stem_bit_depth > 0 and stem_sample_rate > 0:
		# Stereo PCM estimate when bitrate unknown
		stem_bitrate_kbps = int(round(stem_sample_rate * 2 * stem_bit_depth / 1000.0))
	_refresh_media_info_label()


func _read_wav_meta(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_buffer(mini(file.get_length(), 128))
	file.close()
	if raw.size() < 44:
		return {}
	var meta := {
		"codec": "pcm",
		"bit_depth": 16,
		"sample_rate": 44100,
		"channels": 2,
		"bitrate_kbps": 0,
	}
	var i := 12
	while i + 8 < raw.size():
		var chunk_id := raw.slice(i, i + 4).get_string_from_ascii()
		var chunk_size := raw.decode_u32(i + 4)
		if chunk_id == "fmt ":
			var channels := raw.decode_u16(i + 10)
			var rate := raw.decode_u32(i + 12)
			var bits := raw.decode_u16(i + 22)
			meta["channels"] = channels
			meta["sample_rate"] = rate
			meta["bit_depth"] = bits
			meta["bitrate_kbps"] = int(round(rate * channels * bits / 1000.0))
			break
		i += 8 + int(chunk_size)
	return meta


func _refresh_media_info_label() -> void:
	if media_info_label == null:
		return
	if not enabled or stem_path == "":
		media_info_label.text = "Codec: — | Bits: — | Bitrate: — | Type: —"
		return
	var bits_s := ("%d-bit" % stem_bit_depth) if stem_bit_depth > 0 else "—"
	var br_s := ("%d kbps" % stem_bitrate_kbps) if stem_bitrate_kbps > 0 else "—"
	var codec_s := stem_codec if stem_codec != "" else "—"
	var type_s := stem_file_type if stem_file_type != "" else "—"
	var rate_s := (" | %d Hz" % stem_sample_rate) if stem_sample_rate > 0 else ""
	media_info_label.text = "Codec: %s | Bits: %s | Bitrate: %s | Type: %s%s" % [
		codec_s, bits_s, br_s, type_s, rate_s
	]


func _refresh_enabled() -> void:
	var on := enabled and stem_path != ""
	play_btn.disabled = not on
	save_btn.disabled = not on
	status_label.text = "Ready" if on else "Empty / disabled"
	modulate = Color(1, 1, 1, 1.0 if on else 0.55)
	_refresh_media_info_label()


func _load_stream() -> void:
	var ext := stem_path.get_extension().to_lower()
	var stream: AudioStream
	if ext == "mp3":
		var s := AudioStreamMP3.new()
		s.data = FileAccess.get_file_as_bytes(stem_path)
		stream = s
	else:
		stream = _load_wav_file(stem_path)
	if stream:
		_player.stream = stream


func _load_wav_file(path: String) -> AudioStreamWAV:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var raw := file.get_buffer(file.get_length())
	file.close()
	if raw.size() < 44:
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = true
	var i := 12
	var data_start := 44
	var data_size := raw.size() - 44
	while i + 8 < raw.size():
		var chunk_id := raw.slice(i, i + 4).get_string_from_ascii()
		var chunk_size := raw.decode_u32(i + 4)
		if chunk_id == "fmt ":
			stream.mix_rate = raw.decode_u32(i + 12)
			stream.stereo = raw.decode_u16(i + 10) > 1
			if raw.decode_u16(i + 22) == 8:
				stream.format = AudioStreamWAV.FORMAT_8_BITS
		elif chunk_id == "data":
			data_start = i + 8
			data_size = chunk_size
			break
		i += 8 + int(chunk_size)
	stream.data = raw.slice(data_start, mini(raw.size(), data_start + data_size))
	return stream


func toggle_play() -> void:
	if _player.stream == null:
		_load_stream()
	if _player.playing:
		_player.stop()
		play_btn.text = "Play"
	else:
		_apply_live_mix()
		_player.play()
		play_btn.text = "Pause"


func stop_play() -> void:
	if _player and _player.playing:
		_player.stop()
		play_btn.text = "Play"


func is_playing() -> bool:
	return _player != null and _player.playing


func set_export_defaults(format: String, bitrate: int) -> void:
	if format_option == null or bitrate_option == null:
		return
	var fmt := format.to_lower().strip_edges()
	var aliases := {
		"wav": "WAV",
		"mp3": "MP3",
		"mpeg": "MPEG",
		"mpg": "MPEG",
		"m4a": "M4A",
		"aac": "M4A",
		"flac": "FLAC",
		"ogg": "OGG",
		"ac3": "AC3",
		"eac3": "AC3",
	}
	var want := str(aliases.get(fmt, fmt.to_upper()))
	for i in format_option.item_count:
		if format_option.get_item_text(i).to_upper() == want.to_upper():
			format_option.select(i)
			break
	var best_i := bitrate_option.selected
	var best_diff := 999999
	for i in bitrate_option.item_count:
		var b := int(bitrate_option.get_item_text(i).get_slice(" ", 0))
		var d := absi(b - bitrate)
		if d < best_diff:
			best_diff = d
			best_i = i
	bitrate_option.select(best_i)


func get_export_options() -> Dictionary:
	return {
		"input": stem_path,
		"format": format_option.get_item_text(format_option.selected).to_lower(),
		"bitrate": int(bitrate_option.get_item_text(bitrate_option.selected).get_slice(" ", 0)),
		"level_db": level_db,
		"gain_db": gain_db + level_db,
		"volume": volume,
		"pan": pan,
		"amount": amount,
		"reverb_amount": reverb,
	}


func _apply_live_mix() -> void:
	var idx := AudioServer.get_bus_index(_bus_name)
	if idx == -1:
		return
	var vol_lin := maxf(0.0001, volume / 100.0 * amount / 100.0)
	AudioServer.set_bus_volume_db(idx, level_db + gain_db + linear_to_db(vol_lin))
	for i in AudioServer.get_bus_effect_count(idx):
		var fx = AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectReverb:
			var wet := clampf(reverb / 100.0, 0.0, 1.0)
			fx.wet = wet * 0.55
			fx.dry = 1.0 - wet * 0.35
			fx.room_size = 0.35 + wet * 0.45


func _process(_dt: float) -> void:
	if spectrum and spectrum.has_method("set_bus"):
		spectrum.call("set_bus", _bus_name)
