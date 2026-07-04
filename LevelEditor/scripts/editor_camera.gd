extends Camera2D

@export var zoom_level : float = 1.0 :
	set(value):
		zoom_level = value
		zoom = Vector2(zoom_level, zoom_level)

func _ready() -> void:
	zoom = Vector2(zoom_level, zoom_level)
	make_current()
