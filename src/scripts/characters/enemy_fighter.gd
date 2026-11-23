class_name EnemyFighter
extends Fighter


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
var _jump_requested := false


@onready var _jump_intention_detector = $JumpIntentionDetector

var _attack_cooldown_remaining := 0.0

var current_animation := ""


func _gather_input(delta: float) -> void:
	_tick_cooldowns(delta);

	if not is_instance_valid(opponent):
		movement.set_intent(Vector2.ZERO, false, false)
		return

	var distance_to_opponent := _distance_to_opponent()
	
	var move := _set_move_direction(distance_to_opponent, delta)
	_try_attack(distance_to_opponent)
	_update_jump_anticipation(delta)

	movement.set_intent(move, _consume_jump_press(), _is_jump_held(delta))

func _tick_cooldowns(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)


func _distance_to_opponent() -> Vector3:
	var distance := opponent.global_position - global_position
	distance.y = 0.0
	return distance


func _set_move_direction(distance: Vector3, delta: float) -> Vector2:
	if distance.length() <= stop_distance:
		return Vector2.ZERO
	if _run_delay_remaining > 0.0:
		_run_delay_remaining = maxf(_run_delay_remaining - delta, 0.0) 
		return Vector2.ZERO

	return Vector2(distance.x, distance.z).normalized()


func _try_attack(distance: Vector3) -> void:
	if distance.length() > attack_distance or _attack_cooldown_remaining > 0.0:
		return

	if request_attack():
		_attack_cooldown_remaining = attack_cooldown
		_run_delay_remaining = 0.0


func _update_jump_anticipation(delta: float) -> void:
	if not is_on_floor():
		_jump_anticipation_time_remaining = 0.0
		return

	var height_difference := opponent.global_position.y - global_position.y
	var on_other_level := absf(height_difference) > level_height_tolerance
	var on_lower_level = height_difference < 0.0
	var _sees_pit = not on_lower_level and _detector_sees_group("pit")
	var _sees_jumpable = _sees_pit or (on_other_level and _detector_sees_group("jumpable"))

	if not _sees_jumpable:
		_jump_anticipation_time_remaining = 0.0
		return

	_jump_anticipation_time_remaining += delta
	if _sees_pit or _jump_anticipation_time_remaining >= jump_anticipation_time:
		_jump_anticipation_time_remaining = 0.0
		_jump_requested = true
		_jump_hold_remaining = jump_hold_time


func _detector_sees_group(group: StringName) -> bool:
	return _jump_intention_detector.get_overlapping_bodies().any(
		func(b: Node3D) -> bool: return b.is_in_group(group)
		) or _jump_intention_detector.get_overlapping_areas().any(
		func(b: Node3D) -> bool: return b.is_in_group(group)
		)

func _consume_jump_press() -> bool:
	var pressed := _jump_requested
	_jump_requested = false
	return pressed


func _is_jump_held(delta: float) -> bool:
	var held := _jump_hold_remaining > 0.0
	if held:
		_jump_hold_remaining -= delta
	return held
