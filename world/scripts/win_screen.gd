extends Control

const TITLE_SCENE = "res://title_scene/TitleScene.tscn"

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	get_tree().paused = false
	back_button.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
