extends Area2D

# Passive door trigger — GameRoom arms this via body_entered.
# _ready() explicitly disables monitoring and disconnects any connections
# that level_transition.gd may have established via its level_loaded await.

func _ready() -> void:
	monitoring = false
	for conn in body_entered.get_connections():
		body_entered.disconnect(conn["callable"])
	# Watch for level_transition.gd reconnecting after level_loaded fires.
	LevelManager.level_loaded.connect(_on_level_loaded)

func _on_level_loaded() -> void:
	print("[GameTransition] _on_level_loaded fired, connections=", body_entered.get_connections().size())
	monitoring = false
	for conn in body_entered.get_connections():
		body_entered.disconnect(conn["callable"])
