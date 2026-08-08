extends RefCounted
## Point-load grab on a platen-clamped sheet.
## ξ = 0 at clamp (platen), 1 at free tip · η = −1 left … +1 right.

var active: bool = false
var xi: float = 0.7 ## along length from clamp
var eta: float = 0.0 ## across width
var force_lat: float = 0.0 ## N, + = toward camera / rightward bend sense
var force_feed: float = 0.0 ## N, + = pull paper down (feed)
var local_defl_m: float = 0.0 ## deflection under finger
var local_vel: float = 0.0
var twist_rad: float = 0.0
var feed_slip: float = 0.0 ## 0..1 stretch before platen rolls

const GRAB_MASS := 0.0004
const MAX_LOCAL_M := 0.045


func begin_at(xi_in: float, eta_in: float) -> void:
	active = true
	xi = clampf(xi_in, 0.02, 1.0)
	eta = clampf(eta_in, -1.0, 1.0)
	force_lat = 0.0
	force_feed = 0.0
	feed_slip = 0.0


func end() -> void:
	active = false
	force_lat = 0.0
	force_feed = 0.0
	## Keep local_defl / twist so sheet can spring back via aero integrator


func apply_drag_pixels(rel: Vector2, pixels_per_meter: float, pull_armed: bool) -> void:
	## Convert screen drag into forces at the grab point.
	if not active:
		return
	var ppm := maxf(pixels_per_meter, 1.0)
	var sens := 1.0
	## Down (+y) = feed pull; horizontal = bend / twist
	force_feed = clampf(rel.y / ppm * 12.0 * sens, -1.8, 1.8)
	force_lat = clampf(rel.x / ppm * 8.0 * sens, -1.2, 1.2)


func stiffness_at_grab(keff_tip: float) -> float:
	## Point-load stiffness rises near the clamp (ξ→0).
	## k(ξ) ≈ k_tip / shape(ξ)² so tip is soft, clamp is hard.
	var s := _shape(xi)
	return keff_tip / maxf(s * s, 0.04)


func tip_leverage() -> float:
	## How much a force at ξ projects onto tip DOF (cantilever influence).
	return _shape(xi)


func feed_efficiency() -> float:
	## Grab near clamp turns the platen efficiently; near tip you stretch first.
	var stretch := clampf(feed_slip, 0.0, 1.0)
	var base := lerpf(1.0, 0.28, xi) ## tip grab feeds poorly until taut
	return base * (0.35 + 0.65 * stretch)


func step_local(delta: float, keff_tip: float) -> void:
	if not active and absf(local_defl_m) < 1e-5 and absf(twist_rad) < 1e-4:
		local_defl_m = 0.0
		local_vel = 0.0
		twist_rad = 0.0
		return
	var k := stiffness_at_grab(keff_tip)
	var c := 2.0 * 0.22 * sqrt(maxi(k * GRAB_MASS, 1e-9))
	var f := force_lat if active else 0.0
	## Off-center grab adds twist torque ~ η · F
	var twist_target := eta * (force_lat * 0.08 + local_defl_m * 4.0)
	if not active:
		twist_target = 0.0
	twist_rad = lerpf(twist_rad, clampf(twist_target, -0.35, 0.35), clampf(delta * 14.0, 0.0, 1.0))

	var acc := (f - c * local_vel - k * local_defl_m) / GRAB_MASS
	local_vel += acc * delta
	local_defl_m += local_vel * delta
	if absf(local_defl_m) > MAX_LOCAL_M:
		local_defl_m = signf(local_defl_m) * MAX_LOCAL_M
		local_vel *= -0.2

	## Vertical tug builds slip/stretch before platen yields
	if active and absf(force_feed) > 0.02:
		var yield_n := lerpf(1.4, 0.25, xi) ## clamp yields sooner to roll
		feed_slip = move_toward(feed_slip, clampf(absf(force_feed) / yield_n, 0.0, 1.0), delta * 3.5)
	else:
		feed_slip = move_toward(feed_slip, 0.0, delta * 2.0)


func equivalent_tip_force() -> float:
	## Map grab lateral force (+ local spring reaction) onto tip DOF.
	return (force_lat + local_defl_m * stiffness_at_grab(0.15) * 0.15) * tip_leverage()


func feed_roll_pixels(rel_y: float) -> float:
	## How much of a vertical drag should become platen roll.
	if not active:
		return rel_y
	return rel_y * feed_efficiency()


func release_impulse() -> float:
	## Tip velocity kick when letting go of a stretched grab.
	var kick := local_vel * tip_leverage() + force_lat * 0.08 * tip_leverage()
	return kick


func _shape(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return (t * t * (6.0 - 4.0 * t + t * t)) / 3.0
