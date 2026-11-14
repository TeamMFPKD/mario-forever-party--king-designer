extends Node

## 真实流程探针：进入百人团舞台 → 选「新存档」→ 点「喜欢的关卡」，
## 验证在线程里按收藏索引重建池后，四档计数不再为 0、开始按钮可用。
## 用真实 adventure.ini 的副本，避免探针写回玩家数据。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TEMP_STORE: String = "user://adventure_liked_flow_probe.ini"
const RESULT_PATH: String = "res://tools/adventure_liked_flow_probe_result.txt"
const LOAD_TIMEOUT_SEC: float = 60.0


func _ready() -> void:
	var lines: Array[String] = []
	_copy_real_store()
	var store: AdventureStore = AdventureStore.new(TEMP_STORE)
	store.load()
	Adventure.store = store
	Adventure.current_run = {}

	var packed: PackedScene = load("res://room/adventure_stage.tscn") as PackedScene
	if packed == null:
		_write(["stage_loaded=false"])
		return
	var stage: Node = packed.instantiate()
	add_child(stage)
	lines.append("stage_loaded=true")
	await _wait_pool_idle(stage)
	lines.append("initial_source=%s" % Adventure.pool_source)
	lines.append("initial_pool=%d" % Adventure.get_pool().size())

	# 选「新存档」：用户实际操作路径是点存档位栏上的「新存档」卡片。
	var slots: Node = stage.get_node_or_null("Layout/Box/SaveSlots")
	var selection: int = -1
	if slots != null:
		var titles: Array[String] = slots.call("card_titles")
		var new_index: int = titles.find("新存档")
		if new_index >= 0:
			var new_button: Button = slots.call("button_at", new_index) as Button
			if new_button != null:
				new_button.emit_signal("pressed")
				await get_tree().process_frame
				selection = int(slots.call("get_selection"))
	lines.append("selection=%d" % selection)

	# 点「喜欢的关卡」：走按钮回调 → 线程重建池。
	var liked_button: Button = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/ParamsPanel/ParamsMargin/ParamsBox/PoolRow/PoolLiked"
	) as Button
	if liked_button == null:
		_write(lines + ["pool_liked_node=false"])
		return
	liked_button.emit_signal("pressed")
	await _wait_pool_idle(stage)
	lines.append("liked_source=%s" % Adventure.pool_source)
	lines.append("liked_pool=%d" % Adventure.get_pool().size())
	lines.append("liked_loading=%s" % str(bool(stage.get("_loading"))))

	var tier_column: Node = stage.get_node_or_null(
		"Layout/Box/PreviewPanel/ParamsPanel/ParamsMargin/ParamsBox/TierColumn"
	)
	for index: int in range(1, 5):
		var tier_button: Button = tier_column.get_node_or_null("Tier%d" % index) as Button
		if tier_button != null:
			lines.append("tier%d_text=%s" % [index, tier_button.text])
	var start: Button = stage.get_node_or_null("Layout/Box/BottomBar/StartButton") as Button
	lines.append("start_disabled=%s" % str(start.disabled if start != null else true))
	var info: Dictionary = Adventure.get_tier_info()
	lines.append("tier_selectable=%s" % str(info.get("selectable", false)))
	lines.append("tier_counts=%s" % str(info.get("counts", [])))
	lines.append("flow_ok=%s" % str(Adventure.get_pool().size() > 0 and not bool(start.disabled)))

	_write(lines)
	_cleanup()
	get_tree().quit()


func _wait_pool_idle(stage: Node) -> void:
	var waited: float = 0.0
	while waited < LOAD_TIMEOUT_SEC:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if not bool(stage.get("_loading")):
			return
	Log.w("LikedPoolProbe", "等待池加载超时")


func _copy_real_store() -> void:
	if not FileAccess.file_exists("user://adventure.ini"):
		return
	if FileAccess.file_exists(TEMP_STORE):
		return
	var input: FileAccess = FileAccess.open("user://adventure.ini", FileAccess.READ)
	if input == null:
		return
	var data: PackedByteArray = input.get_buffer(input.get_length())
	input.close()
	var output: FileAccess = FileAccess.open(TEMP_STORE, FileAccess.WRITE)
	if output == null:
		Log.w("LikedPoolProbe", "复制 adventure.ini 失败：%s" % error_string(FileAccess.get_open_error()))
		return
	output.store_buffer(data)
	output.close()


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["adventure_liked_flow_probe.ini", "adventure_liked_flow_probe.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
