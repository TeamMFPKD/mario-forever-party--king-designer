extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 方案 D：海报排版（米白纸面 + 大字排版 + 黑色底栏，信息密度最低）

const BG: Color = Color("f4efe3")
const WATERMARK: Color = Color("eae1cb")
const MUTED_LINE: Color = Color(0.17, 0.165, 0.157, 0.16)


func build() -> void:
	DesignKit.apply_theme(self)
	_build_background()
	_build_header()
	_build_form()
	_build_poster()
	_build_bottom_bar()


func _build_background() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, background, 0, 0, 1920, 1080)

	var watermark: Label = DesignKit.text("100", 520, WATERMARK)
	watermark.add_theme_constant_override("outline_size", 0)
	DesignKit.place(self, watermark, 1010, 84)


func _build_header() -> void:
	var back: Button = _flat_option("← 返回标题", 24, DesignKit.INK_3, 200)
	DesignKit.fixed(self, back, 114, 34, 200, 52)

	DesignKit.place(self, DesignKit.text("MARIO FOREVER PARTY / RAID MODE", 22, DesignKit.INK_3), 120, 118)

	var title: Label = DesignKit.text("百人团", 140, DesignKit.INK)
	title.size = Vector2(760, 210)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DesignKit.place(self, title, 112, 142)

	var bar: ColorRect = ColorRect.new()
	bar.color = DesignKit.RED
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, bar, 124, 370, 200, 12)

	DesignKit.place(self, DesignKit.text("把你的关卡池当成题库，抽 %d 关连续打。" % DesignKit.RUN_LENGTH, 32, DesignKit.INK_2), 120, 406)


func _build_form() -> void:
	_build_source_row()
	DesignKit.hairline(self, 120, 596, 1040, MUTED_LINE, 2)
	_build_tier_row()
	DesignKit.hairline(self, 120, 700, 1040, MUTED_LINE, 2)
	_build_mode_row()
	DesignKit.hairline(self, 120, 804, 1040, MUTED_LINE, 2)
	DesignKit.place(self, DesignKit.text("可玩 %d 关 · 已采样 %d 关 · 初始命数 %d（上限 100）" % [DesignKit.PLAYABLE, DesignKit.SAMPLED, DesignKit.LIVES], 22, DesignKit.INK_3), 120, 828)


func _build_source_row() -> void:
	DesignKit.place(self, DesignKit.text("数据源", 26, DesignKit.INK_3), 120, 520)
	_selected_dot(424, 540)
	DesignKit.fixed(self, _flat_option("所有关卡", 32, DesignKit.RED, 180), 442, 508, 180, 56)
	DesignKit.place(self, DesignKit.text(str(DesignKit.PLAYABLE), 22, DesignKit.INK_3), 606, 526)
	DesignKit.fixed(self, _flat_option("喜欢的关卡", 32, DesignKit.INK_3, 220), 700, 508, 220, 56)
	DesignKit.place(self, DesignKit.text(str(DesignKit.LIKED), 22, DesignKit.INK_3), 906, 526)


func _build_tier_row() -> void:
	DesignKit.place(self, DesignKit.text("难度", 26, DesignKit.INK_3), 120, 626)
	var line: HBoxContainer = DesignKit.row(self, 420, 610, 800, 64, 12)
	for index: int in range(4):
		var selected: bool = index + 1 == DesignKit.SELECTED_TIER
		if selected:
			var dot: Panel = DesignKit.flat_panel(DesignKit.RED, 6, 0, DesignKit.RED)
			dot.custom_minimum_size = Vector2(12, 12)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(dot)
		var color: Color = DesignKit.RED if selected else DesignKit.INK_3
		var option: Button = _flat_option("%d %s" % [index + 1, DesignKit.TIER_NAMES[index]], 30, color, 96)
		option.custom_minimum_size = Vector2(96, 56)
		option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(option)
	var random_option: Button = _flat_option("随机", 30, DesignKit.INK_3, 80)
	random_option.custom_minimum_size = Vector2(80, 56)
	random_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(random_option)
	line.add_child(DesignKit.spacer(24, 0))
	var note: Label = DesignKit.text("本档 %d 关" % DesignKit.TIER_COUNTS[DesignKit.SELECTED_TIER - 1], 20, DesignKit.INK_3)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(note)


