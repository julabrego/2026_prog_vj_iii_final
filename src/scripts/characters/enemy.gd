extends CharacterBody3D

enum FighterAction { ATTACK }
enum FighterState { MOVING, ATTACKING }

@export var opponent : Node3D
@export var stop_distance := 2.5
@export var attack_distance := 2.0
@export var attack_cooldown := 0.8

@export var run_delay := 0.83
var _run_delay_remaining := run_delay

var is_facing_jumpable := false
@export var jump_anticipation_time := 0.25
@export var level_height_tolerance := 0.3
@export var jump_hold_time := 0.35
var _jump_hold_remaining := 0.0
var _jump_anticipation_time_remaining := 0.0
var _must_jump := false


@onready var _jump_intention_detector = $JumpIntentionDetector

var _attack_cooldown_remaining := 0.0

var current_animation := ""

var _fighter_state := FighterState.MOVING

@onready var animator: FighterAnimator = $FighterAnimator
@onready var animation_player: AnimationPlayer = $Mannequin_Medium/AnimationPlayer
@onready
var punch_hitbox: Area3D = $Mannequin_Medium/Rig_Medium/Skeleton3D/Hand_Right_Attachment/PunchArea
@onready var movement: PlatformMovement = $PlatformMovement


func request_attack() -> bool:
	if _fighter_state != FighterState.MOVING:
		return false
	_fighter_state = FighterState.ATTACKING
	return true

func _ready() -> void:
	movement.body = self
	animator.setup(self, animation_player)
	animator.attack_finished.connect(_on_attack_finished)
	punch_hitbox.body_entered.connect(_on_punch_body_entered)


func _physics_process(delta: float) -> void:
	_gather_ai_input(delta)
	movement.is_moving = _fighter_state == FighterState.MOVING
	animator.is_attacking = _fighter_state == FighterState.ATTACKING



func _gather_ai_input(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)

	if not is_instance_valid(opponent):
		movement.set_intent(Vector2.ZERO, false, false)
		return

	var to_opponent := opponent.global_position - global_position
	to_opponent.y = 0
	
	var move := Vector2.ZERO

	if to_opponent.length() > stop_distance:
		if _run_delay_remaining > 0.0:
			_run_delay_remaining = maxf(_run_delay_remaining - delta, 0.0) 
		else:
			move = Vector2(to_opponent.x, to_opponent.z).normalized()

	if to_opponent.length() <= attack_distance and _attack_cooldown_remaining <= 0.0:
		if request_attack():
			_attack_cooldown_remaining = attack_cooldown
			_run_delay_remaining = 0.0

	if is_on_floor():
		var on_other_level := absf(opponent.global_position.y - global_position.y) > level_height_tolerance
		var on_lower_level = (opponent.global_position.y - global_position.y) < 0

		var _sees_pit = not on_lower_level and (_jump_intention_detector.get_overlapping_bodies().any(
				func(b: Node3D) -> bool: return b.is_in_group("pit")
			)
		or _jump_intention_detector.get_overlapping_areas().any(
			func(b: Node3D) -> bool: return b.is_in_group("pit")
			)
		)
		
		var _sees_jumpable = _sees_pit or (on_other_level and (
		_jump_intention_detector.get_overlapping_bodies().any(
			func(b: Node3D) -> bool: return b.is_in_group("jumpable")
			)
		or _jump_intention_detector.get_overlapping_areas().any(
			func(b: Node3D) -> bool: return b.is_in_group("jumpable")
			)
		)) 

		if _sees_jumpable:
			_jump_anticipation_time_remaining += delta
			print("tengo que saltar oh")
			if _sees_pit or _jump_anticipation_time_remaining >= jump_anticipation_time:
				_jump_anticipation_time_remaining = 0.0
				_must_jump = true
				_jump_hold_remaining = jump_hold_time
		else:
			_jump_anticipation_time_remaining = 0.0
	else:
		_jump_anticipation_time_remaining = 0.0

	var jump_pressed := false
	if _must_jump:
		jump_pressed = true
		_must_jump = false

	var jump_held := _jump_hold_remaining > 0.0
	if jump_held:
		_jump_hold_remaining -= delta

	movement.set_intent(move, jump_pressed, jump_held)


func _on_punch_body_entered(body: Node3D) -> void:
	if body.is_in_group("hittable"):
		print("Punch hit: ", body.name)


func _on_attack_finished() -> void:
	_fighter_state = FighterState.MOVING
