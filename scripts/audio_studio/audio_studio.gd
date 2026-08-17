extends Control
## Desktop Audio Studio — mixer, input/output, describe/record/hum.

const KnobScript = preload("res://scripts/audio_studio/volume_knob.gd")
const FaderScript = preload("res://scripts/audio_studio/volume_fader.gd")
const MixerBus = preload("res://scripts/audio_studio/mixer_bus.gd")
const SAVE_PATH := "user://audio_studio.cfg"

var vols: Dictionary = MixerBus.defaults()
var page: String = "mixer"
var song_prompt: String = ""
var high_performance: bool = true
var capturing: String = ""
var capture_samples: Array = []
var capture_left: float = 0.0
var mic_level: float = 0.0
var out_level: float = 0.0
var mic_hold: float = 0.0
var status_text: String = "Desktop Audio Studio  ·  " + MixerBus.final_label()

var _knobs: Dictionary = {}
var _faders: Dictionary = {}
var _page_btns: Dictionary = {}
var _describe: LineEdit
var _status: Label
var _mic_lamp: ColorRect
var _in_meter: ColorRect
var _out_meter: ColorRect
var _tone: AudioStreamPlayer
var _gen: AudioStreamGenerator
var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _leather: ColorRect
var _hp: CheckButton


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()
	_load()
	_apply_vols()
	_setup_audio()
	_refresh_status()


func _process(delta: float) -> void:
	if _leather:
		_leather.color = Color(0.03, 0.02, 0.025, 1.0).lerp(Color(0.06, 0.04, 0.045, 1.0), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.0004))
	_poll_mic()
	if capturing != "":
		capture_left -= delta
		capture_samples.append({"t": 3.6 - capture_left, "amp": mic_level, "freq": 0.0})
		if capture_left <= 0.0:
			_finish_capture()
	queue_redraw()
	for k in _knobs.values():
		(k as Control).queue_redraw()
	for f in _faders.values():
		(f as Control).queue_redraw()
	if _status:
		_status.add_theme_color_override("font_color", MixerBus.neon_rgb(Time.get_ticks_msec() / 1000.0))


func _setup_audio() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate = 44100
	_gen.buffer_length = 0.5
	_tone = AudioStreamPlayer.new()
	_tone.stream = _gen
	_tone.bus = "Master"
	add_child(_tone)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.volume_db = -80.0
	add_child(_mic_player)
	var rec_idx := AudioServer.get_bus_index("MicIn")
	if rec_idx < 0:
		AudioServer.add_bus()
		rec_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(rec_idx, "MicIn")
		AudioServer.set_bus_mute(rec_idx, true)
	_capture = _find_capture(rec_idx)
	if _capture == null:
		_capture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(rec_idx, _capture)
	_mic_player.bus = "MicIn"
	_mic_player.play()
	if not _mic_player.playing:
		status_text = "Mic unavailable — knobs and describe still work"


func _find_capture(bus_idx: int) -> AudioEffectCapture:
	for i in AudioServer.get_bus_effect_count(bus_idx):
		var fx := AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectCapture:
			return fx
	return null


func _poll_mic() -> void:
	if _capture and _capture.can_get_buffer(_capture.get_frames_available()):
		var frames: PackedVector2Array = _capture.get_buffer(_capture.get_frames_available())
		var peak := 0.0
		for f in frames:
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
		mic_level = clampf(peak * MixerBus.to_gain("input", vols), 0.0, 1.5)
	else:
		mic_level = maxf(0.0, mic_level - 0.04)
	if mic_level >= 0.03:
		mic_hold = 0.28
	else:
		mic_hold = maxf(0.0, mic_hold - 0.016)
	if _mic_lamp:
		if mic_hold > 0.0:
			var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
			_mic_lamp.color = Color(0.9 * pulse, 0.1, 0.12, 1.0)
		else:
			_mic_lamp.color = Color(0.12, 0.08, 0.08, 1.0)
	if _in_meter:
		_in_meter.anchor_top = 1.0 - clampf(mic_level, 0.0, 1.0)
		_in_meter.offset_top = 0
	if _out_meter:
		_out_meter.anchor_top = 1.0 - clampf(out_level, 0.0, 1.0)
		_out_meter.offset_top = 0
	out_level = maxf(0.0, out_level - 0.02)


