extends RefCounted
class_name TwSettings

const PATH := "user://tw_settings.cfg"

var ink_color: Color = Color("1a1a1a")
var font_color: Color = Color("1a1a1a")
var font_size: int = 20
var font_style: int = 0
var typing_speed: int = 10
## "freesound_typewriter" (default) or a TypingSimulator pack folder name
var sound_pack: String = "freesound_typewriter"


func load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	ink_color = cfg.get_value("look", "ink_color", ink_color)
	font_color = cfg.get_value("look", "font_color", font_color)
	font_size = int(cfg.get_value("look", "font_size", font_size))
	font_style = int(cfg.get_value("look", "font_style", font_style))
	typing_speed = int(cfg.get_value("type", "speed", typing_speed))
	sound_pack = str(cfg.get_value("audio", "pack", sound_pack))


func save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("look", "ink_color", ink_color)
	cfg.set_value("look", "font_color", font_color)
	cfg.set_value("look", "font_size", font_size)
	cfg.set_value("look", "font_style", font_style)
	cfg.set_value("type", "speed", typing_speed)
	cfg.set_value("audio", "pack", sound_pack)
	cfg.save(PATH)
