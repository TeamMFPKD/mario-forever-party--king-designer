extends Button

@export var target_game_mode : GameModeSingleton.GameModeType
@export var level_file_name_label : Label

@export var is_liked_course : bool = false

var basic_path_name : String = "user://"
var level_path_name : String
var level_path_set : Node

const LIKED_COURSES_FOLDER_NAME : String = "liked courses"

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	if not is_liked_course:
		level_path_name = basic_path_name + level_file_name_label.text
	else:
		level_path_name = basic_path_name + LIKED_COURSES_FOLDER_NAME + "/" + level_file_name_label.text
	level_path_set = get_tree().get_first_node_in_group("level_path_set")

func _on_button_pressed() -> void:
	if not level_path_set:
		push_error("Level path set node not found")
		return
	level_path_set.set_meta("level_path_name", level_path_name)
	GameModeSingleton.game_mode = target_game_mode
