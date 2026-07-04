class_name State_Stun extends State

@export var knockback_speed : float = 250.0
@export var decelerate_speed : float = 20.0
@export var invulnerable_duration : float = 1.0

var hurtbox : Hurtbox 
var direction : Vector2

var next_state : State = null

@onready var idle : State = $"../Idle"
@onready var death: Node = $"../death"


func _ready():
	pass


func init() -> void:
	player.player_damaged.connect(_player_damaged)


func Enter() -> void:

	direction = player.global_position.direction_to(hurtbox.global_position)
	player.velocity = direction * -knockback_speed
	player.SetDirection()

	player.make_invulnerable(invulnerable_duration)
	player.effect_animation_player.play("damaged")
	player.UpdateAnimation("stun")
	
	player.get_tree().create_timer(player.animation_player.current_animation_length).timeout.connect(_stun_finished)
	PlayerManager.shake_camera(hurtbox.damage)

func Exit() -> void:
	next_state = null


func Process(_delta: float) -> State:
	return next_state


func Physics(_delta : float) -> State:
	player.velocity = player.velocity.move_toward(Vector2.ZERO, decelerate_speed)
	return null



func HandleInput(_event: InputEvent) -> State:
	return null


func _player_damaged(_hurtbox : Hurtbox) -> void:
	hurtbox = _hurtbox
	if state_machine.current_state != death:
		state_machine.ChangeState(self)
	pass


func _stun_finished() -> void:
	next_state = idle
	if player.hp <= 0:
		next_state = death
