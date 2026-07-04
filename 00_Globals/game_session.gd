extends Node

# Holds the state of one play-through: the 4 rooms and which one we're in.
var rooms: Array = []
var current_index: int = 0


func start_session(first_room: Dictionary, other_rooms: Array) -> void:
	rooms = [first_room]
	rooms.append_array(other_rooms)
	current_index = 0


# Start a play-through from a ready-made list of rooms (e.g. the title screen's
# "Spielen" mode, where all rooms come from the server and none is player-built).
func start_rooms(all_rooms: Array) -> void:
	rooms = all_rooms.duplicate()
	current_index = 0


func has_session() -> bool:
	return rooms.size() > 0


func current_room() -> Dictionary:
	if current_index >= 0 and current_index < rooms.size():
		return rooms[current_index]
	return {}


func is_last_room() -> bool:
	return current_index >= rooms.size() - 1


func advance() -> void:
	current_index += 1


func reset() -> void:
	rooms = []
	current_index = 0
