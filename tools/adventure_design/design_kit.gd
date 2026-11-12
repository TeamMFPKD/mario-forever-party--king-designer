class_name DesignKit
extends RefCounted

## 百人团 UI 方案预览用的公共样式/排布工具。
## 只服务 tools/adventure_design_preview，不参与正式界面。

const THEME: Theme = preload("res://ui/theme/theme_maker.tres")

const INK: Color = Color("2b2a28")
const INK_2: Color = Color("57503f")
const INK_3: Color = Color("8c8471")
const PAPER: Color = Color("fdf7e7")
const PAPER_2: Color = Color("f3ead4")
const PAPER_3: Color = Color("e7dcc2")
const CREAM: Color = Color("fff8e6")
const RED: Color = Color("e0442c")
const RED_DEEP: Color = Color("b3301b")
const YELLOW: Color = Color("ffc531")
const GREEN: Color = Color("57a83f")
const GREEN_DEEP: Color = Color("3d7d2c")
const BLUE: Color = Color("3d7bd9")
const WHITE: Color = Color("ffffff")

const NIGHT: Color = Color("0b1026")
const NIGHT_2: Color = Color("141c3f")
const NIGHT_3: Color = Color("233064")
const CYAN: Color = Color("4ee1ff")
const MAGENTA: Color = Color("ff5fa2")
const NEON_TEXT: Color = Color("dce9ff")
const NEON_MUTED: Color = Color("7f92c4")

const TIER_NAMES: Array[String] = ["轻松", "标准", "困难", "极限"]
const TIER_COLORS: Array[Color] = [
	Color("bfe9ff"),
	Color("ffe7a3"),
	Color("e3b5ff"),
	Color("5a0f1a"),
]
const TIER_ACCENTS: Array[Color] = [
	Color("7bc96f"),
	Color("f2a24b"),
	Color("8e44ad"),
	Color("ff5252"),
]
const TIER_TEXT: Array[Color] = [
	Color("173a45"),
	Color("4a3a0d"),
	Color("3d1a4d"),
	Color("ffe1e1"),
]

## 模拟数据，仅用于让方案看起来像真实界面
const PLAYABLE: int = 1316
const SAMPLED: int = 1061
const TIER_COUNTS: Array[int] = [266, 265, 265, 265]
const LIKED: int = 128
const SELECTED_TIER: int = 2
const RUN_LENGTH: int = 10
const LIVES: int = 20


static func apply_theme(root: Control) -> void:
	root.theme = THEME


static func sb(
	bg: Color,
	radius: int = 12,
	border: int = 0,
	border_color: Color = INK,
	pad_h: float = 0.0,
	pad_v: float = 0.0
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_detail = 10
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = border_color
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	style.anti_aliasing = true
	return style


static func text(content: String, font_size: int, color: Color = INK, wrap_width: float = 0.0) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	if wrap_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(wrap_width, 0)
	return label


static func place(parent: Control, child: Control, x: float, y: float) -> void:
	parent.add_child(child)
	child.position = Vector2(x, y)


static func fixed(parent: Control, child: Control, x: float, y: float, w: float, h: float) -> void:
	parent.add_child(child)
	child.position = Vector2(x, y)
	child.size = Vector2(w, h)
	child.custom_minimum_size = Vector2(w, h)


static func row(parent: Control, x: float, y: float, w: float, h: float, sep: int = 12) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	fixed(parent, box, x, y, w, h)
	return box


static func column(parent: Control, x: float, y: float, w: float, h: float, sep: int = 12) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", sep)
	fixed(parent, box, x, y, w, h)
	return box


static func card(bg: Color, radius: int, border: int, border_color: Color, pad_h: float, pad_v: float) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb(bg, radius, border, border_color, pad_h, pad_v))
	return panel