func _build_ui() -> void:
	_leather = ColorRect.new()
	_leather.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leather.color = Color(0.04, 0.025, 0.03)
	add_child(_leather)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 18
	root.offset_top = 14
	root.offset_right = -18
	root.offset_bottom = -14
	add_child(root)

	var title := Label.new()
	title.text = "AUDIO STUDIO  ·  " + MixerBus.final_label()
	title.add_theme_font_size_override("font_size", 28)
	root.add_child(title)
	_status = Label.new()
	_status.text = status_text
	_status.add_theme_font_size_override("font_size", 14)
	root.add_child(_status)

	var capture := HBoxContainer.new()
	capture.add_theme_constant_override("separation", 8)
	root.add_child(capture)
	var describe_lbl := Label.new()
	describe_lbl.text = MixerBus.DESCRIBE_PLACEHOLDER
	describe_lbl.add_theme_font_size_override("font_size", 13)
	capture.add_child(describe_lbl)
	_describe = LineEdit.new()
	_describe.placeholder_text = MixerBus.DESCRIBE_PLACEHOLDER
	_describe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_describe.text_changed.connect(func(t: String) -> void: song_prompt = MixerBus.describe_to_song(t))
	capture.add_child(_describe)
	var rec := Button.new()
	rec.text = "RECORD MELODY"
	rec.pressed.connect(func() -> void: _start_capture("melody"))
	capture.add_child(rec)
	var hum := Button.new()
	hum.text = "HUM INSTRUMENT"
	hum.pressed.connect(func() -> void: _start_capture("hum"))
	capture.add_child(hum)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)
	for id_label in [["mixer", "MIXER"], ["input", "INPUT AUDIO"], ["output", "OUTPUT AUDIO"]]:
		var b := Button.new()
		b.text = id_label[1]
		b.toggle_mode = true
		b.button_pressed = id_label[0] == "mixer"
		var pid: String = id_label[0]
		b.pressed.connect(func() -> void: _set_page(pid))
		tabs.add_child(b)
		_page_btns[pid] = b

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var meters := VBoxContainer.new()
	meters.custom_minimum_size = Vector2(70, 0)
	body.add_child(meters)
	var lamp_l := Label.new()
	lamp_l.text = "MIC"
	meters.add_child(lamp_l)
	_mic_lamp = ColorRect.new()
	_mic_lamp.custom_minimum_size = Vector2(36, 36)
	_mic_lamp.color = Color(0.12, 0.08, 0.08)
	meters.add_child(_mic_lamp)
	var in_well := ColorRect.new()
	in_well.custom_minimum_size = Vector2(28, 140)
	in_well.color = Color(0.06, 0.06, 0.08)
	in_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meters.add_child(in_well)
	_in_meter = ColorRect.new()
	_in_meter.color = Color(0.9, 0.14, 0.16)
	in_well.clip_contents = true
	_in_meter.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	in_well.add_child(_in_meter)
	var out_well := ColorRect.new()
	out_well.custom_minimum_size = Vector2(28, 140)
	out_well.color = Color(0.06, 0.06, 0.08)
	out_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	meters.add_child(out_well)
	_out_meter = ColorRect.new()
	_out_meter.color = Color(1.0, 0.67, 0.2)
	out_well.clip_contents = true
	_out_meter.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	out_well.add_child(_out_meter)

	var mix_row := HBoxContainer.new()
	mix_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mix_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mix_row.add_theme_constant_override("separation", 10)
	body.add_child(mix_row)

	for id in MixerBus.STRIPS:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kn := KnobScript.new()
		kn.label_text = MixerBus.strip_label(id)
		kn.volume = float(vols[id])
		kn.value_changed.connect(_on_vol.bind(id))
		col.add_child(kn)
		_knobs[id] = kn
		var fd := FaderScript.new()
		fd.label_text = MixerBus.strip_label(id)
		fd.volume = float(vols[id])
		fd.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fd.value_changed.connect(_on_vol.bind(id))
		col.add_child(fd)
		_faders[id] = fd
		mix_row.add_child(col)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	var set_all := Button.new()
	set_all.text = "SET ALL 80%"
	set_all.pressed.connect(_on_set_all)
	actions.add_child(set_all)
	var save_btn := Button.new()
	save_btn.text = "SAVE HIGH PERF"
	save_btn.pressed.connect(_save_high)
	actions.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "LOAD"
	load_btn.pressed.connect(_load)
	actions.add_child(load_btn)
	_hp = CheckButton.new()
	_hp.text = "High Performance"
	_hp.button_pressed = true
	_hp.toggled.connect(func(on: bool) -> void: high_performance = on)
	actions.add_child(_hp)


func _set_page(pid: String) -> void:
	page = pid
	for id in _page_btns:
		(_page_btns[id] as Button).button_pressed = (id == pid)
	# Input page emphasizes IN; output emphasizes OUT/FX; mixer shows all.
	for id in MixerBus.STRIPS:
		var show := true
		if pid == "input":
			show = id == "input"
		elif pid == "output":
			show = id != "input"
		(_knobs[id] as Control).visible = show
		(_faders[id] as Control).visible = show
	_refresh_status()


