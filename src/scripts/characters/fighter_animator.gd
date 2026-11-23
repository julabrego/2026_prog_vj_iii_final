class_name FighterAnimator
extends Node

signal attack_finished

const ANIMATION_PREFIX := "Player/"
const PUNCH_ANIMATION := &"Player/Punch"

@export var max_speed := 14.0

var body: CharacterBody3D
var animation_player: AnimationPlayer
var is_attacking := false

var _current_animation := ""


func setup(new_body: CharacterBody3D, new_animation_player: AnimationPlayer) -> void:
	body = new_body
	animation_player = new_animation_player
	animation_player.animation_finished.connect(_on_animation_finished)


func _physics_process(_delta: float) -> void:
	_update_animation()


func _update_animation() -> void:
	if is_attacking:
		_play("Punch")
	elif not body.is_on_floor():
		_play("Jump_Idle")
	else:
		var horizontal := Vector3(body.velocity.x, 0, body.velocity.z)
		if horizontal.length_squared() > 0.1:
			var speed_ratio := clampf(horizontal.length() / max_speed, 0.0, 1.0)
			var animation_speed := lerpf(0.5, 1.0, speed_ratio) * 1.5
			_play("Walking_A", animation_speed)
		else:
			_play("Idle_A")


func _play(animation_name: String, animation_speed := 1.0) -> void:
	animation_player.speed_scale = animation_speed

	if _current_animation == animation_name and animation_player.is_playing():
		return

	_current_animation = animation_name
	animation_player.play(ANIMATION_PREFIX + animation_name)


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == PUNCH_ANIMATION:
		attack_finished.emit()
