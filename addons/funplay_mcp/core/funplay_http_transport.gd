@tool
extends RefCounted

const MAX_HEADER_BYTES = 32768
const MAX_BODY_BYTES = 8 * 1024 * 1024
const REQUEST_TIMEOUT_MSEC = 10000

var _server = TCPServer.new()
var _connections: Array = []
var _is_listening = false
var _port = 0


func listen(port: int) -> int:
	stop()
	var err = _server.listen(port, "127.0.0.1")
	if err == OK:
		_is_listening = true
		_port = port
	return err


func stop() -> void:
	for connection in _connections:
		var peer: StreamPeerTCP = connection["peer"]
		peer.disconnect_from_host()
	_connections.clear()

	if _is_listening:
		_server.stop()

	_is_listening = false
	_port = 0


func is_listening() -> bool:
	return _is_listening


func get_port() -> int:
	return _port


func poll(request_callback: Callable) -> void:
	if not _is_listening:
		return

	while _server.is_connection_available():
		var peer = _server.take_connection()
		peer.set_no_delay(true)
		_connections.append({
			"peer": peer,
			"buffer": "",
			"headers_parsed": false,
			"content_length": 0,
			"method": "",
			"path": "/",
			"headers": {},
			"started_msec": Time.get_ticks_msec(),
		})

	for index in range(_connections.size() - 1, -1, -1):
		var connection: Dictionary = _connections[index]
		var peer: StreamPeerTCP = connection["peer"]
		peer.poll()

		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_connections.remove_at(index)
			continue

		if Time.get_ticks_msec() - int(connection.get("started_msec", 0)) > REQUEST_TIMEOUT_MSEC:
			_send_response(peer, _text_response(408, "Request Timeout"))
			peer.disconnect_from_host()
			_connections.remove_at(index)
			continue

		var available = peer.get_available_bytes()
		if available > 0:
			connection["buffer"] += peer.get_utf8_string(available)
			_connections[index] = connection

		if not connection["headers_parsed"]:
			var buffer_text: String = connection["buffer"]
			var header_end = buffer_text.find("\r\n\r\n")
			if header_end == -1:
				if buffer_text.to_utf8_buffer().size() > MAX_HEADER_BYTES:
					_send_response(peer, _text_response(431, "Request Header Fields Too Large"))
					peer.disconnect_from_host()
					_connections.remove_at(index)
				continue
			var header_text = buffer_text.substr(0, header_end)
			var parsed = _parse_headers(header_text)
			if int(parsed.get("status", 200)) != 200:
				_send_response(peer, _text_response(int(parsed.get("status", 400)), str(parsed.get("message", "Bad Request"))))
				peer.disconnect_from_host()
				_connections.remove_at(index)
				continue
			connection["headers_parsed"] = true
			connection["content_length"] = parsed["content_length"]
			connection["method"] = parsed["method"]
			connection["path"] = parsed["path"]
			connection["headers"] = parsed["headers"]
			_connections[index] = connection

		var full_text: String = connection["buffer"]
		var body_start = full_text.find("\r\n\r\n")
		if body_start == -1:
			continue
		body_start += 4
		var body_text = full_text.substr(body_start)
		if body_text.to_utf8_buffer().size() < int(connection["content_length"]):
			continue

		var response = request_callback.call(
			str(connection["method"]),
			str(connection["path"]),
			body_text,
			connection.get("headers", {})
		)
		_send_response(peer, response)
		peer.disconnect_from_host()
		_connections.remove_at(index)


func _parse_headers(header_text: String) -> Dictionary:
	var lines = header_text.split("\r\n")
	var method = "POST"
	var path = "/"
	var content_length = 0
	var headers = {}

	if lines.size() > 0:
		var request_line = lines[0].split(" ")
		if request_line.size() >= 2:
			method = request_line[0]
			path = request_line[1]

	for i in range(1, lines.size()):
		var line: String = lines[i]
		var separator = line.find(":")
		if separator == -1:
			continue
		var key = line.substr(0, separator).strip_edges().to_lower()
		var value = line.substr(separator + 1).strip_edges()
		headers[key] = value
		if key == "content-length":
			if not value.is_valid_int():
				return {
					"status": 400,
					"message": "Bad Request: invalid Content-Length",
				}
			content_length = int(value)
			if content_length < 0:
				return {
					"status": 400,
					"message": "Bad Request: invalid Content-Length",
				}
			if content_length > MAX_BODY_BYTES:
				return {
					"status": 413,
					"message": "Payload Too Large",
				}

	return {
		"status": 200,
		"method": method,
		"path": path,
		"content_length": content_length,
		"headers": headers,
	}


func _send_response(peer: StreamPeerTCP, response: Dictionary) -> void:
	var status = int(response.get("status", 200))
	var content_type = str(response.get("content_type", "application/json"))
	var body = str(response.get("body", ""))
	var status_text = "OK"

	match status:
		200:
			status_text = "OK"
		204:
			status_text = "No Content"
		400:
			status_text = "Bad Request"
		401:
			status_text = "Unauthorized"
		403:
			status_text = "Forbidden"
		404:
			status_text = "Not Found"
		405:
			status_text = "Method Not Allowed"
		408:
			status_text = "Request Timeout"
		413:
			status_text = "Payload Too Large"
		431:
			status_text = "Request Header Fields Too Large"
		500:
			status_text = "Internal Server Error"

	var body_bytes = body.to_utf8_buffer()
	var headers = [
		"HTTP/1.1 %d %s" % [status, status_text],
		"Content-Type: %s; charset=utf-8" % content_type,
		"Content-Length: %d" % body_bytes.size(),
		"Connection: close",
		"",
		"",
	]
	var response_text = "\r\n".join(headers) + body
	peer.put_data(response_text.to_utf8_buffer())


func _text_response(status: int, body: String) -> Dictionary:
	return {
		"status": status,
		"content_type": "text/plain",
		"body": body,
	}
