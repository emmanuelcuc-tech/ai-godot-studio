class_name OpenAIClient
extends RefCounted
## ChatGPT / OpenAI Chat Completions API

signal reply(ok: bool, text: String, error: String)

const ENDPOINT := "https://api.openai.com/v1/chat/completions"
const AIHTTPClientScript = preload("res://scripts/ai/ai_http_client.gd")

var _client = AIHTTPClientScript.new()


func attach(host: Node) -> void:
	_client.attach(host)
	_client.completed.connect(_on_completed)


func chat(system_prompt: String, user_prompt: String, model: String = "", api_key: String = "") -> Error:
	var key := api_key if not api_key.is_empty() else AppSettings.openai_api_key
	var mdl := model if not model.is_empty() else AppSettings.openai_model
	if key.is_empty():
		reply.emit(false, "", "OpenAI API key missing")
		return ERR_UNAUTHORIZED
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % key,
	])
	var body := {
		"model": mdl,
		"temperature": 0.4,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": user_prompt},
		],
	}
	var err := _client.post_json(ENDPOINT, headers, body)
	if err != OK and err != ERR_UNAUTHORIZED:
		# post_json already emits completed(false) on start failure; also cover ERR_BUSY
		if err == ERR_BUSY:
			reply.emit(false, "", "OpenAI client busy")
	return err


func _on_completed(ok: bool, text: String, _meta: Dictionary) -> void:
	if not ok:
		reply.emit(false, "", text)
		return
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		reply.emit(false, "", "Invalid OpenAI JSON")
		return
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		reply.emit(false, "", "No choices from OpenAI")
		return
	var message: Dictionary = choices[0].get("message", {})
	var content := str(message.get("content", ""))
	reply.emit(true, content, "")
