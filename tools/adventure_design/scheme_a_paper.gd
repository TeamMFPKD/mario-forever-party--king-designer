extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 方案 A：纸片清单（Maker 纸片风，米黄纸 + 4px 墨线 + 红色印章）


class Stripes extends Control:
	var base_color: Color = Color("eef8e3")
	var stripe_color: Color = Color("e3f1d3")

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), base_color)
		var step: float = 132.0
		var index: int = -10
		while index < 18:
			var x: float = float(index) * step
			var points: PackedVector2Array = PackedVector2Array([
				Vector2(x, 0.0),
				Vector2(x + 46.0, 0.0),
				Vector2(x + 46.0 + 1080.0, 1080.0),
				Vector2(x + 1080.0, 1080.0),
			])
			draw_colored_polygon(points, stripe_color)
			index += 1


func build() -> void:
	DesignKit.apply_theme(self)
	_build_background()
	_build_header()
	_build_settings()
	_build_preview_card()
	_build_actions()


func _build_background() -> void:
	var stripes: Control = Stripes.new()
	stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, stripes, 0, 0, 1920, 1080)
	var wash: ColorRect = ColorRect.new()
	wash.color = Color(1, 1, 1, 0.25)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, wash, 0, 0, 1920, 620)


func _build_header() -> void:
	DesignKit.place(self, DesignKit.text("MARIO FOREVER PARTY / RAID MODE", 22, DesignKit.INK_3), 100, 62)

	var title: Label = DesignKit.text("百人团", 96, DesignKit.INK)
	title.size = Vector2(420, 132)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DesignKit.place(self, title, 96, 84)

	var stamp: Panel = DesignKit.flat_panel(DesignKit.RED, 18, 4, DesignKit.INK)
	stamp.size = Vector2(92, 92)
	stamp.pivot_offset = Vector2(46, 46)
	stamp.rotation = deg_to_rad(-7.0)
	DesignKit.place(self, stamp, 408, 112)
	var stamp_label: Label = DesignKit.text("100", 40, DesignKit.CREAM)
	stamp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_child(stamp_label)

	DesignKit.place(self, DesignKit.text("一关接一关 · 抽 10 关连续闯，命数用完为止", 30, DesignKit.INK_2), 100, 236)

	var status: PanelContainer = DesignKit.card(Color(1, 1, 1, 0.72), 18, 4, DesignKit.INK, 26, 20)
	DesignKit.fixed(self, status, 1248, 84, 576, 152)
	var status_box: VBoxContainer = VBoxContainer.new()
	status_box.add_theme_constant_override("separation", 10)
	status.add_child(status_box)
	var top_line: HBoxContainer = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 12)
	status_box.add_child(top_line)
	top_line.add_child(DesignKit.text("可玩 %d 关" % DesignKit.PLAYABLE, 34, DesignKit.INK))
	top_line.add_child(DesignKit.push())
	top_line.add_child(DesignKit.tag("已采样 %d" % DesignKit.SAMPLED, 20, DesignKit.PAPER_2, DesignKit.INK_2))
	status_box.add_child(DesignKit.text("四档各约 %d 关 · 喜欢 %d 关" % [DesignKit.TIER_COUNTS[0], DesignKit.LIKED], 22, DesignKit.INK_2))
	var bar: ProgressBar = DesignKit.progress_bar(0.0, 12.0, 81.0, DesignKit.GREEN, DesignKit.PAPER_3)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 12)
	status_box.add_child(bar)


func _build_settings() -> void:
	DesignKit.place(self, DesignKit.text("数据源", 30, DesignKit.INK_2), 100, 310)
	DesignKit.fixed(self, DesignKit.pill("所有关卡 %d" % DesignKit.PLAYABLE, 26, true), 100, 352, 256, 58)
	DesignKit.fixed(self, DesignKit.pill("喜欢的关卡 %d" % DesignKit.LIKED, 26, false), 372, 352, 256, 58)

	DesignKit.place(self, DesignKit.text("难度", 30, DesignKit.INK_2), 100, 440)
	var ticket_x: float = 100.0
	for index: int in range(4):
		var selected: bool = index + 1 == DesignKit.SELECTED_TIER
		_build_tier_ticket(index, selected, ticket_x, 482.0 if not selected else 474.0)
		ticket_x += 216.0
	_build_random_ticket(964.0, 482.0)

	DesignKit.place(self, DesignKit.text("流程", 30, DesignKit.INK_2), 100, 632)
	DesignKit.fixed(self, DesignKit.pill("定量团", 26, true), 100, 674, 176, 58)
	DesignKit.fixed(self, DesignKit.pill("无尽团", 26, false), 292, 674, 176, 58)

	DesignKit.place(self, DesignKit.text("打几关  %d" % DesignKit.RUN_LENGTH, 26, DesignKit.INK_2), 100, 766)
	var slider: HSlider = HSlider.new()
	slider.min_value = 5.0
	slider.max_value = 50.0
	slider.step = 1.0
	slider.value = float(DesignKit.RUN_LENGTH)
	slider.focus_mode = Control.FOCUS_NONE
	DesignKit.fixed(self, slider, 100, 804, 420, 40)
	DesignKit.place(self, DesignKit.text("初始命数  %d" % DesignKit.LIVES, 26, DesignKit.INK_2), 560, 766)
	DesignKit.place(self, DesignKit.text("每通过 2 关 +1 · 上限 100", 21, DesignKit.INK_3), 560, 802)


