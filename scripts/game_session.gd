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


func start(path: String, name: String, genre: String) -> void:
	active = true
	project_path = path
	project_name = name
	genre_id = genre
	revision = 1
	history.clear()
	history.append("Started %s (%s)" % [name, genre])
	changed.emit()


func bump(direction: String) -> void:
	revision += 1
	history.append("r%s: %s" % [str(revision), direction.left(200)])
	changed.emit()


func clear() -> void:
	active = false
	project_path = ""
	project_name = ""
	genre_id = ""
	revision = 0
	history.clear()
	changed.emit()


func label() -> String:
	if not active:
		return "No active game — Create Game to start"
	return "Active: %s  ·  rev %s" % [project_name, str(revision)]
