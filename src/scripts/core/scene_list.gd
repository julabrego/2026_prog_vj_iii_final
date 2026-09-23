class_name SceneList
extends Resource

## Data-driven ordered list of scenes, used by [SceneManager].
## Scene ids are derived from each path's file basename (e.g. "scene1.tscn" -> "scene1").

@export var list_name: String = ""
@export var scenes: Array[String] = []


func size() -> int:
	return scenes.size()


func is_empty() -> bool:
	return scenes.is_empty()


func get_path_at(index: int) -> String:
	if index < 0 or index >= scenes.size():
		push_error("SceneList '%s': index %d out of bounds (size %d)" % [list_name, index, scenes.size()])
		return ""
	return scenes[index]


func get_id_at(index: int) -> String:
	var path := get_path_at(index)
	if path.is_empty():
		return ""
	return id_from_path(path)


func index_of_id(scene_id: String) -> int:
	for i in scenes.size():
		if id_from_path(scenes[i]) == scene_id:
			return i
	return -1


func has_id(scene_id: String) -> bool:
	return index_of_id(scene_id) != -1


func has_index(index: int) -> bool:
	return index >= 0 and index < scenes.size()


static func id_from_path(path: String) -> String:
	return path.get_file().get_basename()
