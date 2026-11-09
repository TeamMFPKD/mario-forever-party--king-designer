extends VBoxContainer

signal all_files_loaded

@export var level_list_line_scene: PackedScene
@export var scroll_container: ScrollContainer  # 在场景里把ScrollContainer拖进来
@export var no_file_hint_label: Label

@export var history_file_date_line_scene: PackedScene

var file_names: Array[String] = []
var load_thread: Thread

var mutex: Mutex
var should_exit: bool = false

var scene_tree: SceneTree

const SCROLL_SECTION: String = "history_scroll"
const SCROLL_KEY: String = "v_scroll"

func _ready() -> void:
	scene_tree = get_tree()
	if not OS.has_feature("web"):
		mutex = Mutex.new()
	if scroll_container:
		scroll_container.visible = false  # 读取完成前隐藏
	start_loading()

func start_loading() -> void:
	# Web 导出没有 Thread 支持，退回主线程扫描；
	# 其它平台保持异步扫描，避免阻塞主线程。
	if OS.has_feature("web"):
		_on_files_scanned(_scan_files(false))
		return
	load_thread = Thread.new()
	load_thread.start(_scan_files_thread)

func _scan_files_thread() -> void:
	var names: Array[String] = _scan_files(true)
	mutex.lock()
	var exit: bool = should_exit
	mutex.unlock()
	if exit:
		return
	call_deferred_thread_group("_on_files_scanned", names)

func _scan_files(check_exit: bool) -> Array[String]:
	var result: Array[String] = []
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("无法打开 user:// 目录")
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if check_exit:
			mutex.lock()
			var exit: bool = should_exit
			mutex.unlock()
			if exit:
				dir.list_dir_end()
				return result
		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			result.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

func _on_files_scanned(names: Array[String]) -> void:
	file_names = names

	if file_names.is_empty():
		_show_no_file_hint("未找到历史关卡。")
		return

	var last_date: String = ""

	for i: int in range(file_names.size()):
		# 从文件名中提取日期部分（假设文件名格式为：关卡名_YYYY-MM-DD.lvl）
		var file_name: String = file_names[i]
		var current_date: String = _extract_date_from_filename(file_name)
		
		# 如果日期发生变化，添加日期分隔线
		if current_date != last_date and last_date != "":
			var date_line: Node = history_file_date_line_scene.instantiate()
			# 假设日期分隔线场景有一个设置日期的函数或属性
			if date_line.has_method("set_date"):
				date_line.call("set_date", current_date)
			elif date_line.has_method("set_text"):
				date_line.call("set_text", current_date)
			add_child(date_line)
			
			if scene_tree:
				await scene_tree.process_frame
		
		last_date = current_date
		
		var level_list_line: Node = level_list_line_scene.instantiate()
		var count_label: Label = level_list_line.get_node("CountLabel")
		count_label.text = str(i + 1)
		var level_file_name_label: Label = level_list_line.get_node("LevelFileNameLabel")
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

func _show_no_file_hint(message: String) -> void:
	if no_file_hint_label == null:
		return
	no_file_hint_label.text = tr(message)
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

func _extract_date_from_filename(filename: String) -> String:
	"""从文件名中提取日期部分
	假设文件名格式为：关卡名_YYYY-MM-DD.lvl 或类似格式
	"""
	# 移除文件扩展名
	var base_name: String = filename.get_basename()
	
	# 尝试匹配常见的日期格式
	var regex: RegEx = RegEx.new()
	
	# 匹配 YYYY-MM-DD 格式
	regex.compile("(\\d{4})-(\\d{2})-(\\d{2})")
	var result: RegExMatch = regex.search(base_name)
	if result:
		return result.get_string()
	
	# 匹配 YYYYMMDD 格式
	regex.compile("(\\d{4})(\\d{2})(\\d{2})")
	result = regex.search(base_name)
	if result:
		var year: String = result.get_string(1)
		var month: String = result.get_string(2)
		var day: String = result.get_string(3)
		return "%s-%s-%s" % [year, month, day]
	
	# 如果没有找到日期格式，返回空字符串
	return ""

func _exit_tree() -> void:
	_save_scroll()  # 离开场景时保存

	if OS.has_feature("web") or mutex == null:
		return
	mutex.lock()
	should_exit = true
	mutex.unlock()
	if load_thread and load_thread.is_started():
		load_thread.wait_to_finish()
