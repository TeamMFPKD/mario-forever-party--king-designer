extends Control

## 百人团舞台 / 设置页。
## 先用代码搭 UI，方便快速跑通流程；后续再替换成 SVG 场景与椭圆路径。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const TITLE_SCENE: String = "res://room/title.tscn"
const TIER_NAMES: Array[String] = ["轻松", "标准", "困难", "极限"]
const TIER_COLORS: Array[Color] = [
	Color("#BFE9FF"),
	Color("#FFE7A3"),
	Color("#E3B5FF"),
	Color("#FFC9C9"),
]
const NEUTRAL_COLOR: Color = Color("#DCEBFF")
const TEXT_COLOR: Color = Color("#1A1A1A")

## 背景装饰层：用 preload 而不是直接引用 class_name，避免编辑器类缓存没刷新时报错
const SCENERY_SCRIPT: GDScript = preload("res://script/adventure/adventure_scenery.gd")
const SCENERY_TINT: Color = Color(0.11, 0.16, 0.27, 0.26)

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

var _background: ColorRect
var _scenery: Control
var _status_label: Label
var _lives_label: Label
var _length_label: Label
var _length_slider: HSlider
var _preview_grid: GridContainer
var _start_button: Button
var _resume_button: Button
var _pool_buttons: Array[Button] = []
var _tier_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _tier_info: Dictionary = {}


func _ready() -> void:
	# 从中断/跳过流程进来时场景是冻结着切的，这里负责解冻。
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not OS.has_feature("web"):
		_load_mutex = Mutex.new()
	_build_ui()
	var settings: Dictionary = Adventure.get_settings()
	_pool_source = str(settings.get("pool_source", "all"))
	_tier = clampi(int(settings.get("tier", 0)), 0, 4)
	_mode = str(settings.get("mode", "finite"))
	_run_length = clampi(int(settings.get("run_length", 10)), 5, 50)
	_prefer_low_sample = bool(settings.get("prefer_low_sample", true))
	_length_slider.value = _run_length
	_apply_button_states()
	_resume_button.visible = Adventure.resume_available
	_status_label.text = "读取中……"
	_set_controls_enabled(false)
	# 先让界面画出来，再在后台线程扫描关卡池。
	call_deferred("_begin_pool_load")


