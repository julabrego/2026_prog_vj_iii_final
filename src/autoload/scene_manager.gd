extends Node
## Autoload scene manager: ordered named scene lists, async loading, navigation.
##
## Lists are data-driven [SceneList] resources registered on this autoload.
## Navigation (next/prev/go_to) operates on the active list. Scene changes use
## [ResourceLoader] threaded loading with progress signals, then a deferred-safe
## root swap.

signal scene_load_started(list: String, scene_id: String, path: String)
signal scene_load_progress(progress: float)
signal scene_changed(list: String, scene_id: String, path: String)
signal active_list_changed(list: String)
signal scene_load_failed(path: String, error: String)

## Scene lists registered at startup (optional; folder below is used when empty).
@export var initial_lists: Array[SceneList] = []
## Folder scanned for SceneList .tres files when [member initial_lists] is empty.
@export var lists_folder: String = "res://resources/scene_lists"
## Wrap next/prev at list ends.
@export var wrap_navigation: bool = true

var _lists: Dictionary = {}
var _active_list: String = ""
var _current_index: int = -1
var _current_id: String = ""
var _current_path: String = ""
var _loading: bool = false
var _pending_path: String = ""
var _pending_list: String = ""
var _pending_id: String = ""
var _pending_index: int = -1


func _ready() -> void:
	for list in initial_lists:
		register_list(list)
	if _lists.is_empty():
		_register_lists_from_folder(lists_folder)
	if _active_list.is_empty() and not _lists.is_empty():
		_active_list = _lists.keys()[0]
	# current_scene is not available yet while autoloads enter the tree.
	call_deferred("_sync_current_from_tree")


func _process(_delta: float) -> void:
	if not _loading:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_pending_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				scene_load_progress.emit(float(progress[0]))
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_pending_path)
			_loading = false
			if packed == null or not (packed is PackedScene):
				scene_load_failed.emit(_pending_path, "Loaded resource is not a PackedScene")
				return
			_finish_swap(packed)
		ResourceLoader.THREAD_LOAD_FAILED:
			_loading = false
			scene_load_failed.emit(_pending_path, "THREAD_LOAD_FAILED")
			push_error("SceneManager: failed to load '%s'" % _pending_path)
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = false
			scene_load_failed.emit(_pending_path, "THREAD_LOAD_INVALID_RESOURCE")
			push_error("SceneManager: invalid resource '%s'" % _pending_path)


# --- Registry API ---

func register_list(list: SceneList) -> void:
	if list == null or list.list_name.is_empty():
		push_error("SceneManager: register_list requires a SceneList with a name")
		return
	_lists[list.list_name] = list
	if _active_list.is_empty():
		_active_list = list.list_name


func unregister_list(list_name: String) -> void:
	_lists.erase(list_name)
	if _active_list == list_name:
		_active_list = _lists.keys()[0] if not _lists.is_empty() else ""


func has_list(list_name: String) -> bool:
	return _lists.has(list_name)


func get_list(list_name: String) -> SceneList:
	return _lists.get(list_name)


func get_list_names() -> Array[String]:
	var names: Array[String] = []
	names.assign(_lists.keys())
	return names


func set_active_list(list_name: String) -> void:
	if not _lists.has(list_name):
		push_error("SceneManager: unknown list '%s'" % list_name)
		return
	if _active_list == list_name:
		return
	_active_list = list_name
	active_list_changed.emit(list_name)


func get_active_list() -> SceneList:
	return _lists.get(_active_list)


func get_active_list_name() -> String:
	return _active_list


# --- Navigation API ---

func go_next() -> void:
	var list := get_active_list()
	if list == null or list.is_empty() or _loading:
		return
	if _current_index < 0:
		go_to(0)
		return
	var next := _current_index + 1
	if next >= list.size():
		if not wrap_navigation:
			return
		next = 0
	go_to(next)


func go_prev() -> void:
	var list := get_active_list()
	if list == null or list.is_empty() or _loading:
		return
	if _current_index < 0:
		go_to(list.size() - 1)
		return
	var prev := _current_index - 1
	if prev < 0:
		if not wrap_navigation:
			return
		prev = list.size() - 1
	go_to(prev)


func go_to(index: int) -> void:
	var list := get_active_list()
	if list == null or _loading:
		return
	if not list.has_index(index):
		push_error("SceneManager: index %d out of bounds for list '%s'" % [index, _active_list])
		return
	_start_load(list.get_path_at(index), _active_list, index, list.get_id_at(index))


func go_to_id(scene_id: String) -> void:
	var list := get_active_list()
	if list == null or _loading:
		return
	var index := list.index_of_id(scene_id)
	if index == -1:
		push_error("SceneManager: id '%s' not found in list '%s'" % [scene_id, _active_list])
		return
	go_to(index)


func go_to_list(list_name: String, index: int = 0) -> void:
	if not _lists.has(list_name):
		push_error("SceneManager: unknown list '%s'" % list_name)
		return
	if _loading:
		return
	set_active_list(list_name)
	go_to(index)


func go_to_path(path: String) -> void:
	if _loading:
		return
	_start_load(path, _active_list, -1, SceneList.id_from_path(path))


# --- State queries ---

func is_loading() -> bool:
	return _loading


func get_progress() -> float:
	if not _loading:
		return 0.0
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_pending_path, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS and not progress.is_empty():
		return float(progress[0])
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	return 0.0


func get_current_index() -> int:
	return _current_index


func get_current_id() -> String:
	return _current_id


func get_current_path() -> String:
	return _current_path


# --- Internals ---

func _start_load(path: String, list_name: String, index: int, scene_id: String) -> void:
	if path.is_empty():
		push_error("SceneManager: empty scene path")
		return
	if _loading:
		return
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		scene_load_failed.emit(path, "load_threaded_request error %d" % err)
		push_error("SceneManager: cannot request load of '%s' (error %d)" % [path, err])
		return
	_loading = true
	_pending_path = path
	_pending_list = list_name
	_pending_id = scene_id
	_pending_index = index
	scene_load_started.emit(list_name, scene_id, path)


func _finish_swap(packed: PackedScene) -> void:
	var tree := get_tree()
	var old_scene := tree.current_scene
	var inst := packed.instantiate()
	tree.root.add_child(inst)
	if old_scene != null and is_instance_valid(old_scene):
		old_scene.free()
	tree.current_scene = inst
	_current_path = _pending_path
	_current_id = _pending_id
	_current_index = _pending_index
	if _current_index == -1:
		var list := get_active_list()
		if list != null:
			_current_index = list.index_of_id(_pending_id)
	scene_changed.emit(_pending_list, _pending_id, _pending_path)


func _sync_current_from_tree() -> void:
	var tree := get_tree()
	var current := tree.current_scene
	if current == null:
		return
	var path := current.scene_file_path
	if path.is_empty():
		return
	_current_path = path
	_current_id = SceneList.id_from_path(path)
	for list_name in _lists:
		var list: SceneList = _lists[list_name]
		var idx := list.index_of_id(_current_id)
		if idx != -1:
			_current_index = idx
			if _active_list != list_name:
				set_active_list(list_name)
			return


func _register_lists_from_folder(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var res := load(folder.path_join(file_name))
		if res is SceneList:
			register_list(res)
