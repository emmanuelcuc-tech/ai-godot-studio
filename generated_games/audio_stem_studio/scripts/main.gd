extends Control
## Audio Stem Studio — main window.

const SUPPORTED_EXTENSIONS := [
	"wav", "mp3", "flac", "ogg", "m4a", "aac", "mpeg", "mpg", "mp2",
	"wma", "aiff", "aif", "opus", "ac3", "eac3", "dts",
	"mp4", "mkv", "mov", "webm",
]

var backend: AudioBackend
var strips: Array = []
var media_path: String = ""
var probe_info: Dictionary = {}
var surround_layout: String = "5.1"
var surround_mode: String = "direct"
var target_latency_ms: int = 64
var master_gain_db: float = 0.0
var fill_amount: float = 100.0
var master_reverb_send: float = 0.0
var export_bitrate: int = 256

var file_dialog: FileDialog
var save_dialog: FileDialog
var status_label: Label
var progress_bar: ProgressBar
var bits_label: Label
var codec_label: Label
var type_label: Label
var bitrate_label: Label
var filename_label: Label
var surround_badge: Label
var latency_spin: SpinBox
var latency_readout: Label
var master_gain_spin: SpinBox
var fill_slider: HSlider
var preset_option: OptionButton
var codec_option: OptionButton
var layout_option: OptionButton
var bitrate_global: OptionButton
var channels_host: VBoxContainer
var channels_title: Label
var speaker_panel: SpeakerPanel
var _save_target: String = ""
var _playing_all := false
var _auto_separate_after_probe := false
var _saved_this_session := false
var _scratch_root: String = ""
var scratch_label: Label
var default_export_format: String = "wav"
var default_codec_label: String = "WAV (PCM)"


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_scratch_root = ScratchDrive.resolve_root()
	# Clear leftovers from previous unclean exits + legacy session "projects".
	ScratchDrive.clear_previous_sessions(_scratch_root)
	DirAccess.make_dir_recursive_absolute(_scratch_root)

	backend = AudioBackend.new()
	backend.name = "AudioBackend"
	backend.work_dir = _scratch_root
	add_child(backend)
	backend.set_work_dir(_scratch_root)
	backend.progress.connect(_on_progress)
	backend.probe_finished.connect(_on_probe)
	backend.separate_finished.connect(_on_separate)
	backend.export_finished.connect(_on_export)
	tree_exiting.connect(_on_tree_exiting)
	_build_ui()
	_apply_preset(SurroundPresets.DEFAULT_PRESET)
	_apply_default_codec("WAV (PCM)")
	_select_codec_option("WAV (PCM)")
	_update_latency_readout()
	_update_scratch_label()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.16)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_bottom", 10)
	add_child(root)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	root.add_child(v)

	# Title
	var title := Label.new()
	title.text = "Audio Stem Studio"
	title.add_theme_font_size_override("font_size", 26)
	v.add_child(title)

	# Media row
	var media_box := PanelContainer.new()
	v.add_child(media_box)
	var media_v := VBoxContainer.new()
	media_box.add_child(media_v)
	var media_l := Label.new()
	media_l.text = "Media"
	media_l.add_theme_font_size_override("font_size", 16)
	media_v.add_child(media_l)
	var media_row := HBoxContainer.new()
	media_v.add_child(media_row)
	var media_btn := Button.new()
	media_btn.text = "Open Media…"
	media_btn.tooltip_text = "Pick a file — it loads and separates automatically."
	media_btn.pressed.connect(_open_media)
	media_row.add_child(media_btn)
	var sep_btn := Button.new()
	sep_btn.text = "Re-Separate"
	sep_btn.tooltip_text = "Run stem separation again on the current file."
	sep_btn.pressed.connect(_separate)
	media_row.add_child(sep_btn)
	filename_label = Label.new()
	filename_label.text = "No file selected"
	filename_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media_row.add_child(filename_label)
	codec_label = Label.new()
	codec_label.text = "Codec: —"
	media_row.add_child(codec_label)
	bitrate_label = Label.new()
	bitrate_label.text = "Bitrate: —"
	media_row.add_child(bitrate_label)
	bits_label = Label.new()
	bits_label.text = "Bits: —"
	media_row.add_child(bits_label)
	type_label = Label.new()
	type_label.text = "Type: —"
	media_row.add_child(type_label)
	surround_badge = Label.new()
	surround_badge.text = "Surround: 5.1 | %s" % SurroundPresets.DEFAULT_PRESET
	surround_badge.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	media_row.add_child(surround_badge)

	progress_bar = ProgressBar.new()
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 16
	v.add_child(progress_bar)
	status_label = Label.new()
	status_label.text = "Open Media to auto-load and separate"
	v.add_child(status_label)
	scratch_label = Label.new()
	scratch_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	scratch_label.add_theme_font_size_override("font_size", 12)
	v.add_child(scratch_label)

	# Body split
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	# Left: channels (rebuilt after each separation — one strip per stem)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	split.add_child(left)
	channels_title = Label.new()
	channels_title.text = "Stem Channels — open media to auto-separate"
	left.add_child(channels_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	channels_host = VBoxContainer.new()
	channels_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(channels_host)
	strips.clear()

	# Right: Options / Mixer
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 420
	split.add_child(right)

	var opt_title := Label.new()
	opt_title.text = "Options / Mixer"
	opt_title.add_theme_font_size_override("font_size", 18)
	right.add_child(opt_title)

	var preset_row := HBoxContainer.new()
	right.add_child(preset_row)
	var preset_l := Label.new()
	preset_l.text = "Surround"
	preset_row.add_child(preset_l)
	preset_option = OptionButton.new()
	preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for p in SurroundPresets.PRESET_ORDER:
		preset_option.add_item(p)
	preset_option.item_selected.connect(func(i):
		_apply_preset(preset_option.get_item_text(i))
	)
	preset_option.tooltip_text = "Default: 5.1 Surround. Also: Stereo Surround, Dolby Pro Logic, Dolby Pro, 2.1/7.1, Matrix, Cinema Wide, Headphones."
	# Select default before signals fire from later _apply_preset.
	for i in preset_option.item_count:
		if preset_option.get_item_text(i) == SurroundPresets.DEFAULT_PRESET:
			preset_option.select(i)
			break
	preset_row.add_child(preset_option)

	var codec_row := HBoxContainer.new()
	right.add_child(codec_row)
	codec_row.add_child(_label("Default codec"))
	codec_option = OptionButton.new()
	codec_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c in SurroundPresets.CODEC_ORDER:
		codec_option.add_item(c)
	codec_option.item_selected.connect(func(i):
		_apply_default_codec(codec_option.get_item_text(i))
	)
	codec_option.tooltip_text = "Default save/export codec for stems and mix (WAV, MP3, MPEG, FLAC, M4A, OGG, AC3)."
	codec_row.add_child(codec_option)

	var layout_row := HBoxContainer.new()
	right.add_child(layout_row)
	layout_row.add_child(_label("Layout"))
	layout_option = OptionButton.new()
	for lay in ["stereo", "2.1", "5.1", "7.1"]:
		layout_option.add_item(lay)
	layout_option.item_selected.connect(func(i):
		surround_layout = layout_option.get_item_text(i)
		speaker_panel.set_layout(surround_layout)
		_update_badge()
	)
	layout_row.add_child(layout_option)

	var gain_row := HBoxContainer.new()
	right.add_child(gain_row)
	gain_row.add_child(_label("Gain (dB) master"))
	master_gain_spin = SpinBox.new()
	master_gain_spin.min_value = -60
	master_gain_spin.max_value = 12
	master_gain_spin.step = 0.1
	master_gain_spin.value = 0
	master_gain_spin.suffix = " dB"
	master_gain_spin.value_changed.connect(func(v):
		master_gain_db = v
		speaker_panel.master_gain_db = v
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), v)
	)
	gain_row.add_child(master_gain_spin)

	var fill_row := HBoxContainer.new()
	right.add_child(fill_row)
	fill_row.add_child(_label("Amount / Fill"))
	fill_slider = HSlider.new()
	fill_slider.min_value = 0
	fill_slider.max_value = 200
	fill_slider.value = 100
	fill_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill_slider.value_changed.connect(func(v):
		fill_amount = v
		speaker_panel.fill_amount = v
	)
	fill_row.add_child(fill_slider)

	var lat_row := HBoxContainer.new()
	right.add_child(lat_row)
	lat_row.add_child(_label("Latency (ms)"))
	latency_spin = SpinBox.new()
	latency_spin.min_value = 16
	latency_spin.max_value = 250
	latency_spin.value = 50
	latency_spin.value_changed.connect(func(v):
		target_latency_ms = int(v)
		backend.apply_latency_ms(target_latency_ms)
		_update_latency_readout()
	)
	lat_row.add_child(latency_spin)
	latency_readout = Label.new()
	latency_readout.text = "Est: —"
	lat_row.add_child(latency_readout)

	var br_row := HBoxContainer.new()
	right.add_child(br_row)
	br_row.add_child(_label("Export bitrate"))
	bitrate_global = OptionButton.new()
	for b in ["128", "256", "512"]:
		bitrate_global.add_item(b + " kbps")
	bitrate_global.select(1)
	bitrate_global.item_selected.connect(func(i):
		export_bitrate = int(bitrate_global.get_item_text(i).get_slice(" ", 0))
		_refresh_bits_label()
	)
	br_row.add_child(bitrate_global)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Speaker Defaults"
	reset_btn.pressed.connect(func():
		_apply_preset(preset_option.get_item_text(preset_option.selected))
	)
	right.add_child(reset_btn)

	var sp_title := Label.new()
	sp_title.text = "Speaker Volumes / Gain dB / Pan / Amount"
	right.add_child(sp_title)
	var sp_scroll := ScrollContainer.new()
	sp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp_scroll)
	speaker_panel = SpeakerPanel.new()
	speaker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_scroll.add_child(speaker_panel)

	# Bottom bar
	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	var play_all := Button.new()
	play_all.text = "Play All"
	play_all.pressed.connect(_play_all)
	bottom.add_child(play_all)
	var pause_all := Button.new()
	pause_all.text = "Pause"
	pause_all.pressed.connect(_pause_all)
	bottom.add_child(pause_all)
	var save_sep := Button.new()
	save_sep.text = "Save All Separate"
	save_sep.pressed.connect(_save_all_separate)
	bottom.add_child(save_sep)
	var save_mix := Button.new()
	save_mix.text = "Save All Mixed"
	save_mix.pressed.connect(_save_all_mixed)
	bottom.add_child(save_mix)
	var save_surr := Button.new()
	save_surr.text = "Save Surround Mix"
	save_surr.pressed.connect(_save_surround)
	bottom.add_child(save_surr)
	var down := Button.new()
	down.text = "Downmix 7.1→5.1→2.1"
	down.pressed.connect(_cycle_downmix)
	bottom.add_child(down)

	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Media"
	file_dialog.filters = PackedStringArray([
		"*.wav;WAV (PCM)",
		"*.mp3;MP3",
		"*.flac;FLAC",
		"*.ogg;OGG Vorbis",
		"*.m4a,*.aac;M4A / AAC",
		"*.mpeg,*.mpg,*.mp2;MPEG",
		"*.wma;WMA",
		"*.aiff,*.aif;AIFF",
		"*.opus;Opus",
		"*.ac3,*.eac3;AC3 / E-AC3",
		"*.dts;DTS",
		"*.mp4,*.mkv,*.mov,*.webm;Video containers",
		"*.wav,*.mp3,*.flac,*.ogg,*.m4a,*.aac,*.wma,*.aiff,*.aif,*.opus,*.ac3,*.eac3,*.dts,*.mp4,*.mkv,*.mpeg,*.mpg;All audio/video",
		"*.*;All files",
	])
	file_dialog.file_selected.connect(_on_media_selected)
	add_child(file_dialog)

	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = PackedStringArray([
		"*.wav;WAV (PCM)",
		"*.mp3;MP3",
		"*.mpeg;MPEG",
		"*.flac;FLAC",
		"*.m4a;M4A / AAC",
		"*.ogg;OGG Vorbis",
		"*.ac3;AC3",
	])
	save_dialog.file_selected.connect(_on_save_path)
	save_dialog.dir_selected.connect(_on_save_path)
	add_child(save_dialog)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _process(_dt: float) -> void:
	if speaker_panel:
		var any := _playing_all
		for s in strips:
			if s.is_playing():
				any = true
				break
		speaker_panel.simulate_meters_from_mix(any)


