extends VBoxContainer

@export var level_list_line_scene: PackedScene

func _ready() -> void:
	_load_level_list()

func _load_level_list() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("无法打开 user:// 目录，错误码：%d" % DirAccess.get_open_error())
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	var load_count = 0
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			var level_list_line := level_list_line_scene.instantiate()
			var count_label = level_list_line.get_node("CountLabel")
			load_count += 1
			count_label.text = str(load_count)
			var level_file_name_label = level_list_line.get_node("LevelFileNameLabel")
			level_file_name_label.text = file_name
			add_child(level_list_line)

		file_name = dir.get_next()

	dir.list_dir_end()