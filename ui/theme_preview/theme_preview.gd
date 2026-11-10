extends Control

## UI 主题预览：当前只保留「Maker 纸片制造」这一套方案。
## 顶部按钮可以切换 5 种面板边框表现，左栏第一块是「大面积铺屏测试」，
## 用来判断边框在大底板上的观感；右栏是方案说明与色板。
##
## 用法：编辑器里 F6 运行本场景。
## 正式启用主题：项目设置 → GUI → Theme → Custom 指向 theme_maker.tres，
## 或用 theme_override_styles 只把面板/滑块等控件接到目标场景。

const THEME_DIR: String = "res://ui/theme"
const PANEL_AUTO_SCRIPT: GDScript = preload("res://ui/panel_style_auto.gd")

const INK: Color = Color(0.169, 0.165, 0.157, 1)
const PANEL_BG: Color = Color(0.784, 0.784, 0.784, 0.84)
const CARD_BG: Color = Color(0.973, 0.973, 0.973, 0.92)

const THEMES: Array[Dictionary] = [
	{
		"button": "纸片制造",
		"name": "Maker 纸片制造",
		"tagline": "黑色大底板 · 黄色顶栏卡片",
		"file": "theme_maker.tres",
		"background": Color(0.937, 0.902, 0.808, 1),
		"summary": "大面积面板沿用项目初始的黑色半透明，不做额外样式；只有普通卡片换成纸片面板：黄色顶部矩形 + 深灰细边。按钮保持白色，按下和焦点改用黄色强调。滑条、滚动条、输入框换成新样式。",
		"best_for": "标题界面、房间菜单、设置页等主要交互页面。",
		"palette": [
			{"name": "大底板", "hex": "#1A1A1A"},
			{"name": "卡片", "hex": "#FDF7E7"},
			{"name": "描边", "hex": "#2B2A28"},
			{"name": "强调", "hex": "#FFC531"},
			{"name": "轨道", "hex": "#E9DFC6"},
			{"name": "文字", "hex": "#2B2A28"},
		],
	},
]

const BORDER_OPTIONS: Array[Dictionary] = [
	{"name": "无框", "note": "纯半透明矩形，大面积铺屏首选"},
	{"name": "黄色顶栏", "note": "顶部黄色矩形 + 向下投影，无黑边"},
	{"name": "顶部色条", "note": "只画上边，像分区标题栏"},
	{"name": "底边纸片", "note": "只画下边，纸片叠放感"},
	{"name": "双细线", "note": "外线 + 内线，精致但宜用在卡片"},
]

var _theme_buttons: Array[Button] = []
var _border_buttons: Array[Button] = []
var _current_index: int = 0
var _current_border: int = 1

@onready var _background: ColorRect = %Background
@onready var _subtitle: Label = %Subtitle
@onready var _theme_bar: HBoxContainer = %ThemeBar
@onready var _border_bar: HBoxContainer = %BorderBar
@onready var _demo_list: VBoxContainer = %DemoList
@onready var _info_list: VBoxContainer = %InfoList


func _ready() -> void:
	_build_theme_buttons()
	_build_border_buttons()
	_build_showcase()
	_apply_theme(0)


func _build_theme_buttons() -> void:
	if THEMES.size() <= 1:
		_theme_bar.visible = false
		return

	for index: int in THEMES.size():
		var data: Dictionary = THEMES[index]
		var button: Button = Button.new()
		button.text = data["button"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(170, 64)
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_on_theme_button_pressed.bind(index))
		_theme_bar.add_child(button)
		_theme_buttons.append(button)


