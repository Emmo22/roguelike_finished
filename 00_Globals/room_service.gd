extends Node

# Centralised backend room fetching. Used by BOTH the level editor's Start button
# and the title screen's "Spielen" mode, so the web-vs-native and gzip handling
# lives in exactly one place. Returns [] on any failure so callers can fall back.


func _ready() -> void:
	# The title screen fetches rooms while the tree is paused (title state), so we
	# must keep processing — otherwise our HTTPRequest would never poll and the
	# await would hang.
	process_mode = Node.PROCESS_MODE_ALWAYS


# In a web export the game is served from the same host as the backend, so we use
# a relative origin. In the editor/desktop there is no host, so fall back to the
# local dev server.
static func server_base() -> String:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("window.location.origin")
	return "https://dungeon-delver.wiai-lab.de/"


func _rooms_url(count: int) -> String:
	return server_base() + "/get_rooms?count=" + str(count)


# Fetch `count` random rooms from the server.
func fetch_rooms(count: int) -> Array:
	if OS.has_feature("web"):
		return await _fetch_rooms_web(count)
	return await _fetch_rooms_native(count)


func _fetch_rooms_web(count: int) -> Array:
	var url := _rooms_url(count)
	print("[RoomService] requesting rooms from: ", url)
	# On web the browser handles gzip transparently, so HTTPRequest works fine.
	var http := HTTPRequest.new()
	http.accept_gzip = false
	add_child(http)
	# Poll even while the tree is paused (title screen pauses before fetching).
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	var err = http.request(url)
	if err != OK:
		push_warning("RoomService: could not start room request (err %s)." % err)
		http.queue_free()
		return []
	var result = await http.request_completed
	http.queue_free()
	# result = [result_code, response_code, headers, body]
	print("[RoomService] /get_rooms response: result=", result[0], " http_code=", result[1])
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		push_warning("RoomService: could not fetch rooms (code %s)." % result[1])
		return []
	return _parse_rooms(result[3].get_string_from_utf8())


func _fetch_rooms_native(count: int) -> Array:
	# The lab proxy gzips the body even when we ask for identity, and Godot's
	# HTTPRequest auto-decompress fails on it (RESULT_BODY_DECOMPRESS_FAILED). So
	# on native we use HTTPClient to get the raw bytes and decompress ourselves.
	var url := _rooms_url(count)
	# Split scheme://host[:port]/path?query
	var use_ssl := url.begins_with("https://")
	var rest := url.substr(url.find("://") + 3)
	var slash := rest.find("/")
	var host := rest
	var path := "/"
	if slash != -1:
		host = rest.substr(0, slash)
		path = rest.substr(slash)
	var port := 443 if use_ssl else 80
	if host.contains(":"):
		var hp := host.split(":")
		host = hp[0]
		port = int(hp[1])

	var client := HTTPClient.new()
	var tls := TLSOptions.client() if use_ssl else null
	if client.connect_to_host(host, port, tls) != OK:
		push_warning("RoomService: could not connect to server. Returning no rooms.")
		return []
	while client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		client.poll()
		await get_tree().process_frame
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_warning("RoomService: could not connect (status %s)." % client.get_status())
		return []

	if client.request(HTTPClient.METHOD_GET, path, ["Accept-Encoding: identity"]) != OK:
		push_warning("RoomService: could not start room request.")
		return []
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		await get_tree().process_frame

	var http_code := client.get_response_code()
	var resp_headers := client.get_response_headers_as_dictionary()
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() == 0:
			await get_tree().process_frame
		else:
			body.append_array(chunk)

	print("[RoomService] /get_rooms response (native): http_code=", http_code, " bytes=", body.size())
	if http_code != 200:
		push_warning("RoomService: could not fetch rooms (code %s)." % http_code)
		return []

	# Decompress manually if the server compressed the body anyway.
	var enc := ""
	for k in resp_headers:
		if String(k).to_lower() == "content-encoding":
			enc = String(resp_headers[k]).to_lower()
	if enc.contains("gzip"):
		body = body.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	elif enc.contains("deflate"):
		body = body.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)

	return _parse_rooms(body.get_string_from_utf8())


func _parse_rooms(body_text: String) -> Array:
	var parsed = JSON.parse_string(body_text)
	if typeof(parsed) != TYPE_ARRAY:
		push_warning("RoomService: unexpected room data. Body: " + body_text.left(200))
		return []
	return parsed
