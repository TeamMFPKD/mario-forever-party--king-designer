extends VBoxContainer

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

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
## 文件名里的日期时间，如 mfmp_2026-02-12_20-13-03_name_id.lvl；时间部分可省略。
const DATE_TIME_PATTERN: String = "(\\d{4})-(\\d{2})-(\\d{2})(?:[T_ ](\\d{2})-(\\d{2})-(\\d{2}))?"
## 兼容紧凑写法 20260212。
const COMPACT_DATE_PATTERN: String = "(\\d{4})(\\d{2})(\\d{2})"

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
	var entries: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		push_error("无法打开 user:// 目录")
		return []

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if check_exit:
			mutex.lock()
			var exit: bool = should_exit
			mutex.unlock()
			if exit:
				dir.list_dir_end()
				return []
		if not dir.current_is_dir() and file_name.ends_with(".lvl"):
			entries.append({"name": file_name, "time": _level_sort_time(file_name)})
		file_name = dir.get_next()
	dir.list_dir_end()

	# 强制按文件名里的日期排序；名字解析不出日期时退回文件修改时间。
	entries.sort_custom(_sort_entries_newest_first)
	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append(str(entry.get("name", "")))
	return result


## 排序键：文件名日期（优先）→ 文件修改时间。返回 -1 表示两者都拿不到。
func _level_sort_time(file_name: String) -> int:
	var from_name: int = _parse_filename_time(file_name)
	if from_name > 0:
		return from_name
	var path: String = "user://" + file_name
	var modified: int = FileAccess.get_modified_time(path)
	return modified if modified > 0 else -1


## 解析文件名里的日期时间（本地时间按 UTC 处理只为排序，不参与显示）。
func _parse_filename_time(file_name: String) -> int:
	var base_name: String = file_name.get_basename()
	var regex: RegEx = RegEx.new()
	regex.compile(DATE_TIME_PATTERN)
	var found: RegExMatch = regex.search(base_name)
	if found != null:
		var hour: int = int(found.get_string(4)) if found.get_string(4) != "" else 0
		var minute: int = int(found.get_string(5)) if found.get_string(5) != "" else 0
		var second: int = int(found.get_string(6)) if found.get_string(6) != "" else 0
		return _datetime_to_unix(
			int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3)),
			hour, minute, second
		)
	regex.compile(COMPACT_DATE_PATTERN)
	found = regex.search(base_name)
	if found != null:
		return _datetime_to_unix(
			int(found.get_string(1)), int(found.get_string(2)), int(found.get_string(3)), 0, 0, 0
		)
	return -1


## 非法日期（如 2026-13-45）返回 -1，交给文件修改时间兜底。
func _datetime_to_unix(
	year: int, month: int, day: int, hour: int, minute: int, second: int
) -> int:
	if month < 1 or month > 12 or day < 1 or day > 31:
		return -1
	if hour < 0 or hour > 23 or minute < 0 or minute > 59 or second < 0 or second > 59:
		return -1
	var stamp: int = Time.get_unix_time_from_datetime_dict({
		"year": year,
		"month": month,
		"day": day,
		"hour": hour,
		"minute": minute,
		"second": second,
	})
	# 反查一遍，排掉 2 月 30 日这类会被 quietly 归一化的日期。
	var check: Dictionary = Time.get_datetime_dict_from_unix_time(stamp)
	if int(check.get("year", 0)) != year or int(check.get("month", 0)) != month \
			or int(check.get("day", 0)) != day:
		return -1
	return stamp


## 新的在前；时间相同（或都取不到）时按文件名保证顺序稳定。
func _sort_entries_newest_first(a: Dictionary, b: Dictionary) -> bool:
	var time_a: int = int(a.get("time", -1))
	var time_b: int = int(b.get("time", -1))
	if time_a != time_b:
		return time_a > time_b
	return str(a.get("name", "")) < str(b.get("name", ""))

func _on_files_scanned(names: Array[String]) -> void:
	file_names = names

	if file_names.is_empty():
		_show_no_file_hint("未找到历史关卡。")
		return

	var last_date: String = ""

	for i: int in range(file_names.size()):
		# 从文件名中提取日期部分（假设文件名格式为：关卡名_YYYY-MM-DD.lvl）
		var file_name: String = file_names[i]
		var current_date: String = _date_group_key(file_name)
		
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

## 日期分组键：优先文件名里的日期，拿不到就用文件修改日期。
func _date_group_key(file_name: String) -> String:
	var from_name: String = _extract_date_from_filename(file_name)
	if not from_name.is_empty():
		return from_name
	var modified: int = FileAccess.get_modified_time("user://" + file_name)
	if modified > 0:
		return Time.get_date_string_from_unix_time(modified)
	return ""


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
