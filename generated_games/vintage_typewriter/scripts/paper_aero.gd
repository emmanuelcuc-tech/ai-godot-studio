extends Node
## Platen-clamped A4 strip: light breath bend + point-load grab.
## Does NOT resize or freely translate the sheet — only tip angle / local tug.

signal state_changed(tip_m: float, angle_rad: float, force_n: float, vp: float)

const RHO := 1.225
const E := 3.0e9
const NU := 0.3
const THICKNESS := 1.0e-4
const WIDTH_B := 0.210
const AREAL := 0.08
const G := 9.81

enum BlowMode { UNDER, OVER, PARALLEL }

@export var exposed_length: float = 0.14
@export var clamp_stiff_mul: float = 1.0
@export var damping_ratio: float = 0.2
@export var max_tip_m: float = 0.035 ## keep visual bend subtle
@export var pixels_per_meter: float = 900.0
@export var gravity_enabled: bool = true
@export var physics_enabled: bool = true
@export var blow_angle_deg: float = 90.0
@export var blow_mode: int = BlowMode.UNDER

var tip: float = 0.0
var tip_vel: float = 0.0
var angle: float = 0.0
var force_n: float = 0.0
var vp: float = 0.0
var v_top: float = 0.0
var v_bottom: float = 0.0
var delta_p: float = 0.0
var q_dyn: float = 0.0
var keff: float = 0.2
var meff: float = 0.001
var ei: float = 1.0
var plate_d: float = 0.0
var f_nat: float = 14.0
var grab: RefCounted


func _ready() -> void:
	grab = load("res://scripts/paper_grab.gd").new()
	_recompute_stiffness()


func set_exposed_length(l_m: float) -> void:
	exposed_length = clampf(l_m, 0.08, 0.22)
	_recompute_stiffness()


func set_blow_mode(mode: int) -> void:
	blow_mode = clampi(mode, 0, 2)


func begin_grab(xi: float, eta: float) -> void:
	if grab == null:
		grab = load("res://scripts/paper_grab.gd").new()
	grab.begin_at(xi, eta)


func end_grab() -> void:
	if grab == null:
		return
	if grab.active:
		tip_vel += float(grab.release_impulse()) * 0.35
	grab.end()


func apply_grab_drag(rel_px: Vector2, pull_armed: bool = false) -> float:
	## Manual feed amount (px) after grab efficiency — caller rolls platen.
	if grab == null:
		return rel_px.y
	grab.apply_drag_pixels(rel_px, pixels_per_meter, pull_armed)
	return float(grab.feed_roll_pixels(rel_px.y))


func _recompute_stiffness() -> void:
	plate_d = E * pow(THICKNESS, 3.0) / (12.0 * (1.0 - NU * NU))
	ei = plate_d * WIDTH_B
	var L := exposed_length
	keff = 8.0 * ei / pow(L, 3.0) * clamp_stiff_mul
	meff = AREAL * WIDTH_B * L * 0.33
	f_nat = (1.0 / TAU) * sqrt(keff / maxf(meff, 1e-9))


