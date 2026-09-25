extends CharacterBody3D

enum FighterAction {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	JUMP,
	JUMP_HELD
}

@export var speed := 14.0
@export var jump_velocity := 10.0
@export var acceleration := 5.0
@export var deceleration := 4.0
@export var turn_speed := 10.0

@export var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
@export var fall_gravity_multiplier := 1.4
@export var jump_cut_gravity_multiplier := 2.0
@export var jump_buffer_time := 0.1

var action_state: Dictionary[FighterAction, bool] = {
	FighterAction.MOVE_UP: false,
	FighterAction.MOVE_DOWN: false,
	FighterAction.MOVE_LEFT: false,
	FighterAction.MOVE_RIGHT: false,
	FighterAction.JUMP: false,
	FighterAction.JUMP_HELD: false
}

# Timing state for the jump buffer, not intent
var _jump_buffer_remaining := 0.0


func _physics_process(delta: float) -> void:
	_gather_player_input()
	_move(delta)


func _gather_player_input() -> void:
	action_state[FighterAction.MOVE_UP] = Input.is_action_pressed("ui_up")
	action_state[FighterAction.MOVE_DOWN] = Input.is_action_pressed("ui_down")
	action_state[FighterAction.MOVE_LEFT] = Input.is_action_pressed("ui_left")
	action_state[FighterAction.MOVE_RIGHT] = Input.is_action_pressed("ui_right")
	# JUMP stores edge semantics: true only on the frame it was pressed
	action_state[FighterAction.JUMP] = Input.is_action_just_pressed("action_jump")
	# JUMP_HELD stores level semantics: true every frame the button is down
	action_state[FighterAction.JUMP_HELD] = Input.is_action_pressed("action_jump")


func _move(delta: float) -> void:
	var direction := Vector3.ZERO

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

	if horizontal_movement.length_squared() > 0.1:
		var target_yaw := atan2(-horizontal_movement.x, -horizontal_movement.z)
		# Smoothly turn towards it instead of snapping
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw,
				1.0 - exp(-turn_speed * delta))

	move_and_slide()
