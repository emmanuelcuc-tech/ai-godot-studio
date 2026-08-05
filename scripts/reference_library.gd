class_name ReferenceLibrary
extends RefCounted
## Learn tab: study code, textures, sprites, audio, and Blender/glTF meshes.
## Commercial ROMs / ISOs / pirated dumps are rejected.

const STORE_DIR := "res://learned_refs"
const INDEX_FILE := "res://learned_refs/index.json"
const MAX_FILE_CHARS := 14000
const MAX_TOTAL_CHARS := 48000

const CODE_EXT: PackedStringArray = [
	"gd", "tscn", "tres", "md", "txt", "json", "cfg", "godot", "cs",
	"shader", "gdshader", "xml", "csv", "yml", "yaml", "toml", "import"
]

const IMAGE_EXT: PackedStringArray = [
	"png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"
]

const AUDIO_EXT: PackedStringArray = [
	"wav", "ogg", "mp3"
]

## Blender / Godot 3D pipeline — prefer glTF; .blend kept as source notes.
const MESH_EXT: PackedStringArray = [
	"glb", "gltf", "fbx", "dae", "obj", "blend"
]

## Console dumps, disc images, commercial game packages — not accepted.
const BLOCKED_EXT: PackedStringArray = [
	"nes", "fds", "unf", "smc", "sfc", "fig", "gb", "gbc", "gba", "nds", "3ds",
	"n64", "z64", "v64", "gcm", "iso", "cso", "chd", "rvz", "wbfs", "wia",
	"xci", "nsp", "vpk", "pbp", "cso", "bin", "cue", "mds", "nrg",
	"rom", "a26", "a78", "lnx", "ngp", "pce", "sgx", "ws", "wsc",
	"wad", "iwad", "pwad", "pk3", "pk4", "vpk", "bsp",
	"exe", "dll", "apk", "ipa", "dmg", "pkg",
]


static func ensure_store() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STORE_DIR))


static func allowed_filters() -> PackedStringArray:
	return PackedStringArray([
		"*.gd,*.tscn,*.tres,*.cs,*.gdshader,*.shader ; Code / scenes",
		"*.png,*.jpg,*.jpeg,*.webp,*.bmp,*.tga,*.svg ; Textures / sprites",
		"*.glb,*.gltf,*.fbx,*.dae,*.obj,*.blend ; Meshes / Blender / glTF",
		"*.wav,*.ogg,*.mp3 ; Audio",
		"*.md,*.txt,*.json,*.cfg,*.xml,*.csv ; Docs / data",
	])


static func list_entries() -> Array:
	ensure_store()
	var path := ProjectSettings.globalize_path(INDEX_FILE)
	if not FileAccess.file_exists(path):
		return []
	var raw := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var files = data.get("files", [])
	return files if typeof(files) == TYPE_ARRAY else []


static func save_index(files: Array) -> void:
	ensure_store()
	var path := ProjectSettings.globalize_path(INDEX_FILE)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"files": files}, "\t"))


static func kind_for_ext(ext: String) -> String:
	if CODE_EXT.has(ext):
		return "code"
	if IMAGE_EXT.has(ext):
		return "texture"
	if AUDIO_EXT.has(ext):
		return "audio"
	if MESH_EXT.has(ext):
		return "mesh"
	return ""


