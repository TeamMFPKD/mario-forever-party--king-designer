extends Node

@export var level_list_line_scene: PackedScene
@export var scroll_container: ScrollContainer

var file_names: Array[String] = []
var load_thread: Thread
var thread_done: bool = false

var mutex: Mutex
var should_exit: bool = false

var scene_tree: SceneTree

const LIKED_COURSE_FOLDER_NAME = "liked courses"

const SCROLL_SAVE_PATH = "user://liked_scroll.cfg"
const SCROLL_SECTION = "scroll"
const SCROLL_KEY = "v_scroll"

func _ready() -> void:
	scene_tree = get_tree()
	mutex = Mutex.new()
	if scroll_container:
		scroll_container.visible = false
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

		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			temp_names.append(file_name)

		file_name = dir.get_next()
	dir.list_dir_end()

	mutex.lock()
	exit = should_exit
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

		var level_file_name_label = level_list_line.get_node("LevelFileNameLabel")
		level_file_name_label.text = file_names[i]

		add_sibling(level_list_line)

		var texture_rect = level_list_line.get_node("UiMarginContainer/VBoxContainer/CaptureTextureRect")
		if texture_rect:
			var setter = texture_rect.get_node("CaptureTextureSetter")
			if setter:
				setter.set_photo(file_names[i])

		if i % 10 == 9 and scene_tree:
			await scene_tree.process_frame

	await scene_tree.process_frame
	if scroll_container:
		scroll_container.visible = true
	await scene_tree.process_frame
	_restore_scroll()

func _save_scroll() -> void:
	if scroll_container == null:
		return
	var cfg = ConfigFile.new()
	cfg.set_value(SCROLL_SECTION, SCROLL_KEY, scroll_container.scroll_vertical)
	cfg.save(SCROLL_SAVE_PATH)

func _restore_scroll() -> void:
	if scroll_container == null:
		return
	var cfg = ConfigFile.new()
	if cfg.load(SCROLL_SAVE_PATH) != OK:
		return
	var saved = cfg.get_value(SCROLL_SECTION, SCROLL_KEY, 0)
	scroll_container.scroll_vertical = saved

func _exit_tree():
	_save_scroll()

	mutex.lock()
	should_exit = true
	mutex.unlock()

	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()