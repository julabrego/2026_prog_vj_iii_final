extends CharacterBody3D
class_name Fighter


enum FighterAction { ATTACK }
enum FighterState { MOVING, ATTACKING }

var current_animation := ""

var _fighter_state := FighterState.MOVING

@onready var animator: FighterAnimator = $FighterAnimator
@onready var animation_player: AnimationPlayer = $Mannequin_Medium/AnimationPlayer
@onready
var punch_hitbox: Area3D = $Mannequin_Medium/Rig_Medium/Skeleton3D/Hand_Right_Attachment/PunchArea

@onready var movement: PlatformMovement = $PlatformMovement


func request_attack() -> void:
	if _fighter_state == FighterState.MOVING:
		_fighter_state = FighterState.ATTACKING


func _ready() -> void:
	movement.body = self
	animator.setup(self, animation_player)
	animator.attack_finished.connect(_on_attack_finished)
	punch_hitbox.body_entered.connect(_on_punch_body_entered)


func _physics_process(delta: float) -> void:
	_gather_player_input()
	movement.is_moving = _fighter_state == FighterState.MOVING
	animator.is_attacking = _fighter_state == FighterState.ATTACKING


func _gather_player_input() -> void:
	var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	movement.set_intent(
		move,
		Input.is_action_just_pressed("action_jump"),
		Input.is_action_pressed("action_jump")
	)

	if Input.is_action_just_pressed("action_attack"):
		request_attack()


func _on_punch_body_entered(body: Node3D) -> void:
	if body.is_in_group("hittable"):
		print("Punch hit: ", body.name)


func _on_attack_finished() -> void:
	_fighter_state = FighterState.MOVING
