class_name LevelTileMap extends TileMapLayer

func _ready():
	LevelManager.ChangeTilemapBounds(GetTilemapBounds())
	pass
	


func GetTilemapBounds() -> Array[Vector2]:
	var tile_size = tile_set.tile_size
	var bounds : Array[Vector2]
	bounds.append(
		Vector2(get_used_rect().position * tile_size)
	)
	bounds.append(
		Vector2(get_used_rect().end * tile_size)
	)
	return bounds
