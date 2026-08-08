extends Control
class_name TypebarBasket
## Fan of typebars; snappy swing-to-strike then return (Royal QD basket feel).

const BAR_COUNT := 28
const REST_DEG := 78.0
const STRIKE_DEG := 8.0

var _bars: Array[ColorRect] = []
var _pivots: Array[Control] = []
var _active_tween: Tween
var _hammer: ColorRect
var _ribbon_guide: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_bars.clear()
	_pivots.clear()

	var w := maxf(size.x, 520.0)
	var h := maxf(size.y, 120.0)
	var origin := Vector2(w * 0.5, h * 0.92)

	for i in BAR_COUNT:
		var pivot := Control.new()
		pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot.position = origin
		add_child(pivot)
		var bar := ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.size = Vector2(5, 95 + (i % 3) * 4)
		bar.position = Vector2(-2.5, -bar.size.y)
		var shade := 0.22 + float(i % 5) * 0.03
		bar.color = Color(shade, shade + 0.02, shade + 0.04, 0.92)
		pivot.add_child(bar)
		var spread := lerpf(-52.0, 52.0, float(i) / float(BAR_COUNT - 1))
		pivot.rotation_degrees = spread
		# Store rest as meta; visual "folded" look uses child offset via rotation around fan
		pivot.set_meta("fan", spread)
		pivot.set_meta("rest_extra", REST_DEG * 0.15 * signf(spread + 0.001))
		_pivots.append(pivot)
		_bars.append(bar)

	_ribbon_guide = ColorRect.new()
	_ribbon_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon_guide.size = Vector2(48, 10)
	_ribbon_guide.position = Vector2(w * 0.5 - 24.0, 8.0)
	_ribbon_guide.color = Color(0.05, 0.05, 0.05)
	add_child(_ribbon_guide)
	var red := ColorRect.new()
	red.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red.size = Vector2(48, 5)
	red.position = Vector2(0, 5)
	red.color = Color(0.72, 0.12, 0.12)
	_ribbon_guide.add_child(red)

	_hammer = ColorRect.new()
	_hammer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hammer.size = Vector2(14, 20)
	_hammer.color = Color(0.15, 0.15, 0.16, 0.0)
	_hammer.z_index = 4
	add_child(_hammer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _pivots.size() > 0:
		_relayout()


func _relayout() -> void:
	var w := maxf(size.x, 100.0)
	var h := maxf(size.y, 80.0)
	var origin := Vector2(w * 0.5, h * 0.92)
	for i in _pivots.size():
		_pivots[i].position = origin
	if _ribbon_guide:
		_ribbon_guide.position = Vector2(w * 0.5 - 24.0, 8.0)


## Swing a bar toward strike; `slot` picks which typebar (0..BAR_COUNT-1).
## Returns strike impact delay (seconds) for ink/SFX sync.
func strike(slot: int, intensity: float = 1.0) -> float:
	if _pivots.is_empty():
		_build()
	slot = clampi(slot, 0, _pivots.size() - 1)
	var pivot := _pivots[slot]
	var fan: float = pivot.get_meta("fan")
	var rest := fan
	var hit := fan * 0.12  # swing toward center / paper
	# Stronger bars near center swing more vertical
	hit = lerpf(hit, 0.0, 0.55) - STRIKE_DEG * signf(fan + 0.01) * 0.15

	if _active_tween and _active_tween.is_valid():
		# Don't kill other bars mid-return; only reset this one
		pass

	var up := 0.048
	var hold := 0.02
	var down := 0.085
	var tw := create_tween()
	tw.set_parallel(false)
	pivot.rotation_degrees = rest
	tw.tween_property(pivot, "rotation_degrees", hit, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var bar := _bars[slot]
	tw.parallel().tween_property(bar, "color", Color(0.55, 0.56, 0.58, 1.0), up)
	tw.tween_interval(hold)
	tw.tween_property(pivot, "rotation_degrees", rest, down).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bar, "color", Color(0.24, 0.25, 0.27, 0.92), down)

	# Shared hammer flash toward ribbon guide (visual strike tip)
	if _hammer:
		_hammer.position = Vector2(size.x * 0.5 - 7.0 + float(slot - BAR_COUNT / 2) * 1.2, 0.0)
		_hammer.modulate.a = 0.0
		var ht := create_tween()
		ht.tween_property(_hammer, "modulate:a", 0.95 * intensity, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ht.tween_property(_hammer, "modulate:a", 0.0, down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if _ribbon_guide:
		var rt := create_tween()
		rt.tween_property(_ribbon_guide, "position:y", 4.0, up)
		rt.tween_property(_ribbon_guide, "position:y", 8.0, down)

	return up  # impact time
