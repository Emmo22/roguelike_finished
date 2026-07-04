class_name ControlsPopup
extends CanvasLayer

signal closed

@onready var close_button: Button = $Panel/Margin/VBox/TitleBar/CloseButton


func _ready() -> void:
	close_button.pressed.connect(_on_close)
	# LevelManager unpauses the tree at the end of load_new_level, then emits
	# level_loaded. We wait for that signal so we pause AFTER it unpauses —
	# otherwise LevelManager would undo our pause immediately.
	LevelManager.level_loaded.connect(_on_level_loaded, CONNECT_ONE_SHOT)


func _on_level_loaded() -> void:
	get_tree().paused = true


# Close with the controller's X button too. This CanvasLayer is PROCESS_MODE_ALWAYS,
# so _input still fires while the popup has the tree paused.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		_on_close()


func _on_close() -> void:
	get_tree().paused = false
	LevelManager.skip_next_click = true
	closed.emit()
	queue_free()
