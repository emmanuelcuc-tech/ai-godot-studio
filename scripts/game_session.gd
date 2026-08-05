class_name GameSession
extends RefCounted
## Active game being iteratively modified until the user hits New Game.

signal changed

var active: bool = false
var project_path: String = ""
var project_name: String = ""
var genre_id: String = ""
var revision: int = 0
var history: PackedStringArray = []
var comments: PackedStringArray = []


func start(path: String, name: String, genre: String) -> void:
	active = true
	project_path = path
	project_name = name
	genre_id = genre
	revision = 1
	history.clear()
	comments.clear()
	history.append("Started %s (%s)" % [name, genre])
	changed.emit()


func bump(direction: String) -> void:
	revision += 1
	var note: String = direction.strip_edges()
	history.append("r%s: %s" % [str(revision), note.left(240)])
	if not note.is_empty():
		comments.append(note)
	changed.emit()


func comments_blob(max_chars: int = 4000) -> String:
	if comments.is_empty():
		return "(no extra comments yet)"
	var lines: PackedStringArray = PackedStringArray()
	var i: int = 1
	for c in comments:
		lines.append("%s. %s" % [str(i), c])
		i += 1
	var blob: String = "\n".join(lines)
	if blob.length() > max_chars:
		return blob.substr(blob.length() - max_chars)
	return blob


func clear() -> void:
	active = false
	project_path = ""
	project_name = ""
	genre_id = ""
	revision = 0
	history.clear()
	comments.clear()
	changed.emit()


func label() -> String:
	if not active:
		return "No active game — Create Game to start"
	return "Active: %s  ·  rev %s" % [project_name, str(revision)]