func _on_vol(value: float, id: String) -> void:
	vols[id] = MixerBus.clamp_vol(value)
	(_knobs[id] as KnobScript).volume = float(vols[id])
	(_faders[id] as FaderScript).volume = float(vols[id])
	(_knobs[id] as Control).queue_redraw()
	(_faders[id] as Control).queue_redraw()
	_apply_vols()
	status_text = "%s tweaked — %.0f%%" % [MixerBus.strip_label(id), (float(vols[id]) / MixerBus.UNITY) * 100.0]
	_refresh_status()


func _apply_vols() -> void:
	if _tone:
		_tone.volume_db = linear_to_db(clampf(MixerBus.to_gain("output", vols), 0.001, 2.0))


func _on_set_all() -> void:
	vols = MixerBus.set_all(vols, MixerBus.UNITY)
	for id in MixerBus.STRIPS:
		(_knobs[id] as KnobScript).volume = MixerBus.UNITY
		(_faders[id] as FaderScript).volume = MixerBus.UNITY
		(_knobs[id] as Control).queue_redraw()
		(_faders[id] as Control).queue_redraw()
	_apply_vols()
	status_text = "All volumes (incl. Master) set to 80%"
	_refresh_status()
	_save_high()


func _start_capture(mode: String) -> void:
	capturing = mode
	capture_samples.clear()
	capture_left = 3.6
	status_text = "Recording %s — sing or hum" % mode
	_refresh_status()


func _finish_capture() -> void:
	var mode := capturing
	capturing = ""
	if mode == "hum":
		var inst: Dictionary = MixerBus.hum_instrument(capture_samples)
		status_text = "Hum instrument · %s · MIDI %d" % [song_prompt if song_prompt != "" else "hum", int(inst.get("midi", 60))]
		_play_tone(MixerBus.midi_to_hz(float(inst.get("midi", 60))), 0.85)
	else:
		var notes: Array = MixerBus.quantize_melody(capture_samples, 0.07)
		status_text = "Melody · %s · %d notes" % [song_prompt if song_prompt != "" else "melody", notes.size()]
		if notes.is_empty():
			status_text = "No notes heard — try louder"
		else:
			_play_tone(MixerBus.midi_to_hz(float(notes[0].get("midi", 60))), float(notes[0].get("dur", 0.2)))
	_refresh_status()
	_save()


func _play_tone(hz: float, dur: float) -> void:
	if _tone == null or _gen == null:
		return
	if not _tone.playing:
		_tone.play()
	var pb := _tone.get_stream_playback()
	if pb == null:
		return
	var n := int(_gen.mix_rate * clampf(dur, 0.08, 1.2))
	var amp := clampf(MixerBus.to_gain("output", vols), 0.05, 1.0) * 0.25
	for i in n:
		var s := sin(TAU * hz * i / _gen.mix_rate) * amp
		pb.push_frame(Vector2(s, s))
	out_level = maxf(out_level, amp * 3.0)


func _save_high() -> void:
	high_performance = true
	_save()
	status_text = "Saved in high performance mode · " + MixerBus.final_label()
	_refresh_status()


func _save() -> void:
	if _describe:
		song_prompt = MixerBus.describe_to_song(_describe.text)
	var cfg := ConfigFile.new()
	for k in MixerBus.STRIPS:
		cfg.set_value("vols", k, float(vols[k]))
	cfg.set_value("meta", "prompt", song_prompt)
	cfg.set_value("meta", "high_performance", 1 if high_performance else 0)
	cfg.set_value("meta", "page", page)
	cfg.set_value("meta", "version", MixerBus.VERSION)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in MixerBus.STRIPS:
		vols[k] = MixerBus.clamp_vol(float(cfg.get_value("vols", k, MixerBus.UNITY)))
	song_prompt = MixerBus.describe_to_song(str(cfg.get_value("meta", "prompt", "")))
	high_performance = int(cfg.get_value("meta", "high_performance", 1)) != 0
	page = str(cfg.get_value("meta", "page", "mixer"))
	if _describe:
		_describe.text = song_prompt
	if _hp:
		_hp.set_pressed_no_signal(high_performance)
	for id in MixerBus.STRIPS:
		if _knobs.has(id):
			(_knobs[id] as KnobScript).volume = float(vols[id])
			(_faders[id] as FaderScript).volume = float(vols[id])
	_set_page(page)
	_apply_vols()
	status_text = "Loaded · " + MixerBus.final_label()
	_refresh_status()


func _refresh_status() -> void:
	if _status:
		_status.text = status_text


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_high()
