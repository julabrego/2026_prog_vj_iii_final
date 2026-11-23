extends CharacterBody3D

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

#
# func _animate() -> void:
# 	var horizontal_movement := Vector3(velocity.x, 0, velocity.z)
# 	var speed = movement.speed
#
# 	if _fighter_state == FighterState.ATTACKING:
# 		_play_animation("Punch")
# 	elif not is_on_floor():
# 		_play_animation("Jump_Idle")
# 	elif horizontal_movement.length_squared() > 0.1:
# 		var horizontal_speed := horizontal_movement.length()
# 		var speed_ratio := clampf(horizontal_speed / speed, 0.0, 1.0)
# 		var animation_speed := lerpf(0.5, 1.0, speed_ratio) * 1.5
#
# 		_play_animation("Walking_A", animation_speed)
# 	else:
# 		_play_animation("Idle_A")
#
#
# func _move(delta: float) -> void:
# 	var direction := Vector3.ZERO
#
# 	if _fighter_state == FighterState.MOVING:
# 		if action_state[FighterAction.MOVE_UP]:
# 			direction.z -= 1
# 		if action_state[FighterAction.MOVE_DOWN]:
# 			direction.z += 1
# 		if action_state[FighterAction.MOVE_RIGHT]:
# 			direction.x += 1
# 		if action_state[FighterAction.MOVE_LEFT]:
# 			direction.x -= 1
# 		if direction != Vector3.ZERO:
# 			direction = direction.normalized()
#
# 	var horizontal_velocity := velocity
# 	horizontal_velocity.y = 0
#
# 	var target := direction * speed
#
# 	# The dot product (direction.dot(hvel)) checks if the object is already
# 	# moving in the same direction as the input.
# 	# Choose if accelerates or decelerates
# 	var accel: float
# 	if direction.dot(horizontal_velocity) > 0:
# 		accel = acceleration
# 	else:
# 		accel = deceleration
#
# 	horizontal_velocity = horizontal_velocity.lerp(target, 1.0 - exp(-accel * delta))
#
# 	var vertical := velocity.y
# 	var on_floor := is_on_floor()
# 	if on_floor:
# 		vertical = 0.0
#
# 	# The jump buffer remembers a recent press until landing
# 	if action_state[FighterAction.JUMP]:
# 		_jump_buffer_remaining = jump_buffer_time
# 	else:
# 		_jump_buffer_remaining = maxf(_jump_buffer_remaining - delta, 0.0)
#
# 	if on_floor and _jump_buffer_remaining > 0.0:
# 		vertical = jump_velocity
# 		_jump_buffer_remaining = 0.0
#
# 	# Heavier gravity while rising without holding jump (jump cut)
# 	if vertical > 0.0:
# 		var rise_gravity := gravity
# 		if not action_state[FighterAction.JUMP_HELD]:
# 			rise_gravity *= jump_cut_gravity_multiplier
# 		vertical -= rise_gravity * delta
# 	elif not on_floor:
# 		vertical -= gravity * fall_gravity_multiplier * delta
#
# 	velocity = Vector3(horizontal_velocity.x, vertical, horizontal_velocity.z)
#
# 	var horizontal_movement := Vector3(velocity.x, 0, velocity.z)
#
# 	if horizontal_movement.length_squared() > 0.1:
# 		var target_yaw := atan2(-horizontal_movement.x, -horizontal_movement.z)
# 		# Smoothly turn towards it instead of snapping
# 		global_rotation.y = lerp_angle(
# 			global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta)
# 		)
#
# 	move_and_slide()

	
# func _update_state() -> void:
# 	if action_state[FighterAction.ATTACK] and _fighter_state == FighterState.MOVING:
# 		_enter_attack()
#
#
# func _enter_attack() -> void:
# 	_fighter_state = FighterState.ATTACKING
# 	_play_animation("Punch")
#
#
func _on_punch_body_entered(body: Node3D) -> void:
	if body.is_in_group("hittable"):
		print("Punch hit: ", body.name)

# func _play_animation(animation_name: String, animation_speed := 1.0) -> void:
# 	animation_player.speed_scale = animation_speed
#
# 	if current_animation == animation_name and animation_player.is_playing():
# 		return
#
# 	current_animation = animation_name
# 	animation_player.play("Player/" + animation_name)
#

func _on_attack_finished() -> void:
	_fighter_state = FighterState.MOVING