## V4 布局：左侧 412px 竖排导航栏装全部设置按钮，右侧大路线预览，底部动作条。
## 只重排控件，所有原有引用（按钮数组 / 滑块 / 状态 / 预览网格）保持不变。
func _build_ui() -> void:
	_background = ColorRect.new()
	_background.color = NEUTRAL_COLOR
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 14)
	margin.add_child(root_box)

	var title: Label = Label.new()
	title.text = "百人团"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", TEXT_COLOR)
	root_box.add_child(title)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", TEXT_COLOR)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_status_label)

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content)

	# ── 左：竖排导航 ──────────────────────────────────────────────
	var rail: PanelContainer = PanelContainer.new()
	rail.custom_minimum_size = Vector2(412, 0)
	var rail_style: StyleBoxFlat = StyleBoxFlat.new()
	rail_style.bg_color = Color(1, 1, 1, 0.58)
	rail_style.corner_radius_top_left = 18
	rail_style.corner_radius_top_right = 18
	rail_style.corner_radius_bottom_left = 18
	rail_style.corner_radius_bottom_right = 18
	rail_style.border_width_left = 2
	rail_style.border_width_top = 2
	rail_style.border_width_right = 2
	rail_style.border_width_bottom = 2
	rail_style.border_color = Color(0.15, 0.2, 0.3, 0.22)
	rail.add_theme_stylebox_override("panel", rail_style)
	content.add_child(rail)

	var rail_margin: MarginContainer = MarginContainer.new()
	rail_margin.add_theme_constant_override("margin_left", 20)
	rail_margin.add_theme_constant_override("margin_top", 18)
	rail_margin.add_theme_constant_override("margin_right", 20)
	rail_margin.add_theme_constant_override("margin_bottom", 18)
	rail.add_child(rail_margin)

	var rail_box: VBoxContainer = VBoxContainer.new()
	rail_box.add_theme_constant_override("separation", 8)
	rail_margin.add_child(rail_box)

	rail_box.add_child(_make_section_title("数据源"))
	_pool_buttons = _make_toggle_column(
		["所有关卡", "喜欢的关卡"],
		func(index: int) -> void: _select_pool("all" if index == 0 else "liked"),
		364.0
	)
	rail_box.add_child(_pool_buttons[0].get_parent())

	rail_box.add_child(_make_section_title("难度"))
	_tier_buttons = _make_toggle_column(
		["1 轻松", "2 标准", "3 困难", "4 极限", "随机"],
		func(index: int) -> void: _select_tier(index + 1 if index < 4 else 0),
		364.0
	)
	rail_box.add_child(_tier_buttons[0].get_parent())

	rail_box.add_child(_make_section_title("流程"))
	_mode_buttons = _make_toggle_column(
		["定量团", "无尽团"],
		func(index: int) -> void: _select_mode("finite" if index == 0 else "endless"),
		364.0
	)
	rail_box.add_child(_mode_buttons[0].get_parent())

	var rail_spacer: Control = Control.new()
	rail_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail_box.add_child(rail_spacer)

	# ── 右：关数信息条 + 路线预览 ─────────────────────────────────
	var right_box: VBoxContainer = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 12)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right_box)

	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 16)
	right_box.add_child(info_row)
	_length_label = Label.new()
	_length_label.custom_minimum_size = Vector2(240, 0)
	_length_label.add_theme_font_size_override("font_size", 22)
	_length_label.add_theme_color_override("font_color", TEXT_COLOR)
	info_row.add_child(_length_label)
	_length_slider = HSlider.new()
	_length_slider.min_value = 5
	_length_slider.max_value = 50
	_length_slider.step = 1
	_length_slider.custom_minimum_size = Vector2(320, 36)
	_length_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_length_slider.value_changed.connect(_on_length_changed)
	info_row.add_child(_length_slider)
	_lives_label = Label.new()
	_lives_label.custom_minimum_size = Vector2(420, 0)
	_lives_label.add_theme_font_size_override("font_size", 20)
	_lives_label.add_theme_color_override("font_color", TEXT_COLOR)
	_lives_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_row.add_child(_lives_label)

	var preview_panel: PanelContainer = PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_style: StyleBoxFlat = StyleBoxFlat.new()
	preview_style.bg_color = Color(1, 1, 1, 0.42)
	preview_style.corner_radius_top_left = 20
	preview_style.corner_radius_top_right = 20
	preview_style.corner_radius_bottom_left = 20
	preview_style.corner_radius_bottom_right = 20
	preview_style.border_width_left = 2
	preview_style.border_width_top = 2
	preview_style.border_width_right = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.15, 0.2, 0.3, 0.18)
	preview_panel.add_theme_stylebox_override("panel", preview_style)

	# 关卡椭圆附近的迷你剪影装饰：在面板底色之上、椭圆之下
	_scenery = SCENERY_SCRIPT.new() as Control
	_scenery.name = "Scenery"
	_scenery.set("tint", SCENERY_TINT)
	preview_panel.add_child(_scenery)

	right_box.add_child(preview_panel)
	var preview_margin: MarginContainer = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 16)
	preview_margin.add_theme_constant_override("margin_top", 16)
	preview_margin.add_theme_constant_override("margin_right", 16)
	preview_margin.add_theme_constant_override("margin_bottom", 16)
	preview_panel.add_child(preview_margin)
	var center: CenterContainer = CenterContainer.new()
	preview_margin.add_child(center)
	_preview_grid = GridContainer.new()
	_preview_grid.columns = 10
	_preview_grid.add_theme_constant_override("h_separation", 14)
	_preview_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_preview_grid)

	# ── 动作条放在右侧栏底部：次要按钮靠左，主 CTA 靠右放大 ──────
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	actions.custom_minimum_size = Vector2(0, 108)
	right_box.add_child(actions)
	var back_button: Button = _make_button("返回标题", false)
	back_button.custom_minimum_size = Vector2(190, 64)
	back_button.pressed.connect(_on_back)
	actions.add_child(back_button)
	_resume_button = _make_button("继续上次的团", false)
	_resume_button.custom_minimum_size = Vector2(240, 64)
	_resume_button.pressed.connect(_on_resume)
	actions.add_child(_resume_button)
	var action_spacer: Control = Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	_start_button = _make_button("开始打团", false)
	_start_button.custom_minimum_size = Vector2(360, 96)
	_start_button.add_theme_font_size_override("font_size", 32)
	_start_button.pressed.connect(_on_start)
	actions.add_child(_start_button)


func _make_section_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


func _make_button(text: String, toggle: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 54)
	button.add_theme_font_size_override("font_size", 24)
	return button


## V4：设置按钮竖排进左侧导航栏，父节点是 VBoxContainer。
func _make_toggle_column(texts: Array[String], on_selected: Callable, width: float) -> Array[Button]:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var buttons: Array[Button] = []
	for index: int in range(texts.size()):
		var button: Button = _make_button(texts[index], true)
		button.custom_minimum_size = Vector2(width, 54)
		button.pressed.connect(on_selected.bind(index))
		column.add_child(button)
		buttons.append(button)
	return buttons


func _apply_button_states() -> void:
	for index: int in range(_pool_buttons.size()):
		var expected: String = "all" if index == 0 else "liked"
		var selected: bool = _pool_source == expected
		_pool_buttons[index].button_pressed = selected
		_pool_buttons[index].modulate = Color(1, 1, 1) if selected else Color(0.72, 0.72, 0.72)
	for index: int in range(_tier_buttons.size()):
		var expected_tier: int = index + 1 if index < 4 else 0
		var selected: bool = _tier == expected_tier
		_tier_buttons[index].button_pressed = selected
		_tier_buttons[index].modulate = Color(1, 1, 1) if selected else Color(0.72, 0.72, 0.72)
	for index: int in range(_mode_buttons.size()):
		var expected_mode: String = "finite" if index == 0 else "endless"
		var selected: bool = _mode == expected_mode
		_mode_buttons[index].button_pressed = selected
		_mode_buttons[index].modulate = Color(1, 1, 1) if selected else Color(0.72, 0.72, 0.72)
	_length_slider.visible = _mode == "finite"
	_length_label.visible = _mode == "finite"
	_update_lives()


