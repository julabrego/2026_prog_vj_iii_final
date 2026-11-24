class_name Fighter
extends CharacterBody3D


enum FighterState { MOVING, ATTACKING }

var _fighter_state := FighterState.MOVING

@export var movement_settings: PlatformMovementSettings

@onready var movement: PlatformMovement = $PlatformMovement
@onready var animator: FighterAnimator = $FighterAnimator
@onready var animation_player: AnimationPlayer = $Mannequin_Medium/AnimationPlayer
@onready
var punch_hitbox: Area3D = $Mannequin_Medium/Rig_Medium/Skeleton3D/Hand_Right_Attachment/PunchArea


func _ready() -> void:
	movement.body = self
	movement.settings = movement_settings
	animator.setup(self, animation_player)
	animator.attack_finished.connect(_on_attack_finished)
	punch_hitbox.body_entered.connect(_on_punch_body_entered)

func _physics_process(delta: float) -> void:
	_gather_input(delta)
	movement.is_moving = _fighter_state == FighterState.MOVING
	animator.is_attacking = _fighter_state == FighterState.ATTACKING


func _gather_input(_delta: float) -> void:
	pass


func request_attack() -> bool:
	if _fighter_state != FighterState.MOVING:
		return false
	_fighter_state = FighterState.ATTACKING
	return true


func _on_punch_body_entered(body: Node3D) -> void:
	if body.is_in_group("hittable"):
		print("Punch hit: ", body.name)


func _on_attack_finished() -> void:
	_fighter_state = FighterState.MOVING
