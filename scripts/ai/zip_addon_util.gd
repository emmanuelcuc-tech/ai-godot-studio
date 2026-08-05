class_name ZipAddonUtil
extends RefCounted
## Inspect / extract Godot addon zips. Never run installers. Only unpack addon-shaped archives.


static func inspect(zip_path: String) -> Dictionary:
	if zip_path.is_empty() or not FileAccess.file_exists(zip_path):
		return {"ok": false, "error": "Zip not found", "is_addon": false}
	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(zip_path)
	if err != OK:
		return {"ok": false, "error": "Cannot open zip (%s)" % err, "is_addon": false}
	var names: PackedStringArray = reader.get_files()
	reader.close()
	var has_plugin_cfg: bool = false
	var has_addons_dir: bool = false
	var plugin_cfgs: PackedStringArray = PackedStringArray()
	for n in names:
		var rel: String = str(n).replace("\\", "/")
		if rel.ends_with("/"):
			continue
		if rel.get_file() == "plugin.cfg":
			has_plugin_cfg = true
			plugin_cfgs.append(rel)
		if rel.begins_with("addons/") or rel.contains("/addons/"):
			has_addons_dir = true
	return {
		"ok": true,
		"is_addon": has_plugin_cfg or has_addons_dir,
		"has_plugin_cfg": has_plugin_cfg,
		"has_addons_dir": has_addons_dir,
		"plugin_cfgs": plugin_cfgs,
		"file_count": names.size(),
	}


static func extract_addon(zip_path: String, project_root: String) -> Dictionary:
	var info: Dictionary = inspect(zip_path)
	if not info.get("ok", false):
		return info
	if not info.get("is_addon", false):
		return {"ok": false, "error": "Archive is not a Godot addon (no plugin.cfg / addons/)", "is_addon": false}
	var reader: ZIPReader = ZIPReader.new()
	var err: Error = reader.open(zip_path)
	if err != OK:
		return {"ok": false, "error": "Cannot reopen zip (%s)" % err}
	var names: PackedStringArray = reader.get_files()
	var written: PackedStringArray = PackedStringArray()
	var dest_root: String = project_root.path_join("addons")
	DirAccess.make_dir_recursive_absolute(dest_root)
	for n in names:
		var rel: String = str(n).replace("\\", "/")
		if rel.ends_with("/") or rel.contains(".."):
			continue
		var out_rel: String = _map_addon_member(rel)
		if out_rel.is_empty():
			continue
		var data: PackedByteArray = reader.read_file(n)
		if data.is_empty() and rel.get_extension().is_empty():
			continue
		var dest: String = project_root.path_join(out_rel)
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var out: FileAccess = FileAccess.open(dest, FileAccess.WRITE)
		if out == null:
			continue
		out.store_buffer(data)
		written.append(out_rel)
	reader.close()
	if written.is_empty():
		return {"ok": false, "error": "No addon files extracted", "is_addon": true}
	return {"ok": true, "is_addon": true, "files": written, "count": written.size()}


static func _map_addon_member(rel: String) -> String:
	var idx: int = rel.find("/addons/")
	if idx >= 0:
		return rel.substr(idx + 1)
	if rel.begins_with("addons/"):
		return rel
	if rel.get_file() == "plugin.cfg" or rel.ends_with(".gd") or rel.ends_with(".cfg") or rel.ends_with(".uid"):
		var parts: PackedStringArray = rel.split("/")
		if parts.is_empty():
			return ""
		var plugin_folder: String = parts[0]
		if parts.size() >= 2 and parts[parts.size() - 1] == "plugin.cfg":
			plugin_folder = parts[parts.size() - 2]
		elif parts.size() >= 2:
			plugin_folder = parts[0]
		if plugin_folder.is_empty() or plugin_folder == ".":
			plugin_folder = "imported_addon"
		var rest: String = rel
		if rel.begins_with(plugin_folder + "/"):
			rest = rel.substr(plugin_folder.length() + 1)
		elif parts.size() >= 2:
			rest = "/".join(parts.slice(1, parts.size()))
		return "addons/%s/%s" % [plugin_folder, rest]
	return ""
