extends Node

@export var level_list_line_scene: PackedScene

var file_names: Array[String] = []
var load_thread: Thread
var thread_done: bool = false

# 线程控制
var mutex: Mutex
var should_exit: bool = false

var scene_tree : SceneTree

const LIKED_COURSE_FOLDER_NAME = "liked courses"

func _ready() -> void:
	scene_tree = get_tree()
	mutex = Mutex.new()
	start_loading()

func start_loading() -> void:
	load_thread = Thread.new()
	load_thread.start(_scan_files_thread)

func _scan_files_thread():
	var dir = DirAccess.open("user://" + LIKED_COURSE_FOLDER_NAME)
	if dir == null:
		push_error("无法打开 liked courses 目录")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var temp_names: Array[String] = []

	var exit = false
	while file_name != "":
		mutex.lock()
		exit = should_exit
		mutex.unlock()
		if exit:
			dir.list_dir_end()
			return

		# 只取文件（排除子目录），且只要 .lvl
		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			temp_names.append(file_name)

		file_name = dir.get_next()
	dir.list_dir_end()

	# 最后一次检查退出标志
	mutex.lock()
	exit = should_exit
	mutex.unlock()
	if exit:
		return

	# 安全地通知主线程
	call_deferred_thread_group("_on_files_scanned", temp_names)

func _on_files_scanned(names: Array[String]):
	file_names = names
	thread_done = true
	load_thread.wait_to_finish()  # 清理线程资源
	# 分批创建 UI 避免卡顿
	for i in range(file_names.size()):
		var level_list_line = level_list_line_scene.instantiate()
		
		var level_file_name_label = level_list_line.get_node("LevelFileNameLabel")
		level_file_name_label.text = file_names[i]

		add_sibling(level_list_line)

		# 设置截图纹理
		var texture_rect = level_list_line.get_node("UiMarginContainer/VBoxContainer/CaptureTextureRect")
		if texture_rect:
			var setter = texture_rect.get_node("CaptureTextureSetter")
			if setter:
				setter.set_photo(file_names[i])

		if i % 10 == 9 and scene_tree:
			await scene_tree.process_frame

func _exit_tree():
	# 通知线程退出
	mutex.lock()
	should_exit = true
	mutex.unlock()

	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()
