extends Control

## 百人团舞台：布局按 docs/raid_mode §8.3.2 参考图（顶部标题 / 通栏存档位 /
## 全宽预览 / 底部动作条 / 右下状态），交互按 §8.3.1「先选存档，再点开始」。
##
## UI 节点全部在 room/adventure_stage.tscn，脚本只做数据绑定、主题色、关卡池扫描与交互。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TITLE_SCENE: String = "res://room/title.tscn"
const TRASH_SCENE: String = "res://room/adventure_trash.tscn"
const TIER_NAMES: Array[String] = ["简单", "普通", "困难", "超难"]
## 四档主题色：淡蓝 / 偏深绿 / 土黄 / 紫。
const TIER_COLORS: Array[Color] = [
	Color("#CDEBFF"),
	Color("#3F8C5A"),
	Color("#C8A45C"),
	Color("#8E44AD"),
]
## 各主题色上的前景文字：浅底用深色，深底用白字（土黄底用深棕）。
const TIER_TEXT_COLORS: Array[Color] = [
	Color("#1A1A1A"),
	Color("#F5FBFF"),
	Color("#3A2A12"),
	Color("#F5FBFF"),
]
const NEUTRAL_COLOR: Color = Color("#E7EBF2")
const TEXT_COLOR: Color = Color("#1A1A1A")
const SCENERY_TINT_ON_LIGHT_BG: Color = Color(0.11, 0.16, 0.27, 0.26)
const SCENERY_TINT_ON_DARK_BG: Color = Color(1, 1, 1, 0.24)

const POOL_BUTTON_NAMES: Array[String] = ["PoolAll", "PoolLiked"]
const TIER_BUTTON_NAMES: Array[String] = ["Tier1", "Tier2", "Tier3", "Tier4", "Tier5"]
const MODE_BUTTON_NAMES: Array[String] = ["ModeFinite", "ModeEndless"]
## 「随机」难度没有档位色，按钮描边用银白色。
const RANDOM_BORDER_COLOR: Color = Color("#C2C8D2")

## 新存档配置页：与标题页 HostPage 同款的居中页面零件。
const PARAMS_VISIBLE_SET: String = "ControlVisibieSet"
const META_FOCUS_SKIP: StringName = &"ui_focus_skip"

## 右下状态文字：只在关卡池读取中显示（左划淡入，读完右划淡出），
## 读完后不再换成提示句（用户要求）。操作失败反馈仍复用同一句位。
const STATUS_LOADING_TEXT: String = "读取中……"
const STATUS_SLIDE_DISTANCE: float = 32.0
const STATUS_SLIDE_SEC: float = 0.22

## 关卡示意图上的马里奥：沿用过关过场动画的 mario_small 帧与缩放，站在当前进度那一格的上沿。
const MARIO_FRAMES: SpriteFrames = preload("res://object/level/player/mario_small.tres")
const MARIO_SCALE: float = 0.9
const MARIO_FRAME_H: float = 66.0
## 关卡：白色半透明实心椭圆 + 白色编号，样式都在场景里调（编辑器可见）。
const LEVEL_NODE_SCENE: PackedScene = preload("res://object/adventure/level_node.tscn")
## 椭圆高度（与 level_node.tscn 一致）：马里奥站在椭圆上沿时按它算脚底位置。
const ELLIPSE_H: float = 58.0
const ENDLESS_PREVIEW_COUNT: int = 10
## 命数显示上限：与游玩左侧信息面板一致，触顶显示「× MAX」。
const LIVES_CAP: int = 100
## 难度背景：object/adventure/backgrounds.tscn 里的 5 张 1920×1080 渐变，铺满整屏。
const BACKGROUND_NODE_NAMES: Array[String] = ["Easy", "Normal", "Expert", "SuperExpert", "Random"]
const BACKGROUND_DESIGN_SIZE: Vector2 = Vector2(1920, 1080)

