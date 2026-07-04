extends CanvasLayer


@export var button_focus_audio : AudioStream = preload("res://title_scene/audio/menu_focus.wav")
@export var button_select_audio : AudioStream = preload("res://title_scene/audio/menu_select.wav")


var hearts : Array[HeartGUI] = []

@onready var game_over: Control = $Control/GameOver
@onready var title_button: Button = $Control/GameOver/VBoxContainer/title
@onready var continue_button: Button = $Control/GameOver/VBoxContainer/fortsetzen
@onready var animation_player: AnimationPlayer = $Control/GameOver/AnimationPlayer
@onready var game_won: Control = $Control/GameWon
@onready var won_title_button: Button = $Control/GameWon/VBoxContainer/title
@onready var won_continue_button: Button = $Control/GameWon/VBoxContainer/fortsetzen
@onready var won_animation_player: AnimationPlayer = $Control/GameWon/AnimationPlayer
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D



func _ready():
	for child in $Control/HFlowContainer.get_children():
		if child is HeartGUI:
			hearts.append(child)
			child.visible = false

	hide_game_over_stream()
	hide_game_won()
	continue_button.focus_entered.connect(play_audio.bind(button_focus_audio))
	continue_button.pressed.connect(_on_continue_pressed)
	title_button.focus_entered.connect(play_audio.bind(button_focus_audio))
	title_button.pressed.connect(title_screen)
	won_title_button.focus_entered.connect(play_audio.bind(button_focus_audio))
	won_title_button.pressed.connect(title_screen)
	won_continue_button.visible = false

	LevelManager.level_load_started.connect(hide_game_over_stream)
	LevelManager.level_load_started.connect(hide_game_won)
	pass



func update_hp( _hp : int, _max_hp : int ) -> void:
	update_max_hp(_max_hp)
	var _heart_count : int = roundi(_max_hp * 0.5)
	for i in _heart_count:
		update_heart(i, _hp)
	pass


func update_heart(_index : int, _hp : int) -> void:
	var _value : int = clampi( _hp - _index * 2, 0, 2)
	hearts[_index].value = _value
	pass

func update_max_hp(_max_hp : int) -> void:
	var _heart_count : int = roundi(_max_hp * 0.5)
	for i in hearts.size():
		if i < _heart_count:
			hearts[i].visible = true
		else:
			hearts[i].visible = false
	pass


func show_game_over_screen():
	game_over.visible = true
	game_over.mouse_filter = Control.MOUSE_FILTER_STOP
	# Bring back the mouse cursor and put focus on a button so the screen is usable
	# with mouse and controller (X), just like the title screen and editor.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	continue_button.grab_focus()
	animation_player.play("show_game_over")


func show_game_won() -> void:
	game_won.visible = true
	game_won.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	won_title_button.grab_focus()
	won_animation_player.play("show_game_over")


func _input(event: InputEvent) -> void:
	# Press the focused button with the controller's X button while a game-over /
	# won screen is up (mirrors the title screen / controls popup behaviour).
	if not (game_over.visible or game_won.visible):
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		var focused := get_viewport().gui_get_focus_owner()
		if focused is BaseButton:
			focused.pressed.emit()
			get_viewport().set_input_as_handled()


func hide_game_won() -> void:
	game_won.visible = false
	game_won.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_won.modulate = Color(1, 1, 1, 0)
	won_animation_player.stop()


func hide_game_over_stream() -> void:
	game_over.visible = false
	game_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over.modulate = Color(1, 1, 1, 0)
	animation_player.stop()

func _on_continue_pressed() -> void:
	play_audio(button_select_audio)
	await fade_to_black()
	PlayerManager.player.global_position = LevelManager.saved_player_position
	PlayerManager.player.set_physics_process(true)
	PlayerManager.player.set_process(true)
	hide_game_over_stream()


func title_screen() -> void:
	play_audio(button_select_audio)
	await fade_to_black()
	LevelManager.load_new_level("res://title_scene/TitleScene.tscn", "", Vector2.ZERO)


func fade_to_black() -> bool:
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	PlayerManager.player.revive_player()
	return true




func play_audio(_a : AudioStream) -> void:
	audio.stream = _a
	audio.play()
