class_name EnemyStateChase extends EnemyState

@export var anim_name : String = "walk"
@export var chase_speed : float = 60.0
@export var turn_rate : float = 0.25


@export_category("AI")
@export var state_aggro_duration : float = 0.5
@export var next_state : EnemyState
@export var vision_area: VisionArea
@export var attack_area: Hurtbox 

var _timer : float = 0.0
var _direction : Vector2
var _can_see_player : bool = false


func init() -> void:
	if vision_area:
		vision_area.player_entered.connect(_on_player_enter)
		vision_area.player_exited.connect(_on_player_exit)
	pass
	

func enter() -> void:
	_timer = state_aggro_duration
	enemy.UpdateAnimation(anim_name)
	if attack_area:
		attack_area.monitoring = true
		
	pass



func Exit() -> void:
	if attack_area:
		attack_area.monitoring = false
	_can_see_player = false
	pass



func Process(_delta: float) -> EnemyState:
	if PlayerManager.player.hp <= 0:
		return next_state
		
	var new_dir : Vector2 = enemy.global_position.direction_to(PlayerManager.player.global_position)
	_direction = lerp(_direction, new_dir, turn_rate)
	enemy.velocity = _direction * chase_speed
	
	if enemy.SetDirection(_direction):
		enemy.UpdateAnimation(anim_name)
	
	
	if _can_see_player == false:
		_timer -= _delta
		if _timer < 0:
			return next_state
	else:
		_timer = state_aggro_duration
	return null



func Physics(_delta : float) -> EnemyState:
	return null


func _on_player_enter() -> void:
	_can_see_player = true
	if state_machine.current_state is EnemyStateStun:
		return
	state_machine.change_state(self)
	pass


func _on_player_exit() -> void:
	_can_see_player = false
	pass
