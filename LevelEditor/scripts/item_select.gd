extends Control

const SAVE_PATH = "user://level.json"
const GAME_SCENE = "res://world/game.tscn"

# In a web export the game is served from the same host as the backend, so we
# use relative URLs. In the editor/desktop there is no host, so fall back to
# the local dev server.
static func server_base() -> String:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("window.location.origin")
	return "https://dungeon-delver.wiai-lab.de/"

@onready var upload_url: String = server_base() + "/upload_level"

@onready var start_button: Button = $Button
@onready var http_upload: HTTPRequest = $HTTPRequest

var _warn_dialog: AcceptDialog


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	http_upload.request_completed.connect(_on_upload_completed)

	# Popup shown when the level can't be started (e.g. door walled off).
	_warn_dialog = AcceptDialog.new()
	_warn_dialog.title = "Achtung"
	_warn_dialog.ok_button_text = "OK"
	_warn_dialog.confirmed.connect(func(): LevelManager.skip_next_click = true)
	add_child(_warn_dialog)

	# The lab's HTTPS proxy gzip-compresses responses, and Godot's HTTPRequest
	# fails to decompress that gzip (RESULT_BODY_DECOMPRESS_FAILED, result==8).
	# Don't request gzip, so the proxy returns the body uncompressed.
	http_upload.accept_gzip = false


func _on_start_pressed() -> void:
	var scene = get_tree().current_scene
	var level_node: Node = scene.get_node("Level")
	var custom_walls: TileMapLayer = scene.get_node("Level/Room00/CustomWalls")

	# Make sure the player hasn't walled the door off (or boxed in their spawn).
	if not _door_reachable(scene):
		_show_warning("Die Tür ist blockiert! Schaffe einen Weg frei, bevor du startest.")
		return

	start_button.disabled = true
	var data = _build_data(custom_walls, level_node)
	_save_local(data)
	_upload(data)

	# Fetch 3 random rooms from the server for rooms 2-4 (room 1 is the one the
	# player just built). RoomService centralises the web/native HTTP handling.
	var others = await RoomService.fetch_rooms(3)

	print("[ItemSelect] fetched ", others.size(), " server rooms. Total session rooms: ", 1 + others.size())
	print("[ItemSelect] is_web=", OS.has_feature("web"), " upload_url=", upload_url)

	GameSession.start_session(data, others)
	LevelManager.load_new_level(GAME_SCENE, "", Vector2.ZERO)


func _show_warning(text: String) -> void:
	_warn_dialog.dialog_text = text
	_warn_dialog.popup_centered()
	print("[ItemSelect] start blocked: ", text)


# Flood-fill from the player's spawn over walkable floor cells and check that a
# door cell is reachable. Walls (both the room's base walls and the player's
# custom walls) block movement, matching the in-game tile collision.
func _door_reachable(scene: Node) -> bool:
	var boden: TileMapLayer = scene.get_node("Level/Room00/Boden")
	var waende_base: TileMapLayer = scene.get_node("Level/Room00/Waende_base")
	var custom_walls: TileMapLayer = scene.get_node("Level/Room00/CustomWalls")
	var door: TileMapLayer = scene.get_node("Level/Room00/door")
	var spawn: Node2D = scene.get_node("Level/PlayerSpawn")

	# Run the search in CustomWalls cell-space; convert to world to query the
	# other layers (each layer may have its own offset).
	var start: Vector2i = custom_walls.local_to_map(custom_walls.to_local(spawn.global_position))
	if not _is_passable(start, boden, waende_base, custom_walls, door):
		return false

	var neighbors := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var visited := { start: true }
	var stack := [start]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if _is_door(cell, custom_walls, door):
			return true
		for n in neighbors:
			var ncell: Vector2i = cell + n
			if visited.has(ncell):
				continue
			if _is_passable(ncell, boden, waende_base, custom_walls, door):
				visited[ncell] = true
				stack.append(ncell)
	return false


func _cell_to_world(cell: Vector2i, custom_walls: TileMapLayer) -> Vector2:
	return custom_walls.to_global(custom_walls.map_to_local(cell))


func _is_passable(cell: Vector2i, boden: TileMapLayer, waende_base: TileMapLayer, custom_walls: TileMapLayer, door: TileMapLayer) -> bool:
	var world := _cell_to_world(cell, custom_walls)
	# Blocked by a base wall or a painted custom wall.
	if waende_base.get_cell_source_id(waende_base.local_to_map(waende_base.to_local(world))) != -1:
		return false
	if custom_walls.get_cell_source_id(cell) != -1:
		return false
	# Must stand on floor or on the door.
	var has_floor := boden.get_cell_source_id(boden.local_to_map(boden.to_local(world))) != -1
	return has_floor or _is_door(cell, custom_walls, door)


func _is_door(cell: Vector2i, custom_walls: TileMapLayer, door: TileMapLayer) -> bool:
	var world := _cell_to_world(cell, custom_walls)
	return door.get_cell_source_id(door.local_to_map(door.to_local(world))) != -1


func _on_upload_completed(result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("Level upload failed - server may not be running.")


func _build_data(custom_walls: TileMapLayer, level_node: Node) -> Dictionary:
	var walls = []
	for cell in custom_walls.get_used_cells():
		var coords = custom_walls.get_cell_atlas_coords(cell)
		walls.append({ "x": cell.x, "y": cell.y, "tile": coords.x })

	var enemies = []
	for child in level_node.get_children():
		if child is Enemy:
			enemies.append({
				"x": child.global_position.x,
				"y": child.global_position.y,
				"scene": child.scene_file_path
			})

	return { "walls": walls, "enemies": enemies }


func _save_local(data: Dictionary) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file: " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Level saved locally: ", ProjectSettings.globalize_path(SAVE_PATH))


func _upload(data: Dictionary) -> void:
	var body = JSON.stringify(data)
	var headers = ["Content-Type: application/json", "Accept-Encoding: identity"]
	http_upload.request(upload_url, headers, HTTPClient.METHOD_POST, body)
	print("Level uploaded to server.")
