extends MarginContainer
## Settings: paper type/color, fonts, spacing, HQ 4K/2K, haptics.

signal request_rebuild_assets

var _paper_option: OptionButton
var _font_style: OptionButton
var _spacing: OptionButton
var _font_size: SpinBox
var _hq: CheckButton
var _haptics: CheckButton
var _fx: CheckButton
var _sound: CheckButton
var _custom_paper: CheckButton
var _paper_picker: ColorPickerButton
var _font_picker: ColorPickerButton
var _status: Label
var _preset_row: HBoxContainer


func _ready() -> void:
	_build()
	_load_into_form()


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", 16)
	add_theme_constant_override("margin_top", 12)
	add_theme_constant_override("margin_right", 16)
	add_theme_constant_override("margin_bottom", 12)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	scroll.add_child(root)

	root.add_child(_title("Settings — Paper, Fonts, HQ"))
	root.add_child(_hint("Referenced from Underwood / Remington / Olivetti manuals. Paper textures bake at 4K; key sprites at 2K when HQ is on."))

	root.add_child(_section("HQ graphics"))
	_hq = CheckButton.new()
	_hq.text = "HQ mode — 4K paper · 2K key sprites"
	_hq.toggled.connect(func(on: bool) -> void:
		TwSettings.hq_assets = on
		TwSettings.notify()
		request_rebuild_assets.emit()
		_status.text = "Rebaking assets at %s…" % ("4K/2K" if on else "2K/1K")
	)
	root.add_child(_hq)

	root.add_child(_section("Paper type"))
	_paper_option = OptionButton.new()
	for id in ["white", "tinted_yellow", "vintage", "green", "blue", "red", "yellow", "black"]:
		_paper_option.add_item(id.replace("_", " ").capitalize())
		_paper_option.set_item_metadata(_paper_option.item_count - 1, id)
	_paper_option.item_selected.connect(func(i: int) -> void:
		TwSettings.paper_type = str(_paper_option.get_item_metadata(i))
		TwSettings.use_custom_paper_color = false
		_custom_paper.button_pressed = false
		TwSettings.notify()
	)
	root.add_child(_paper_option)

	_custom_paper = CheckButton.new()
	_custom_paper.text = "Custom paper color (overrides preset tint)"
	root.add_child(_custom_paper)
	_paper_picker = ColorPickerButton.new()
	_paper_picker.custom_minimum_size = Vector2(0, 36)
	_paper_picker.edit_alpha = false
	root.add_child(_paper_picker)
	_custom_paper.toggled.connect(func(on: bool) -> void:
		TwSettings.use_custom_paper_color = on
		TwSettings.notify()
	)
	_paper_picker.color_changed.connect(func(c: Color) -> void:
		TwSettings.paper_color = c
		TwSettings.use_custom_paper_color = true
		_custom_paper.button_pressed = true
		TwSettings.notify()
	)

	root.add_child(_section("Font"))
	_font_style = OptionButton.new()
	_font_style.add_item("Regular"); _font_style.set_item_metadata(0, "regular")
	_font_style.add_item("Bold"); _font_style.set_item_metadata(1, "bold")
	_font_style.add_item("Italic"); _font_style.set_item_metadata(2, "italic")
	_font_style.item_selected.connect(func(i: int) -> void:
		TwSettings.font_style = str(_font_style.get_item_metadata(i))
		TwSettings.notify()
	)
	root.add_child(_font_style)

	var size_row := HBoxContainer.new()
	root.add_child(size_row)
	var sl := Label.new()
	sl.text = "Font size"
	size_row.add_child(sl)
	_font_size = SpinBox.new()
	_font_size.min_value = 12
	_font_size.max_value = 72
	_font_size.value = 26
	_font_size.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_font_size.value_changed.connect(func(v: float) -> void:
		TwSettings.font_size = int(v)
		TwSettings.notify()
	)
	size_row.add_child(_font_size)

	_spacing = OptionButton.new()
	_spacing.add_item("Single spaced"); _spacing.set_item_metadata(0, "single")
	_spacing.add_item("Double spaced"); _spacing.set_item_metadata(1, "double")
	_spacing.item_selected.connect(func(i: int) -> void:
		TwSettings.line_spacing = str(_spacing.get_item_metadata(i))
		TwSettings.notify()
	)
	root.add_child(_spacing)

	root.add_child(_section("Font color — presets + full picker"))
	_preset_row = HBoxContainer.new()
	_preset_row.add_theme_constant_override("separation", 8)
	root.add_child(_preset_row)
	for name in TwSettings.FONT_PRESETS.keys():
		var b := Button.new()
		b.text = str(name).capitalize()
		var col: Color = TwSettings.FONT_PRESETS[name]
		b.add_theme_color_override("font_color", col if col.v > 0.4 else Color(0.9, 0.9, 0.9))
		b.pressed.connect(func() -> void:
			TwSettings.font_color = col
			_font_picker.color = col
			TwSettings.notify()
		)
		_preset_row.add_child(b)
	_font_picker = ColorPickerButton.new()
	_font_picker.custom_minimum_size = Vector2(0, 40)
	_font_picker.edit_alpha = false
	_font_picker.color_changed.connect(func(c: Color) -> void:
		TwSettings.font_color = c
		TwSettings.notify()
	)
	root.add_child(_font_picker)

	root.add_child(_section("Proofreading"))
	var spell := CheckButton.new()
	spell.text = "Spell check (offer corrections while typing)"
	spell.button_pressed = TwSettings.spell_check_enabled
	spell.toggled.connect(func(on: bool) -> void:
		TwSettings.spell_check_enabled = on
		TwSettings.notify()
	)
	root.add_child(spell)
	var lit := CheckButton.new()
	lit.text = "Comma / literature corrections (spacing, capitals, polish)"
	lit.button_pressed = TwSettings.literary_check_enabled
	lit.toggled.connect(func(on: bool) -> void:
		TwSettings.literary_check_enabled = on
		TwSettings.notify()
	)
	root.add_child(lit)
	var offer := CheckButton.new()
	offer.text = "Ask before correcting (Correct / Skip / Fix all)"
	offer.button_pressed = TwSettings.offer_corrections
	offer.toggled.connect(func(on: bool) -> void:
		TwSettings.offer_corrections = on
		TwSettings.notify()
	)
	root.add_child(offer)
	var auto_lit := CheckButton.new()
	auto_lit.text = "Auto-apply literature polish (no prompt)"
	auto_lit.button_pressed = TwSettings.auto_fix_literary
	auto_lit.toggled.connect(func(on: bool) -> void:
		TwSettings.auto_fix_literary = on
		TwSettings.notify()
	)
	root.add_child(auto_lit)
	var auto_paper := CheckButton.new()
	auto_paper.text = "Slide whole sheet while typing (off = real typewriter)"
	auto_paper.button_pressed = false
	TwSettings.auto_paper_move = false
	auto_paper.toggled.connect(func(on: bool) -> void:
		TwSettings.auto_paper_move = on
		TwSettings.notify()
	)
	root.add_child(auto_paper)

	root.add_child(_section("Paper physics — gravity + breath wind"))
	root.add_child(_hint("Sheet clipped at bottom (platen). Mic measures breath → Q → vp → dynamic pressure → cantilever bend. Hold BLOW if mic is unavailable."))
	var phys := CheckButton.new()
	phys.text = "Paper aero physics (cantilever + flutter)"
	phys.button_pressed = TwSettings.paper_physics
	phys.toggled.connect(func(on: bool) -> void:
		TwSettings.paper_physics = on
		TwSettings.notify()
	)
	root.add_child(phys)
	var grav := CheckButton.new()
	grav.text = "Gravity sag on paper"
	grav.button_pressed = TwSettings.paper_gravity
	grav.toggled.connect(func(on: bool) -> void:
		TwSettings.paper_gravity = on
		TwSettings.notify()
	)
	root.add_child(grav)
	var mic := CheckButton.new()
	mic.text = "Microphone breath sensing"
	mic.button_pressed = TwSettings.mic_breath
	mic.toggled.connect(func(on: bool) -> void:
		TwSettings.mic_breath = on
		TwSettings.notify()
	)
	root.add_child(mic)
	var sens_row := HBoxContainer.new()
	root.add_child(sens_row)
	var sens_l := Label.new()
	sens_l.text = "Mic sensitivity"
	sens_row.add_child(sens_l)
	var sens := HSlider.new()
	sens.min_value = 0.5
	sens.max_value = 6.0
	sens.step = 0.1
	sens.value = TwSettings.mic_sensitivity
	sens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens.value_changed.connect(func(v: float) -> void:
		TwSettings.mic_sensitivity = v
		TwSettings.notify()
	)
	sens_row.add_child(sens)
	var clamp_row := HBoxContainer.new()
	root.add_child(clamp_row)
	var clamp_l := Label.new()
	clamp_l.text = "Platen clamp stiffness"
	clamp_row.add_child(clamp_l)
	var clamp_s := HSlider.new()
	clamp_s.min_value = 0.4
	clamp_s.max_value = 3.0
	clamp_s.step = 0.05
	clamp_s.value = TwSettings.clamp_stiffness
	clamp_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clamp_s.value_changed.connect(func(v: float) -> void:
		TwSettings.clamp_stiffness = v
		TwSettings.notify()
	)
	clamp_row.add_child(clamp_s)

	root.add_child(_section("Feel"))
	_haptics = CheckButton.new()
	_haptics.text = "Spring vibration on each letter (peak → soft settle)"
	_haptics.toggled.connect(func(on: bool) -> void:
		TwSettings.haptics_enabled = on
		TwSettings.notify()
	)
	root.add_child(_haptics)
	_fx = CheckButton.new()
	_fx.text = "Key / typebar animations"
	_fx.toggled.connect(func(on: bool) -> void:
		TwSettings.key_fx_enabled = on
		TwSettings.notify()
	)
	root.add_child(_fx)
	_sound = CheckButton.new()
	_sound.text = "Clean key click + return + bell (no ambient)"
	_sound.toggled.connect(func(on: bool) -> void:
		TwSettings.sound_enabled = on
		TwSettings.notify()
	)
	root.add_child(_sound)

	var surround := CheckButton.new()
	surround.text = "Extra room reverb (soft)"
	surround.button_pressed = TwSettings.surround_max
	surround.toggled.connect(func(on: bool) -> void:
		TwSettings.surround_max = on
		TwSettings.notify()
	)
	root.add_child(surround)
	var mic_rev := CheckButton.new()
	mic_rev.text = "Mic reverb monitor (hear breath with springy room)"
	mic_rev.button_pressed = false
	TwSettings.mic_reverb_monitor = false
	mic_rev.toggled.connect(func(on: bool) -> void:
		TwSettings.mic_reverb_monitor = on
		TwSettings.notify()
	)
	root.add_child(mic_rev)
	var rev_row := HBoxContainer.new()
	root.add_child(rev_row)
	var rev_l := Label.new()
	rev_l.text = "Reverb"
	rev_row.add_child(rev_l)
	var rev := HSlider.new()
	rev.min_value = 0.0
	rev.max_value = 1.0
	rev.step = 0.01
	rev.value = TwSettings.reverb_amount
	rev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rev.value_changed.connect(func(v: float) -> void:
		TwSettings.reverb_amount = v
		TwSettings.notify()
	)
	rev_row.add_child(rev)
	var click_row := HBoxContainer.new()
	root.add_child(click_row)
	var click_l := Label.new()
	click_l.text = "Click / spring feel"
	click_row.add_child(click_l)
	var click_s := HSlider.new()
	click_s.min_value = 0.3
	click_s.max_value = 1.5
	click_s.step = 0.05
	click_s.value = TwSettings.click_feel
	click_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	click_s.value_changed.connect(func(v: float) -> void:
		TwSettings.click_feel = v
		TwSettings.notify()
	)
	click_row.add_child(click_s)

	var save := Button.new()
	save.text = "Save settings"
	save.pressed.connect(func() -> void:
		TwSettings.save_settings()
		_status.text = "Saved."
	)
	root.add_child(save)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.65))
	_status.text = "Changes apply live to the Typewriter tab."
	root.add_child(_status)


func _load_into_form() -> void:
	_hq.button_pressed = TwSettings.hq_assets
	for i in _paper_option.item_count:
		if str(_paper_option.get_item_metadata(i)) == TwSettings.paper_type:
			_paper_option.select(i)
			break
	_custom_paper.button_pressed = TwSettings.use_custom_paper_color
	_paper_picker.color = TwSettings.paper_color
	_font_picker.color = TwSettings.font_color
	_font_size.value = TwSettings.font_size
	for i in _font_style.item_count:
		if str(_font_style.get_item_metadata(i)) == TwSettings.font_style:
			_font_style.select(i)
			break
	for i in _spacing.item_count:
		if str(_spacing.get_item_metadata(i)) == TwSettings.line_spacing:
			_spacing.select(i)
			break
	_haptics.button_pressed = TwSettings.haptics_enabled
	_fx.button_pressed = TwSettings.key_fx_enabled
	_sound.button_pressed = TwSettings.sound_enabled


func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 22)
	return l


func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.82, 0.72, 0.42))
	return l


func _hint(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	return l
