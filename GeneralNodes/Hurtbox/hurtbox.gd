class_name Hurtbox extends Area2D

@export var damage : int = 1

# When false this hurtbox deals no damage, even if its Area2D is still monitoring.
# A dying enemy flips this immediately (see Enemy.disable_attacks) so there is no
# one-frame window — unlike set_deferred("monitoring", false), which only applies
# at the end of the frame and let dead enemies still hit the player.
var active : bool = true

func _ready():
	area_entered.connect(AreaEntered)
	pass


func _process(delta):
	pass


func AreaEntered( a: Area2D) -> void:
	if active and a is Hitbox:
		a.TakeDamage(self)
	pass
