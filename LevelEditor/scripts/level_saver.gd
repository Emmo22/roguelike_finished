extends Node

# Change this path to wherever you want the file saved.
# user:// maps to: C:\Users\<you>\AppData\Roaming\Godot\app_userdata\<project>\
const SAVE_PATH = "user://level.json"


func save(custom_walls: TileMapLayer, level_node: Node) -> void:
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

	var data = { "walls": walls, "enemies": enemies }
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("Level saved to: ", ProjectSettings.globalize_path(SAVE_PATH))


func load_level(custom_walls: TileMapLayer, level_node: Node) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("No saved level found at: " + SAVE_PATH)
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data == null:
		push_error("Failed to parse level JSON.")
		return

	custom_walls.clear()
	for wall in data["walls"]:
		custom_walls.set_cell(Vector2i(wall["x"], wall["y"]), 0, Vector2i(wall["tile"], 0))

	for enemy_data in data["enemies"]:
		var packed = load(enemy_data["scene"]) as PackedScene
		if packed == null:
			continue
		var enemy = packed.instantiate()
		level_node.add_child(enemy)
		enemy.global_position = Vector2(enemy_data["x"], enemy_data["y"])
