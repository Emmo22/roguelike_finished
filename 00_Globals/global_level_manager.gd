extends Node

signal level_load_started
signal level_loaded
signal TileMapBoundsChanged(bounds : Array[Vector2])

var current_tilemap_bounds : Array[Vector2]
var target_transition : String
var position_offset : Vector2
var saved_player_position : Vector2
var current_tile = 0
var place_tile = false
var skip_next_click = false

const TITLE_SCENE = "res://title_scene/TitleScene.tscn"

func _ready() -> void:
	await get_tree().process_frame
	level_loaded.emit()

func _input(event: InputEvent) -> void:
	# "ui_cancel" is the built-in Escape key; "esc" is our own action mapped to
	# Escape + LB (left shoulder, joypad button 9). Listen for both so the
	# controller's LB returns to the title just like the Escape key.
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("esc")) \
			and not get_tree().paused:
		load_new_level(TITLE_SCENE, "", Vector2.ZERO)

func ChangeTilemapBounds(bounds : Array[Vector2]) -> void:
	current_tilemap_bounds = bounds
	TileMapBoundsChanged.emit(bounds)


func load_new_level(
	level_path : String,
	_target_transition : String,
	_position_offset: Vector2
) -> void:

	get_tree().paused = true
	target_transition = _target_transition
	position_offset = _position_offset
	saved_player_position = PlayerManager.player.global_position

	await SceneTransition.fade_out()

	level_load_started.emit()

	await get_tree().process_frame

	PlayerManager.set_as_parent(self)
	get_tree().change_scene_to_file(level_path)

	await SceneTransition.fade_in()

	PlayerManager.player.visible = true
	place_tile = false
	skip_next_click = false
	get_tree().paused = false

	await get_tree().process_frame

	level_loaded.emit()
	pass
