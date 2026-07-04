extends TextureRect

@export var this_scene : PackedScene
@export var tile : bool = false
@export var tile_id = 0
var object_cursor
var cursor_sprite


func _ready() -> void:
	object_cursor = get_tree().current_scene.get_node("CanvasLayer/Editor_Object")
	cursor_sprite = object_cursor.get_node("Sprite2D")
	connect("gui_input", _item_clicked)


func _item_clicked(event) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("mb_left"):
		select()


# Select this palette entry. Called by the mouse (gui_input) and directly by the
# controller cursor in editor_object, so both paths share one code path.
func select() -> void:
	if !tile:
		object_cursor.current_item = this_scene
		LevelManager.place_tile = false
	else:
		LevelManager.place_tile = true
		LevelManager.current_tile = tile_id
	cursor_sprite.texture = texture
