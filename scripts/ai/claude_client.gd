class_name ClaudeClient
extends RefCounted
## Anthropic Claude Messages API

signal reply(ok: bool, text: String, error: String)

const ENDPOINT := "https://api.anthropic.com/v1/messages"
const API_VERSION := "2023-06-01"
const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")

var _client = AIHTTPClientScript.new()


func attach(host: Node) -> void:
	_client.attach(host)
	_client.completed.connect(_on_completed)


func chat(system_prompt: String, user_prompt: String, model: String = "", api_key: String = "") -> Error:
	var key := api_key if not api_key.is_empty() else AppSettings.claude_api_key
	var mdl := model if not model.is_empty() else AppSettings.claude_model
	if key.is_empty():
		reply.emit(false, "", "Claude API key missing")
		return ERR_UNAUTHORIZED
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-api-key: %s" % key,
		"anthropic-version: %s" % API_VERSION,
	])
	var body := {
		"model": mdl,
		"max_tokens": 8192,
		"temperature": 0.4,
		"system": system_prompt,
		"messages": [
			{"role": "user", "content": user_prompt},
		],
	}
	return _client.post_json(ENDPOINT, headers, body)


func _on_completed(ok: bool, text: String, _meta: Dictionary) -> void:
	if not ok:
		reply.emit(false, "", text)
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		reply.emit(false, "", "Invalid Claude JSON")
		return
	var content: Array = data.get("content", [])
	var parts: PackedStringArray = []
	for block in content:
		if typeof(block) == TYPE_DICTIONARY and str(block.get("type", "")) == "text":
			parts.append(str(block.get("text", "")))
	var joined := "\n".join(parts)
	if joined.is_empty():
		reply.emit(false, "", "Empty Claude response")
		return
	reply.emit(true, joined, "")
