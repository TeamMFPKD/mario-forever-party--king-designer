extends Button

@export var level_file_name_label: Label
@export var path_to_ancestor: NodePath = "../../.."

var ancestor_node: Node

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	ancestor_node = get_node(path_to_ancestor)

func _on_button_pressed() -> void:
	var file_name: String = level_file_name_label.text

	# 只移除收藏索引与封面，关卡本体继续留在 user:// 根目录
	LikedCourses.remove(file_name)

	var photo_path: String = LikedCourses.photo_path(file_name)
	if FileAccess.file_exists(photo_path):
		# 创建独立节点挂到根节点，生命周期不受 ancestor_node 影响
		var helper: FileDeleteHelper = FileDeleteHelper.new()
		helper.paths = [photo_path]
		get_tree().root.add_child(helper)
		helper.start()

	ancestor_node.queue_free()