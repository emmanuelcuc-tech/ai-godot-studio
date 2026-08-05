class_name GeminiClient
extends RefCounted
## Google Gemini generateContent API

signal reply(ok: bool, text: String, error: String)

const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")

var _client = AIHTTPClientScript.new()


func attach(host: Node) -> void:
	_client.attach(host)
	_client.completed.connect(_on_completed)


func chat(system_prompt: String, user_prompt: String, model: String = "", api_key: String = "") -> Error:
	var key := api_key if not api_key.is_empty() else AppSettings.gemini_api_key
	var mdl := model if not model.is_empty() else AppSettings.gemini_model
	if key.is_empty():
		reply.emit(false, "", "Gemini API key missing")
		return ERR_UNAUTHORIZED
	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" % [mdl, key]
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := {
		"system_instruction": {
			"parts": [{"text": system_prompt}]
		},
		"contents": [
			{"role": "user", "parts": [{"text": user_prompt}]}
		],
		"generationConfig": {
			"temperature": 0.4,
			"maxOutputTokens": 8192,
		},
	}
	return _client.post_json(url, headers, body)


func _on_completed(ok: bool, text: String, _meta: Dictionary) -> void:
	if not ok:
		reply.emit(false, "", text)
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		reply.emit(false, "", "Invalid Gemini JSON")
		return
	var candidates: Array = data.get("candidates", [])
	if candidates.is_empty():
		reply.emit(false, "", "No Gemini candidates")
		return
	var content: Dictionary = candidates[0].get("content", {})
	var parts: Array = content.get("parts", [])
	var out: PackedStringArray = []
	for part in parts:
		if typeof(part) == TYPE_DICTIONARY:
			out.append(str(part.get("text", "")))
	var joined := "\n".join(out)
	if joined.is_empty():
		reply.emit(false, "", "Empty Gemini response")
		return
	reply.emit(true, joined, "")
