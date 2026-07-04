extends Node

const START_LEVEL : String = "res://world/world.tscn"
const LEVEL_EDITOR : String = "res://LevelEditor/LevelEditor.tscn"
const GAME_SCENE : String = "res://world/game.tscn"

# How many random server rooms the "Spielen" mode plays through.
const PLAY_ROOM_COUNT : int = 4

@export var music : AudioStream
@export var button_focus_audio : AudioStream
@export var button_press_audio : AudioStream


@onready var button_tutorial: Button = $CanvasLayer/Control/Button_tutorial
@onready var button_builder: Button = $CanvasLayer/Control/Button_builder
@onready var button_spielen: Button = $CanvasLayer/Control/Button_spielen
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

# Guards against starting "Spielen" twice while the room fetch is in flight.
var _starting_play : bool = false




func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# The title state pauses the tree (see enter_title_state). Process while paused
	# so _input still fires for the controller; the buttons' CanvasLayer is also
	# set to PROCESS_MODE_ALWAYS, which is why the mouse already works.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Re-apply the title state after LevelManager finishes loading us,
	# because load_new_level un-hides the player and un-pauses the tree.
	LevelManager.level_loaded.connect(enter_title_state)
	enter_title_state()
	setup_title_screne()


func enter_title_state() -> void:
	get_tree().paused = true
	# The title root is PROCESS_MODE_ALWAYS so _input works while paused, but the
	# player is a child and would inherit ALWAYS too — explicitly freeze it so the
	# stick can't move the (hidden) player and drag the camera along.
	PlayerManager.player.process_mode = Node.PROCESS_MODE_DISABLED
	PlayerManager.player.visible = false
	PlayerHud.visible = false


func setup_title_screne() -> void:
	button_tutorial.pressed.connect(start_tutorial)
	button_builder.pressed.connect(start_level_editor)
	button_spielen.pressed.connect(start_spielen)

	button_tutorial.focus_entered.connect(play_audio.bind(button_focus_audio))
	button_builder.focus_entered.connect(play_audio.bind(button_focus_audio))
	button_spielen.focus_entered.connect(play_audio.bind(button_focus_audio))
	button_tutorial.grab_focus()
	


func start_tutorial() -> void:
	play_audio(button_press_audio)
	PlayerHud.visible = true
	LevelManager.load_new_level(START_LEVEL, "", Vector2.ZERO)


func start_level_editor() -> void:
	play_audio(button_press_audio)
	PlayerHud.visible = true
	LevelManager.load_new_level(LEVEL_EDITOR, "", Vector2.ZERO)


# "Spielen": play through 4 random server rooms, no level building. Same in-game
# flow as the editor's Start button (controls popup on room 1, win screen after
# the last room is cleared) — we just fill the session straight from the server.
func start_spielen() -> void:
	if _starting_play:
		return
	_starting_play = true
	play_audio(button_press_audio)

	var rooms := await RoomService.fetch_rooms(PLAY_ROOM_COUNT)
	if rooms.is_empty():
		push_warning("[Title] Keine Level vom Server erhalten — 'Spielen' abgebrochen.")
		_starting_play = false
		return

	GameSession.start_rooms(rooms)
	PlayerHud.visible = true
	LevelManager.load_new_level(GAME_SCENE, "", Vector2.ZERO)



func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		if button_tutorial.has_focus():
			start_tutorial()
		elif button_builder.has_focus():
			start_level_editor()
		elif button_spielen.has_focus():
			start_spielen()


func play_audio(_a : AudioStream) -> void:
	audio_stream_player_2d.stream = _a
	audio_stream_player_2d.play()
	
