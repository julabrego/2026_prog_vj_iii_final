extends Node
## Autoload scene manager: ordered named scene lists and navigation.
##
## Lists are data-driven [SceneList] resources registered on this autoload.
## Navigation (next/prev/go_to) operates on the active list. Godot's SceneTree
## handles scene changes and their lifecycle.

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
var _transitioning: bool = false


func _ready() -> void:
	for list in initial_lists:
		register_list(list)
	if _lists.is_empty():
		_register_lists_from_folder(lists_folder)
	if _lists.is_empty():
		push_error("SceneManager: no scene lists registered (check '%s')" % lists_folder)
	# current_scene is not available yet while autoloads enter the tree.
	call_deferred("_sync_current_from_tree")


# --- Registry API ---

func register_list(list: SceneList) -> void:
	if list == null or list.list_name.is_empty():
		push_error("SceneManager: register_list requires a SceneList with a name")
		return
	if _lists.has(list.list_name):
		push_error("SceneManager: duplicate list name '%s'" % list.list_name)
		return
	var ids: Dictionary = {}
	for path in list.scenes:
		if path.is_empty():
			push_error("SceneManager: empty scene path in list '%s'" % list.list_name)
			return
		var scene_id := SceneList.id_from_path(path)
		if ids.has(scene_id):
			push_error("SceneManager: duplicate scene id '%s' in list '%s'" % [scene_id, list.list_name])
			return
		ids[scene_id] = true
	_lists[list.list_name] = list
	if _active_list.is_empty():
		_active_list = list.list_name


func unregister_list(list_name: String) -> void:
	if not _lists.erase(list_name):
		return
	if _active_list == list_name:
		if _lists.is_empty():
			_active_list = ""
			_current_index = -1
			active_list_changed.emit("")
		else:
			set_active_list(_lists.keys()[0])


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
	var list: SceneList = _lists[list_name]
	_current_index = list.index_of_path(_current_path)
	active_list_changed.emit(list_name)


func get_active_list() -> SceneList:
	return _lists.get(_active_list)


func get_active_list_name() -> String:
	return _active_list


# --- Navigation API ---

func go_next() -> void:
	var list := get_active_list()
	if list == null or list.is_empty() or _transitioning:
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
	if list == null or list.is_empty() or _transitioning:
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
	if list == null or _transitioning:
		return
	if not list.has_index(index):
		push_error("SceneManager: index %d out of bounds for list '%s'" % [index, _active_list])
		return
	_change_scene(list.get_path_at(index), _active_list, index, list.get_id_at(index))


func go_to_id(scene_id: String) -> void:
	var list := get_active_list()
	if list == null or _transitioning:
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
	if _transitioning:
		return
	var list: SceneList = _lists[list_name]
	if not list.has_index(index):
		push_error("SceneManager: index %d out of bounds for list '%s'" % [index, list_name])
		return
	_change_scene(list.get_path_at(index), list_name, index, list.get_id_at(index))


func go_to_path(path: String) -> void:
	if _transitioning:
		return
	var list := get_active_list()
	var index := list.index_of_path(path) if list != null else -1
	_change_scene(path, _active_list, index, SceneList.id_from_path(path))


# --- State queries ---

func get_current_index() -> int:
	return _current_index


func get_current_id() -> String:
	return _current_id


func get_current_path() -> String:
	return _current_path


# --- Internals ---

func _change_scene(path: String, list_name: String, index: int, scene_id: String) -> void:
	if path.is_empty():
		push_error("SceneManager: empty scene path")
		return
	if _transitioning:
		return
	_transitioning = true
	var tree := get_tree()
	var err := tree.change_scene_to_file(path)
	if err != OK:
		_transitioning = false
		scene_load_failed.emit(path, "change_scene_to_file error %d" % err)
		push_error("SceneManager: cannot change to '%s' (error %d)" % [path, err])
		return
	await tree.scene_changed
	_current_path = path
	_current_id = scene_id
	_current_index = index
	if list_name != _active_list and _lists.has(list_name):
		set_active_list(list_name)
	_transitioning = false
	scene_changed.emit(list_name, scene_id, path)


func _sync_current_from_tree() -> void:
	if _transitioning:
		return
	var tree := get_tree()
	var current := tree.current_scene
	if current == null:
		return
	var path := current.scene_file_path
	if path.is_empty():
		return
	_current_path = path
	_current_id = SceneList.id_from_path(path)
	_current_index = -1
	for list_name in _lists:
		var list: SceneList = _lists[list_name]
		var idx := list.index_of_path(path)
		if idx != -1:
			_current_index = idx
			if _active_list != list_name:
				set_active_list(list_name)
			return


func _register_lists_from_folder(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("SceneManager: cannot open scene lists folder '%s'" % folder)
		return
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue
		var res := load(folder.path_join(file_name))
		if res is SceneList:
			register_list(res)