func _open_media() -> void:
	file_dialog.popup_centered_ratio(0.7)


func _is_supported_media(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext in SUPPORTED_EXTENSIONS


func _clear_media_meta_labels() -> void:
	codec_label.text = "Codec: —"
	if bitrate_label:
		bitrate_label.text = "Bitrate: —"
	bits_label.text = "Bits: —"
	if type_label:
		type_label.text = "Type: —"


func _on_media_selected(path: String) -> void:
	if not _is_supported_media(path):
		media_path = ""
		probe_info = {}
		_auto_separate_after_probe = false
		filename_label.text = path.get_file()
		_clear_media_meta_labels()
		progress_bar.value = 0
		var ext := path.get_extension().to_lower()
		status_label.text = "Unsupported file type: .%s — use WAV, MP3, FLAC, OGG, M4A, AAC, MPEG, WMA, AIFF, Opus, AC3/EAC3, DTS, or MP4/MKV/MOV/WebM." % ext
		return
	media_path = path
	filename_label.text = path.get_file()
	_auto_separate_after_probe = true
	_clear_media_meta_labels()
	_clear_channel_strips()
	status_label.text = "Loading… separating…"
	progress_bar.value = 10
	# Always queue probe; separate is enqueued from _on_probe (queue handles busy).
	backend.run_probe_async(path)


func _on_probe(result: Dictionary) -> void:
	probe_info = result
	var should_auto := _auto_separate_after_probe
	_auto_separate_after_probe = false
	if not result.get("ok", false):
		status_label.text = "Probe warning: %s — Loading… separating…" % str(result.get("error", "?"))
		progress_bar.value = 20
		codec_label.text = "Codec: unknown"
		if bitrate_label:
			bitrate_label.text = "Bitrate: —"
		bits_label.text = "Bits: —"
		if type_label:
			type_label.text = "Type: %s" % media_path.get_extension().to_lower()
		_refresh_bits_label()
		if should_auto and not media_path.is_empty():
			_separate(true)
		return
	_apply_probe_labels(result)
	_refresh_bits_label()
	if result.get("surround_hint"):
		var hint := str(result.get("surround_hint"))
		if hint in ["stereo", "2.1", "5.1", "7.1"]:
			surround_layout = hint
			_select_layout(hint)
	progress_bar.value = 30
	if should_auto:
		status_label.text = "Loading… separating…"
		_separate(true)
	else:
		status_label.text = "Media ready. Click Re-Separate if needed."


func _apply_probe_labels(result: Dictionary) -> void:
	var codec := str(result.get("codec", "?"))
	var codec_long := str(result.get("codec_long", ""))
	if codec_long != "" and codec_long.to_lower() != codec.to_lower():
		codec_label.text = "Codec: %s (%s)" % [codec, codec_long]
	else:
		codec_label.text = "Codec: %s" % codec
	var br_kbps = result.get("bitrate_kbps", null)
	if br_kbps == null and result.get("bitrate", null) != null:
		br_kbps = int(round(float(result.get("bitrate")) / 1000.0))
	if bitrate_label:
		if br_kbps != null and int(br_kbps) > 0:
			bitrate_label.text = "Bitrate: %d kbps" % int(br_kbps)
		else:
			bitrate_label.text = "Bitrate: —"
	var depth = result.get("bit_depth", null)
	var ch: Variant = result.get("channels", "?")
	var rate = result.get("sample_rate", null)
	var bits_parts: PackedStringArray = []
	if depth != null:
		bits_parts.append("%s-bit" % str(depth))
	else:
		bits_parts.append("—")
	bits_parts.append("%s ch" % str(ch))
	if rate != null and int(rate) > 0:
		bits_parts.append("%d Hz" % int(rate))
	bits_label.text = "Bits: %s" % " | ".join(bits_parts)
	var file_type := str(result.get("file_type", ""))
	var container := str(result.get("container", ""))
	if file_type == "" and media_path != "":
		file_type = media_path.get_extension().to_lower()
	if type_label:
		if container != "" and container.to_lower() != file_type.to_lower():
			type_label.text = "Type: %s (%s)" % [file_type, container]
		elif file_type != "":
			type_label.text = "Type: %s" % file_type
		else:
			type_label.text = "Type: —"
	# Keep surround hint visible on codec line via badge; also note channel layout
	var layout_hint := str(result.get("surround_hint", ""))
	if layout_hint != "":
		codec_label.text += " · %s" % layout_hint


func _refresh_bits_label() -> void:
	# Keep Bits label focused on source bit depth; append export default briefly.
	var depth = probe_info.get("bit_depth", null) if not probe_info.is_empty() else null
	var ch = probe_info.get("channels", null) if not probe_info.is_empty() else null
	var rate = probe_info.get("sample_rate", null) if not probe_info.is_empty() else null
	var parts: PackedStringArray = []
	parts.append(("%s-bit" % str(depth)) if depth != null else "—")
	if ch != null:
		parts.append("%s ch" % str(ch))
	if rate != null and int(rate) > 0:
		parts.append("%d Hz" % int(rate))
	parts.append("Export %s @ %d kbps" % [default_export_format.to_upper(), export_bitrate])
	bits_label.text = "Bits: %s" % " | ".join(parts)
	if bitrate_label == null:
		return
	var br_kbps = probe_info.get("bitrate_kbps", null) if not probe_info.is_empty() else null
	if br_kbps == null and not probe_info.is_empty() and probe_info.get("bitrate", null) != null:
		br_kbps = int(round(float(probe_info.get("bitrate")) / 1000.0))
	if br_kbps != null and int(br_kbps) > 0:
		bitrate_label.text = "Bitrate: %d kbps" % int(br_kbps)


func _apply_default_codec(label: String) -> void:
	default_codec_label = label
	var mapped: Dictionary = SurroundPresets.codec_to_format_bitrate(label)
	default_export_format = str(mapped.get("format", "wav"))
	export_bitrate = int(mapped.get("bitrate", 256))
	_select_codec_option(label)
	if bitrate_global:
		_select_bitrate(export_bitrate)
	_apply_codec_to_strips()
	_refresh_bits_label()


func _select_codec_option(label: String) -> void:
	if codec_option == null:
		return
	for i in codec_option.item_count:
		if codec_option.get_item_text(i) == label:
			codec_option.select(i)
			return


func _select_bitrate(br: int) -> void:
	if bitrate_global == null:
		return
	for i in bitrate_global.item_count:
		var b := int(bitrate_global.get_item_text(i).get_slice(" ", 0))
		if b == br:
			bitrate_global.select(i)
			return


func _apply_codec_to_strips() -> void:
	for s in strips:
		if s.has_method("set_export_defaults"):
			s.set_export_defaults(default_export_format, export_bitrate)


func _separate(from_auto: bool = false) -> void:
	if media_path.is_empty():
		status_label.text = "Select a Media file first."
		return
	# Auto-separate after probe must not be blocked by a stale busy flag —
	# the backend job queue serializes work. Manual Re-Separate still waits.
	if not from_auto and backend.is_busy():
		status_label.text = "Busy — wait for the current job to finish."
		return
	status_label.text = "Loading… separating…"
	progress_bar.value = 40
	backend.run_separate_async(media_path, false)


func _clear_channel_strips() -> void:
	_playing_all = false
	for s in strips:
		if is_instance_valid(s):
			s.stop_play()
	strips.clear()
	if channels_host:
		var old := channels_host.get_children()
		for child in old:
			channels_host.remove_child(child)
			child.free()
	if channels_title:
		channels_title.text = "Stem Channels — separating…"


func _rebuild_channel_strips(channels: Array) -> int:
	## One stem file = one channel strip. Clears previous strips first.
	_clear_channel_strips()
	var loaded := 0
	for ch in channels:
		var path := str(ch.get("path", "")).strip_edges()
		if path == "" or not FileAccess.file_exists(path):
			continue
		var data: Dictionary = ch.duplicate(true) if typeof(ch) == TYPE_DICTIONARY else {}
		var label := str(data.get("label", "")).strip_edges()
		if label == "":
			label = path.get_file().get_basename().replace("_", " ")
		data["path"] = path
		data["label"] = label
		data["enabled"] = true
		var index := strips.size()
		var strip := ChannelStrip.new()
		strip.setup(index)
		strip.play_pressed.connect(_on_strip_play)
		strip.save_pressed.connect(_on_strip_save)
		channels_host.add_child(strip)
		strips.append(strip)
		strip.configure(data)
		loaded += 1
	if channels_title:
		channels_title.text = "Stem Channels (%d)" % loaded
	return loaded


func _on_separate(result: Dictionary) -> void:
	progress_bar.value = 100 if result.get("ok", false) else 0
	if not result.get("ok", false):
		var err := str(result.get("error", "?"))
		var hint := str(result.get("install_hint", ""))
		if err.to_lower().contains("python") or err.to_lower().contains("audio-separator") or err.to_lower().contains("no manifest"):
			status_label.text = "Separate failed: %s — install Python + pip install audio-separator (and ffmpeg)." % err
		else:
			status_label.text = "Separate failed: %s" % err
		if hint != "":
			status_label.text += " Hint: %s" % hint.get_slice("\n", 0)
		_clear_channel_strips()
		if channels_title:
			channels_title.text = "Stem Channels — separation failed"
		return
	var channels: Array = result.get("channels", [])
	var loaded := _rebuild_channel_strips(channels)
	_apply_codec_to_strips()
	var eng := str(result.get("engine", ""))
	if loaded <= 0:
		status_label.text = "Separate produced no stem files (engine: %s)." % eng
		return
	status_label.text = "Channels ready — %d tracks via %s. Each stem is on its own strip." % [loaded, eng]
	if result.get("error", "") != "":
		status_label.text += " Note: %s" % str(result.get("error"))


func _on_strip_play(index: int) -> void:
	strips[index].toggle_play()


func _on_strip_save(index: int) -> void:
	_save_target = "stem:%d" % index
	strips[index].set_export_defaults(default_export_format, export_bitrate)
	var opts: Dictionary = strips[index].get_export_options()
	var ext := str(opts.get("format", default_export_format))
	save_dialog.current_file = "stem_%d.%s" % [index + 1, ext]
	save_dialog.popup_centered_ratio(0.6)


func _play_all() -> void:
	_playing_all = true
	for s in strips:
		if s.enabled:
			if not s.is_playing():
				s.toggle_play()


func _pause_all() -> void:
	_playing_all = false
	for s in strips:
		s.stop_play()


func _save_all_separate() -> void:
	_save_target = "all_separate"
	save_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	save_dialog.title = "Folder for stems"
	save_dialog.popup_centered_ratio(0.6)


func _save_all_mixed() -> void:
	_save_target = "all_mixed"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.current_file = "mix.%s" % default_export_format
	save_dialog.popup_centered_ratio(0.6)


func _save_surround() -> void:
	_save_target = "surround"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.current_file = "surround_%s.%s" % [
		surround_layout.replace(".", ""),
		default_export_format,
	]
	save_dialog.popup_centered_ratio(0.6)


func _export_format_for_path(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "":
		return default_export_format
	return ext


func _on_save_path(path: String) -> void:
	if _save_target.begins_with("stem:"):
		var idx := int(_save_target.get_slice(":", 1))
		var opts: Dictionary = strips[idx].get_export_options()
		opts["output"] = path
		opts["format"] = _export_format_for_path(path)
		opts["bitrate"] = export_bitrate
		status_label.text = "Exporting stem…"
		backend.run_export_stem_async(opts)
	elif _save_target == "all_separate":
		# path is directory when OPEN_DIR — on some platforms file_selected still fires with file; handle both
		var dir := path
		if not DirAccess.dir_exists_absolute(dir):
			dir = path.get_base_dir()
		_apply_codec_to_strips()
		for i in strips.size():
			var s: ChannelStrip = strips[i]
			if not s.enabled or s.stem_path == "":
				continue
			var opts: Dictionary = s.get_export_options()
			var ext := default_export_format
			opts["format"] = ext
			opts["output"] = dir.path_join("stem_%d_%s.%s" % [i + 1, s.label_text.to_snake_case(), ext])
			opts["bitrate"] = export_bitrate
			backend.run_export_stem_async(opts)
		status_label.text = "Exporting separate stems (%s @ %d kbps) → %s" % [
			default_export_format.to_upper(), export_bitrate, dir
		]
	elif _save_target == "all_mixed":
		var inputs: Array = []
		for s in strips:
			if s.enabled and s.stem_path != "":
				inputs.append(s.stem_path)
		backend.run_export_stem_async({
			"mix": true,
			"inputs": inputs,
			"input": inputs[0] if inputs.size() else "",
			"output": path,
			"format": _export_format_for_path(path),
			"bitrate": export_bitrate,
		})
		status_label.text = "Exporting mix (%s @ %d kbps)…" % [
			default_export_format.to_upper(), export_bitrate
		]
	elif _save_target == "surround":
		var src := media_path
		for s in strips:
			if s.enabled and s.stem_path != "":
				src = s.stem_path
				break
		var gains: Dictionary = speaker_panel.get_gains_payload()
		gains["master_gain_db"] = master_gain_db
		gains["fill_amount"] = fill_amount
		backend.run_surround_export_async({
			"input": src,
			"output": path,
			"layout": surround_layout,
			"mode": surround_mode,
			"gains": gains,
			"format": _export_format_for_path(path),
			"bitrate": export_bitrate,
		})
		status_label.text = "Exporting surround (%s, %s @ %d kbps)…" % [
			surround_layout, default_export_format.to_upper(), export_bitrate
		]
	# restore save dialog mode
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE


func _on_export(result: Dictionary) -> void:
	if result.get("ok", false):
		_saved_this_session = true
		status_label.text = "Saved: %s" % str(result.get("path", ""))
	else:
		status_label.text = "Export issue: %s" % str(result.get("error", result))


func _update_scratch_label() -> void:
	if scratch_label == null:
		return
	scratch_label.text = "Scratch: %s (auto-clears if you quit without Save)" % _scratch_root


func _on_tree_exiting() -> void:
	_clear_scratch_safe()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_clear_scratch_safe()
		get_tree().quit()


func _clear_scratch_safe() -> void:
	# Stop playback so stem files are not locked while deleting.
	_pause_all()
	if backend != null:
		backend.wait_for_idle()
	# Always wipe scratch temps. Successful Save / Save All write outside scratch
	# (_saved_this_session tracks that the user persisted something this run).
	# Also clear legacy session roots so old session "projects" never linger after quit.
	ScratchDrive.clear_previous_sessions(_scratch_root)
	if _scratch_root != "":
		DirAccess.make_dir_recursive_absolute(_scratch_root)


func _on_progress(msg: String) -> void:
	status_label.text = msg
	progress_bar.value = mini(95, progress_bar.value + 5)


func _apply_preset(name: String) -> String:
	var p: Dictionary = SurroundPresets.get_preset(name)
	surround_layout = str(p.get("layout", "stereo"))
	surround_mode = str(p.get("mode", "direct"))
	master_gain_db = float(p.get("master_gain_db", 0.0))
	fill_amount = float(p.get("fill_amount", 100.0))
	master_reverb_send = float(p.get("reverb_send", 0.0))
	target_latency_ms = int(p.get("latency_ms", 50))
	master_gain_spin.value = master_gain_db
	fill_slider.value = fill_amount
	latency_spin.value = target_latency_ms
	_select_layout(surround_layout)
	if speaker_panel:
		speaker_panel.master_gain_db = master_gain_db
		speaker_panel.fill_amount = fill_amount
		speaker_panel.set_layout(surround_layout)
		speaker_panel.apply_preset_speakers(p.get("speakers", {}))
	# select preset in dropdown
	for i in preset_option.item_count:
		if preset_option.get_item_text(i) == name:
			preset_option.select(i)
			break
	preset_option.tooltip_text = str(p.get("note", SurroundPresets.tooltip_for(name)))
	var alias := SurroundPresets.apply_alias_note(name)
	status_label.text = "Preset: %s%s" % [name, (" — " + alias) if alias != "" else ""]
	_update_badge()
	_update_latency_readout()
	return name


func _select_layout(lay: String) -> void:
	for i in layout_option.item_count:
		if layout_option.get_item_text(i) == lay:
			layout_option.select(i)
			break
	surround_layout = lay


func _update_badge() -> void:
	var preset_name := preset_option.get_item_text(preset_option.selected)
	surround_badge.text = "Surround: %s | %s" % [surround_layout, preset_name]


func _update_latency_readout() -> void:
	var reported := backend.get_reported_latency_ms() if backend else 0.0
	latency_readout.text = "Target %d ms | Output ~%.1f ms" % [target_latency_ms, reported]


func _cycle_downmix() -> void:
	match surround_layout:
		"7.1":
			surround_layout = "5.1"
		"5.1":
			surround_layout = "2.1"
		"2.1":
			surround_layout = "stereo"
		_:
			surround_layout = "7.1"
	_select_layout(surround_layout)
	speaker_panel.set_layout(surround_layout)
	_update_badge()
	status_label.text = "Downmix monitor → %s" % surround_layout
