class_name PlatformMovement
extends Node


enum PlatformMovementActions { MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, JUMP, JUMP_HELD }

var settings: PlatformMovementSettings
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

var body: CharacterBody3D
var is_moving := false

var _jump_buffer_remaining := 0.0
var _action_state: Dictionary[PlatformMovementActions, bool] = {
	PlatformMovementActions.MOVE_UP: false,
	PlatformMovementActions.MOVE_DOWN: false,
	PlatformMovementActions.MOVE_LEFT: false,
	PlatformMovementActions.MOVE_RIGHT: false,
	PlatformMovementActions.JUMP: false,
	PlatformMovementActions.JUMP_HELD: false,
}


func set_intent(move: Vector2, jump_pressed: bool, jump_held: bool) -> void:
	_action_state[PlatformMovementActions.MOVE_LEFT] = move.x < 0.0
	_action_state[PlatformMovementActions.MOVE_RIGHT] = move.x > 0.0
	_action_state[PlatformMovementActions.MOVE_UP] = move.y < 0.0
	_action_state[PlatformMovementActions.MOVE_DOWN] = move.y > 0.0
	_action_state[PlatformMovementActions.JUMP] = jump_pressed
	_action_state[PlatformMovementActions.JUMP_HELD] = jump_held


func _physics_process(delta: float) -> void:
	_move(delta)


func _move(delta: float) -> void:
	var direction := Vector3.ZERO

	if is_moving:
		if _action_state[PlatformMovementActions.MOVE_UP]:
			direction.z -= 1
		if _action_state[PlatformMovementActions.MOVE_DOWN]:
			direction.z += 1
		if _action_state[PlatformMovementActions.MOVE_RIGHT]:
			direction.x += 1
		if _action_state[PlatformMovementActions.MOVE_LEFT]:
			direction.x -= 1
		if direction != Vector3.ZERO:
			direction = direction.normalized()

	var horizontal_velocity := body.velocity
	horizontal_velocity.y = 0

	var target := direction * settings.speed

	# The dot product (direction.dot(hvel)) checks if the object is already
	# moving in the same direction as the input.
	# Choose if accelerates or decelerates
	var accel: float
	if direction.dot(horizontal_velocity) > 0:
		accel = settings.acceleration
	else:
		accel = settings.deceleration

	horizontal_velocity = horizontal_velocity.lerp(target, 1.0 - exp(-accel * delta))

	var vertical := body.velocity.y
	var on_floor := body.is_on_floor()
	if on_floor:
		vertical = 0.0

	# The jump buffer remembers a recent press until landing
	if _action_state[PlatformMovementActions.JUMP]:
		_jump_buffer_remaining = settings.jump_buffer_time
	else:
		_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)

	if on_floor and _jump_buffer_remaining > 0.0:
		vertical = settings.jump_velocity
		_jump_buffer_remaining = 0.0

	# Heavier gravity while rising without holding jump (jump cut)
	if vertical > 0.0:
		var rise_gravity := gravity
		if not _action_state[PlatformMovementActions.JUMP_HELD]:
			rise_gravity *= settings.jump_cut_gravity_multiplier
		vertical -= rise_gravity * delta
	elif not on_floor:
		vertical -= gravity * settings.fall_gravity_multiplier * delta

	body.velocity = Vector3(horizontal_velocity.x, vertical, horizontal_velocity.z)

	var horizontal_movement := Vector3(body.velocity.x, 0, body.velocity.z)
	if horizontal_movement.length_squared() > 0.1:
		var target_yaw := atan2(-horizontal_movement.x, -horizontal_movement.z)
		body.global_rotation.y = lerp_angle(
		body.global_rotation.y, target_yaw, 1.0 - exp(-settings.turn_speed * delta)
	)

	body.move_and_slide()
