class_name Plant extends Node2D

func _ready():
	$Hitbox.Damaged.connect(TakeDamage)
	pass
	
func TakeDamage(_damage: int) -> void:
	queue_free()
