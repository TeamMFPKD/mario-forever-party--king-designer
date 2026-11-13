extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团舞台按钮布局 V4（左侧竖排导航）的单版预览 pv。
##
## 运行 res://tools/adventure_button_pv.tscn 即可看到 V4 布局；
## S = 保存当前画面，加 --pv-shot 则自动导出后退出。
## 已废除的 V1 横排分组 / V2 双列网格 / V3 分段通栏不再保留。
##
## 正式实现见 script/adventure/adventure_stage.gd 的 _build_ui()。

const CANVAS_SIZE: Vector2 = Vector2(1920, 1080)
const OUTPUT: String = "res://tools/adventure_button_pv.png"

const BG: Color = Color("#DCEBFF")
const INK: Color = Color("#1A1A1A")
const INK_2: Color = Color("#4A5876")
const WHITE: Color = Color("#FFFFFF")
const PANEL_BG: Color = Color(1, 1, 1, 0.58)
const BORDER: Color = Color(0.15, 0.2, 0.3, 0.28)
const SELECTED: Color = Color("#2C3E66")
const ACCENT: Color = Color("#E0442C")
const HIGHLIGHT: Color = Color("#F08A2C")
const CHIP: Color = Color("#9CC7F0")

const POOL_LABELS: Array[String] = ["所有关卡", "喜欢的关卡"]
const TIER_LABELS: Array[String] = ["简单", "普通", "困难", "超难", "随机"]
const MODE_LABELS: Array[String] = ["定量团", "无尽团"]

var _canvas: Control
var _badge: Panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.11, 0.11, 0.13, 1)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_canvas = Control.new()
	_canvas.size = CANVAS_SIZE
	add_child(_canvas)
	var stage: Control = _make_stage()
	_canvas.add_child(stage)
	resized.connect(_fit_canvas)
	_fit_canvas()

	_build_badge()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot()
	if OS.get_cmdline_args().has("--pv-shot"):
		get_tree().quit()


func _build_badge() -> void:
	_badge = _flat_panel(Color(0.08, 0.08, 0.09, 0.86), 10, 0, Color(0, 0, 0, 0))
	_badge.position = Vector2(560, 14)
	_badge.size = Vector2(800, 52)
	add_child(_badge)
	var label: Label = _label_node("V4 · 左侧竖排导航（已应用）    S 截图", 20, Color("#F2ECD9"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2.ZERO
	label.size = Vector2(800, 52)
	_badge.add_child(label)


func _fit_canvas() -> void:
	if _canvas == null:
		return
	var factor: float = minf(size.x / CANVAS_SIZE.x, size.y / CANVAS_SIZE.y)
	if factor <= 0.0:
		factor = 1.0
	_canvas.scale = Vector2(factor, factor)
	_canvas.position = (size - CANVAS_SIZE * factor) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_S:
		_save_shot()


func _save_shot() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT)


# ---------------------------------------------------------------------------
# 舞台底板
# ---------------------------------------------------------------------------

func _make_stage() -> Control:
	var stage: Control = Control.new()
	stage.size = CANVAS_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_PASS

	var background: ColorRect = ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(background)

	_fixed(stage, _label_node("百人团", 64, INK), 64, 32, 700, 86)
	_fixed(stage, _label_node("可玩 128 关  ·  已采样 34  ·  普通", 25, INK_2), 68, 120, 900, 40)
	_layout_v4(stage)
	return stage


func _layout_v4(stage: Control) -> void:
	_frame(stage, 56, 174, 428, 850)
	var rail: Panel = _flat_panel(PANEL_BG, 18, 2, BORDER)
	_fixed(stage, rail, 64, 182, 412, 834)

	var y: float = 200.0
	_fixed(stage, _label_node("数据源", 22, INK_2), 88, y, 200, 30)
	y += 36.0
	for i: int in POOL_LABELS.size():
		_fixed(stage, _button(POOL_LABELS[i], i == 0), 88, y, 364, 56)
		y += 62.0
	y += 16.0
	_fixed(stage, _label_node("难度", 22, INK_2), 88, y, 200, 30)
	y += 36.0
	for i: int in TIER_LABELS.size():
		_fixed(stage, _button(TIER_LABELS[i], i == 1), 88, y, 364, 56)
		y += 62.0
	y += 16.0
	_fixed(stage, _label_node("流程", 22, INK_2), 88, y, 200, 30)
	y += 36.0
	for i: int in MODE_LABELS.size():
		_fixed(stage, _button(MODE_LABELS[i], i == 0), 88, y, 364, 56)
		y += 62.0

	_frame(stage, 1476, 884, 380, 140)
	_route(stage, 512, 182, 1344, 676)
	_fixed(stage, _button("返回标题", false), 512, 904, 190, 64)
	_fixed(stage, _button("继续上次的团", false), 718, 904, 240, 64)
	_fixed(stage, _button("开始打团", false, true, 36), 1496, 894, 360, 108)


func _route(parent: Control, x: float, y: float, w: float, h: float) -> void:
	var panel: Panel = _flat_panel(PANEL_BG, 22, 2, BORDER)
	_fixed(parent, panel, x, y, w, h)
	_fixed(parent, _label_node("本次路线  ·  10 关", 26, INK), x + 28, y + 20, 420, 38)
	_fixed(parent, _label_node("初始命数 20", 22, INK_2), x + w - 240, y + 22, 210, 34)

	var gap: float = 12.0
	var chip_w: float = (w - 56.0 - gap * 9.0) / 10.0
	for i: int in range(10):
		var chip: Panel = _flat_panel(CHIP if i != 4 else Color("#F6C65B"), 40, 2, BORDER)
		_fixed(parent, chip, x + 28.0 + float(i) * (chip_w + gap), y + 92, chip_w, 76)
		var number: Label = _label_node(str(i + 1), 26, INK)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_fixed(parent, number, x + 28.0 + float(i) * (chip_w + gap), y + 92, chip_w, 76)
	_fixed(parent, _label_node("（路线预览内容保持与其它元素一致）", 20, INK_2), x + 28, y + h - 52, 620, 34)


func _frame(parent: Control, x: float, y: float, w: float, h: float) -> void:
	var frame: Panel = _flat_panel(Color(0, 0, 0, 0), 14, 2, HIGHLIGHT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fixed(parent, frame, x, y, w, h)


# ---------------------------------------------------------------------------
# 通用样式
# ---------------------------------------------------------------------------

func _fixed(parent: Control, child: Control, x: float, y: float, w: float, h: float) -> void:
	parent.add_child(child)
	child.position = Vector2(x, y)
	child.size = Vector2(w, h)
	child.custom_minimum_size = Vector2(w, h)


func _label_node(content: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _flat_panel(bg: Color, radius: float, border: int, border_color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _sb(bg, int(radius), border_color, border))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _button(content: String, selected: bool, primary: bool = false, font_size: int = 25) -> Button:
	var button: Button = Button.new()
	button.text = content
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	var normal: Color = ACCENT if primary else (SELECTED if selected else WHITE)
	var edge: Color = ACCENT if primary else (HIGHLIGHT if selected else BORDER)
	button.add_theme_stylebox_override("normal", _sb(normal, 12, edge, 2))
	button.add_theme_stylebox_override("hover", _sb(normal.lightened(0.08), 12, edge, 2))
	button.add_theme_stylebox_override("pressed", _sb(normal.darkened(0.12), 12, edge, 2))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fg: Color = WHITE if (primary or selected) else INK
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)
	return button


func _sb(bg: Color, radius: int, border_color: Color, border: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = border_color
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.anti_aliasing = true
	return style
