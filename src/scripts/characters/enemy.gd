extends CharacterBody3D

enum FighterAction { MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, JUMP, JUMP_HELD, ATTACK }
enum FighterState { MOVING, ATTACKING }

@export var speed := 14.0
@export var jump_velocity := 10.0
@export var acceleration := 5.0
@export var deceleration := 4.0
@export var turn_speed := 10.0

@export var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@export var fall_gravity_multiplier := 1.4
@export var jump_cut_gravity_multiplier := 2.0
@export var jump_buffer_time := 0.1

@export var opponent : Node3D
@export var stop_distance := 2.5
@export var attack_distance := 2.0
@export var attack_cooldown := 0.8

var _attack_cooldown_remaining := 0.0

var current_animation := ""

var action_state: Dictionary[FighterAction, bool] = {
	FighterAction.MOVE_UP: false,
	FighterAction.MOVE_DOWN: false,
	FighterAction.MOVE_LEFT: false,
	FighterAction.MOVE_RIGHT: false,
	FighterAction.JUMP: false,
	FighterAction.JUMP_HELD: false,
	FighterAction.ATTACK: false
}

# Timing state for the jump buffer, not intent
var _jump_buffer_remaining := 0.0
var _fighter_state := FighterState.MOVING

@onready var animation_player: AnimationPlayer = $Mannequin_Medium/AnimationPlayer
@onready
var punch_hitbox: Area3D = $Mannequin_Medium/Rig_Medium/Skeleton3D/Hand_Right_Attachment/PunchArea


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	punch_hitbox.body_entered.connect(_on_punch_body_entered)


func _physics_process(delta: float) -> void:
	_gather_ai_input(delta)
	_update_state()
	_move(delta)


func _gather_ai_input(delta: float) -> void:
	for action in action_state:
		action_state[action] = false

	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)

	if not is_instance_valid(opponent):
		return

	var to_opponent := opponent.global_position - global_position
	to_opponent.y = 0
	
	if to_opponent.length() > stop_distance:
		action_state[FighterAction.MOVE_UP] = to_opponent.z < -0.1
		action_state[FighterAction.MOVE_DOWN] = to_opponent.z > 0.1
		action_state[FighterAction.MOVE_LEFT] = to_opponent.x < -0.1
		action_state[FighterAction.MOVE_RIGHT] = to_opponent.x > 0.1

	if to_opponent.length() <= attack_distance and _attack_cooldown_remaining <= 0.0:
		action_state[FighterAction.ATTACK] = true
		_attack_cooldown_remaining = attack_cooldown
	
func _move(delta: float) -> void:
	var direction := Vector3.ZERO
	 
	if _fighter_state == FighterState.MOVING:
		if action_state[FighterAction.MOVE_UP]:
			direction.z -= 1
		if action_state[FighterAction.MOVE_DOWN]:
			direction.z += 1
		if action_state[FighterAction.MOVE_RIGHT]:
			direction.x += 1
		if action_state[FighterAction.MOVE_LEFT]:
			direction.x -= 1
		if direction != Vector3.ZERO:
			direction = direction.normalized()

	var horizontal_velocity := velocity
	horizontal_velocity.y = 0

	var target := direction * speed

	# The dot product (direction.dot(hvel)) checks if the object is already
	# moving in the same direction as the input.
	# Choose if accelerates or decelerates
	var accel: float
	if direction.dot(horizontal_velocity) > 0:
		accel = acceleration
	else:
		accel = deceleration

	horizontal_velocity = horizontal_velocity.lerp(target, 1.0 - exp(-accel * delta))

	var vertical := velocity.y
	var on_floor := is_on_floor()
	if on_floor:
		vertical = 0.0

	# The jump buffer remembers a recent press until landing
	if action_state[FighterAction.JUMP]:
		_jump_buffer_remaining = jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)

	if on_floor and _jump_buffer_remaining > 0.0:
		vertical = jump_velocity
		_jump_buffer_remaining = 0.0

	# Heavier gravity while rising without holding jump (jump cut)
	if vertical > 0.0:
		var rise_gravity := gravity
		if not action_state[FighterAction.JUMP_HELD]:
			rise_gravity *= jump_cut_gravity_multiplier
		vertical -= rise_gravity * delta
	elif not on_floor:
		vertical -= gravity * fall_gravity_multiplier * delta

	velocity = Vector3(horizontal_velocity.x, vertical, horizontal_velocity.z)

	var horizontal_movement := Vector3(velocity.x, 0, velocity.z)

	var to_opponent := Vector3.ZERO
	if is_instance_valid(opponent):
		to_opponent = opponent.global_position - global_position
		to_opponent.y = 0

	var face_direction := horizontal_movement
	if is_instance_valid(opponent) and (_fighter_state == FighterState.ATTACKING or horizontal_movement.length_squared() > 0.1 or to_opponent.length() < stop_distance):
		face_direction = opponent.global_position - global_position
		face_direction.y = 0

	if face_direction.length_squared() > 0.1:
		var target_yaw := atan2(-face_direction.x, -face_direction.z)
		# Smoothly turn towards it instead of snapping
		global_rotation.y = lerp_angle(
			global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta)
		)

	move_and_slide()

	if _fighter_state == FighterState.ATTACKING:
		_play_animation("Punch")
	elif not is_on_floor():
		_play_animation("Jump_Idle")
	elif horizontal_movement.length_squared() > 0.1:
		var horizontal_speed := horizontal_movement.length()
		var speed_ratio := clampf(horizontal_speed / speed, 0.0, 1.0)
		var animation_speed := lerpf(0.5, 1.0, speed_ratio) * 1.5

		_play_animation("Walking_A", animation_speed)
	else:
		_play_animation("Idle_A")


func _update_state() -> void:
	if action_state[FighterAction.ATTACK] and _fighter_state == FighterState.MOVING:
		_enter_attack()


func _enter_attack() -> void:
	_fighter_state = FighterState.ATTACKING
	_play_animation("Punch")


func _on_punch_body_entered(body: Node3D) -> void:
	if body.is_in_group("hittable"):
		print("Punch hit: ", body.name)


func _play_animation(animation_name: String, animation_speed := 1.0) -> void:
	animation_player.speed_scale = animation_speed

	if current_animation == animation_name and animation_player.is_playing():
		return

	current_animation = animation_name
	animation_player.play("Player/" + animation_name)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"Player/Punch" and _fighter_state == FighterState.ATTACKING:
		_fighter_state = FighterState.MOVING
