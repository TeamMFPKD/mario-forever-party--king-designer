extends VBoxContainer

signal all_files_loaded

@export var level_list_line_scene: PackedScene
@export var scroll_container: ScrollContainer  # 在场景里把ScrollContainer拖进来

var file_names: Array[String] = []
var load_thread: Thread
var thread_done: bool = false

var mutex: Mutex
var should_exit: bool = false

var scene_tree: SceneTree

const SCROLL_SECTION = "history_scroll"
const SCROLL_KEY = "v_scroll"

func _ready() -> void:
	scene_tree = get_tree()
	mutex = Mutex.new()
	if scroll_container:
		scroll_container.visible = false  # 读取完成前隐藏
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

	while file_name != "":
		mutex.lock()
		var exit = should_exit
		mutex.unlock()
		if exit:
			dir.list_dir_end()
			return

		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			temp_names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	mutex.lock()
	var exit = should_exit
	mutex.unlock()
	if exit:
		return

	call_deferred_thread_group("_on_files_scanned", temp_names)

func _on_files_scanned(names: Array[String]):
	file_names = names
	thread_done = true
	load_thread.wait_to_finish()

	for i in range(file_names.size()):
		var level_list_line = level_list_line_scene.instantiate()
		var count_label = level_list_line.get_node("CountLabel")
		count_label.text = str(i + 1)
		var level_file_name_label = level_list_line.get_node("LevelFileNameLabel")
		level_file_name_label.text = file_names[i]
		add_child(level_list_line)

		if i % 10 == 9 and scene_tree:
			await scene_tree.process_frame

	await scene_tree.process_frame
	if scroll_container:
		scroll_container.visible = true
	await scene_tree.process_frame  # 等visible生效、布局重算完毕
	_restore_scroll()
	emit_signal("all_files_loaded")

func _save_scroll() -> void:
	if scroll_container == null:
		return
	GameConfig.config.set_value(SCROLL_SECTION, SCROLL_KEY, scroll_container.scroll_vertical)
	GameConfig.save()

func _restore_scroll() -> void:
	if scroll_container == null:
		return
	if not GameConfig.config.has_section_key(SCROLL_SECTION, SCROLL_KEY):
		return
	var saved = GameConfig.config.get_value(SCROLL_SECTION, SCROLL_KEY, 0)
	scroll_container.scroll_vertical = saved

func _exit_tree():
	_save_scroll()  # 离开场景时保存

	mutex.lock()
	should_exit = true
	mutex.unlock()

	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()