static func import_path(abs_path: String) -> Dictionary:
	ensure_store()
	var ext := abs_path.get_extension().to_lower()
	if BLOCKED_EXT.has(ext):
		return {
			"ok": false,
			"error": "Commercial ROM/ISO/dump (.%s) not allowed. Drop your own or CC0 code/sprites/textures instead (Kenney, OpenGameArt). Searching or using pirated ROMs is not supported." % ext,
		}
	var kind := kind_for_ext(ext)
	if kind.is_empty():
		return {
			"ok": false,
			"error": "Unsupported .%s — use code, textures/sprites, glTF/FBX/Blend meshes, or audio." % ext,
		}
	if not FileAccess.file_exists(abs_path):
		return {"ok": false, "error": "File not found"}

	var base := abs_path.get_file()
	var safe := base.validate_filename()
	if safe.is_empty():
		safe = "ref_%s.%s" % [str(Time.get_unix_time_from_system()), ext]
	var dest_rel := "%s/%s" % [STORE_DIR, safe]
	var dest_abs := ProjectSettings.globalize_path(dest_rel)
	var n := 1
	while FileAccess.file_exists(dest_abs):
		safe = "%s_%d.%s" % [base.get_basename(), n, ext]
		dest_rel = "%s/%s" % [STORE_DIR, safe]
		dest_abs = ProjectSettings.globalize_path(dest_rel)
		n += 1

	var analysis := ""
	var chars := 0
	if kind == "code":
		var content := FileAccess.get_file_as_string(abs_path)
		if content.is_empty() and FileAccess.get_file_as_bytes(abs_path).size() > 0:
			return {"ok": false, "error": "Looks binary — for sprites use PNG/JPG, not this extension."}
		if content.length() > MAX_FILE_CHARS:
			content = content.left(MAX_FILE_CHARS) + "\n...[truncated]..."
		var out := FileAccess.open(dest_abs, FileAccess.WRITE)
		if out == null:
			return {"ok": false, "error": "Cannot write learned_refs"}
		out.store_string(content)
		chars = content.length()
		analysis = _analyze_code(safe, content, ext)
	else:
		# Binary copy for textures / audio
		var bytes := FileAccess.get_file_as_bytes(abs_path)
		if bytes.is_empty():
			return {"ok": false, "error": "Empty file"}
		var bout := FileAccess.open(dest_abs, FileAccess.WRITE)
		if bout == null:
			return {"ok": false, "error": "Cannot write learned_refs"}
		bout.store_buffer(bytes)
		chars = bytes.size()
		if kind == "texture":
			analysis = _analyze_image(dest_abs, safe, abs_path)
		elif kind == "mesh":
			analysis = _analyze_mesh(safe, abs_path, ext, bytes.size())
		else:
			analysis = _analyze_audio(safe, abs_path, bytes.size())

	# Sidecar study notes always written for Create/AI
	var note_rel := "%s/%s.study.md" % [STORE_DIR, safe.get_basename()]
	var note_abs := ProjectSettings.globalize_path(note_rel)
	# uniquify note if needed
	var note_n := 1
	while FileAccess.file_exists(note_abs) and note_n < 50:
		note_rel = "%s/%s_%d.study.md" % [STORE_DIR, safe.get_basename(), note_n]
		note_abs = ProjectSettings.globalize_path(note_rel)
		note_n += 1
	var nf := FileAccess.open(note_abs, FileAccess.WRITE)
	if nf:
		nf.store_string(analysis)

	var files := list_entries()
	files.append({
		"name": safe,
		"source": abs_path,
		"path": dest_rel,
		"note_path": note_rel,
		"kind": kind,
		"chars": chars,
		"analysis_preview": analysis.left(400),
		"imported_at": Time.get_datetime_string_from_system(),
	})
	save_index(files)
	return {
		"ok": true,
		"name": safe,
		"path": dest_rel,
		"kind": kind,
		"analysis": analysis,
	}


static func import_folder(folder_abs: String) -> Dictionary:
	var dir := DirAccess.open(folder_abs)
	if dir == null:
		return {"ok": false, "error": "Cannot open folder", "imported": [], "skipped": []}
	var imported: Array = []
	var skipped: Array = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and not name.begins_with("."):
			var full := folder_abs.path_join(name)
			var res := import_path(full)
			if res.get("ok", false):
				imported.append(res.get("name", name))
			else:
				skipped.append("%s: %s" % [name, str(res.get("error", ""))])
		name = dir.get_next()
	return {"ok": true, "imported": imported, "skipped": skipped}


static func study_entry(entry: Dictionary) -> String:
	var note_p := ProjectSettings.globalize_path(str(entry.get("note_path", "")))
	if FileAccess.file_exists(note_p):
		return FileAccess.get_file_as_string(note_p)
	var kind := str(entry.get("kind", "code"))
	var p := ProjectSettings.globalize_path(str(entry.get("path", "")))
	if kind == "code" and FileAccess.file_exists(p):
		return _analyze_code(str(entry.get("name", "")), FileAccess.get_file_as_string(p), str(entry.get("name", "")).get_extension())
	if kind == "texture" and FileAccess.file_exists(p):
		return _analyze_image(p, str(entry.get("name", "")), str(entry.get("source", "")))
	if kind == "mesh":
		return _analyze_mesh(
			str(entry.get("name", "")),
			str(entry.get("source", "")),
			str(entry.get("name", "")).get_extension(),
			int(entry.get("chars", 0))
		)
	return str(entry.get("analysis_preview", "No study notes."))


static func clear_all() -> void:
	var files := list_entries()
	for e in files:
		for key in ["path", "note_path"]:
			var p := ProjectSettings.globalize_path(str(e.get(key, "")))
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
	# Also wipe leftover study md / assets in store
	var abs_store := ProjectSettings.globalize_path(STORE_DIR)
	var d := DirAccess.open(abs_store)
	if d:
		d.list_dir_begin()
		var n := d.get_next()
		while n != "":
			if not d.current_is_dir() and n != ".gitkeep":
				DirAccess.remove_absolute(abs_store.path_join(n))
			n = d.get_next()
	save_index([])


