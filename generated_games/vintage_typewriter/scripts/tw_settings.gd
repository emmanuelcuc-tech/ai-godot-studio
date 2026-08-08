extends Node
## Shared typewriter settings (paper, fonts, HQ, haptics). Persists to user://.

signal changed

const SAVE_PATH := "user://typewriter_settings.cfg"

var hq_assets: bool = true
## dropin = bake from assets/images when present · procedural = cream/chrome
var key_sprite_style: String = "procedural"
var paper_type: String = "beige"
var paper_color: Color = Color(0.93, 0.86, 0.70)
var use_custom_paper_color: bool = false
var font_color: Color = Color(0.12, 0.1, 0.08)
var font_size: int = 26
var font_style: String = "regular" # regular | bold | italic
var line_spacing: String = "single" # single | double
var haptics_enabled: bool = true
var key_fx_enabled: bool = true
var sound_enabled: bool = true
## Prefer res://assets/audio/{key,erase,return,bell,feed}.ogg when present; else silent
var use_asset_sounds: bool = true
var erase_sound_enabled: bool = true
## Master key SFX level 0..1 (separate from click_feel spring bias)
var sound_volume: float = 0.85
## Ambient room bed removed — kept for save-file compat (no-op in SFX)
var ambient_room: bool = false
var ambient_volume: float = 0.12
var click_feel: float = 0.85
var auto_paper_move: bool = false ## typing must NOT slide the sheet; text scrolls in place
var paper_physics: bool = true
var paper_gravity: bool = true
var mic_breath: bool = true
var mic_sensitivity: float = 2.8
var clamp_stiffness: float = 1.0
var surround_max: bool = false
var reverb_amount: float = 0.18
var mic_reverb_monitor: bool = false
var spell_check_enabled: bool = true
var literary_check_enabled: bool = true
var offer_corrections: bool = true # show Correct / Skip instead of silent auto
var auto_fix_literary: bool = false
var margin_left: int = 4
var margin_right: int = 60
var chars_per_line: int = 64

const FONT_PRESETS := {
	"black": Color(0.08, 0.08, 0.09),
	"white": Color(0.96, 0.96, 0.94),
	"yellow": Color(0.92, 0.78, 0.12),
	"red": Color(0.78, 0.12, 0.12),
	"blue": Color(0.12, 0.28, 0.78),
}


func _ready() -> void:
	load_settings()


func effective_paper_color() -> Color:
	if use_custom_paper_color:
		return paper_color
	## Textured paper types carry their look in the image — keep modulate white.
	if HQAssets.is_textured_paper(paper_type):
		return Color.WHITE
	var presets: Dictionary = HQAssets.PAPER_PRESETS
	return presets.get(paper_type, Color(0.93, 0.86, 0.70))