@export var background: ColorRect
@export var backgrounds: Node2D
@export var title_label: Label
@export var status_label: Label
@export var save_slots: PanelContainer
@export var params_panel: PanelContainer
@export var params_title: Label
@export var length_label: Label
@export var length_slider: HSlider
@export var lives_label: Label
@export var preview_grid: Control
@export var scenery: Control
@export var back_button: Button
@export var trash_button: Button
## 底栏中间的「删除存档」（红字）：只在选中一个有团的存档位时出现。
@export var delete_button: Button
@export var start_button: Button
## 主面板左上角的存档摘要：选中「有团的存档位」时才显示。
@export var save_info: PanelContainer
@export var save_lives_label: Label
@export var save_tier_label: Label
@export var save_progress_label: Label

var _pool_source: String = "all"
var _tier: int = 0
var _mode: String = "finite"
var _run_length: int = 10
var _prefer_low_sample: bool = true

var _load_thread: Thread
var _load_mutex: Mutex
var _should_exit: bool = false
var _load_generation: int = 0
var _loading: bool = false

var _pool_buttons: Array[Button] = []
var _tier_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _tier_info: Dictionary = {}
## -1 = 无选中，0 = 新存档，1..5 = 存档位
var _selection: int = -1
## 配置页被底部 OK 关掉后保持关闭，直到用户重新点存档位。
var _params_dismissed: bool = false
var _ellipse_border: Color = Color(0.15, 0.2, 0.3, 0.85)
## 存档位数据快照：选中已有存档时，关卡示意图改成显示该团的真实路线。
var _run_slots: Array[Dictionary] = []
## 状态文字是否处于显示态（淡出动画期间已经是 false）。
var _status_visible: bool = false
var _status_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not OS.has_feature("web"):
		_load_mutex = Mutex.new()
	_bind_controls()
	_fit_background()
	resized.connect(_fit_background)

	var settings: Dictionary = Adventure.get_settings()
	_pool_source = str(settings.get("pool_source", "all"))
	_tier = clampi(int(settings.get("tier", 0)), 0, 4)
	_mode = str(settings.get("mode", "finite"))
	_run_length = clampi(int(settings.get("run_length", 10)), 5, 50)
	_prefer_low_sample = bool(settings.get("prefer_low_sample", true))
	length_slider.value = _run_length

	_apply_button_states()
	_update_theme()
	_refresh_save_slots()
	_load_pool.call_deferred()


func _bind_controls() -> void:
	# 配置页按钮沿用 ui_button.tscn 的 50 号大按钮 / 6px 描边，不再套 SmallButton 细描边。
	for index: int in range(POOL_BUTTON_NAMES.size()):
		var button: Button = params_panel.find_child(POOL_BUTTON_NAMES[index], true, false) as Button
		if button == null:
			continue
		_pool_buttons.append(button)
		button.pressed.connect(_select_pool.bind("all" if index == 0 else "liked"))
	for index: int in range(TIER_BUTTON_NAMES.size()):
		var button: Button = params_panel.find_child(TIER_BUTTON_NAMES[index], true, false) as Button
		if button == null:
			continue
		if index >= TIER_NAMES.size():
			# 第 5 个是「随机」，没有档位色，用银白描边和四档区分开。
			_apply_silver_border(button)
		_tier_buttons.append(button)
		button.pressed.connect(_select_tier.bind(index + 1 if index < 4 else 0))
	for index: int in range(MODE_BUTTON_NAMES.size()):
		var button: Button = params_panel.find_child(MODE_BUTTON_NAMES[index], true, false) as Button
		if button == null:
			continue
		_mode_buttons.append(button)
		button.pressed.connect(_select_mode.bind("finite" if index == 0 else "endless"))
	length_slider.value_changed.connect(_on_length_changed)
	save_slots.connect("selection_changed", Callable(self, "_on_selection_changed"))


# ---------------------------------------------------------------------------
# 参数 / 主题
# ---------------------------------------------------------------------------

## 「随机」没有专属档位色：三道状态（常态 / 悬停 / 选中）的描边统一换成银白色。
func _apply_silver_border(button: Button) -> void:
	var pressed_style: StyleBoxFlat = _silver_style(button, "pressed")
	button.add_theme_stylebox_override("normal", _silver_style(button, "normal"))
	button.add_theme_stylebox_override("hover", _silver_style(button, "hover"))
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover_pressed", pressed_style)


