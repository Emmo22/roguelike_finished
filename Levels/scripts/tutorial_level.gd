class_name TutorialLevel extends Level

# The tutorial is a single room: the door is disabled (see level_transition.gd)
# and the game is won once every enemy in the room has been defeated.

var _enemies_spawned : bool = false
var _won : bool = false


func _ready() -> void:
	super._ready()
	PlayerManager.player.process_mode = Node.PROCESS_MODE_INHERIT
	PlayerManager.player.set_process(true)
	PlayerManager.player.set_physics_process(true)
	PlayerHud.visible = true
	# Wait one frame so the enemies are present in the tree before we count them.
	await get_tree().process_frame
	_enemies_spawned = _count_enemies() > 0


func _process(_delta : float) -> void:
	if _won or not _enemies_spawned:
		return
	if _count_enemies() == 0:
		_win()


func _win() -> void:
	_won = true
	PlayerManager.player.set_physics_process(false)
	PlayerHud.show_game_won()


func _count_enemies() -> int:
	var count : int = 0
	for child in get_children():
		if child is Enemy and not child.is_queued_for_deletion():
			count += 1
	return count
