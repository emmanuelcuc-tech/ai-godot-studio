extends Control
## Live spectrum bars from AudioEffectSpectrumAnalyzer on a bus.

var bus_name: String = "Master"
const VU_COUNT := 32

func set_bus(name: String) -> void:
	bus_name = name


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.07, 0.08, 0.1))
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var mag: PackedFloat32Array = PackedFloat32Array()
	mag.resize(VU_COUNT)
	var effect: AudioEffectSpectrumAnalyzerInstance = null
	for i in AudioServer.get_bus_effect_count(idx):
		var inst = AudioServer.get_bus_effect_instance(idx, i)
		if inst is AudioEffectSpectrumAnalyzerInstance:
			effect = inst
			break
	var w := size.x / float(VU_COUNT)
	for i in VU_COUNT:
		var h := 2.0
		if effect:
			var f_from := 40.0 * pow(2.0, float(i) * 0.25)
			var f_to := 40.0 * pow(2.0, float(i + 1) * 0.25)
			var m: float = effect.get_magnitude_for_frequency_range(f_from, f_to).length()
			h = clampf(m * 12.0, 0.0, 1.0) * size.y
		var x := i * w
		draw_rect(Rect2(x + 1, size.y - h, w - 2, h), Color(0.35, 0.95, 0.65, 0.9))