static func context_blob() -> String:
	var files := list_entries()
	if files.is_empty():
		return ""
	var parts: PackedStringArray = []
	var total := 0
	for e in files:
		var kind := str(e.get("kind", "code"))
		var chunk := ""
		if kind == "code":
			var p := ProjectSettings.globalize_path(str(e.get("path", "")))
			var body := FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""
			chunk = "### CODE FILE: %s (from %s)\n%s\n" % [
				str(e.get("name", "")), str(e.get("source", "")), body,
			]
		else:
			chunk = "### ASSET (%s): %s\n%s\nStored at: %s\nUse this mesh/sprite/texture/audio in the Godot game (glTF → AnimationPlayer; PNG → SpriteFrames/materials).\n" % [
				kind,
				str(e.get("name", "")),
				study_entry(e),
				str(e.get("path", "")),
			]
		if total + chunk.length() > MAX_TOTAL_CHARS:
			parts.append("### %s\n...[omitted, context budget]...\n" % str(e.get("name", "")))
			break
		parts.append(chunk)
		total += chunk.length()
	return "\n".join(parts)


static func _analyze_code(name: String, content: String, ext: String) -> String:
	var lines := content.split("\n")
	var extends_line := ""
	var funcs: PackedStringArray = []
	var signals: PackedStringArray = []
	var exports: PackedStringArray = []
	for line in lines:
		var t := line.strip_edges()
		if t.begins_with("extends "):
			extends_line = t
		elif t.begins_with("func "):
			funcs.append(t.left(80))
		elif t.begins_with("signal "):
			signals.append(t)
		elif t.begins_with("@export"):
			exports.append(t.left(80))
	return """# Study notes: %s

- Type: code (.%s)
- %s
- Functions (%s): %s
- Signals: %s
- Exports: %s

## How Create should use this
Match naming, node types, and patterns from this file when modifying the genre template.
Do not copy proprietary assets — only coding structure and techniques.

## Snippet head
```
%s
```
""" % [
		name, ext,
		extends_line if not extends_line.is_empty() else "(no extends line)",
		str(funcs.size()), ", ".join(funcs.slice(0, mini(12, funcs.size()))),
		", ".join(signals) if signals.size() else "(none)",
		", ".join(exports) if exports.size() else "(none)",
		"\n".join(PackedStringArray(lines).slice(0, mini(40, lines.size()))),
	]


static func _analyze_image(abs_path: String, name: String, source: String) -> String:
	var img := Image.new()
	var err := img.load(abs_path)
	if err != OK:
		return """# Study notes: %s
- Type: texture/sprite (load failed: %s)
- Source: %s
- Still copy into game as res://assets/ if user owns rights / CC0.
""" % [name, str(err), source]
	var w := img.get_width()
	var h := img.get_height()
	var usage := "UI / texture"
	if w == h and w <= 128:
		usage = "Likely icon or tile"
	elif w > h * 2:
		usage = "Likely spritesheet or UI bar (slice frames in AtlasTexture)"
	elif h > w * 2:
		usage = "Likely vertical strip / character sheet"
	elif w <= 64 and h <= 64:
		usage = "Likely sprite frame or tile"
	else:
		usage = "Likely background, texture, or large sprite"
	return """# Study notes: %s

- Type: texture / sprite
- Source: %s
- Size: %sx%s px
- Format hint: %s
- Suggested use: %s

## How Create should use this
- Copy into generated project as `assets/%s`
- Create Sprite2D / Sprite3D / TextureRect / StandardMaterial3D albedo from it
- If spritesheet, document frame size guess and use AtlasTexture
- Only reuse if the user owns the file or it is CC0/open licensed
""" % [name, source, str(w), str(h), str(img.get_format()), usage, name]


static func _analyze_audio(name: String, source: String, bytes_len: int) -> String:
	return """# Study notes: %s

- Type: audio
- Source: %s
- Bytes: %s
- Suggested use: AudioStreamPlayer / AudioStreamPlayer2D (SFX or music)

## How Create should use this
Reference as `res://assets/%s` with AudioStreamPlayer. Confirm license (own file or CC0).
""" % [name, source, str(bytes_len), name]


static func _analyze_mesh(name: String, source: String, ext: String, bytes_len: int) -> String:
	var preferred := "Ready for Godot import" if ext in ["glb", "gltf"] else "Export from Blender as glTF 2.0 (.glb) for best Godot results"
	var blend_note := ""
	if ext == "blend":
		blend_note = """
## Blender source
Open in Blender (Studio → Open Blender). Export File → Export → glTF 2.0 (.glb) with Meshes, Materials, Animations, Skinning.
Godot does not play .blend directly — use the exported .glb in `assets/`.
"""
	return """# Study notes: %s

- Type: 3D mesh / Blender pipeline (.%s)
- Source: %s
- Bytes: %s
- Status: %s
%s
## How Create should use this
- Copy into generated project as `assets/%s`
- Instance glTF scene; use imported AnimationPlayer clips (idle/walk/attack)
- Materials: StandardMaterial3D from imported slots or override albedo/roughness
- If FBX/OBJ/DAE: prefer re-export to .glb from Blender
- Only reuse if the user owns the file or it is CC0/open licensed
""" % [name, ext, source, str(bytes_len), preferred, blend_note, name]
