class_name TitleKit
extends RefCounted

## 标题画面按钮重做方案的公共零件：背景、标题、按钮、排版工具。
## 只服务 tools/title_design_preview 与 tools/title_design/*，不参与正式界面。

const CANVAS: Vector2 = Vector2(1920.0, 1080.0)
const THEME: Theme = preload("res://mfmp_theme.tres")
const BG_TEXTURE: Texture2D = preload("res://sprite/psc.png")

const INK: Color = Color("1b1b1b")
const INK_SOFT: Color = Color("514c41")
const INK_MUTED: Color = Color("8c8471")
const PAPER: Color = Color("fffdf2")
const PAPER_2: Color = Color("f4ecd9")
const PAPER_3: Color = Color("e6dcc4")
const CREAM: Color = Color("fff8e6")
const YELLOW: Color = Color("ffc531")
const YELLOW_DEEP: Color = Color("d99a0c")
const RED: Color = Color("e0442c")
const GREEN: Color = Color("57a83f")
const BLUE: Color = Color("3d7bd9")
const PURPLE: Color = Color("8e6bd9")
const WHITE: Color = Color("ffffff")

const TITLE_TOP: float = 34.0
const TITLE_WIDTH: float = 1400.0


## 5 个入口。第一条是主推项，accent 用于各方案里的色条/色块。
static func menu_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = [
		{
			"id": "host",
			"label": "组织游戏",
			"en": "HOST GAME",
			"note": "开个房间，等朋友进来",
			"accent": YELLOW,
		},
		{
			"id": "join",
			"label": "加入游戏",
			"en": "JOIN GAME",
			"note": "填房主地址，直接进场",
			"accent": BLUE,
		},
		{
			"id": "history",
			"label": "游玩记录",
			"en": "HISTORY",
			"note": "回看玩过的关卡与战绩",
			"accent": GREEN,
		},
		{
			"id": "raid",
			"label": "百人团",
			"en": "RAID MODE",
			"note": "十关连闯，命数用尽为止",
			"accent": RED,
		},
		{
			"id": "options",
			"label": "设置界面",
			"en": "OPTIONS",
			"note": "音量、分辨率、按键",
			"accent": PURPLE,
		},
	]
	return items


static func prepare(root: Control) -> void:
	root.size = CANVAS
	root.custom_minimum_size = CANVAS
	root.theme = THEME
	root.mouse_filter = Control.MOUSE_FILTER_PASS


static func add_background(root: Control) -> void:
	var bg: TextureRect = TextureRect.new()
	bg.texture = BG_TEXTURE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed(root, bg, 0.0, 0.0, CANVAS.x, CANVAS.y)


## 标题组：与正式标题页一致（黑字、白描边、15px 阴影）+ 右下角副标题。
static func add_title(root: Control, top: float = TITLE_TOP) -> void:
	var group: Control = Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fixed(root, group, (CANVAS.x - TITLE_WIDTH) * 0.5, top, TITLE_WIDTH, 470.0)

	var title: Label = text("MARIO FOREVER\nMAKER PARTY", 160, Color(0, 0, 0, 1), 20, WHITE)
	title.add_theme_constant_override("shadow_offset_x", 15)
	title.add_theme_constant_override("shadow_offset_y", 15)
	title.add_theme_constant_override("shadow_outline_size", 20)
	title.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	fixed(group, title, 0.0, 0.0, TITLE_WIDTH, 420.0)

	var subtitle: Label = text("GALAXY UPDATE", 48, Color(0, 0, 0, 1), 20, WHITE)
	subtitle.add_theme_constant_override("shadow_offset_x", 15)
	subtitle.add_theme_constant_override("shadow_offset_y", 15)
	subtitle.add_theme_constant_override("shadow_outline_size", 20)
	subtitle.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 1))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fixed(group, subtitle, 0.0, 372.0, 1246.0, 64.0)


## 左上角版本号，只为让方案看起来像真画面。
static func add_version(root: Control) -> void:
	var version: Label = text("v20261109_2238", 25, Color(1, 1, 1, 1), 5, Color(0, 0, 0, 1))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fixed(root, version, 16.0, 16.0, 300.0, 40.0)


static func sb(
	bg: Color,
	radius: int = 16,
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
	style.corner_detail = 12
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


static func text(
	content: String,
	font_size: int,
	color: Color = INK,
	outline: int = 0,
	outline_color: Color = INK,
	wrap_width: float = 0.0
) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
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


## 硬阴影 + 立体卡片的统一做法：返回按钮，影子由调用方决定要不要加。
static func button(
	parent: Control,
	x: float,
	y: float,
	w: float,
	h: float,
	bg: Color,
	radius: int,
	border: int,
	shadow_offset: float
) -> Button:
	if shadow_offset > 0.0:
		var shadow: Panel = Panel.new()
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.add_theme_stylebox_override("panel", sb(INK, radius, 0, INK))
		fixed(parent, shadow, x + shadow_offset, y + shadow_offset, w, h)
	var control: Button = Button.new()
	control.focus_mode = Control.FOCUS_NONE
	control.add_theme_stylebox_override("normal", sb(bg, radius, border, INK))
	control.add_theme_stylebox_override("hover", sb(bg.lightened(0.07), radius, border, INK))
	control.add_theme_stylebox_override("pressed", sb(bg.darkened(0.08), radius, border, INK))
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	fixed(parent, control, x, y, w, h)
	return control


## 鼠标悬停：整块抬升 + 轻微放大。trigger 通常是按钮，mover 是包住它的容器。
static func bind_hover(mover: Control, trigger: Control, lift: float, zoom: float) -> void:
	mover.pivot_offset = mover.size * 0.5
	var base_position: Vector2 = mover.position
	var base_scale: Vector2 = mover.scale
	trigger.mouse_entered.connect(_hover_to.bind(mover, base_position - Vector2(0.0, lift), base_scale * zoom))
	trigger.mouse_exited.connect(_hover_to.bind(mover, base_position, base_scale))


static func _hover_to(mover: Control, to_position: Vector2, to_scale: Vector2) -> void:
	if not is_instance_valid(mover) or not mover.is_inside_tree():
		return
	var tween: Tween = mover.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mover, "position", to_position, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(mover, "scale", to_scale, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 序号文本：01 ~ 05
static func index_text(index: int) -> String:
	return "%02d" % (index + 1)
