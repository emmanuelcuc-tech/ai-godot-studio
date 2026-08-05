class_name AIHTTPClient
extends RefCounted
## Shared async HTTP helper for AI providers.

signal completed(ok: bool, text: String, meta: Dictionary)
signal completed_bytes(ok: bool, bytes: PackedByteArray, error: String, meta: Dictionary)

var _http: HTTPRequest
var _busy: bool = false
var _want_bytes: bool = false


func attach(host: Node) -> void:
	_http = HTTPRequest.new()
	_http.timeout = 120
	_http.use_threads = true
	host.add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_busy() -> bool:
	return _busy


func post_json(url: String, headers: PackedStringArray, body: Dictionary) -> Error:
	if _busy:
		return ERR_BUSY
	_busy = true
	_want_bytes = false
	var payload := JSON.stringify(body)
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		_busy = false
		completed.emit(false, "HTTP request failed to start (%s)" % err, {"code": 0})
	return err


func get_url(url: String, headers: PackedStringArray = PackedStringArray()) -> Error:
	if _busy:
		return ERR_BUSY
	_busy = true
	_want_bytes = false
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		completed.emit(false, "HTTP request failed to start (%s)" % err, {"code": 0})
	return err


func get_bytes(url: String, headers: PackedStringArray = PackedStringArray()) -> Error:
	if _busy:
		return ERR_BUSY
	_busy = true
	_want_bytes = true
	var err := _http.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_busy = false
		_want_bytes = false
		completed_bytes.emit(false, PackedByteArray(), "HTTP request failed to start (%s)" % err, {"code": 0})
	return err


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var as_bytes := _want_bytes
	_want_bytes = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if as_bytes:
			completed_bytes.emit(false, PackedByteArray(), "Network error (%s)" % result, {"code": response_code})
		else:
			completed.emit(false, "Network error (%s)" % result, {"code": response_code})
		return
	if response_code < 200 or response_code >= 300:
		var err_txt := body.get_string_from_utf8().left(800)
		if as_bytes:
			completed_bytes.emit(false, PackedByteArray(), "HTTP %s: %s" % [response_code, err_txt], {"code": response_code})
		else:
			completed.emit(false, "HTTP %s: %s" % [response_code, err_txt], {"code": response_code})
		return
	if as_bytes:
		completed_bytes.emit(true, body, "", {"code": response_code})
	else:
		completed.emit(true, body.get_string_from_utf8(), {"code": response_code})
