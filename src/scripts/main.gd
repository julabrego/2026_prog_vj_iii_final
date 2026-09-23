extends Node


func _ready() -> void:
	SceneManager.call_deferred("go_to_list", "MainFlow", 0)