func _select_pool(source: String) -> void:
	if _loading:
		return
	_pool_source = source
	_apply_button_states()
	_begin_pool_load()


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


func _set_controls_enabled(enabled: bool) -> void:
	for button: Button in _pool_buttons:
		button.disabled = not enabled
	for button: Button in _mode_buttons:
		button.disabled = not enabled
	for button: Button in _tier_buttons:
		button.disabled = not enabled
	if _length_slider != null:
		_length_slider.editable = enabled
	_start_button.disabled = not enabled
	_resume_button.disabled = not enabled


func _begin_pool_load() -> void:
	if _loading:
		return
	_loading = true
	_status_label.text = "读取中……"
	_set_controls_enabled(false)
	_load_generation += 1
	var generation: int = _load_generation
	var source: String = _pool_source
	if OS.has_feature("web"):
		var built: Dictionary = AdventurePoolBuilder.build_isolated(source, Adventure.store.path)
		_on_pool_loaded(built, source, generation)
		return
	_load_thread = Thread.new()
	var ini_path: String = Adventure.store.path
	_load_thread.start(_thread_build_pool.bind(source, generation, ini_path))


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
	var raw_stats: Array = built.get("stats", [])
	for stat: AdventureLevelStat in raw_stats:
		stats.append(stat)
	Adventure.set_pool(stats, source)
	_loading = false
	_set_controls_enabled(true)
	_start_button.disabled = false
	_resume_button.visible = Adventure.resume_available
	_refresh_pool_ui()


func _refresh_pool_ui() -> void:
	_tier_info = Adventure.get_tier_info()
	var sampled: int = int(_tier_info.get("sampled", 0))
	var selectable: bool = bool(_tier_info.get("selectable", false))
	var suffix: String = "" if selectable else " · 样本不足，只能随机"
	_status_label.text = "可玩 %d 关 · 已采样 %d 关%s" % [Adventure.playable_count(), sampled, suffix]

	var counts: Array = _tier_info.get("counts", [0, 0, 0, 0])
	for index: int in range(4):
		var count: int = int(counts[index]) if index < counts.size() else 0
		_tier_buttons[index].disabled = not selectable
		_tier_buttons[index].tooltip_text = "本档 %d 关" % count
		_tier_buttons[index].text = "%d %s（%d）" % [index + 1, TIER_NAMES[index], count]
	if not selectable and _tier > 0:
		_tier = 0
	_apply_button_states()
	_update_theme()
	_rebuild_preview()


func _update_theme() -> void:
	if _tier >= 1 and _tier <= 4:
		_background.color = TIER_COLORS[_tier - 1]
	else:
		_background.color = NEUTRAL_COLOR


func _update_lives() -> void:
	var lives: int = _run_length * 2 if _mode == "finite" else 30
	_lives_label.text = "初始命数：%d（上限 100，每通过 2 关 +1）" % lives
	_length_label.text = "打几关：%d" % _run_length if _mode == "finite" else "打几关：无尽"


func _rebuild_preview() -> void:
	for child: Node in _preview_grid.get_children():
		child.queue_free()
	var count: int = _run_length if _mode == "finite" else 10
	var color: Color = TIER_COLORS[_tier - 1] if _tier >= 1 else Color("#F4F8FF")
	for index: int in range(count):
		_preview_grid.add_child(_make_ellipse(index + 1, color, _mode == "endless"))


func _make_ellipse(number: int, color: Color, endless: bool) -> Control:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(74, 46)
	panel.pivot_offset = Vector2(37, 23)
	panel.rotation = deg_to_rad(-8.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_left = 22
	style.corner_radius_bottom_right = 22
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.15, 0.2, 0.65)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = "?" if endless else str(number)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _on_start() -> void:
	if _loading:
		return
	var settings: Dictionary = {
		"pool_source": _pool_source,
		"tier": _tier,
		"mode": _mode,
		"run_length": _run_length,
		"prefer_low_sample": _prefer_low_sample,
	}
	Adventure.save_settings(settings)
	_start_button.disabled = true
	if Adventure.start_run(settings):
		GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)
	else:
		_start_button.disabled = false
		_status_label.text = Adventure.last_error


func _on_resume() -> void:
	if _loading:
		return
	if Adventure.resume_run():
		GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)
	else:
		_resume_button.visible = false
		_status_label.text = "没有可继续的团"


func _on_back() -> void:
	GlobalTransition.change_scene_to_file(TITLE_SCENE)


func _exit_tree() -> void:
	if _load_mutex != null:
		_load_mutex.lock()
		_should_exit = true
		_load_mutex.unlock()
	if _load_thread != null and _load_thread.is_started():
		_load_thread.wait_to_finish()
