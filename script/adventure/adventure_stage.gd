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
## 主题里给「小按钮」准备的细描边变体（3px），见 mfmp_theme.tres。
const SMALL_BUTTON_VARIATION: StringName = &"SmallButton"
## 「随机」难度没有档位色，按钮描边用银白色。
const RANDOM_BORDER_COLOR: Color = Color("#C2C8D2")

## 左侧侧边栏（开团详细配置）只在新存档态展开，其余时候收起让预览区吃满宽度。
## 展开/收起用滑动 + 淡入淡出，避免面板突然出现/消失。
const PARAMS_SLIDE_SEC: float = 0.18
const PARAMS_SLIDE_DISTANCE: float = 64.0

## 关卡示意图上的马里奥：沿用过关过场动画的 mario_small 帧与缩放，站在当前进度那一格的上沿。
const MARIO_FRAMES: SpriteFrames = preload("res://object/level/player/mario_small.tres")
const MARIO_SCALE: float = 0.9
const MARIO_FRAME_H: float = 66.0
const ELLIPSE_SIZE: float = 58.0
const ENDLESS_PREVIEW_COUNT: int = 10

@export var background: ColorRect
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
@export var start_button: Button

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
var _theme_labels: Array[Label] = []
var _tier_info: Dictionary = {}
## -1 = 无选中，0 = 新存档，1..5 = 存档位
var _selection: int = -1
var _label_tint: Color = TEXT_COLOR
var _ellipse_border: Color = Color(0.15, 0.2, 0.3, 0.85)
## 存档位数据快照：选中已有存档时，关卡示意图改成显示该团的真实路线。
var _run_slots: Array[Dictionary] = []
## 侧边栏展开态几何（tscn 里的值），收起时整体左滑出；示意图不被推挤。
var _params_rest_left: float = 16.0
var _params_rest_right: float = 404.0
var _params_expanded: bool = false
var _params_layout_ready: bool = false
var _params_tween: Tween


func _ready() -> void:
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not OS.has_feature("web"):
		_load_mutex = Mutex.new()
	_bind_controls()
	_capture_params_layout()

	var settings: Dictionary = Adventure.get_settings()
	_pool_source = str(settings.get("pool_source", "all"))
	_tier = clampi(int(settings.get("tier", 0)), 0, 4)
	_mode = str(settings.get("mode", "finite"))
	_run_length = clampi(int(settings.get("run_length", 10)), 5, 50)
	_prefer_low_sample = bool(settings.get("prefer_low_sample", true))
	length_slider.value = _run_length

	_theme_labels = [title_label, status_label]
	_apply_button_states()
	_update_theme()
	Adventure.play_bgm(_tier)
	_refresh_save_slots()
	_load_pool.call_deferred()


func _bind_controls() -> void:
	# 侧边栏里都是小按钮：用主题的 SmallButton 变体（3px 细描边），别用大按钮的 6px。
	for index: int in range(POOL_BUTTON_NAMES.size()):
		var button: Button = params_panel.find_child(POOL_BUTTON_NAMES[index], true, false) as Button
		if button == null:
			continue
		button.theme_type_variation = SMALL_BUTTON_VARIATION
		_pool_buttons.append(button)
		button.pressed.connect(_select_pool.bind("all" if index == 0 else "liked"))
	for index: int in range(TIER_BUTTON_NAMES.size()):
		var button: Button = params_panel.find_child(TIER_BUTTON_NAMES[index], true, false) as Button
		if button == null:
			continue
		button.theme_type_variation = SMALL_BUTTON_VARIATION
		if index >= TIER_NAMES.size():
			# 第 5 个是「随机」，没有档位色，用银白描边和四档区分开。
			_apply_silver_border(button)
		_tier_buttons.append(button)
		button.pressed.connect(_select_tier.bind(index + 1 if index < 4 else 0))
	for index: int in range(MODE_BUTTON_NAMES.size()):
		var button: Button = params_panel.find_child(MODE_BUTTON_NAMES[index], true, false) as Button
		if button == null:
			continue
		button.theme_type_variation = SMALL_BUTTON_VARIATION
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
	Adventure.play_bgm(tier)


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
	lives_label.text = "初始命数：%d" % lives
	length_label.text = "打几关：%d" % _run_length if _mode == "finite" else "打几关：无尽"


## 换档：背景主题色 + 直接压在背景上的文字前景色 + 装饰剪影配色。
## 选中已有存档时，主题色跟着该团的难度档走（而不是侧边栏里选的那个）。
func _update_theme() -> void:
	var bg: Color = NEUTRAL_COLOR
	var tint: Color = TEXT_COLOR
	var theme_tier: int = _theme_tier()
	if theme_tier >= 1 and theme_tier <= 4:
		bg = TIER_COLORS[theme_tier - 1]
		tint = TIER_TEXT_COLORS[theme_tier - 1]
	background.color = bg
	_label_tint = tint
	_ellipse_border = bg.darkened(0.25)
	for label: Label in _theme_labels:
		label.add_theme_color_override("font_color", tint)
	var dark_theme: bool = tint.get_luminance() > 0.6
	if scenery != null:
		scenery.set(
			"tint",
			SCENERY_TINT_ON_DARK_BG if dark_theme else SCENERY_TINT_ON_LIGHT_BG
		)


