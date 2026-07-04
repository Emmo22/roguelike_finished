class_name GameRoom extends Node2D

const GAME_SCENE = "res://world/game.tscn"
const CONTROLS_POPUP = preload("res://GUI/controls_popup/controls_popup.tscn")

# Levels saved on the server before the slime scene was split into blue/red still
# reference the old "slime.tscn", which no longer exists. Remap such orphaned
# paths so enemies from those rooms still spawn instead of being silently skipped.
const ENEMY_SCENE_ALIASES := {
	"res://Enemies/slime/slime.tscn": "res://Enemies/slime/slime_blue.tscn",
}

# Set these node paths in the editor to match game.tscn's structure.
@export var custom_walls_path: NodePath = "Room00/CustomWalls"
@export var transition_path: NodePath = "Room00/LevelTransition"
@export var spawn_path: NodePath = "PlayerSpawn"

@onready var custom_walls: TileMapLayer = get_node(custom_walls_path)
@onready var transition: Area2D = get_node(transition_path)
@onready var spawn: Node2D = get_node_or_null(spawn_path)

var _last_room: bool = false
# Number of enemies in this room still alive. We count down via each enemy's
# "enemy_destroyed" signal (fires the moment its HP hits 0) instead of polling
# the child list every frame — that's deterministic and doesn't depend on _process
# running or on the ~1s death animation finishing before we detect the win.
var _alive_enemies: int = 0
var _won: bool = false


func _ready() -> void:
	self.y_sort_enabled = true
	PlayerManager.set_as_parent(self)
	LevelManager.level_load_started.connect(_free_level)

	# The editor freezes the player (PROCESS_MODE_DISABLED); make sure it's fully
	# active again in-game, otherwise it stays frozen.
	PlayerManager.player.process_mode = Node.PROCESS_MODE_INHERIT
	PlayerManager.player.set_process(true)
	PlayerManager.player.set_physics_process(true)
	PlayerManager.player.visible = true
	PlayerHud.visible = true

	_last_room = GameSession.is_last_room()

	# Show the controls popup on the very first room only (just after Start in the
	# editor). It pauses the tree on level_loaded and closes on X, exactly like the
	# tutorial — so the room is already built behind it and the game begins on close.
	if GameSession.current_index == 0:
		add_child(CONTROLS_POPUP.instantiate())

	print("[GameRoom] index=", GameSession.current_index, " total=", GameSession.rooms.size(), " last=", _last_room)

	_apply_room(GameSession.current_room())

	# Move the player to the spawn point BEFORE arming the door, so it isn't
	# sitting on the transition from the previous room (which would instantly
	# skip ahead).
	# Kill monitoring and strip any connections baked in by level_transition.gd
	# (its _ready() awaits level_loaded and re-enables the door on every room).
	transition.monitoring = false
	for conn in transition.body_entered.get_connections():
		transition.body_entered.disconnect(conn["callable"])

	if spawn:
		PlayerManager.player.global_position = spawn.global_position
		LevelManager.saved_player_position = spawn.global_position

	if not _last_room:
		call_deferred("_arm_door")


func _arm_door() -> void:
	# Wait one beat so physics syncs the player to the spawn point before
	# we enable monitoring — otherwise the Area2D fires instantly because
	# the physics body is still at the previous room's door position.
	await get_tree().create_timer(0.15).timeout
	if _last_room:
		return
	print("[GameRoom] door armed index=", GameSession.current_index)
	transition.monitoring = true
	if not transition.body_entered.is_connected(_on_transition_entered):
		transition.body_entered.connect(_on_transition_entered)


func _apply_room(room: Dictionary) -> void:
	if room.is_empty():
		push_warning("GameRoom: no room data in GameSession.")
		return

	# Paint custom walls
	custom_walls.clear()
	for wall in room.get("walls", []):
		var cell = Vector2i(int(wall["x"]), int(wall["y"]))
		custom_walls.set_cell(cell, 0, Vector2i(int(wall["tile"]), 0))

	# Spawn enemies
	for enemy_data in room.get("enemies", []):
		var scene_path : String = enemy_data["scene"]
		scene_path = ENEMY_SCENE_ALIASES.get(scene_path, scene_path)
		var packed = load(scene_path) as PackedScene
		if packed == null:
			push_warning("GameRoom: could not load enemy scene '%s'" % scene_path)
			continue
		var enemy = packed.instantiate()
		add_child(enemy)
		enemy.global_position = Vector2(enemy_data["x"], enemy_data["y"])
		_alive_enemies += 1
		enemy.enemy_destroyed.connect(_on_enemy_defeated)

	# Either this room had no enemies, or (on the last room) check whether we've
	# already met the win condition. Deferred so _win() never fires mid-_ready /
	# scene transition; per-enemy defeats below call _check_win() directly.
	call_deferred("_check_win")


func _on_enemy_defeated(_hurtbox: Hurtbox) -> void:
	_alive_enemies -= 1
	_check_win()


func _check_win() -> void:
	# Only the last room ends the run; earlier rooms just open their door instead.
	if _won or not _last_room:
		return
	if _alive_enemies <= 0:
		_won = true
		_win()


func _on_transition_entered(body: Node2D) -> void:
	print("[GameRoom] DOOR TRIGGERED index=", GameSession.current_index, " last=", _last_room, " body=", body.name)
	if _last_room or not (body is Player):
		return
	transition.set_deferred("monitoring", false)
	GameSession.advance()
	LevelManager.load_new_level(GAME_SCENE, "", Vector2.ZERO)


func _win() -> void:
	print("[GameRoom] WIN at index=", GameSession.current_index)
	PlayerManager.player.set_physics_process(false)
	GameSession.reset()
	PlayerHud.show_game_won()


func _free_level() -> void:
	PlayerManager.unparent_player(self)
	queue_free()
