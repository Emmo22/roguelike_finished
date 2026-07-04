extends Node

const PLAYER = preload("uid://dsofsq8ngjuf5")


signal camera_shook(trauma : float)

var player : Player
var player_spawned : bool = false

func _ready() -> void:
	add_player_instance()
	await get_tree().create_timer(0.5).timeout
	player_spawned = true



func add_player_instance() -> void:
	player = PLAYER.instantiate()
	get_tree().current_scene.add_child(player)
	pass


func set_player_position(_new_pos : Vector2) -> void:
	player.global_position = _new_pos
	pass
	
	
func set_as_parent(_p : Node) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	_p.add_child(player)


func unparent_player(_p : Node) -> void:
	if player.get_parent() == _p:
		_p.remove_child(player)


func shake_camera(trauma : float = 1) -> void:
	camera_shook.emit(trauma)
