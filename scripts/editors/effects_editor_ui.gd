extends MarginContainer
## Effects tab — muzzle, bullet trail, enemy death, destroy VFX toggles + intensity.

const ConfigScript = preload("res://scripts/editors/studio_game_config.gd")

var _empty: Label
var _scroll: ScrollContainer
var _root: VBoxContainer
var _muzzle: CheckButton
var _muzzle_i: HSlider
var _trail: CheckButton
var _trail_i: HSlider
var _death: CheckButton
var _death_i: HSlider
var _destroy: CheckButton
var _destroy_i: HSlider
var _status: Label


func _ready() -> void:
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	_build()
	if not AIOrchestrator.session_changed.is_connected(refresh):
		AIOrchestrator.session_changed.connect(refresh)
	refresh()


func refresh() -> void:
	var path: String = AIOrchestrator.get_project_path()
	var active: bool = AIOrchestrator.has_active_session() and not path.is_empty()
	_empty.visible = not active
	_scroll.visible = active
	if not active:
		return
	ConfigScript.ensure_on_disk(path)
	var fx: Dictionary = ConfigScript.load_effects(path)
	_muzzle.button_pressed = bool(fx.get("muzzle_flash", true))
	_muzzle_i.value = float(fx.get("muzzle_intensity", 1.0))
	_trail.button_pressed = bool(fx.get("bullet_trail", true))
	_trail_i.value = float(fx.get("bullet_intensity", 1.0))
	_death.button_pressed = bool(fx.get("enemy_death", true))
	_death_i.value = float(fx.get("enemy_death_intensity", 1.0))
	_destroy.button_pressed = bool(fx.get("destroy_fx", true))
	_destroy_i.value = float(fx.get("destroy_intensity", 1.0))


func _build() -> void:
	_empty = Label.new()
	_empty.text = "No active game yet.\nCreate a game, then toggle gun / bullet / kill / destroy VFX for that project."
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_empty)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 10)
	_scroll.add_child(_root)

	var title: Label = Label.new()
	title.text = "Effects / VFX"
	title.add_theme_font_size_override("font_size", 18)
	_root.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Writes studio_effects.json and scripts/effects_config.gd. StudioRuntime scales GPUParticles (muzzle/impact) on Run Game."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.56, 0.64, 0.72))
	_root.add_child(hint)

	_muzzle = CheckButton.new()
	_muzzle.text = "Gun muzzle flash"
	_muzzle.button_pressed = true
	_root.add_child(_muzzle)
	_muzzle_i = _slider("Muzzle intensity")

	_trail = CheckButton.new()
	_trail.text = "Bullet trail / impact flash"
	_trail.button_pressed = true
	_root.add_child(_trail)
	_trail_i = _slider("Bullet / impact intensity")

	_death = CheckButton.new()
	_death.text = "Enemy kill VFX"
	_death.button_pressed = true
	_root.add_child(_death)
	_death_i = _slider("Enemy death intensity")

	_destroy = CheckButton.new()
	_destroy.text = "Destroy / break VFX"
	_destroy.button_pressed = true
	_root.add_child(_destroy)
	_destroy_i = _slider("Destroy intensity")

	var apply_btn: Button = Button.new()
	apply_btn.text = "Apply effects to game"
	apply_btn.pressed.connect(_on_apply)
	_root.add_child(apply_btn)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.3, 0.86, 0.59))
	_root.add_child(_status)


func _slider(caption: String) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	_root.add_child(row)
	var l: Label = Label.new()
	l.text = caption
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = 0.0
	s.max_value = 2.5
	s.step = 0.05
	s.value = 1.0
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	return s


func _on_apply() -> void:
	var path: String = AIOrchestrator.get_project_path()
	if path.is_empty():
		return
	var data: Dictionary = {
		"muzzle_flash": _muzzle.button_pressed,
		"muzzle_intensity": _muzzle_i.value,
		"bullet_trail": _trail.button_pressed,
		"bullet_intensity": _trail_i.value,
		"enemy_death": _death.button_pressed,
		"enemy_death_intensity": _death_i.value,
		"destroy_fx": _destroy.button_pressed,
		"destroy_intensity": _destroy_i.value,
	}
	ConfigScript.save_effects(path, data)
	ConfigScript.ensure_on_disk(path)
	var notes: String = path.path_join("docs/SHOOTER_FX.md")
	DirAccess.make_dir_recursive_absolute(notes.get_base_dir())
	var body: String = """# Shooter / VFX (studio)

- Muzzle: %s @ %s
- Bullet / impact: %s @ %s
- Enemy death: %s @ %s
- Destroy / break: %s @ %s

`scripts/effects_config.gd` and `studio_effects.json` are the source of truth.
StudioRuntime applies particle amounts when the game runs.
""" % [
		str(data["muzzle_flash"]), str(data["muzzle_intensity"]),
		str(data["bullet_trail"]), str(data["bullet_intensity"]),
		str(data["enemy_death"]), str(data["enemy_death_intensity"]),
		str(data["destroy_fx"]), str(data["destroy_intensity"]),
	]
	var f: FileAccess = FileAccess.open(notes, FileAccess.WRITE)
	if f:
		f.store_string(body)
	_status.text = "Effects saved. Run Game to see particle/flash changes."