func _build_border_buttons() -> void:
	for index: int in BORDER_OPTIONS.size():
		var option: Dictionary = BORDER_OPTIONS[index]
		var button: Button = Button.new()
		button.text = option["name"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(110, 56)
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(_on_border_button_pressed.bind(index))
		_border_bar.add_child(button)
		_border_buttons.append(button)


func _on_theme_button_pressed(index: int) -> void:
	_apply_theme(index)


func _on_border_button_pressed(index: int) -> void:
	_apply_border(index)


func _apply_theme(index: int) -> void:
	var next_index: int = clampi(index, 0, THEMES.size() - 1)
	var data: Dictionary = THEMES[next_index]
	var theme_path: String = THEME_DIR + "/" + str(data["file"])
	var loaded_theme: Theme = load(theme_path) as Theme
	if loaded_theme == null:
		push_error("找不到主题资源：" + theme_path)
		return

	_current_index = next_index
	_background.color = data["background"]
	_subtitle.text = "%s  ·  %s" % [data["name"], data["tagline"]]

	for i: int in _theme_buttons.size():
		var selected: bool = i == next_index
		_theme_buttons[i].button_pressed = selected
		_theme_buttons[i].modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.7)

	_rebuild_info(next_index)
	_apply_border(_current_border)


func _apply_border(index: int) -> void:
	var next_index: int = clampi(index, 0, BORDER_OPTIONS.size() - 1)
	var data: Dictionary = THEMES[_current_index]
	var theme_path: String = THEME_DIR + "/" + str(data["file"])
	var base_theme: Theme = load(theme_path) as Theme
	if base_theme == null:
		push_error("找不到主题资源：" + theme_path)
		return

	var variant: Theme = base_theme.duplicate() as Theme
	variant.set_stylebox("panel", "PanelContainer", _make_border_style(next_index, true))

	_current_border = next_index
	theme = variant

	for i: int in _border_buttons.size():
		var selected: bool = i == next_index
		_border_buttons[i].button_pressed = selected
		_border_buttons[i].modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.7)


func _make_border_style(index: int, is_card: bool) -> StyleBox:
	if index == 1:
		return load("res://ui/theme/panel_small.tres") as StyleBox
	if index == 4:
		return _make_double_border_style(is_card)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG if is_card else PANEL_BG
	var corner: int = 14 if is_card else 16
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_detail = 8
	style.content_margin_left = 26.0
	style.content_margin_top = 22.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 22.0

	match index:
		0:
			pass
		1:
			style.border_width_left = 2
			style.border_width_top = 6
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = INK
			style.content_margin_top = 26.0
		2:
			style.border_width_top = 4 if is_card else 6
			style.border_color = INK
			style.content_margin_top = 30.0 if is_card else 32.0
		3:
			style.border_width_bottom = 3 if is_card else 4
			style.border_color = Color(INK.r, INK.g, INK.b, 0.30 if is_card else 0.22)

	return style


func _make_double_border_style(is_card: bool) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	var file_name: String = "panel_double_92.svg" if is_card else "panel_double_84.svg"
	style.texture = load("res://ui/theme/borders/" + file_name) as Texture2D
	style.texture_margin_left = 22.0
	style.texture_margin_top = 22.0
	style.texture_margin_right = 22.0
	style.texture_margin_bottom = 22.0
	style.content_margin_left = 26.0
	style.content_margin_top = 22.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 22.0
	return style


func _build_showcase() -> void:
	_demo_list.add_child(_make_large_panel())
	_add_section("尺寸自适应（原版 / 纸片）", _make_auto_size_demo())
	_add_section("按钮 Button", _make_button_row())
	_add_section("文本输入 LineEdit", _make_line_edits())
	_add_section("面板堆叠（半透明策略）", _make_panel_stack())
	_add_section("面板边框对比", _make_border_compare())
	_add_section("滑块 HSlider / VSlider", _make_sliders())
	_add_section("滚动条 HScrollBar / VScrollBar", _make_scroll_bars())
	_add_section("进度条 ProgressBar", _make_progress())
	_add_section("滚动容器 ScrollContainer", _make_scroll_list())
	_add_section("标签 Label", _make_labels())


func _make_large_panel() -> Control:
	var panel: Panel = Panel.new()
	panel.custom_minimum_size = Vector2(0, 340)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "大面积铺屏测试"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	box.add_child(title)

	var hint: Label = Label.new()
	hint.text = "世界 1-1 · 甜甜圈平原。这块面板保持项目初始的黑色半透明，不加额外样式，用来看大面积铺屏的边缘。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	box.add_child(hint)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_make_button("开始游戏"))
	row.add_child(_make_button("返回列表"))
	box.add_child(row)
	return panel


