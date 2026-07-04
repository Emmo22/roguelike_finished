class_name Enemy extends CharacterBody2D

signal direction_changed( new_direction: Vector2)
signal enemy_damaged(hurtbox : Hurtbox)
signal enemy_destroyed(hurtbox : Hurtbox)

const DIR_4 = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

@export var hp : int = 2

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO
var player : Player
var invulnerable : bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite : Sprite2D = $Sprite2D
@onready var hitbox : Hitbox = $Hitbox
@onready var state_machine : EnemyStateMachine = $EnemyStateMachine

func _ready():
	state_machine.initialize(self)
	player = PlayerManager.player
	hitbox.Damaged.connect(_take_damage)
	pass


func _process(_delta):
	pass


func _physics_process(_delta):
	move_and_slide()

func SetDirection(_new_direction : Vector2) -> bool:
	direction = _new_direction
	if direction == Vector2.ZERO:
		return false
		
	var direction_id : int = int (round(
		(direction + cardinal_direction * 0.1).angle()
		/TAU * DIR_4.size()
	))
	var new_dir = DIR_4[direction_id]
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


func disable_attacks() -> void:
	# Turn off every damage-dealing Hurtbox (body contact + attack) so a dying
	# enemy can't still hit the player during its destroy/knockback animation —
	# including the ~0.65s after the sprite has faded but the node still exists.
	# We walk the tree with an explicit `is Hurtbox` check instead of
	# find_children("*", "Hurtbox", ...): that type filter doesn't reliably match
	# script class_names, so it can return nothing and leave the hurtboxes live.
	for hb in _find_hurtboxes(self):
		# active=false takes effect THIS frame (it's a plain var, safe to set inside
		# the physics signal of the killing hit) — so the hurtbox stops dealing damage
		# instantly, with no one-frame gap. monitoring/monitorable are still turned off
		# (deferred, as required mid-physics) so the area also stops registering overlaps.
		hb.active = false
		hb.set_deferred("monitoring", false)
		hb.set_deferred("monitorable", false)


func _find_hurtboxes(node: Node) -> Array:
	var result : Array = []
	for child in node.get_children():
		if child is Hurtbox:
			result.append(child)
		result.append_array(_find_hurtboxes(child))
	return result


func _take_damage(hurtbox : Hurtbox) -> void:
	if invulnerable == true:
		return
	hp -= hurtbox.damage
	PlayerManager.shake_camera()
	if hp > 0:
		enemy_damaged.emit(hurtbox)
	else:
		enemy_destroyed.emit(hurtbox)
	
