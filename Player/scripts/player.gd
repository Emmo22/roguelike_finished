class_name Player extends CharacterBody2D


signal direction_changed( new_direction : Vector2)
signal player_damaged(hurtbox : Hurtbox)


var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO

var invulnerable : bool = false
var hp : int = 6
var max_hp : int = 6

@onready var animation_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var effect_animation_player: AnimationPlayer = $EffectAnimationPlayer
@onready var sprite : Sprite2D = $Sprite2D
@onready var state_machine : Playerstatemachine = $StateMachine
@onready var hitbox: Hitbox = $Hitbox


func _ready():
	PlayerManager.player = self
	state_machine.Initialize(self)
	hitbox.Damaged.connect(_take_damage)
	update_hp(99)
	pass


func _process (_delta):
	direction = Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	).normalized()
	pass


func _physics_process(delta: float) -> void:
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	pass


func SetDirection() -> bool:
	var new_dir : Vector2 = cardinal_direction
	if direction == Vector2.ZERO:
		return false
		
	if direction.y == 0: 
		new_dir = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
	elif direction.x == 0:
		new_dir = Vector2.UP if direction.y < 0 else Vector2.DOWN
		
	if new_dir == cardinal_direction:
		return false
		
	cardinal_direction = new_dir
	direction_changed.emit(new_dir)
	sprite.scale.x = -1 if cardinal_direction == Vector2.LEFT else 1
	return true


func UpdateAnimation(state : String) -> void:
	animation_player.play(state + "_" + AnimDirection())
	pass


func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"


func _take_damage(hurtbox : Hurtbox) -> void:
	if invulnerable == true:
		return
		
	if hp > 0:
		update_hp(-hurtbox.damage)
		player_damaged.emit(hurtbox)
	
	pass
	


func update_hp(delta : int) -> void:
	hp = clampi(hp + delta, 0, max_hp)
	PlayerHud.update_hp(hp, max_hp)
	pass
	


func make_invulnerable(_duration : float = 1.0) -> void:
	invulnerable = true
	hitbox.monitoring = false
	await get_tree().create_timer(_duration).timeout
	invulnerable = false 
	hitbox.monitoring = true
	pass


func revive_player():
	update_hp(99)
	state_machine.ChangeState($StateMachine/Idle)
