extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 方案 C：街机霓虹（深底 + 青色荧光，强调"命数 / 关卡数"的数字感）


class NeonBackground extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b1026"))
		var glow_center: Vector2 = Vector2(1120, 500)
		var index: int = 9
		while index > 0:
			var ratio: float = float(index) / 9.0
			draw_circle(glow_center, 760.0 * ratio, Color(0.18, 0.55, 0.92, 0.03))
			index -= 1
		var gx: int = 0
		while gx <= 24:
			var x: float = float(gx) * 80.0
			draw_line(Vector2(x, 0), Vector2(x, 1080), Color(0.3, 0.8, 1, 0.05), 2.0)
			gx += 1
		var gy: int = 0
		while gy <= 14:
			var y: float = float(gy) * 80.0
			draw_line(Vector2(0, y), Vector2(1920, y), Color(0.3, 0.8, 1, 0.05), 2.0)
			gy += 1
		var scan: int = 0
		while scan < 1080:
			draw_line(Vector2(0, float(scan)), Vector2(1920, float(scan)), Color(0, 0, 0, 0.13), 2.0)
			scan += 6
		draw_line(Vector2(0, 828), Vector2(1920, 828), Color(0.3, 0.88, 1, 0.14), 2.0)


func build() -> void:
	DesignKit.apply_theme(self)
	_build_background()
	_build_header()
	_build_tiers()
	_build_route()
	_build_notes()
	_build_actions()


func _build_background() -> void:
	var background: Control = NeonBackground.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, background, 0, 0, 1920, 1080)


func _build_header() -> void:
	DesignKit.place(self, DesignKit.text("RAID MODE // 100", 22, DesignKit.CYAN), 100, 58)
	var title: Label = DesignKit.text("百人团", 88, DesignKit.WHITE)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.88, 1, 0.35))
	DesignKit.place(self, title, 96, 88)
	DesignKit.place(self, DesignKit.text("抽 %d 关连续闯 · 命数归零即结束" % DesignKit.RUN_LENGTH, 26, DesignKit.NEON_MUTED), 100, 218)

	var stats: HBoxContainer = DesignKit.row(self, 1290, 100, 530, 54, 12)
	stats.add_child(_neon_tag("命数 %d" % DesignKit.LIVES, DesignKit.YELLOW))
	stats.add_child(_neon_tag("可玩 %d" % DesignKit.PLAYABLE, DesignKit.CYAN))
	stats.add_child(_neon_tag("采样 %d" % DesignKit.SAMPLED, DesignKit.NEON_TEXT))


func _build_tiers() -> void:
	DesignKit.place(self, DesignKit.text("难度档", 22, DesignKit.NEON_MUTED), 100, 282)
	var index: int = 0
	while index < 4:
		var selected: bool = index + 1 == DesignKit.SELECTED_TIER
		_build_tier_card(index, selected, 322.0 + float(index) * 120.0)
		index += 1
	_build_tier_card(-1, false, 802.0)


func _build_tier_card(index: int, selected: bool, y: float) -> void:
	var border: Color = DesignKit.CYAN if selected else DesignKit.NIGHT_3
	var bg: Color = Color(0.11, 0.16, 0.34, 0.96) if selected else Color(0.07, 0.1, 0.22, 0.82)
	var panel: PanelContainer = DesignKit.card(bg, 14, 3 if selected else 2, border, 22, 12)
	if selected:
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.shadow_color = Color(0.3, 0.88, 1, 0.3)
			style.shadow_size = 14
	DesignKit.fixed(self, panel, 100, y, 432, 104)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	panel.add_child(line)
	var number_text: String = "--" if index < 0 else str(index + 1)
	var number_label: Label = DesignKit.text(number_text, 46, DesignKit.CYAN if selected else DesignKit.NEON_MUTED)
	number_label.custom_minimum_size = Vector2(70, 0)
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(number_label)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	line.add_child(box)
	var name_text: String = "随机抽取" if index < 0 else DesignKit.TIER_NAMES[index]
	box.add_child(DesignKit.text(name_text, 28, DesignKit.WHITE))
	var detail: String = "每次重算 · 不锁档" if index < 0 else "%d 关 · 通过率分档" % DesignKit.TIER_COUNTS[index]
	box.add_child(DesignKit.text(detail, 19, DesignKit.NEON_MUTED))
	if selected:
		line.add_child(DesignKit.push())
		line.add_child(DesignKit.tag("当前", 17, DesignKit.CYAN, DesignKit.NIGHT, 8, 10, 3))


