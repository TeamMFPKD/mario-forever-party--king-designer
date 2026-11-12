extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 方案 B：舞台路线（把设置压在底部横条，关卡椭圆铺满画面，参考 SMM 百人团世界地图）

var _points: Array[Vector2] = []


class Scenery extends Control:
	var points: Array[Vector2] = []

	func _draw() -> void:
		_draw_cloud(Vector2(620, 158), 1.05)
		_draw_cloud(Vector2(1000, 268), 0.72)
		_draw_cloud(Vector2(1290, 168), 0.86)
		draw_circle(Vector2(1720, 168), 92.0, Color("fff3b0"))
		draw_circle(Vector2(1720, 168), 70.0, Color("fff8d2"))
		draw_circle(Vector2(200, 1040), 330.0, Color("a9dfa2"))
		draw_circle(Vector2(760, 1070), 380.0, Color("a9dfa2"))
		draw_circle(Vector2(1380, 1030), 340.0, Color("a9dfa2"))
		draw_circle(Vector2(430, 1090), 320.0, Color("7bc96f"))
		draw_circle(Vector2(1120, 1110), 360.0, Color("7bc96f"))
		draw_rect(Rect2(0, 966, 1920, 114), Color("57a83f"))
		draw_rect(Rect2(0, 956, 1920, 16), Color("6fc15a"))
		var bush_index: int = 0
		while bush_index < 14:
			var bx: float = 40.0 + float(bush_index) * 142.0
			draw_circle(Vector2(bx, 958), 26.0, Color("4c9737"))
			draw_circle(Vector2(bx + 30, 960), 20.0, Color("4c9737"))
			bush_index += 1
		_draw_route()

	func _draw_cloud(center: Vector2, scale_factor: float) -> void:
		var color: Color = Color(1, 1, 1, 0.95)
		draw_circle(center, 52.0 * scale_factor, color)
		draw_circle(center + Vector2(58, 12) * scale_factor, 40.0 * scale_factor, color)
		draw_circle(center + Vector2(-62, 16) * scale_factor, 34.0 * scale_factor, color)
		draw_circle(center + Vector2(8, 30) * scale_factor, 42.0 * scale_factor, color)
		draw_rect(
			Rect2(center + Vector2(-92, 22) * scale_factor, Vector2(190, 34) * scale_factor),
			color
		)

	func _draw_route() -> void:
		for index: int in range(points.size() - 1):
			var from_point: Vector2 = points[index]
			var to_point: Vector2 = points[index + 1]
			var distance: float = from_point.distance_to(to_point)
			var step_count: int = int(distance / 26.0)
			for step: int in range(step_count + 1):
				var t: float = float(step) / float(maxi(step_count, 1))
				var dot: Vector2 = from_point.lerp(to_point, t)
				draw_circle(dot, 6.0, Color(1, 0.984, 0.902, 0.92))
		if points.size() > 0:
			var last_point: Vector2 = points[points.size() - 1]
			draw_line(last_point + Vector2(44, -18), last_point + Vector2(44, -150), Color("2b2a28"), 7.0)
			var flag: PackedVector2Array = PackedVector2Array([
				last_point + Vector2(47, -148),
				last_point + Vector2(152, -122),
				last_point + Vector2(47, -96),
			])
			draw_colored_polygon(flag, Color("e0442c"))


func build() -> void:
	DesignKit.apply_theme(self)
	_fill_route_points()
	_build_sky()
	_build_chips()
	_build_sign()
	_build_status()
	_build_bottom_bar()
	_build_start()


func _build_sky() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color("8ed3ff"))
	gradient.set_color(1, Color("edfbff"))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 512
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var sky: TextureRect = TextureRect.new()
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, sky, 0, 0, 1920, 1080)

	var scenery: Control = Scenery.new()
	scenery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	DesignKit.fixed(self, scenery, 0, 0, 1920, 1080)
	scenery.set("points", _points)


func _fill_route_points() -> void:
	var index: int = 0
	while index < DesignKit.RUN_LENGTH:
		var x: float = 210.0 + float(index) * 158.0
		var y: float = 640.0 + sin(float(index) * 0.82) * 74.0
		_points.append(Vector2(x, y))
		index += 1


func _build_chips() -> void:
	for point_index: int in range(_points.size()):
		_build_chip(point_index, _points[point_index])