func _make_auto_size_demo() -> Control:
	var stage: Control = Control.new()
	stage.custom_minimum_size = Vector2(0, 760)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.42, 0.5, 0.56, 1)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(backdrop)

	var large: Panel = Panel.new()
	large.anchor_left = 0.02
	large.anchor_top = 0.03
	large.anchor_right = 0.98
	large.anchor_bottom = 0.72
	stage.add_child(large)
	var large_auto: Node = Node.new()
	large_auto.set_script(PANEL_AUTO_SCRIPT)
	large.add_child(large_auto)

	var large_margin: MarginContainer = MarginContainer.new()
	large_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	large_margin.add_theme_constant_override("margin_left", 32)
	large_margin.add_theme_constant_override("margin_top", 28)
	large_margin.add_theme_constant_override("margin_right", 32)
	large_margin.add_theme_constant_override("margin_bottom", 28)
	large.add_child(large_margin)

	var large_box: VBoxContainer = VBoxContainer.new()
	large_box.add_theme_constant_override("separation", 10)
	large_margin.add_child(large_box)

	var large_title: Label = Label.new()
	large_title.text = "接近一屏 → 项目初始黑色半透明"
	large_title.add_theme_font_size_override("font_size", 34)
	large_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	large_box.add_child(large_title)

	var large_hint: Label = Label.new()
	large_hint.text = "面积达到视口 25%（或最长边达到 90%）时，不套纸片样式，保持项目最初的黑色半透明面板。"
	large_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	large_hint.add_theme_font_size_override("font_size", 24)
	large_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.82))
	large_box.add_child(large_hint)

	var small: PanelContainer = PanelContainer.new()
	small.anchor_left = 0.08
	small.anchor_top = 0.36
	small.anchor_right = 0.64
	small.anchor_bottom = 0.68
	stage.add_child(small)
	var small_auto: Node = Node.new()
	small_auto.set_script(PANEL_AUTO_SCRIPT)
	small.add_child(small_auto)

	var small_box: VBoxContainer = VBoxContainer.new()
	small_box.add_theme_constant_override("separation", 8)
	small.add_child(small_box)

	var small_title: Label = Label.new()
	small_title.text = "普通卡片 → 黄色顶栏"
	small_title.add_theme_font_size_override("font_size", 30)
	small_box.add_child(small_title)

	var small_hint: Label = Label.new()
	small_hint.text = "顶部黄色矩形 + 向下投影，面板不带黑色描边，和按钮的 4px 全边拉开区分。"
	small_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	small_hint.add_theme_font_size_override("font_size", 24)
	small_box.add_child(small_hint)
	return stage


func _add_section(title: String, content: Control) -> void:
	var panel: PanelContainer = PanelContainer.new()
	_demo_list.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var heading: Label = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)

	var separator: HSeparator = HSeparator.new()
	box.add_child(separator)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(content)


func _make_button_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var primary: Button = _make_button("开始游戏")
	var secondary: Button = _make_button("关卡编辑器")
	var disabled: Button = _make_button("不可用")
	disabled.disabled = true

	row.add_child(primary)
	row.add_child(secondary)
	row.add_child(disabled)
	return row


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(230, 76)
	return button


func _make_line_edits() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)

	var placeholder_edit: LineEdit = LineEdit.new()
	placeholder_edit.placeholder_text = "输入关卡名称…"
	placeholder_edit.custom_minimum_size = Vector2(0, 64)

	var filled_edit: LineEdit = LineEdit.new()
	filled_edit.text = "Mario"
	filled_edit.custom_minimum_size = Vector2(0, 64)

	var read_only_edit: LineEdit = LineEdit.new()
	read_only_edit.editable = false
	read_only_edit.text = "只读状态：3 / 100"
	read_only_edit.custom_minimum_size = Vector2(0, 64)

	box.add_child(placeholder_edit)
	box.add_child(filled_edit)
	box.add_child(read_only_edit)
	return box


