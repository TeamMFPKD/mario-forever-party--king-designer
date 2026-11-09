extends Node

signal all_files_loaded

@export var level_list_line_scene: PackedScene
@export var scroll_container: ScrollContainer
@export var no_file_hint_label: Label

var file_names: Array[String] = []
var load_thread: Thread

var mutex: Mutex
var should_exit: bool = false
var _scanned_names: Array[String] = []
var _scan_done: bool = false

var scene_tree: SceneTree

const SCROLL_SECTION: String = "liked_scroll"
const SCROLL_KEY: String = "v_scroll"

func _ready() -> void:
	scene_tree = get_tree()
	if scroll_container:
		scroll_container.visible = false
	# Web 导出没有线程支持，主线程直接读索引；其它平台保持异步扫描
	if OS.has_feature("web"):
		_on_files_scanned(LikedCourses.get_files())
		return
	mutex = Mutex.new()
	set_process(true)
	start_loading()

func start_loading() -> void:
	load_thread = Thread.new()
	load_thread.start(_scan_files_thread)

func _scan_files_thread() -> void:
	# 收藏数据源是索引文件，不再扫描 liked courses 目录里的 .lvl 副本。
	# 线程只写共享字段，不回调节点（避免节点已释放后的 call_deferred 报错）。
	var temp_names: Array[String] = LikedCourses.get_files()

	mutex.lock()
	if should_exit:
		mutex.unlock()
		return
	_scanned_names = temp_names
	_scan_done = true
	mutex.unlock()

func _process(_delta: float) -> void:
	var done: bool = false
	var names: Array[String] = []
	mutex.lock()
	done = _scan_done
	if done:
		names = _scanned_names
	mutex.unlock()

	if not done:
		return

	set_process(false)
	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()
	_on_files_scanned(names)

func _on_files_scanned(names: Array[String]) -> void:
	file_names = names

	if file_names.is_empty():
		_show_no_file_hint()
		return

	# Web 主线程要同步读封面，缩小每帧创建的卡片数，避免一次性解码太多 PNG
	var batch_size: int = 4 if OS.has_feature("web") else 10
	var loaded_count: int = 0
	for i: int in range(file_names.size()):
		var file_name: String = file_names[i]
		if not FileAccess.file_exists(LikedCourses.level_path(file_name)):
			Log.w("LikedCourses", "收藏关卡文件缺失，跳过：%s" % file_name)
			continue

		var level_list_line: Node = level_list_line_scene.instantiate()

		var level_file_name_label: Label = level_list_line.get_node("LevelFileNameLabel")
		level_file_name_label.text = file_name

		add_sibling(level_list_line)

		var texture_rect: TextureRect = level_list_line.get_node("CoverRoot/CaptureTextureRect")
		if texture_rect:
			var setter: Node = texture_rect.get_node("CaptureTextureSetter")
			if setter:
				setter.call("set_photo", file_name)

		loaded_count += 1
		if loaded_count % batch_size == 0 and scene_tree:
			await scene_tree.process_frame

	if loaded_count == 0:
		_show_no_file_hint()
		return

	await scene_tree.process_frame
	if scroll_container:
		scroll_container.visible = true
	await scene_tree.process_frame
	_restore_scroll()
	emit_signal("all_files_loaded")

func _show_no_file_hint() -> void:
	if no_file_hint_label == null:
		return
	no_file_hint_label.text = tr("未找到喜欢的关卡。")
	no_file_hint_label.visible = true

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
	var saved: int = GameConfig.config.get_value(SCROLL_SECTION, SCROLL_KEY, 0)
	scroll_container.scroll_vertical = saved

func _exit_tree() -> void:
	_save_scroll()

	if mutex == null:
		return
	mutex.lock()
	should_exit = true
	mutex.unlock()

	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()