func _build_route() -> void:
	var filters: HBoxContainer = DesignKit.row(self, 580, 288, 1240, 48, 10)
	filters.add_child(DesignKit.text("数据源", 21, DesignKit.NEON_MUTED))
	filters.add_child(_neon_pill("所有关卡 %d" % DesignKit.PLAYABLE, 20, true))
	filters.add_child(_neon_pill("喜欢的 %d" % DesignKit.LIKED, 20, false))
	filters.add_child(DesignKit.spacer(22, 0))
	filters.add_child(DesignKit.text("流程", 21, DesignKit.NEON_MUTED))
	filters.add_child(_neon_pill("定量团", 20, true))
	filters.add_child(_neon_pill("无尽团", 20, false))

	DesignKit.place(self, DesignKit.text("本次路线", 30, DesignKit.WHITE), 580, 366)
	DesignKit.place(self, DesignKit.text("%d 关 · 初始 %d 命" % [DesignKit.RUN_LENGTH, DesignKit.LIVES], 21, DesignKit.NEON_MUTED), 1580, 374)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	DesignKit.fixed(self, grid, 580, 424, 1236, 250)
	for index: int in range(DesignKit.RUN_LENGTH):
		grid.add_child(_build_slot(index))

	DesignKit.place(self, DesignKit.text("命数 %d / 100" % DesignKit.LIVES, 22, DesignKit.NEON_TEXT), 580, 716)
	DesignKit.place(self, DesignKit.text("每通过 2 关 +1 · 上限 100", 20, DesignKit.NEON_MUTED), 1420, 718)
	var bar: ProgressBar = DesignKit.progress_bar(0.0, 16.0, 20.0, DesignKit.CYAN, Color(0.13, 0.19, 0.4, 1))
	DesignKit.fixed(self, bar, 580, 756, 1236, 16)
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.shadow_color = Color(0.3, 0.88, 1, 0.45)
		fill.shadow_size = 10


func _build_slot(index: int) -> Control:
	var first: bool = index == 0
	var border: Color = DesignKit.CYAN if first else DesignKit.NIGHT_3
	var panel: PanelContainer = DesignKit.card(Color(0.08, 0.12, 0.26, 0.92), 12, 2, border, 0, 0)
	panel.custom_minimum_size = Vector2(236, 118)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var number_label: Label = DesignKit.text(str(index + 1), 46, DesignKit.CYAN if first else DesignKit.NEON_TEXT)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(number_label)
	var caption: Label = DesignKit.text("起点" if first else "待抽", 18, DesignKit.NEON_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	return panel


func _build_notes() -> void:
	var values: Array[String] = ["%d" % DesignKit.LIVES, "+1", "100"]
	var captions: Array[String] = ["初始命数", "每通过 2 关", "命数上限"]
	var details: Array[String] = ["定量团 = 关数 ×2", "上限 100", "满 100 显示 MAX"]
	var index: int = 0
	while index < 3:
		var panel: PanelContainer = DesignKit.card(Color(0.08, 0.12, 0.26, 0.78), 12, 2, DesignKit.NIGHT_3, 22, 10)
		DesignKit.fixed(self, panel, 580.0 + float(index) * 414.0, 790, 400, 88)
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)
		panel.add_child(line)
		var value_text: String = values[index]
		var caption_text: String = captions[index]
		var value: Label = DesignKit.text(value_text, 40, DesignKit.CYAN)
		value.custom_minimum_size = Vector2(92, 0)
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(value)
		var box: VBoxContainer = VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		line.add_child(box)
		box.add_child(DesignKit.text(caption_text, 20, DesignKit.NEON_TEXT))
		box.add_child(DesignKit.text(details[index], 17, DesignKit.NEON_MUTED))
		index += 1


func _build_actions() -> void:
	DesignKit.fixed(self, _neon_outline_button("继续上次的团", 22, 262, 66), 1104, 908, 262, 66)
	DesignKit.fixed(self, _start_button(), 1392, 892, 424, 108)
	DesignKit.fixed(self, _neon_outline_button("返回标题", 20, 170, 52), 100, 976, 170, 52)


