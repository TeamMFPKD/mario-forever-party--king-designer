extends Node

@export var load_level_node : LoadLevel

var level_path_name : String = ""
var level_path_set : Node

func _ready() -> void:
	level_path_set = get_tree().get_first_node_in_group("level_path_set")
	if not level_path_set:
		push_error("Level path set node not found")
		return
	if not level_path_set.has_meta("level_path_name"):
		push_error("Level path name not found")
		return
	level_path_name = level_path_set.get_meta("level_path_name") as String
	load_level_node.file_name = level_path_name
	load_level_node._on_load_button_pressed()
	