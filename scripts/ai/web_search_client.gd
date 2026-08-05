class_name WebSearchClient
extends RefCounted
## Internet research for Godot game patterns.
## Prefers Tavily when keyed; otherwise uses DuckDuckGo Instant Answer + Wikipedia.

signal reply(ok: bool, text: String, error: String)

const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")

var _client = AIHTTPClientScript.new()
var _mode: String = ""
var _query: String = ""


func attach(host: Node) -> void:
	_client.attach(host)
	_client.completed.connect(_on_completed)


func search(query: String) -> Error:
	_query = query
	var tavily := AppSettings.tavily_api_key
	if not tavily.is_empty():
		_mode = "tavily"
		var headers := PackedStringArray(["Content-Type: application/json"])
		var body := {
			"api_key": tavily,
			"query": query,
			"search_depth": "basic",
			"max_results": 5,
			"include_answer": true,
		}
		return _client.post_json("https://api.tavily.com/search", headers, body)
	_mode = "ddg"
	var encoded := query.uri_encode()
	var url := "https://api.duckduckgo.com/?q=%s&format=json&no_html=1&skip_disambig=1" % encoded
	return _client.get_url(url, PackedStringArray(["User-Agent: AI-Godot-Studio/1.0"]))


func _on_completed(ok: bool, text: String, _meta: Dictionary) -> void:
	if not ok:
		reply.emit(false, "", text)
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		reply.emit(false, "", "Invalid search JSON")
		return
	if _mode == "tavily":
		_parse_tavily(data)
	else:
		_parse_ddg(data)


func _parse_tavily(data: Dictionary) -> void:
	var chunks: PackedStringArray = []
	var answer := str(data.get("answer", ""))
	if not answer.is_empty():
		chunks.append("Answer: %s" % answer)
	for item in data.get("results", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		chunks.append("- %s: %s (%s)" % [
			str(item.get("title", "")),
			str(item.get("content", "")).left(400),
			str(item.get("url", "")),
		])
	if chunks.is_empty():
		reply.emit(false, "", "No Tavily results")
		return
	reply.emit(true, "\n".join(chunks), "")


func _parse_ddg(data: Dictionary) -> void:
	var chunks: PackedStringArray = []
	var abstract := str(data.get("AbstractText", ""))
	var abs_url := str(data.get("AbstractURL", ""))
	if not abstract.is_empty():
		chunks.append("Summary: %s (%s)" % [abstract, abs_url])
	for topic in data.get("RelatedTopics", []):
		if typeof(topic) != TYPE_DICTIONARY:
			continue
		var t := str(topic.get("Text", ""))
		var u := str(topic.get("FirstURL", ""))
		if not t.is_empty():
			chunks.append("- %s (%s)" % [t.left(350), u])
		if chunks.size() >= 6:
			break
	if chunks.is_empty():
		# Soft fallback so pipeline continues
		reply.emit(true, "No Instant Answer for '%s'. Use Godot 4 docs and common genre patterns." % _query, "")
		return
	reply.emit(true, "\n".join(chunks), "")