func _neon_tag(content: String, color: Color) -> Control:
	var panel: PanelContainer = DesignKit.card(Color(0.08, 0.12, 0.26, 0.9), 10, 2, color, 14, 6)
	var label: Label = DesignKit.text(content, 20, color)
	panel.add_child(label)
	return panel


func _neon_pill(content: String, font_size: int, selected: bool) -> Button:
	var button: Button = Button.new()
	button.text = content
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	var pad_h: float = roundf(float(font_size) * 0.8)
	var pad_v: float = roundf(float(font_size) * 0.3)
	if selected:
		button.add_theme_stylebox_override("normal", DesignKit.sb(DesignKit.CYAN, 10, 0, DesignKit.CYAN, pad_h, pad_v))
		button.add_theme_stylebox_override("hover", DesignKit.sb(DesignKit.CYAN.lightened(0.1), 10, 0, DesignKit.CYAN, pad_h, pad_v))
		button.add_theme_stylebox_override("pressed", DesignKit.sb(DesignKit.CYAN.darkened(0.12), 10, 0, DesignKit.CYAN, pad_h, pad_v))
		button.add_theme_color_override("font_color", DesignKit.NIGHT)
		button.add_theme_color_override("font_hover_color", DesignKit.NIGHT)
		button.add_theme_color_override("font_pressed_color", DesignKit.NIGHT)
	else:
		button.add_theme_stylebox_override("normal", DesignKit.sb(Color(0.08, 0.12, 0.26, 0.9), 10, 2, DesignKit.NIGHT_3, pad_h, pad_v))
		button.add_theme_stylebox_override("hover", DesignKit.sb(Color(0.12, 0.18, 0.38, 0.95), 10, 2, DesignKit.CYAN, pad_h, pad_v))
		button.add_theme_stylebox_override("pressed", DesignKit.sb(Color(0.06, 0.09, 0.2, 1), 10, 2, DesignKit.CYAN, pad_h, pad_v))
		button.add_theme_color_override("font_color", DesignKit.NEON_TEXT)
		button.add_theme_color_override("font_hover_color", DesignKit.WHITE)
		button.add_theme_color_override("font_pressed_color", DesignKit.WHITE)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _neon_outline_button(content: String, font_size: int, width: float, height: float) -> Button:
	var button: Button = Button.new()
	button.text = content
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", DesignKit.sb(Color(0, 0, 0, 0), 12, 2, Color(0.3, 0.6, 0.85, 0.7), 18, 10))
	button.add_theme_stylebox_override("hover", DesignKit.sb(Color(0.3, 0.88, 1, 0.12), 12, 2, DesignKit.CYAN, 18, 10))
	button.add_theme_stylebox_override("pressed", DesignKit.sb(Color(0.3, 0.88, 1, 0.2), 12, 2, DesignKit.CYAN, 18, 10))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", DesignKit.NEON_TEXT)
	button.add_theme_color_override("font_hover_color", DesignKit.WHITE)
	button.add_theme_color_override("font_pressed_color", DesignKit.WHITE)
	button.size = Vector2(width, height)
	return button


func _start_button() -> Button:
	var button: Button = Button.new()
	button.text = "开始打团"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_constant_override("outline_size", 0)
	var normal: StyleBoxFlat = DesignKit.sb(DesignKit.CYAN, 16, 0, DesignKit.CYAN, 28, 16)
	normal.shadow_color = Color(0.3, 0.88, 1, 0.34)
	normal.shadow_size = 14
	var hover: StyleBoxFlat = DesignKit.sb(DesignKit.CYAN.lightened(0.15), 16, 0, DesignKit.CYAN, 28, 16)
	hover.shadow_color = Color(0.3, 0.88, 1, 0.5)
	hover.shadow_size = 18
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", DesignKit.sb(DesignKit.CYAN.darkened(0.15), 16, 0, DesignKit.CYAN, 28, 16))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", DesignKit.NIGHT)
	button.add_theme_color_override("font_hover_color", DesignKit.NIGHT)
	button.add_theme_color_override("font_pressed_color", DesignKit.NIGHT)
	button.size = Vector2(424, 108)
	return button