func line_height_mul() -> float:
	return 2.0 if line_spacing == "double" else 1.0


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	hq_assets = bool(cfg.get_value("gfx", "hq", hq_assets))
	key_sprite_style = str(cfg.get_value("gfx", "key_style", key_sprite_style))
	## Migrate old Underwood/ref style → drop-in images folder
	if key_sprite_style == "underwood":
		key_sprite_style = "dropin"
	if key_sprite_style not in ["dropin", "procedural"]:
		key_sprite_style = "procedural"
	paper_type = str(cfg.get_value("paper", "type", paper_type))
	use_custom_paper_color = bool(cfg.get_value("paper", "custom", use_custom_paper_color))
	paper_color = cfg.get_value("paper", "color", paper_color)
	font_color = cfg.get_value("font", "color", font_color)
	font_size = int(cfg.get_value("font", "size", font_size))
	font_style = str(cfg.get_value("font", "style", font_style))
	line_spacing = str(cfg.get_value("font", "spacing", line_spacing))
	haptics_enabled = bool(cfg.get_value("feel", "haptics", haptics_enabled))
	key_fx_enabled = bool(cfg.get_value("feel", "key_fx", key_fx_enabled))
	sound_enabled = bool(cfg.get_value("feel", "sound", sound_enabled))
	use_asset_sounds = bool(cfg.get_value("feel", "asset_sfx", use_asset_sounds))
	erase_sound_enabled = bool(cfg.get_value("feel", "erase_sfx", erase_sound_enabled))
	sound_volume = float(cfg.get_value("feel", "volume", sound_volume))
	ambient_room = bool(cfg.get_value("feel", "ambient", ambient_room))
	ambient_volume = float(cfg.get_value("feel", "ambient_vol", ambient_volume))
	surround_max = bool(cfg.get_value("feel", "surround_max", surround_max))
	reverb_amount = float(cfg.get_value("feel", "reverb", reverb_amount))
	mic_reverb_monitor = bool(cfg.get_value("feel", "mic_reverb", mic_reverb_monitor))
	click_feel = float(cfg.get_value("feel", "click_feel", click_feel))
	auto_paper_move = bool(cfg.get_value("feel", "auto_paper", auto_paper_move))
	paper_physics = bool(cfg.get_value("aero", "physics", paper_physics))
	paper_gravity = bool(cfg.get_value("aero", "gravity", paper_gravity))
	mic_breath = bool(cfg.get_value("aero", "mic", mic_breath))
	mic_sensitivity = float(cfg.get_value("aero", "mic_sens", mic_sensitivity))
	clamp_stiffness = float(cfg.get_value("aero", "clamp", clamp_stiffness))
	spell_check_enabled = bool(cfg.get_value("proof", "spell", spell_check_enabled))
	literary_check_enabled = bool(cfg.get_value("proof", "literary", literary_check_enabled))
	offer_corrections = bool(cfg.get_value("proof", "offer", offer_corrections))
	auto_fix_literary = bool(cfg.get_value("proof", "auto_literary", auto_fix_literary))
	margin_left = int(cfg.get_value("machine", "margin_left", margin_left))
	margin_right = int(cfg.get_value("machine", "margin_right", margin_right))
	## Hard reset of broken feel defaults (old saves forced wild paper scroll / loud beds)
	auto_paper_move = false
	surround_max = false
	mic_reverb_monitor = false
	## Ambient stays off — room bed removed in fresh-start reset
	ambient_room = false
	reverb_amount = mini(reverb_amount, 0.25)
	sound_volume = clampf(sound_volume, 0.0, 1.0)
	ambient_volume = clampf(ambient_volume, 0.0, 0.4)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gfx", "hq", hq_assets)
	cfg.set_value("gfx", "key_style", key_sprite_style)
	cfg.set_value("paper", "type", paper_type)
	cfg.set_value("paper", "custom", use_custom_paper_color)
	cfg.set_value("paper", "color", paper_color)
	cfg.set_value("font", "color", font_color)
	cfg.set_value("font", "size", font_size)
	cfg.set_value("font", "style", font_style)
	cfg.set_value("font", "spacing", line_spacing)
	cfg.set_value("feel", "haptics", haptics_enabled)
	cfg.set_value("feel", "key_fx", key_fx_enabled)
	cfg.set_value("feel", "sound", sound_enabled)
	cfg.set_value("feel", "asset_sfx", use_asset_sounds)
	cfg.set_value("feel", "erase_sfx", erase_sound_enabled)
	cfg.set_value("feel", "volume", sound_volume)
	cfg.set_value("feel", "ambient", ambient_room)
	cfg.set_value("feel", "ambient_vol", ambient_volume)
	cfg.set_value("feel", "surround_max", surround_max)
	cfg.set_value("feel", "reverb", reverb_amount)
	cfg.set_value("feel", "mic_reverb", mic_reverb_monitor)
	cfg.set_value("feel", "click_feel", click_feel)
	cfg.set_value("feel", "auto_paper", auto_paper_move)
	cfg.set_value("aero", "physics", paper_physics)
	cfg.set_value("aero", "gravity", paper_gravity)
	cfg.set_value("aero", "mic", mic_breath)
	cfg.set_value("aero", "mic_sens", mic_sensitivity)
	cfg.set_value("aero", "clamp", clamp_stiffness)
	cfg.set_value("proof", "spell", spell_check_enabled)
	cfg.set_value("proof", "literary", literary_check_enabled)
	cfg.set_value("proof", "offer", offer_corrections)
	cfg.set_value("proof", "auto_literary", auto_fix_literary)
	cfg.set_value("machine", "margin_left", margin_left)
	cfg.set_value("machine", "margin_right", margin_right)
	cfg.save(SAVE_PATH)
	changed.emit()


func notify() -> void:
	save_settings()
