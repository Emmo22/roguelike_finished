class_name EnemyStateStun extends EnemyState

@export var anim_name : String = "stun"
@export var knockback_speed : float = 300.0
@export var decelerate_speed : float = 20.0

@export_category("AI")
@export var next_state : EnemyState

# Fixed stun length (matches the ~0.3s stun animation). Driven by a SceneTreeTimer,
# so leaving stun does NOT depend on this node's _process running — that dependency
# (via animation_finished + a Process() counter) is what left enemies stuck in stun
# far too long whenever the state machine wasn't ticking reliably.
const STUN_DURATION : float = 0.35

var _damage_position : Vector2
var _direction : Vector2


func init() -> void:
	enemy.enemy_damaged.connect(_on_enemy_damaged)
	pass


func enter() -> void:
	enemy.invulnerable = true
	_direction = enemy.global_position.direction_to(_damage_position)
	enemy.SetDirection(_direction)
	enemy.velocity = _direction * -knockback_speed
	enemy.UpdateAnimation(anim_name)
	get_tree().create_timer(STUN_DURATION).timeout.connect(_force_exit)
	pass


func Exit() -> void:
	enemy.invulnerable = false
	pass


func Process(_delta: float) -> EnemyState:
	enemy.velocity -= enemy.velocity * decelerate_speed * _delta
	return null


func Physics(_delta : float) -> EnemyState:
	return null


func _on_enemy_damaged(hurtbox : Hurtbox) -> void:
	_damage_position = hurtbox.global_position
	state_machine.change_state( self )


func _force_exit() -> void:
	# Only act if we're still the active stun; a stale timer must not yank a later state.
	if is_instance_valid(enemy) and state_machine.current_state == self:
		state_machine.change_state(next_state)