func _silver_style(button: Button, state: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
	if style == null:
		return null
	style.border_color = RANDOM_BORDER_COLOR
	return style


func _apply_button_states() -> void:
	# 选中态靠 toggle 按钮自身的描边表达；不要把未选中项调灰，
	# 否则看起来和真正的 Disabled 一样，分不清参数能不能改。
	for index: int in range(_pool_buttons.size()):
		var expected: String = "all" if index == 0 else "liked"
		_pool_buttons[index].button_pressed = _pool_source == expected
	for index: int in range(_tier_buttons.size()):
		var expected_tier: int = index + 1 if index < 4 else 0
		_tier_buttons[index].button_pressed = _tier == expected_tier
	for index: int in range(_mode_buttons.size()):
		var expected_mode: String = "finite" if index == 0 else "endless"
		_mode_buttons[index].button_pressed = _mode == expected_mode
	length_slider.visible = _mode == "finite"
	length_label.visible = _mode == "finite"
	_update_lives()


func _select_pool(source: String) -> void:
	if _loading:
		return
	_pool_source = source
	_apply_button_states()
	_load_pool()


func _select_tier(tier: int) -> void:
	_tier = tier
	_apply_button_states()
	_update_theme()
	_rebuild_preview()


func _select_mode(mode: String) -> void:
	_mode = mode
	_apply_button_states()
	_rebuild_preview()


func _on_length_changed(value: float) -> void:
	_run_length = int(value)
	_apply_button_states()
	_rebuild_preview()


func _update_lives() -> void:
	var lives: int = _run_length * 2 if _mode == "finite" else 30
	lives_label.text = tr("初始命数：%d") % lives
	length_label.text = (tr("关卡数：%d") % _run_length) if _mode == "finite" else tr("关卡数：无尽")


## 换档：背景主题色 + 装饰剪影配色 + BGM。
## 选中已有存档时，主题与 BGM 都跟着该团的难度档走（而不是配置页里选的那个）。
## 标题/状态文字落在橙黄横幅上，颜色固定（不再跟难度前景色，深色档的白字在橙底上会糊）。
func _update_theme() -> void:
	var bg: Color = NEUTRAL_COLOR
	var tint: Color = TEXT_COLOR
	var theme_tier: int = _theme_tier()
	if theme_tier >= 1 and theme_tier <= 4:
		bg = TIER_COLORS[theme_tier - 1]
		tint = TIER_TEXT_COLORS[theme_tier - 1]
	# ColorRect 只做兜底底色：真正的背景是铺满整屏的难度渐变（object/adventure/backgrounds.tscn）。
	background.color = bg
	_show_background(theme_tier)
	# BGM 与背景同源：切存档位时档位跟着变，曲目必须一起换（play_tier 对同档幂等，重复调用不重播）。
	Adventure.play_bgm(theme_tier)
	_ellipse_border = bg.darkened(0.25)
	var dark_theme: bool = tint.get_luminance() > 0.6
	if scenery != null:
		scenery.set(
			"tint",
			SCENERY_TINT_ON_DARK_BG if dark_theme else SCENERY_TINT_ON_LIGHT_BG
		)


## 难度渐变背景铺满整个屏幕：背景 Sprite 是 1920×1080，按舞台当前尺寸拉伸并居中。
func _fit_background() -> void:
	if backgrounds == null:
		return
	backgrounds.position = size * 0.5
	backgrounds.scale = Vector2(
		size.x / BACKGROUND_DESIGN_SIZE.x,
		size.y / BACKGROUND_DESIGN_SIZE.y
	)


## 只显示该难度对应的那一张渐变（tier 0 = 随机）。
func _show_background(tier: int) -> void:
	if backgrounds == null:
		return
	var index: int = tier - 1 if tier >= 1 and tier <= 4 else BACKGROUND_NODE_NAMES.size() - 1
	for node_index: int in range(BACKGROUND_NODE_NAMES.size()):
		var sprite: Sprite2D = backgrounds.get_node_or_null(
			BACKGROUND_NODE_NAMES[node_index]
		) as Sprite2D
		if sprite != null:
			sprite.visible = node_index == index


## 关卡示意图：没选存档时按配置页设置画，选中已有存档时画该团的真实路线，
## 并在当前进度那一格上站一个马里奥（与过关过场里站在椭圆顶边一致）。
func _rebuild_preview() -> void:
	# 先摘出再释放：queue_free 的旧节点在本帧仍是子节点，会打乱后面按下标挂马里奥。
	for child: Node in preview_grid.get_children():
		preview_grid.remove_child(child)
		child.queue_free()
	var run: Dictionary = _selected_run()
	var endless: bool = _mode == "endless"
	var count: int = ENDLESS_PREVIEW_COUNT if endless else _run_length
	if not run.is_empty():
		endless = str(run.get("mode", "finite")) == "endless"
		if endless:
			count = ENDLESS_PREVIEW_COUNT
		else:
			count = maxi(int(run.get("total_levels", _run_length)), 1)
	for index: int in range(count):
		preview_grid.add_child(_make_ellipse(index + 1, endless))
	# 位置与连线都交给示意图脚本：同行直线、换行曲线。
	preview_grid.set("line_color", _ellipse_border)
	preview_grid.call("relayout")
	var progress: int = 1
	if not run.is_empty():
		progress = int(run.get("index", 0)) + 1
	_place_progress_mario(clampi(progress, 1, maxi(count, 1)))
	_refresh_save_info()


## 主面板左上角的存档摘要（选中「有团的存档位」时才有）：
## 第一行 mario_small 的 walk 第 2 帧 + × 命数；第二行 难度 + 进度。
## 进度：固定「当前关/总关数」，无尽没有总数，显示「已通过关数（无尽）」。
func _refresh_save_info() -> void:
	if save_info == null:
		return
	var run: Dictionary = _selected_run()
	save_info.visible = not run.is_empty()
	if delete_button != null:
		delete_button.visible = not run.is_empty()
	if run.is_empty():
		return
	var lives: int = int(run.get("lives_left", 0))
	save_lives_label.text = "× MAX" if lives >= LIVES_CAP else "× %d" % lives
	var tier: int = int(run.get("tier", 0))
	save_tier_label.text = (
		TIER_NAMES[tier - 1] if tier >= 1 and tier <= TIER_NAMES.size() else "随机"
	)
	var total: int = int(run.get("total_levels", -1))
	if total > 0:
		save_progress_label.text = "%d/%d" % [int(run.get("index", 0)) + 1, total]
	else:
		# 无尽没有总关数，只报进度数字（不带后缀）。
		save_progress_label.text = "%d" % int(run.get("cleared_count", 0))


## 选中的存档位对应的团数据；新存档 / 无选中返回空字典。
func _selected_run() -> Dictionary:
	if _selection >= 1 and _selection <= _run_slots.size():
		var data: Dictionary = _run_slots[_selection - 1]
		if bool(data.get("valid", false)):
			return data
	return {}


## 背景主题色跟谁走：选中已有存档时用该团的难度档，否则用配置页选的档位。
func _theme_tier() -> int:
	var run: Dictionary = _selected_run()
	if not run.is_empty():
		return clampi(int(run.get("tier", 0)), 0, 4)
	return _tier


func _place_progress_mario(progress: int) -> void:
	var index: int = progress - 1
	if index < 0 or index >= preview_grid.get_child_count():
		return
	var cell: Node2D = preview_grid.get_child(index) as Node2D
	if cell == null:
		return
	var mario: AnimatedSprite2D = AnimatedSprite2D.new()
	mario.sprite_frames = MARIO_FRAMES
	mario.scale = Vector2(MARIO_SCALE, MARIO_SCALE)
	mario.play(&"idle")
	cell.add_child(mario)
	# 帧高 66、脚底在帧底：让脚正好踩在椭圆关卡的上沿。
	mario.position = Vector2(0.0, -ELLIPSE_H * 0.5 - MARIO_FRAME_H * MARIO_SCALE * 0.5)


## 一关：object/adventure/level_node.tscn（椭圆 + 编号全在场景里，脚本只填关卡号）。
func _make_ellipse(number: int, endless: bool) -> Node2D:
	var cell: AdventureLevelNode = LEVEL_NODE_SCENE.instantiate()
	cell.setup(number, endless)
	return cell



# ---------------------------------------------------------------------------
# 选择态门控（§8.3.1）
# ---------------------------------------------------------------------------

## 「排除的关卡」页的「删除存档」要知道舞台上高亮的是哪个存档位（0 = 没选 / 新存档）。
func _sync_stage_slot() -> void:
	Adventure.stage_slot = _selection if _selection >= 1 else 0


func _on_selection_changed(selection: int) -> void:
	_selection = selection
	# 每次点存档位（含重新点「新存档」）都重新允许配置页出现。
	_params_dismissed = false
	_sync_stage_slot()
	_apply_selection_gate()
	# 选中已有存档：主题色切到该团难度档，关卡示意图换成该团路线、马里奥落到当前进度。
	_update_theme()
	_rebuild_preview()


func _apply_selection_gate() -> void:
	var selectable: bool = bool(_tier_info.get("selectable", false))
	var params_on: bool = not _loading and _selection == 0
	for button: Button in _pool_buttons:
		button.disabled = not params_on
	for button: Button in _mode_buttons:
		button.disabled = not params_on
	for index: int in range(_tier_buttons.size()):
		var locked_by_sample: bool = index < 4 and not selectable
		_tier_buttons[index].disabled = not params_on or locked_by_sample
	length_slider.editable = params_on
	# 配置页只在新存档态出现；OK 关掉后保持关闭，加载中也不重新弹出。
	_set_params_page(_selection == 0 and not _params_dismissed)
	start_button.text = "开始挑战"
	start_button.disabled = _loading or _selection < 0
	# 右下状态文字只用来报读取进度：读完直接右划淡出，不再换成提示句（用户要求）。
	if _loading:
		_show_status(STATUS_LOADING_TEXT)
	else:
		_hide_status()


## 新存档配置页：与标题页 HostPage 同款的页面零件 ——
## ControlVisibieSet 管显隐，DropInAnimation 在页面显示时自动从屏幕上方掉落进场。
## 隐藏时给整页打 ui_focus_skip，避免方向键/手柄把焦点跳到看不见的按钮上。
func _set_params_page(expanded: bool) -> void:
	var page_set: Node = params_panel.get_node_or_null(PARAMS_VISIBLE_SET)
	params_panel.set_meta(META_FOCUS_SKIP, not expanded)
	if page_set != null:
		if expanded:
			page_set.call("_set_visible")
		else:
			page_set.call("_set_invisible")
	else:
		params_panel.visible = expanded
	var navigator: Node = get_node_or_null("/root/UiNavigator")
	if navigator != null:
		navigator.call("refresh_now")


## 配置页底部 OK：确认设置并关闭弹窗；「新存档」仍是选中态，可直接点开始挑战。
func _on_params_ok() -> void:
	_params_dismissed = true
	_set_params_page(false)


## 左划淡入：从右侧偏移滑回原位并淡入。已经在显示时不重播，避免闪动。
func _show_status(text: String) -> void:
	if status_label == null:
		return
	status_label.text = text
	if _status_visible:
		return
	_status_visible = true
	_kill_status_tween()
	status_label.visible = true
	status_label.position.x = STATUS_SLIDE_DISTANCE
	status_label.modulate.a = 0.0
	_status_tween = create_tween().set_parallel(true)
	_status_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_status_tween.tween_property(status_label, "position:x", 0.0, STATUS_SLIDE_SEC)
	_status_tween.tween_property(status_label, "modulate:a", 1.0, STATUS_SLIDE_SEC)


## 右划淡出：向右滑出并淡出，结束后隐藏。已隐藏时无操作，可反复调用。
func _hide_status() -> void:
	if status_label == null or not _status_visible:
		return
	_status_visible = false
	_kill_status_tween()
	_status_tween = create_tween().set_parallel(true)
	_status_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_status_tween.tween_property(
		status_label, "position:x", STATUS_SLIDE_DISTANCE, STATUS_SLIDE_SEC
	)
	_status_tween.tween_property(status_label, "modulate:a", 0.0, STATUS_SLIDE_SEC)
	_status_tween.chain().tween_callback(_finish_hide_status)


func _kill_status_tween() -> void:
	if _status_tween != null and _status_tween.is_valid():
		_status_tween.kill()
	_status_tween = null


func _finish_hide_status() -> void:
	# 淡出途中又被重新显示时不隐藏。
	if not _status_visible:
		status_label.visible = false


func _refresh_save_slots() -> void:
	# 「新存档」标签落在系统实际分配的第一个空槽上，一排固定 5 格。
	_run_slots = Adventure.get_run_slots()
	save_slots.call("setup", _run_slots, Adventure.store.first_free_slot())
	_selection = int(save_slots.call("get_selection"))
	_sync_stage_slot()
	_apply_selection_gate()
	# 存档列表变化可能让选中失效，主题色与路线都要按当前选中重算。
	_update_theme()
	_rebuild_preview()


# ---------------------------------------------------------------------------
# 关卡池
# ---------------------------------------------------------------------------

func _load_pool() -> void:
	if _loading:
		return
	_loading = true
	_apply_selection_gate()
	_load_generation += 1
	var generation: int = _load_generation
	var source: String = _pool_source
	if OS.has_feature("web"):
		var built: Dictionary = AdventurePoolBuilder.build_isolated(source, Adventure.store.path)
		_on_pool_loaded(built, source, generation)
		return
	_load_thread = Thread.new()
	_load_thread.start(_thread_build_pool.bind(source, generation, Adventure.store.path))


func _thread_build_pool(source: String, generation: int, ini_path: String) -> void:
	var built: Dictionary = AdventurePoolBuilder.build_isolated(source, ini_path)
	if _load_mutex != null:
		_load_mutex.lock()
		var exit: bool = _should_exit
		_load_mutex.unlock()
		if exit:
			return
	call_deferred_thread_group("_on_pool_loaded", built, source, generation)


func _on_pool_loaded(built: Dictionary, source: String, generation: int) -> void:
	if _should_exit or generation != _load_generation:
		return
	if _load_thread != null and _load_thread.is_started():
		_load_thread.wait_to_finish()
	_load_thread = null
	Adventure.apply_pool_meta(built.get("meta_updates", []))
	var stats: Array[AdventureLevelStat] = []
	for stat: AdventureLevelStat in built.get("stats", []):
		stats.append(stat)
	Adventure.set_pool(stats, source)
	_loading = false
	_refresh_pool_ui()
	# 加载完保留当前选择态，按状态矩阵重新计算全部 Disabled。
	_apply_selection_gate()


func _refresh_pool_ui() -> void:
	_tier_info = Adventure.get_tier_info()
	var selectable: bool = bool(_tier_info.get("selectable", false))
	var counts: Array = _tier_info.get("counts", [0, 0, 0, 0])
	for index: int in range(4):
		var count: int = int(counts[index]) if index < counts.size() else 0
		_tier_buttons[index].text = "%s（%d）" % [tr(TIER_NAMES[index]), count]
	if not selectable and _tier > 0:
		_tier = 0
	_apply_button_states()
	_update_theme()
	_rebuild_preview()
	_refresh_save_slots()


# ---------------------------------------------------------------------------
# 按钮
# ---------------------------------------------------------------------------

func _on_start() -> void:
	if _loading or _selection < 0:
		return
	if _selection > 0:
		if Adventure.resume_run(_selection):
			GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)
		else:
			_refresh_save_slots()
			_show_status("这个存档位无法继续")
		return
	var settings: Dictionary = {
		"pool_source": _pool_source,
		"tier": _tier,
		"mode": _mode,
		"run_length": _run_length,
		"prefer_low_sample": _prefer_low_sample,
	}
	Adventure.save_settings(settings)
	if Adventure.start_run(settings):
		GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)
	else:
		_show_status(Adventure.last_error)


func _on_trash_pressed() -> void:
	GlobalTransition.change_scene_to_file(TRASH_SCENE)


## 底栏的「删除存档」：先弹全局面板做两按钮确认（默认答案是「否」），点「是」才真删。
func _on_delete_pressed() -> void:
	var slot: int = _selection
	if slot < 1:
		return
	Notice.show_confirm("删除当前存档？", "删除存档", "否", "是")
	var accepted: bool = await Notice.answered
	if not accepted:
		return
	Adventure.delete_run_slot(slot)
	_refresh_save_slots()


func _on_back() -> void:
	Adventure.stop_bgm()
	GlobalTransition.change_scene_to_file(TITLE_SCENE)


func _exit_tree() -> void:
	if _load_mutex != null:
		_load_mutex.lock()
		_should_exit = true
		_load_mutex.unlock()
	if _load_thread != null and _load_thread.is_started():
		_load_thread.wait_to_finish()
