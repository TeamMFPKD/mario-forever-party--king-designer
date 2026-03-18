extends Button

@export var level_file_name_label : Label
@export var path_to_ancestor : NodePath = "../../.."

const LIKED_COURSE_FOLDER_NAME = "liked courses"

var level_path_name : String
var level_path_set : Node
var ancestor_node : Node

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	level_path_name = "user://" + LIKED_COURSE_FOLDER_NAME + "/" + level_file_name_label.text
	level_path_set = get_tree().get_first_node_in_group("level_path_set")
	ancestor_node = get_node(path_to_ancestor)

func _on_button_pressed() -> void:
	if not level_path_set:
		push_error("Level path set node not found")
		return
	
	# 创建独立节点挂到根节点，生命周期不受 ancestor_node 影响
	var helper := FileDeleteHelper.new()
	helper.paths = [level_path_name, level_path_name.replace(".lvl", ".png")]
	get_tree().root.add_child(helper)
	helper.start()
	
	ancestor_node.queue_free()