## 关卡示意图：没选存档时按侧边栏设置画，选中已有存档时画该团的真实路线，
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


## 选中的存档位对应的团数据；新存档 / 无选中返回空字典。
func _selected_run() -> Dictionary:
	if _selection >= 1 and _selection <= _run_slots.size():
		var data: Dictionary = _run_slots[_selection - 1]
		if bool(data.get("valid", false)):
			return data
	return {}


## 背景主题色跟谁走：选中已有存档时用该团的难度档，否则用侧边栏选的档位。
func _theme_tier() -> int:
	var run: Dictionary = _selected_run()
	if not run.is_empty():
		return clampi(int(run.get("tier", 0)), 0, 4)
	return _tier


func _place_progress_mario(progress: int) -> void:
	var index: int = progress - 1
	if index < 0 or index >= preview_grid.get_child_count():
		return
	var panel: Control = preview_grid.get_child(index) as Control
	if panel == null:
		return
	var mario: AnimatedSprite2D = AnimatedSprite2D.new()
	mario.sprite_frames = MARIO_FRAMES
	mario.scale = Vector2(MARIO_SCALE, MARIO_SCALE)
	mario.play(&"idle")
	panel.add_child(mario)
	# 帧高 66、脚底在帧底：让脚正好踩在圆形关卡的上沿。
	mario.position = Vector2(ELLIPSE_SIZE * 0.5, -MARIO_FRAME_H * MARIO_SCALE * 0.5)


func _make_ellipse(number: int, endless: bool) -> Control:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(58, 58)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.55)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = _ellipse_border
	style.corner_radius_top_left = 29
	style.corner_radius_top_right = 29
	style.corner_radius_bottom_right = 29
	style.corner_radius_bottom_left = 29
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = "?" if endless else str(number)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18, 1))
	label.add_theme_font_size_override("font_size", 24)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


# ---------------------------------------------------------------------------
# 选择态门控（§8.3.1）
# ---------------------------------------------------------------------------

func _on_selection_changed(selection: int) -> void:
	_selection = selection
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
	# 侧边栏只在「新存档」态展开；加载中保持当前展开状态，免得收起又弹开。
	_set_params_expanded(_selection == 0)
	start_button.text = "开始打团"
	start_button.disabled = _loading or _selection < 0
	status_label.text = _status_text()


## tscn 存的是展开态几何（侧栏左边缘 16、右边缘 404）；收起时整体滑出左边界。
## 侧栏是**覆盖层**：展开/收起都不动关卡示意图，避免关卡圆圈被挤走。
func _capture_params_layout() -> void:
	_params_rest_left = params_panel.offset_left
	_params_rest_right = params_panel.offset_right


func _set_params_expanded(expanded: bool) -> void:
	if _params_layout_ready and expanded == _params_expanded:
		return
	_params_expanded = expanded
	if _params_tween != null and _params_tween.is_valid():
		_params_tween.kill()
	var slide: float = 0.0 if expanded else -PARAMS_SLIDE_DISTANCE
	var alpha: float = 1.0 if expanded else 0.0
	if not _params_layout_ready:
		# 进舞台/刷新存档时不播动画，直接落到目标态，免得看见面板闪一下。
		_params_layout_ready = true
		params_panel.visible = expanded
		params_panel.modulate.a = alpha
		params_panel.offset_left = _params_rest_left + slide
		params_panel.offset_right = _params_rest_right + slide
		return
	if expanded:
		params_panel.visible = true
	_params_tween = create_tween().set_parallel(true)
	_params_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_params_tween.tween_property(
		params_panel, "offset_left", _params_rest_left + slide, PARAMS_SLIDE_SEC
	)
	_params_tween.tween_property(
		params_panel, "offset_right", _params_rest_right + slide, PARAMS_SLIDE_SEC
	)
	_params_tween.tween_property(params_panel, "modulate:a", alpha, PARAMS_SLIDE_SEC)
	if not expanded:
		_params_tween.chain().tween_callback(_hide_params_panel)


func _hide_params_panel() -> void:
	# 收起动画结束后才真正隐藏，避免滑到一半被裁掉。
	if not _params_expanded:
		params_panel.visible = false


func _status_text() -> String:
	if _loading:
		return "读取中……"
	if _selection < 0:
		if Adventure.is_run_slots_full():
			return "存档位已满（5/5）"
		return "选一个存档位，或选「新存档」"
	if _selection == 0:
		return "新存档 · 点「开始打团」开始"
	return "存档 %d · 点「开始打团」继续" % _selection


func _refresh_save_slots() -> void:
	# 「新存档」标签落在系统实际分配的第一个空槽上，一排固定 5 格。
	_run_slots = Adventure.get_run_slots()
	save_slots.call("setup", _run_slots, Adventure.store.first_free_slot())
	_selection = int(save_slots.call("get_selection"))
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
		_tier_buttons[index].tooltip_text = "本档 %d 关" % count
		_tier_buttons[index].text = "%s（%d）" % [TIER_NAMES[index], count]
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
			status_label.text = "这个存档位无法继续"
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
		status_label.text = Adventure.last_error


func _on_trash_pressed() -> void:
	GlobalTransition.change_scene_to_file(TRASH_SCENE)


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
