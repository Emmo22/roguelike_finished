class_name EnemyStateDestroy extends EnemyState

@export var anim_name : String = "destroy"
@export var knockback_speed : float = 300.0
@export var decelerate_speed : float = 20.0

@export_category("AI")

# How long the death animation plays before the enemy is removed.
const DESTROY_TIMEOUT : float = 1.0

var _damage_position : Vector2
var _direction : Vector2
var _freeing : bool = false


func init() -> void:
	enemy.enemy_destroyed.connect(_on_enemy_destroyed)
	pass


func enter() -> void:
	enemy.invulnerable = true
	enemy.disable_attacks()
	_direction = enemy.global_position.direction_to(_damage_position)
	enemy.SetDirection(_direction)
	enemy.velocity = _direction * -knockback_speed
	enemy.UpdateAnimation(anim_name)
	# Free the enemy after the death animation via a SceneTreeTimer rather than a
	# counter in Process() or the animation_finished signal. The timer is driven by
	# the SceneTree, so it fires even if this enemy's state machine ever stops
	# processing — which is exactly what left dead enemies frozen on their first
	# destroy frame, invulnerable and uncountable, blocking the win.
	if not _freeing:
		_freeing = true
		get_tree().create_timer(DESTROY_TIMEOUT).timeout.connect(_free_enemy)
	pass



func Exit() -> void:
	pass



func Process(_delta: float) -> EnemyState:
	enemy.velocity -= enemy.velocity * decelerate_speed * _delta
	return null



func Physics(_delta : float) -> EnemyState:
	return null



func _on_enemy_destroyed(hurtbox : Hurtbox) -> void:
	_damage_position = hurtbox.global_position
	state_machine.change_state( self )


func _free_enemy() -> void:
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy.queue_free()
