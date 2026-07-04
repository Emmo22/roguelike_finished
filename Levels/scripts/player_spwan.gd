extends Node2D


func _ready() -> void:
	visible = false
	PlayerManager.set_player_position.call_deferred(global_position)
	# The spawn point is also where "fortsetzen" (continue after game over) returns
	# the player. Without this the tutorial kept saved_player_position from the title
	# load, so continue dropped the player in the middle of the room instead of here.
	LevelManager.saved_player_position = global_position
