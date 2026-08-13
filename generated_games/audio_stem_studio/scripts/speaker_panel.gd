extends VBoxContainer
class_name SpeakerPanel
## Per-speaker meters + Gain(dB)/Volume/Pan/Amount controls. Updates with surround layout.

signal speakers_changed

const SPEAKER_LABELS := {
	"FL": "Front Left",
	"FR": "Front Right",
	"FC": "Center",
	"LFE": "LFE / Sub",
	"SL": "Surround Left",
	"SR": "Surround Right",
	"BL": "Back Left",
	"BR": "Back Right",
}

var layout: String = "stereo"
var speakers: Dictionary = {} # id -> {gain_db, volume, amount, pan, meter_db}
var master_gain_db: float = 0.0
var fill_amount: float = 100.0

var _rows: Dictionary = {} # id -> controls dict
var _meter_values: Dictionary = {}

@onready var rows_host: VBoxContainer = $Rows if has_node("Rows") else null


func _ready() -> void:
	if rows_host == null:
		rows_host = VBoxContainer.new()
		rows_host.name = "Rows"
		add_child(rows_host)
	set_layout("stereo")


func set_layout(new_layout: String) -> void:
	layout = new_layout
	var keys := _keys_for(layout)
	var old := speakers.duplicate(true)
	speakers.clear()
	for k in keys:
		if old.has(k):
			speakers[k] = old[k]
		else:
			speakers[k] = {"gain_db": 0.0, "volume": 100.0, "amount": 100.0, "pan": 0.0}
	_rebuild_rows()


func apply_preset_speakers(data: Dictionary) -> void:
	speakers = data.duplicate(true)
	_rebuild_rows()


func get_gains_payload() -> Dictionary:
	var out := speakers.duplicate(true)
	out["master_gain_db"] = master_gain_db
	out["fill_amount"] = fill_amount
	return out


func set_meter(speaker_id: String, db_fs: float) -> void:
	_meter_values[speaker_id] = db_fs
	if _rows.has(speaker_id):
		var meter: ProgressBar = _rows[speaker_id]["meter"]
		var lab: Label = _rows[speaker_id]["meter_label"]
		# map -60..0 dBFS to 0..100
		var pct := clampf((db_fs + 60.0) / 60.0 * 100.0, 0.0, 100.0)
		meter.value = pct
		lab.text = "%.1f dBFS" % db_fs


func simulate_meters_from_mix(playing: bool) -> void:
	## Lightweight visual energy until true multi-channel analysis is available.
	for k in speakers.keys():
		var g: float = float(speakers[k].get("gain_db", 0.0))
		var vol: float = float(speakers[k].get("volume", 100.0)) / 100.0
		var amt: float = float(speakers[k].get("amount", 100.0)) / 100.0 * (fill_amount / 100.0)
		var base := -45.0
		if playing:
			base = -18.0 + sin(Time.get_ticks_msec() * 0.01 + hash(k) % 7) * 6.0
		var db := base + g + linear_to_db(maxf(0.0001, vol * amt)) + master_gain_db
		set_meter(k, clampf(db, -60.0, 6.0))


func _keys_for(lay: String) -> Array:
	match lay:
		"7.1":
			return ["FL", "FR", "FC", "LFE", "BL", "BR", "SL", "SR"]
		"5.1":
			return ["FL", "FR", "FC", "LFE", "SL", "SR"]
		"2.1":
			return ["FL", "FR", "LFE"]
		_:
			return ["FL", "FR"]


func _rebuild_rows() -> void:
	for c in rows_host.get_children():
		c.free()
	_rows.clear()
	for k in _keys_for(layout):
		_rows[k] = _make_row(k, speakers[k])


func _make_row(id: String, data: Dictionary) -> Dictionary:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	rows_host.add_child(panel)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var name_l := Label.new()
	name_l.text = "%s — %s" % [id, SPEAKER_LABELS.get(id, id)]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	var meter_label := Label.new()
	meter_label.custom_minimum_size.x = 90
	meter_label.text = "-60.0 dBFS"
	head.add_child(meter_label)

	var meter := ProgressBar.new()
	meter.min_value = 0
	meter.max_value = 100
	meter.show_percentage = false
	meter.custom_minimum_size.y = 14
	vb.add_child(meter)

	var grid := GridContainer.new()
	grid.columns = 4
	vb.add_child(grid)

	var gain_spin := _spin(-60, 12, float(data.get("gain_db", 0.0)))
	var vol_sl := _slider(0, 200, float(data.get("volume", 100.0)), 1.0)
	var pan_sl := _slider(-1, 1, float(data.get("pan", 0.0)), 0.01)
	var amount_sl := _slider(0, 200, float(data.get("amount", 100.0)), 1.0)
	var vol_lab := Label.new()
	vol_lab.text = "Vol %d%%" % int(data.get("volume", 100.0))
	var pan_lab := Label.new()
	pan_lab.text = "Pan %.2f" % float(data.get("pan", 0.0))
	var amount_lab := Label.new()
	amount_lab.text = "Amt %d%%" % int(data.get("amount", 100.0))

	_add_labeled(grid, "Gain (dB)", gain_spin)
	_add_labeled(grid, "Volume", vol_sl)
	_add_labeled(grid, "Pan", pan_sl)
	_add_labeled(grid, "Amount", amount_sl)
	grid.add_child(vol_lab)
	grid.add_child(pan_lab)
	grid.add_child(amount_lab)
	grid.add_child(Control.new())

	gain_spin.value_changed.connect(func(v):
		speakers[id]["gain_db"] = v
		speakers_changed.emit()
	)
	vol_sl.value_changed.connect(func(v):
		speakers[id]["volume"] = v
		vol_lab.text = "Vol %d%%" % int(v)
		speakers_changed.emit()
	)
	pan_sl.value_changed.connect(func(v):
		speakers[id]["pan"] = v
		pan_lab.text = "Pan %.2f" % v
		speakers_changed.emit()
	)
	amount_sl.value_changed.connect(func(v):
		speakers[id]["amount"] = v
		amount_lab.text = "Amt %d%%" % int(v)
		speakers_changed.emit()
	)

	return {
		"meter": meter,
		"meter_label": meter_label,
		"gain": gain_spin,
		"volume": vol_sl,
		"pan": pan_sl,
		"amount": amount_sl,
	}


func _spin(mn: float, mx: float, val: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.1
	s.value = val
	s.suffix = " dB"
	s.custom_minimum_size.x = 110
	return s


func _slider(mn: float, mx: float, val: float, step: float = 1.0) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = mn
	sl.max_value = mx
	sl.step = step
	sl.value = val
	sl.custom_minimum_size.x = 120
	return sl


func _add_labeled(grid: GridContainer, title: String, control: Control) -> void:
	var l := Label.new()
	l.text = title
	grid.add_child(l)
	grid.add_child(control)
