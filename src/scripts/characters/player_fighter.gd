class_name PlayerFighter
extends Fighter


func _gather_input(_delta: float) -> void:
	var move := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	movement.set_intent(
		move,
		Input.is_action_just_pressed("action_jump"),
		Input.is_action_pressed("action_jump")
	)

	if Input.is_action_just_pressed("action_attack"):
		request_attack()