func _build_chip(index: int, center: Vector2) -> void:
	var tier: int = DesignKit.SELECTED_TIER - 1
	var panel: PanelContainer = DesignKit.card(DesignKit.TIER_COLORS[tier], 42, 4, DesignKit.INK, 0, 0)
	panel.size = Vector2(148, 88)
	panel.custom_minimum_size = Vector2(148, 88)
	panel.pivot_offset = Vector2(74, 44)
	panel.rotation = deg_to_rad(-8.0)
	DesignKit.place(self, panel, center.x - 74.0, center.y - 44.0)
	var label: Label = DesignKit.text(str(index + 1), 32, DesignKit.TIER_TEXT[tier])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(74, 44)
	label.rotation = deg_to_rad(8.0)
	panel.add_child(label)
	if index == 0:
		var tag: PanelContainer = DesignKit.card(DesignKit.RED, 10, 3, DesignKit.INK, 14, 4)
		DesignKit.fixed(self, tag, center.x - 54.0, center.y - 84.0, 92, 36)
		tag.add_child(DesignKit.text("起点", 21, DesignKit.CREAM))


func _build_sign() -> void:
	var wrapper: Control = Control.new()
	DesignKit.fixed(self, wrapper, 92, 62, 420, 152)
	var shadow: Panel = DesignKit.flat_panel(DesignKit.INK, 18, 0, DesignKit.INK)
	shadow.position = Vector2(10, 10)
	shadow.size = Vector2(398, 138)
	wrapper.add_child(shadow)
	var plank: PanelContainer = DesignKit.card(DesignKit.PAPER, 18, 4, DesignKit.INK, 24, 16)
	plank.position = Vector2.ZERO
	plank.size = Vector2(398, 138)
	plank.pivot_offset = Vector2(199, 69)
	plank.rotation = deg_to_rad(-2.0)
	wrapper.add_child(plank)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	plank.add_child(box)
	box.add_child(DesignKit.text("百人团", 56, DesignKit.INK))
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	box.add_child(line)
	line.add_child(DesignKit.tag("100", 20, DesignKit.RED, DesignKit.CREAM, 8, 12, 2))
	line.add_child(DesignKit.text("标准档 · %d 关" % DesignKit.TIER_COUNTS[DesignKit.SELECTED_TIER - 1], 22, DesignKit.INK_2))


func _build_status() -> void:
	var status: PanelContainer = DesignKit.card(Color(1, 1, 1, 0.78), 14, 3, DesignKit.INK, 20, 10)
	DesignKit.fixed(self, status, 1440, 70, 388, 62)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	status.add_child(line)
	line.add_child(DesignKit.text("可玩 %d" % DesignKit.PLAYABLE, 24, DesignKit.INK))
	line.add_child(DesignKit.text("·", 24, DesignKit.INK_3))
	line.add_child(DesignKit.text("已采样 %d" % DesignKit.SAMPLED, 24, DesignKit.INK_2))


func _build_bottom_bar() -> void:
	var panel: PanelContainer = DesignKit.card(Color(0.992, 0.969, 0.906, 0.94), 20, 4, DesignKit.INK, 26, 16)
	DesignKit.fixed(self, panel, 96, 840, 1490, 196)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(_row_source_mode())
	box.add_child(DesignKit.rule(1438, Color(0.17, 0.165, 0.157, 0.16), 2))
	box.add_child(_row_tier())


func _row_source_mode() -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(DesignKit.text("数据源", 24, DesignKit.INK_3))
	line.add_child(DesignKit.pill("所有关卡 %d" % DesignKit.PLAYABLE, 21, true))
	line.add_child(DesignKit.pill("喜欢的 %d" % DesignKit.LIKED, 21, false))
	line.add_child(DesignKit.spacer(28, 0))
	line.add_child(DesignKit.text("流程", 24, DesignKit.INK_3))
	line.add_child(DesignKit.pill("定量团", 21, true))
	line.add_child(DesignKit.pill("无尽团", 21, false))
	line.add_child(DesignKit.push())
	line.add_child(DesignKit.text("打 %d 关 · 初始命数 %d" % [DesignKit.RUN_LENGTH, DesignKit.LIVES], 22, DesignKit.INK_2))
	return line


func _row_tier() -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	line.add_child(DesignKit.text("难度", 24, DesignKit.INK_3))
	for index: int in range(4):
		var selected: bool = index + 1 == DesignKit.SELECTED_TIER
		line.add_child(DesignKit.pill("%d %s %d" % [index + 1, DesignKit.TIER_NAMES[index], DesignKit.TIER_COUNTS[index]], 21, selected, DesignKit.TIER_ACCENTS[index]))
	line.add_child(DesignKit.pill("随机", 21, false))
	return line


func _build_start() -> void:
	DesignKit.place(self, DesignKit.big_button("开始打团", 204, 104, DesignKit.RED, DesignKit.CREAM, 34), 1632, 852)
	DesignKit.fixed(self, DesignKit.pill("继续上次的团", 20, false), 1632, 966, 204, 48)
	DesignKit.fixed(self, DesignKit.pill("返回标题", 20, false), 1632, 1022, 204, 44)