static func flat_panel(bg: Color, radius: int, border: int, border_color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", sb(bg, radius, border, border_color))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


static func hairline(parent: Control, x: float, y: float, w: float, color: Color = Color(0.17, 0.165, 0.157, 0.18), thickness: float = 2.0) -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed(parent, line, x, y, w, thickness)
	return line


static func rule(width: float, color: Color = Color(0.17, 0.165, 0.157, 0.18), thickness: float = 2.0) -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(width, thickness)
	return line


static func spacer(width: float, height: float) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2(width, height)
	return node


static func push() -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2.ZERO
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func pill(label_text: String, font_size: int, selected: bool, accent: Color = RED) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	var pad_h: float = roundf(float(font_size) * 0.82)
	var pad_v: float = roundf(float(font_size) * 0.36)
	if selected:
		button.add_theme_stylebox_override("normal", sb(INK, 12, 4, accent, pad_h, pad_v))
		button.add_theme_stylebox_override("hover", sb(INK.lightened(0.12), 12, 4, accent, pad_h, pad_v))
		button.add_theme_stylebox_override("pressed", sb(INK.darkened(0.2), 12, 4, accent, pad_h, pad_v))
		button.add_theme_color_override("font_color", CREAM)
		button.add_theme_color_override("font_hover_color", CREAM)
		button.add_theme_color_override("font_pressed_color", CREAM)
	else:
		button.add_theme_stylebox_override("normal", sb(PAPER, 12, 3, INK, pad_h, pad_v))
		button.add_theme_stylebox_override("hover", sb(PAPER_2, 12, 3, INK, pad_h, pad_v))
		button.add_theme_stylebox_override("pressed", sb(PAPER_3, 12, 3, INK, pad_h, pad_v))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_disabled_color", INK_3)
	button.add_theme_stylebox_override("disabled", sb(PAPER_3, 12, 3, INK_3, pad_h, pad_v))
	return button


static func ghost_pill(label_text: String, font_size: int) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", sb(Color(1, 1, 1, 0), 12, 3, INK_3, 24, 12))
	button.add_theme_stylebox_override("hover", sb(Color(1, 1, 1, 0.45), 12, 3, INK, 24, 12))
	button.add_theme_stylebox_override("pressed", sb(Color(1, 1, 1, 0.7), 12, 3, INK, 24, 12))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", INK_2)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	return button


static func big_button(label_text: String, width: float, height: float, bg: Color, fg: Color, font_size: int = 38) -> Control:
	var wrapper: Control = Control.new()
	wrapper.custom_minimum_size = Vector2(width + 10.0, height + 10.0)
	wrapper.size = Vector2(width + 10.0, height + 10.0)
	var shadow: Panel = flat_panel(INK, 16, 0, INK)
	shadow.position = Vector2(10, 10)
	shadow.size = Vector2(width, height)
	wrapper.add_child(shadow)
	var button: Button = Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.position = Vector2.ZERO
	button.size = Vector2(width, height)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("outline_size", 0)
	button.add_theme_stylebox_override("normal", sb(bg, 16, 4, INK, 24, 14))
	button.add_theme_stylebox_override("hover", sb(bg.lightened(0.08), 16, 4, INK, 24, 14))
	button.add_theme_stylebox_override("pressed", sb(bg.darkened(0.1), 16, 4, INK, 24, 14))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", fg)
	button.add_theme_color_override("font_hover_color", fg)
	button.add_theme_color_override("font_pressed_color", fg)
	wrapper.add_child(button)
	return wrapper


static func tag(label_text: String, font_size: int, bg: Color, fg: Color, radius: int = 10, pad_h: float = 16.0, pad_v: float = 8.0) -> PanelContainer:
	var panel: PanelContainer = card(bg, radius, 0, bg, pad_h, pad_v)
	var label: Label = text(label_text, font_size, fg)
	panel.add_child(label)
	return panel


static func progress_bar(width: float, height: float, value: float, fill: Color, bg: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.size = Vector2(width, height)
	bar.add_theme_stylebox_override("background", sb(bg, int(height * 0.5), 0, bg))
	bar.add_theme_stylebox_override("fill", sb(fill, int(height * 0.5), 0, fill))
	return bar
