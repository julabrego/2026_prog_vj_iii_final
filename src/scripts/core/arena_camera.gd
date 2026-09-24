@tool
extends Camera3D

@export var target_path: NodePath:
	set(value):
		target_path = value
		_request_layout()

@export var smoothness: float = 5.0

@export var perspective: bool = false:
	set(value):
		perspective = value
		_request_layout()
		notify_property_list_changed()

@export var yaw_degrees: float = 45.0:
	set(value):
		yaw_degrees = value
		_request_layout()

@export var pitch_degrees: float = -30.0:
	set(value):
		pitch_degrees = value
		_request_layout()

@export var distance: float = 30.0:
	set(value):
		distance = value
		_request_layout()

@export var ortho_size: float = 20.0:
	set(value):
		ortho_size = value
		_request_layout()

@export_range(1.0, 120.0, 0.5, "degrees") var fov_degrees: float = 35.0:
	set(value):
		fov_degrees = value
		_request_layout()

var target: Node3D
var camera_offset: Vector3
var _layout_dirty := false
var _last_layout_request_ms := 0


func _ready() -> void:
	_apply_layout()
	set_physics_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	if not _layout_dirty:
		return
	if Engine.is_editor_hint():
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			return
		if Time.get_ticks_msec() - _last_layout_request_ms < 80:
			return
	_layout_dirty = false
	_apply_layout()


func _request_layout() -> void:
	_layout_dirty = true
	_last_layout_request_ms = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired_pos := target.global_position + camera_offset
	var weight := 1.0 - exp(-smoothness * delta)
	global_position = global_position.lerp(desired_pos, weight)


func _validate_property(property: Dictionary) -> void:
	if property.name == "ortho_size" and perspective:
		property.usage = PROPERTY_USAGE_NONE
	elif property.name == "fov_degrees" and not perspective:
		property.usage = PROPERTY_USAGE_NONE


func _apply_layout() -> void:
	if not is_node_ready():
		return
	if perspective:
		projection = Camera3D.PROJECTION_PERSPECTIVE
		fov = fov_degrees
	else:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = ortho_size
	rotation_degrees = Vector3(pitch_degrees, yaw_degrees, 0.0)
	camera_offset = global_transform.basis.z * distance
	target = get_node_or_null(target_path) if not target_path.is_empty() else null
	var origin := target.global_position if target else Vector3.ZERO
	global_position = origin + camera_offset
