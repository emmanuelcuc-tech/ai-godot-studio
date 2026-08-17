extends RefCounted
class_name SurroundPresets
## Generic surround layout presets + default export codec choices.

## Most compatible full surround: FL/FR/FC/LFE/SL/SR — plays on almost all
## AV receivers / TVs / soundbars and downmixes cleanly to stereo / 2.1.
const DEFAULT_PRESET := "5.1 Surround"

const PRESET_ORDER := [
	"Stereo",
	"Stereo Surround",
	"2.1 Surround",
	"5.1 Surround",
	"7.1 Surround",
	"Matrix Surround",
	"Dolby Pro Logic",
	"Dolby Pro",
	"Cinema Wide 7.1",
	"Headphones",
]

## Default sound-file / export codecs shown in the UI.
const CODEC_ORDER := [
	"WAV (PCM)",
	"MP3 128 kbps",
	"MP3 256 kbps",
	"MP3 512 kbps",
	"MPEG",
	"FLAC",
	"M4A / AAC",
	"OGG Vorbis",
	"AC3 (if ffmpeg)",
]


static func tooltip_for(name: String) -> String:
	return "'%s' sets speaker layout, fill, and mix defaults. Export uses your selected codec." % name


static func apply_alias_note(_name: String) -> String:
	## Legacy hook kept for UI status text; presets are generic names now.
	return ""


static func default_speakers(layout: String) -> Dictionary:
	var keys: Array = []
	match layout:
		"7.1":
			keys = ["FL", "FR", "FC", "LFE", "BL", "BR", "SL", "SR"]
		"5.1":
			keys = ["FL", "FR", "FC", "LFE", "SL", "SR"]
		"2.1":
			keys = ["FL", "FR", "LFE"]
		_:
			keys = ["FL", "FR"]
	var out := {}
	for k in keys:
		out[k] = {
			"gain_db": 0.0,
			"volume": 100.0,
			"amount": 100.0,
			"pan": 0.0,
		}
	return out


static func codec_to_format_bitrate(codec_label: String) -> Dictionary:
	match codec_label:
		"WAV (PCM)":
			return {"format": "wav", "bitrate": 256}
		"MP3 128 kbps":
			return {"format": "mp3", "bitrate": 128}
		"MP3 256 kbps":
			return {"format": "mp3", "bitrate": 256}
		"MP3 512 kbps":
			return {"format": "mp3", "bitrate": 512}
		"MPEG":
			return {"format": "mpeg", "bitrate": 256}
		"FLAC":
			return {"format": "flac", "bitrate": 256}
		"M4A / AAC":
			return {"format": "m4a", "bitrate": 256}
		"OGG Vorbis":
			return {"format": "ogg", "bitrate": 256}
		"AC3 (if ffmpeg)":
			return {"format": "ac3", "bitrate": 448}
		_:
			return {"format": "wav", "bitrate": 256}