func _make_panel_stack() -> Control:
	var stack: Control = Control.new()
	stack.custom_minimum_size = Vector2(0, 420)

	var texture: Texture2D = load("res://sprite/psc.png") as Texture2D
	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(backdrop)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.169, 0.165, 0.157, 0.18)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(dim)

	var outer: Panel = Panel.new()
	outer.anchor_left = 0.03
	outer.anchor_top = 0.06
	outer.anchor_right = 0.97
	outer.anchor_bottom = 0.58
	stack.add_child(outer)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 26)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_right", 26)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	outer.add_child(outer_margin)

	var outer_box: VBoxContainer = VBoxContainer.new()
	outer_box.add_theme_constant_override("separation", 10)
	outer_margin.add_child(outer_box)

	var outer_title: Label = Label.new()
	outer_title.text = "外层 Panel · 项目初始黑色半透明"
	outer_title.add_theme_font_size_override("font_size", 30)
	outer_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	outer_box.add_child(outer_title)

	var outer_hint: Label = Label.new()
	outer_hint.text = "大面积底板保持黑色透明，不加额外样式，能透出后面的画面。"
	outer_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer_hint.add_theme_font_size_override("font_size", 24)
	outer_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	outer_box.add_child(outer_hint)

	var inner: PanelContainer = PanelContainer.new()
	inner.anchor_left = 0.12
	inner.anchor_top = 0.48
	inner.anchor_right = 0.88
	inner.anchor_bottom = 0.94
	stack.add_child(inner)

	var inner_box: VBoxContainer = VBoxContainer.new()
	inner_box.add_theme_constant_override("separation", 8)
	inner.add_child(inner_box)

	var inner_title: Label = Label.new()
	inner_title.text = "内层 PanelContainer · 黄色顶栏卡片"
	inner_title.add_theme_font_size_override("font_size", 28)
	inner_box.add_child(inner_title)

	var inner_hint: Label = Label.new()
	inner_hint.text = "内容卡用这一档：压在外层底板上时只透出极淡的底色，文字不会被背后的画面干扰。"
	inner_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner_hint.add_theme_font_size_override("font_size", 24)
	inner_box.add_child(inner_hint)
	return stack


func _make_border_compare() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)

	for index: int in BORDER_OPTIONS.size():
		var option: Dictionary = BORDER_OPTIONS[index]
		var panel: Panel = Panel.new()
		panel.custom_minimum_size = Vector2(0, 84)
		panel.add_theme_stylebox_override("panel", _make_border_style(index, true))

		var margin: MarginContainer = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		panel.add_child(margin)

		var label: Label = Label.new()
		label.text = "%s  ·  %s" % [option["name"], option["note"]]
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		margin.add_child(label)

		column.add_child(panel)

	return column


func _make_sliders() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)

	var slider: HSlider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = 65
	slider.custom_minimum_size = Vector2(0, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label: Label = Label.new()
	value_label.text = "音量 65%"
	value_label.add_theme_font_size_override("font_size", 26)
	slider.value_changed.connect(_on_slider_value_changed.bind(value_label))

	column.add_child(slider)
	column.add_child(value_label)

	var vertical: VSlider = VSlider.new()
	vertical.min_value = 0
	vertical.max_value = 100
	vertical.step = 1
	vertical.value = 40
	vertical.custom_minimum_size = Vector2(48, 180)

	row.add_child(column)
	row.add_child(vertical)
	return row


func _on_slider_value_changed(value: float, label: Label) -> void:
	label.text = "音量 %d%%" % int(value)


func _make_scroll_bars() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)

	var horizontal: HScrollBar = HScrollBar.new()
	horizontal.max_value = 100
	horizontal.value = 40
	horizontal.custom_minimum_size = Vector2(0, 28)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var vertical: VScrollBar = VScrollBar.new()
	vertical.max_value = 100
	vertical.value = 35
	vertical.custom_minimum_size = Vector2(28, 170)

	var hint: Label = Label.new()
	hint.text = "拖动滑轨查看抓取块的三态颜色；滚动条样式同时作用于 ScrollContainer 内部。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hint.add_theme_font_size_override("font_size", 26)

	row.add_child(vertical)
	row.add_child(hint)

	box.add_child(horizontal)
	box.add_child(row)
	return box