func _build_mode_row() -> void:
	DesignKit.place(self, DesignKit.text("流程", 26, DesignKit.INK_3), 120, 730)
	_selected_dot(424, 750)
	DesignKit.fixed(self, _flat_option("定量团 · %d 关" % DesignKit.RUN_LENGTH, 30, DesignKit.RED, 230), 442, 718, 230, 56)
	var option: Button = _flat_option("无尽团 · 30 命", 30, DesignKit.INK_3, 230)
	DesignKit.fixed(self, option, 700, 718, 230, 56)
	DesignKit.place(self, DesignKit.text("每通过 2 关 +1 命", 21, DesignKit.INK_3), 1030, 734)


func _build_poster() -> void:
	_build_poster_chip(1268, 604, -6.0, 0, "1")
	_build_poster_chip(1492, 604, 4.0, 1, "2")
	_build_poster_chip(1268, 736, 3.0, 2, "3")
	_build_poster_chip(1492, 736, -4.0, 3, "4")

	var badge: Panel = DesignKit.flat_panel(DesignKit.RED, 78, 4, DesignKit.INK)
	badge.size = Vector2(156, 156)
	badge.pivot_offset = Vector2(78, 78)
	badge.rotation = deg_to_rad(3.0)
	DesignKit.place(self, badge, 1600, 396)
	var badge_label: Label = DesignKit.text("100", 48, DesignKit.CREAM)
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)
	DesignKit.place(self, DesignKit.text("每次从池里抽 %d 关" % DesignKit.RUN_LENGTH, 21, DesignKit.INK_3), 1348, 866)


func _build_poster_chip(x: float, y: float, angle: float, tier: int, number_text: String) -> void:
	var panel: PanelContainer = DesignKit.card(DesignKit.TIER_COLORS[tier], 48, 4, DesignKit.INK, 0, 0)
	panel.size = Vector2(204, 104)
	panel.custom_minimum_size = Vector2(204, 104)
	panel.pivot_offset = Vector2(102, 52)
	panel.rotation = deg_to_rad(angle)
	DesignKit.place(self, panel, x, y)
	var label: Label = DesignKit.text(number_text, 44, DesignKit.TIER_TEXT[tier])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(102, 52)
	label.rotation = deg_to_rad(-angle)
	panel.add_child(label)


func _build_bottom_bar() -> void:
	var bar: ColorRect = ColorRect.new()
	bar.color = DesignKit.INK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, bar, 0, 940, 1920, 140)

	var accent: ColorRect = ColorRect.new()
	accent.color = DesignKit.RED
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, accent, 0, 940, 1920, 8)

	DesignKit.fixed(self, _flat_option("开始打团 →", 42, DesignKit.CREAM, 300, DesignKit.YELLOW), 108, 962, 300, 92)
	DesignKit.place(self, DesignKit.text("%d 关 · 初始命数 %d · %s档" % [DesignKit.RUN_LENGTH, DesignKit.LIVES, DesignKit.TIER_NAMES[DesignKit.SELECTED_TIER - 1]], 24, Color("b7ae9a")), 1516, 1002)
	DesignKit.fixed(self, _flat_option("继续上次的团", 24, Color("d8cfb8"), 240, DesignKit.CREAM), 1208, 966, 240, 84)


func _selected_dot(x: float, y: float) -> void:
	var dot: Panel = DesignKit.flat_panel(DesignKit.RED, 6, 0, DesignKit.RED)
	DesignKit.fixed(self, dot, x, y, 12, 12)


func _flat_option(content: String, font_size: int, color: Color, width: float, hover_color: Color = DesignKit.INK) -> Button:
	var button: Button = Button.new()
	button.text = content
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", hover_color)
	button.add_theme_color_override("font_pressed_color", hover_color)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.size = Vector2(width, 56)
	return button
