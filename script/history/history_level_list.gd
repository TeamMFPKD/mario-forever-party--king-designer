extends VBoxContainer

@export var level_list_line_scene: PackedScene

var file_names: Array[String] = []
var load_thread: Thread
var thread_done: bool = false

# 线程控制
var mutex: Mutex
var should_exit: bool = false

func _ready() -> void:
	mutex = Mutex.new()
	start_loading()

func start_loading() -> void:
	load_thread = Thread.new()
	load_thread.start(_scan_files_thread)

func _scan_files_thread():
	var dir = DirAccess.open("user://")
	if dir == null:
		push_error("无法打开 user:// 目录")
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var temp_names: Array[String] = []

	var exit = false
	while file_name != "":
		# 检查是否需要提前退出
		mutex.lock()
		exit = should_exit
		mutex.unlock()
		if exit:
			dir.list_dir_end()
			return

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
		var count_label = level_list_line.get_node("CountLabel")
		count_label.text = str(i + 1)
		var level_file_name_label = level_list_line.get_node("LevelFileNameLabel")
		level_file_name_label.text = file_names[i]
		add_child(level_list_line)

		var scene_tree = get_tree()
		if i % 10 == 9 and scene_tree:
			await scene_tree.process_frame

func _exit_tree():
	# 通知线程退出
	mutex.lock()
	should_exit = true
	mutex.unlock()

	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()
		