func _build_tier_ticket(index: int, selected: bool, x: float, y: float) -> void:
	var bg: Color = DesignKit.INK if selected else DesignKit.TIER_COLORS[index]
	var fg: Color = DesignKit.CREAM if selected else DesignKit.TIER_TEXT[index]
	var edge: Color = DesignKit.TIER_ACCENTS[index]
	var panel: PanelContainer = DesignKit.card(bg, 16, 6 if selected else 4, edge, 22, 14)
	DesignKit.fixed(self, panel, x, y, 200, 106)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(DesignKit.text("%d %s" % [index + 1, DesignKit.TIER_NAMES[index]], 28, fg))
	box.add_child(DesignKit.text("%d 关" % DesignKit.TIER_COUNTS[index], 20, Color(fg, 0.72)))
	if selected:
		box.add_child(DesignKit.text("当前选择", 17, edge))


func _build_random_ticket(x: float, y: float) -> void:
	var panel: PanelContainer = DesignKit.card(DesignKit.PAPER, 16, 4, DesignKit.INK_3, 22, 14)
	DesignKit.fixed(self, panel, x, y, 200, 106)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(DesignKit.text("随机", 28, DesignKit.INK))
	box.add_child(DesignKit.text("每次重算", 20, DesignKit.INK_3))


func _build_preview_card() -> void:
	var panel: PanelContainer = DesignKit.card(Color(1, 1, 1, 0.78), 20, 4, DesignKit.INK, 26, 24)
	DesignKit.fixed(self, panel, 1248, 270, 576, 616)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	header.add_child(DesignKit.text("本次路线", 34, DesignKit.INK))
	header.add_child(DesignKit.push())
	header.add_child(DesignKit.text("%d 关 · %d 命" % [DesignKit.RUN_LENGTH, DesignKit.LIVES], 22, DesignKit.INK_2))

	var grid: GridContainer = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)
	for index: int in range(DesignKit.RUN_LENGTH):
		grid.add_child(_build_route_chip(index))

	box.add_child(DesignKit.rule(512))

	var lives_line: HBoxContainer = HBoxContainer.new()
	lives_line.add_theme_constant_override("separation", 12)
	box.add_child(lives_line)
	lives_line.add_child(DesignKit.text("命数 %d / 100" % DesignKit.LIVES, 24, DesignKit.INK))
	lives_line.add_child(DesignKit.push())
	lives_line.add_child(DesignKit.text("每 2 关 +1", 20, DesignKit.INK_3))
	var bar: ProgressBar = DesignKit.progress_bar(0.0, 14.0, 20.0, DesignKit.YELLOW, DesignKit.PAPER_3)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 14)
	box.add_child(bar)

	box.add_child(DesignKit.rule(512))
	box.add_child(_info_line("数据源", "所有关卡 · 可玩 %d 关" % DesignKit.PLAYABLE))
	box.add_child(_info_line("难度", "%s档 · 本档 %d 关" % [DesignKit.TIER_NAMES[DesignKit.SELECTED_TIER - 1], DesignKit.TIER_COUNTS[DesignKit.SELECTED_TIER - 1]]))
	box.add_child(_info_line("已采样", "%d 关" % DesignKit.SAMPLED))

	box.add_child(DesignKit.rule(512))
	box.add_child(DesignKit.text("打团规则", 21, DesignKit.INK_3))
	box.add_child(DesignKit.text("死亡 −1 命 · 通过 2 关 +1 命（上限 100）", 20, DesignKit.INK_2))
	box.add_child(DesignKit.text("「打不过」跳过不扣命，「不可能通过」永久排除", 20, DesignKit.INK_2))


func _build_route_chip(index: int) -> Control:
	var tier: int = DesignKit.SELECTED_TIER - 1
	var panel: PanelContainer = DesignKit.card(DesignKit.TIER_COLORS[tier], 30, 3, DesignKit.INK, 0, 0)
	panel.custom_minimum_size = Vector2(96, 58)
	panel.pivot_offset = Vector2(48, 29)
	panel.rotation = deg_to_rad(-8.0)
	var label: Label = DesignKit.text(str(index + 1), 26, DesignKit.TIER_TEXT[tier])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func _info_line(key: String, value: String) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	var key_label: Label = DesignKit.text(key, 21, DesignKit.INK_3)
	key_label.custom_minimum_size = Vector2(88, 0)
	line.add_child(key_label)
	line.add_child(DesignKit.text(value, 21, DesignKit.INK_2))
	return line


func _build_actions() -> void:
	DesignKit.fixed(self, DesignKit.ghost_pill("返回标题", 24), 100, 916, 190, 66)
	DesignKit.fixed(self, DesignKit.pill("继续上次的团", 24, false), 1140, 916, 260, 66)
	DesignKit.place(self, DesignKit.big_button("开始打团", 320, 96, DesignKit.RED, DesignKit.CREAM, 40), 1452, 900)
	DesignKit.place(self, DesignKit.text("百人团只玩你自己的关卡池，不写联机统计", 20, DesignKit.INK_3), 100, 1008)