func _make_progress() -> Control:
	var progress: ProgressBar = ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = 62
	progress.custom_minimum_size = Vector2(0, 44)
	return progress


func _make_scroll_list() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)

	for i: int in range(1, 13):
		var button: Button = _make_button("列表项 %02d" % i)
		button.custom_minimum_size = Vector2(0, 56)
		button.add_theme_font_size_override("font_size", 28)
		list.add_child(button)

	scroll.add_child(list)
	return scroll


func _make_labels() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)

	var big: Label = Label.new()
	big.text = "大标题 46"
	big.add_theme_font_size_override("font_size", 46)

	var medium: Label = Label.new()
	medium.text = "正文 34：世界 1-1 已经解锁，可以开始建造了。"
	medium.add_theme_font_size_override("font_size", 34)
	medium.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var small: Label = Label.new()
	small.text = "辅助说明 24：主题只影响控件样式，不改动场景布局。"
	small.add_theme_font_size_override("font_size", 24)
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	box.add_child(big)
	box.add_child(medium)
	box.add_child(small)
	return box


func _rebuild_info(index: int) -> void:
	for child: Node in _info_list.get_children():
		child.free()

	var data: Dictionary = THEMES[index]

	var overview: VBoxContainer = _add_info_card("主题定位")
	var name_label: Label = Label.new()
	name_label.text = data["name"]
	name_label.add_theme_font_size_override("font_size", 42)
	overview.add_child(name_label)

	var summary: Label = Label.new()
	summary.text = data["summary"]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 24)
	overview.add_child(summary)

	var best_for_label: Label = Label.new()
	best_for_label.text = "适合：" + str(data["best_for"])
	best_for_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	best_for_label.add_theme_font_size_override("font_size", 24)
	overview.add_child(best_for_label)

	var palette_card: VBoxContainer = _add_info_card("色板")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 16)
	palette_card.add_child(grid)

	var palette: Array = data["palette"]
	for i: int in palette.size():
		var entry: Dictionary = palette[i]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 4)

		var swatch: ColorRect = ColorRect.new()
		swatch.color = entry["hex"]
		swatch.custom_minimum_size = Vector2(0, 56)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_text: Label = Label.new()
		name_text.text = entry["name"]
		name_text.add_theme_font_size_override("font_size", 22)

		var hex_text: Label = Label.new()
		hex_text.text = str(entry["hex"]).to_upper()
		hex_text.add_theme_font_size_override("font_size", 18)
		hex_text.modulate = Color(1, 1, 1, 0.65)

		cell.add_child(swatch)
		cell.add_child(name_text)
		cell.add_child(hex_text)
		grid.add_child(cell)

	var tips_card: VBoxContainer = _add_info_card("尺寸与边框规则")
	var tips: Label = Label.new()
	tips.text = "· 尺寸自适应：面积 ≥ 视口 25%（或最长边 ≥ 90%）→ 项目初始黑色半透明，不加额外样式。\n· 其余卡片 → 顶部黄色矩形 + 向下投影，面板不带黑色描边。\n· 按钮保持白色；按下、焦点、选中改用黄色强调。\n· 大面板不随顶部边框方案切换；顶部按钮只改小面板卡片。\n· 卡片是 92% 纸片底色，不做内部纹理。\n· 阈值与两套样式在 ui/panel_style_auto.gd、panel_large.tres、panel_small.tres 里调。"
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tips.add_theme_font_size_override("font_size", 23)
	tips_card.add_child(tips)


func _add_info_card(title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	_info_list.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var heading: Label = Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 30)
	box.add_child(heading)
	return box
