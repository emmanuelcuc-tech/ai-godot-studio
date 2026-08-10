extends Control
class_name TypebarBasket
## Striker photo backdrop + one animated typebar that swings to strike on keypress.

const BAR_COUNT := 28

var _striker: TextureRect
var _pivots: Array[Control] = []
var _bars: Array[ColorRect] = []
var _active_tween: Tween
var _flash: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_pivots.clear()
	_bars.clear()

	_striker = TextureRect.new()
	_striker.name = "StrikerPhoto"
	_striker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_striker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_striker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_striker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_striker.modulate = Color(1, 1, 1, 0.98)
	add_child(_striker)
	_load_striker()

	var w := maxf(size.x, 200.0)
	var h := maxf(size.y, 80.0)
	var origin := Vector2(w * 0.5, h * 0.95)

	for i in BAR_COUNT:
		var pivot := Control.new()
		pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot.position = origin
		add_child(pivot)
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(3.5, 70 + (i % 4) * 3)
		bar.position = Vector2(-1.75, -bar.size.y)
		bar.color = Color(0.72, 0.73, 0.75, 0.0)  # invisible until strike
		pivot.add_child(bar)
		var spread := lerpf(-48.0, 48.0, float(i) / float(BAR_COUNT - 1))
		pivot.rotation_degrees = spread
		pivot.set_meta("fan", spread)
		_pivots.append(pivot)
		_bars.append(bar)

	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.size = Vector2(18, 22)
	_flash.color = Color(0.85, 0.86, 0.88, 0.0)
	_flash.z_index = 5
	add_child(_flash)


func _load_striker() -> void:
	var path := "res://assets/images/striker.png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img:
				tex = ImageTexture.create_from_image(img)
	if _striker and tex:
		_striker.texture = tex


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _pivots.size() > 0:
		_relayout()


func _relayout() -> void:
	var w := maxf(size.x, 100.0)
	var h := maxf(size.y, 60.0)
	var origin := Vector2(w * 0.5, h * 0.95)
	for p in _pivots:
		p.position = origin


## Swing a silver typebar up through the guide then return.
func strike(slot: int, intensity: float = 1.0) -> float:
	if _pivots.is_empty():
		_build()
	slot = clampi(slot, 0, _pivots.size() - 1)
	var pivot := _pivots[slot]
	var fan: float = pivot.get_meta("fan")
	var rest := fan
	var hit := lerpf(fan, 0.0, 0.88)

	var up := 0.05
	var hold := 0.018
	var down := 0.09
	var bar := _bars[slot]
	bar.color = Color(0.78, 0.79, 0.82, 0.95 * intensity)
	pivot.rotation_degrees = rest

	if _active_tween and _active_tween.is_valid():
		pass
	var tw := create_tween()
	_active_tween = tw
	tw.set_parallel(false)
	tw.tween_property(pivot, "rotation_degrees", hit, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(hold)
	tw.tween_property(pivot, "rotation_degrees", rest, down).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		bar.color.a = 0.0
	)

	if _flash:
		_flash.position = Vector2(size.x * 0.5 - 9.0, size.y * 0.18)
		_flash.modulate.a = 0.0
		var ht := create_tween()
		ht.tween_property(_flash, "modulate:a", 0.85 * intensity, up)
		ht.tween_property(_flash, "modulate:a", 0.0, down)

	return up