func step(delta: float, breath_vp: float, breath_level: float) -> void:
	if grab == null:
		grab = load("res://scripts/paper_grab.gd").new()
	if not physics_enabled:
		tip = move_toward(tip, 0.0, delta * 0.08)
		tip_vel = 0.0
		angle = move_toward(angle, 0.0, delta * 2.0)
		force_n = 0.0
		vp = breath_vp
		state_changed.emit(tip, angle, force_n, vp)
		return

	vp = clampf(breath_vp, 0.0, 10.0)
	if breath_level > 0.05 and vp < 0.4:
		vp = lerpf(0.0, 6.0, breath_level)

	match blow_mode:
		BlowMode.UNDER:
			v_bottom = vp
			v_top = 0.0
		BlowMode.OVER:
			v_top = vp
			v_bottom = 0.0
		_:
			v_top = vp * 0.5
			v_bottom = vp * 0.45

	delta_p = 0.5 * RHO * (v_top * v_top - v_bottom * v_bottom)
	q_dyn = 0.5 * RHO * vp * vp
	var theta := deg_to_rad(clampf(blow_angle_deg, 15.0, 90.0))
	var incidence := sin(theta) * sin(theta)
	var Ap := WIDTH_B * exposed_length
	var Fair := -delta_p * Ap * incidence * 0.45 ## scaled down for subtlety
	if blow_mode == BlowMode.OVER:
		Fair = absf(Fair)
	elif blow_mode == BlowMode.UNDER:
		Fair = -absf(Fair)
	elif blow_mode == BlowMode.PARALLEL:
		Fair *= 0.1

	var Fgrav := 0.0
	if gravity_enabled:
		Fgrav = meff * G * 0.06 * signf(tip + 0.001)

	grab.step_local(delta, keff)
	var Fgrab: float = float(grab.equivalent_tip_force()) * 0.5
	force_n = Fair + Fgrav + Fgrab

	var k := keff
	if absf(tip) > 0.01:
		k *= 1.0 + 8.0 * pow(absf(tip) / max_tip_m, 2.0)
	var zeta := 0.35 if grab.active else damping_ratio
	var c := 2.0 * zeta * sqrt(maxi(k * meff, 1e-9))
	var acc := (force_n - c * tip_vel - k * tip) / maxf(meff, 1e-6)
	tip_vel += acc * delta
	tip += tip_vel * delta
	if absf(tip) > max_tip_m:
		tip = signf(tip) * max_tip_m
		tip_vel *= -0.2
	angle = clampf(tip / maxf(exposed_length, 0.01) * 0.55 + float(grab.twist_rad) * 0.25, -0.35, 0.35)
	f_nat = (1.0 / TAU) * sqrt(k / maxf(meff, 1e-9))
	state_changed.emit(tip, angle, force_n, vp)


func tip_pixels() -> float:
	return tip * pixels_per_meter


func mode_name() -> String:
	match blow_mode:
		BlowMode.OVER:
			return "over"
		BlowMode.PARALLEL:
			return "parallel"
		_:
			return "under"


func debug_text() -> String:
	var g := ""
	if grab and grab.active:
		g = "  grab ξ=%.2f" % float(grab.xi)
	return "vp=%.1f  δ=%.1fmm  F=%.3fN%s" % [vp, tip * 1000.0, force_n, g]


func shape_xi(xi: float) -> float:
	var x := clampf(xi, 0.0, 1.0)
	return (x * x * (6.0 - 4.0 * x + x * x)) / 3.0


func deflection_polyline(n: int, rect_size: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if n < 2:
		return pts
	var Lpx := maxf(rect_size.y * 0.75, 40.0)
	var origin := Vector2(rect_size.x * 0.28, rect_size.y - 20.0)
	var tip_lat := tip_pixels() * 0.4
	for i in n:
		var xi := float(i) / float(n - 1)
		pts.append(origin + Vector2(tip_lat * shape_xi(xi), -xi * Lpx))
	return pts


func curve_extrema(n: int, rect_size: Vector2) -> Dictionary:
	var pts := deflection_polyline(n, rect_size)
	if pts.is_empty():
		return {}
	var grab_pt := Vector2.ZERO
	var grab_on := grab != null and bool(grab.active)
	if grab_on:
		var gi := int(clampf(float(grab.xi), 0.0, 1.0) * float(pts.size() - 1))
		grab_pt = pts[gi] + Vector2(float(grab.eta) * 24.0, 0.0)
	return {
		"strongest": pts[0],
		"weakest": pts[pts.size() - 1],
		"fastest": pts[pts.size() - 1],
		"softest": pts[mini(2, pts.size() - 1)],
		"grab": grab_pt,
		"grab_active": grab_on,
	}