static func get_preset(name: String) -> Dictionary:
	var base := {
		"name": name,
		"layout": "stereo",
		"mode": "direct",
		"speakers": default_speakers("stereo"),
		"master_gain_db": 0.0,
		"fill_amount": 100.0,
		"reverb_send": 0.0,
		"latency_ms": 50,
		"note": tooltip_for(name),
	}

	match name:
		"Stereo", "Headphones":
			base.layout = "stereo"
			base.mode = "direct"
			base.speakers = default_speakers("stereo")
			base.fill_amount = 100.0
			base.reverb_send = 0.0 if name == "Stereo" else 4.0
			base.latency_ms = 32

		"Stereo Surround":
			# Widened stereo / Lt-Rt style monitoring (still 2.0 speakers).
			base.layout = "stereo"
			base.mode = "matrix_encode"
			base.speakers = default_speakers("stereo")
			base.fill_amount = 120.0
			base.reverb_send = 6.0
			base.latency_ms = 40
			base.note = "Stereo Surround: widened Lt/Rt-style stereo field for surround-encoded listening."

		"2.1 Surround":
			base.layout = "2.1"
			base.mode = "direct"
			base.speakers = default_speakers("2.1")
			base.speakers["LFE"]["gain_db"] = 2.0
			base.speakers["LFE"]["amount"] = 120.0
			base.fill_amount = 105.0
			base.latency_ms = 48

		"5.1 Surround":
			# Default / most compatible: full 5.1 channel set, neutral gains,
			# mild surround fill — safe for export, downmix, and most hardware.
			base.layout = "5.1"
			base.mode = "direct"
			base.speakers = default_speakers("5.1")
			base.speakers["FC"]["gain_db"] = 0.0
			base.speakers["LFE"]["gain_db"] = 0.0
			base.speakers["SL"]["amount"] = 100.0
			base.speakers["SR"]["amount"] = 100.0
			base.fill_amount = 100.0
			base.latency_ms = 64
			base.note = "5.1 Surround (default): most compatible layout for all common channels — FL/FR/C/LFE/SL/SR."

		"7.1 Surround":
			base.layout = "7.1"
			base.mode = "direct"
			base.speakers = default_speakers("7.1")
			base.fill_amount = 115.0
			base.latency_ms = 80

		"Matrix Surround":
			base.layout = "5.1"
			base.mode = "matrix_expand"
			base.speakers = default_speakers("5.1")
			base.speakers["FC"]["gain_db"] = -1.5
			base.speakers["SL"]["amount"] = 125.0
			base.speakers["SR"]["amount"] = 125.0
			base.fill_amount = 125.0
			base.reverb_send = 10.0
			base.latency_ms = 64
			base.note = "Matrix Surround expands stereo into a 5.1-style field (open matrix, not a branded codec)."

		"Dolby Pro Logic":
			# Classic Pro Logic–style decode: strong center, mono-ish surrounds.
			base.layout = "5.1"
			base.mode = "prologic_expand"
			base.speakers = default_speakers("5.1")
			base.speakers["FC"]["gain_db"] = 1.0
			base.speakers["FC"]["amount"] = 115.0
			base.speakers["LFE"]["gain_db"] = -3.0
			base.speakers["LFE"]["amount"] = 70.0
			base.speakers["SL"]["gain_db"] = -1.0
			base.speakers["SR"]["gain_db"] = -1.0
			base.speakers["SL"]["amount"] = 110.0
			base.speakers["SR"]["amount"] = 110.0
			base.fill_amount = 115.0
			base.reverb_send = 8.0
			base.latency_ms = 64
			base.note = "Dolby Pro Logic–style matrix expand (approx.): center lock + shared surrounds. Not a licensed Dolby encoder."

		"Dolby Pro", "Dolby Pro Logic II":
			# Pro Logic II–style: stereo surrounds, wider image (aka “Dolby Pro”).
			base.layout = "5.1"
			base.mode = "pl2_expand"
			base.speakers = default_speakers("5.1")
			base.speakers["FC"]["gain_db"] = 0.5
			base.speakers["FC"]["amount"] = 110.0
			base.speakers["LFE"]["gain_db"] = -1.5
			base.speakers["SL"]["amount"] = 135.0
			base.speakers["SR"]["amount"] = 135.0
			base.fill_amount = 130.0
			base.reverb_send = 12.0
			base.latency_ms = 72
			base.note = "Dolby Pro / Pro Logic II–style expand (approx.): stereo surrounds + wider field. Not a licensed Dolby encoder."

		"Cinema Wide 7.1":
			base.layout = "7.1"
			base.mode = "direct"
			base.speakers = default_speakers("7.1")
			base.speakers["SL"]["gain_db"] = 1.5
			base.speakers["SR"]["gain_db"] = 1.5
			base.speakers["BL"]["gain_db"] = 3.0
			base.speakers["BR"]["gain_db"] = 3.0
			base.speakers["SL"]["amount"] = 140.0
			base.speakers["SR"]["amount"] = 140.0
			base.speakers["BL"]["amount"] = 150.0
			base.speakers["BR"]["amount"] = 150.0
			base.speakers["LFE"]["gain_db"] = 2.0
			base.fill_amount = 145.0
			base.reverb_send = 18.0
			base.latency_ms = 96
			base.master_gain_db = -1.0

		_:
			pass

	return base
