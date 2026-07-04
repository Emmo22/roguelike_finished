extends Node

# Temporary diagnostic autoload. Logs every connected joypad plus all button
# and axis activity to the console, so we can see whether Godot detects the
# controller and which indices it reports. Remove once controllers work.

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_print_connected()


func _print_connected() -> void:
	var pads := Input.get_connected_joypads()
	print("[JoypadDebug] connected joypads: ", pads)
	for id in pads:
		print("[JoypadDebug]   device ", id,
			" name='", Input.get_joy_name(id),
			"' guid=", Input.get_joy_guid(id))
	if pads.is_empty():
		print("[JoypadDebug]   (none — Godot sees no controller)")


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	print("[JoypadDebug] device ", device, " connected=", connected,
		" name='", Input.get_joy_name(device), "'")


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		print("[JoypadDebug] BUTTON device=", event.device, " index=", event.button_index)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		print("[JoypadDebug] AXIS device=", event.device,
			" axis=", event.axis, " value=", snappedf(event.axis_value, 0.01))
