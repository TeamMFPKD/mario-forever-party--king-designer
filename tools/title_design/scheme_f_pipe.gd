extends Control

## 方案 F · 水管按钮
## 5 个入口用 1:1 复刻的水管 SVG（sprite/ui/pipe/warp_pipe.svg）当按钮，
## 靠色相旋转换成五种配色；文字白色压黑边，不摆英文（英文留给 po 本地化）。
## 水管在帽檐以下分成「帽檐 + 可纵向拉伸的管身」两段：管身向下多伸 150px 出画面，
## 所以 hover 整根上浮也永远不会露出底边。
## 管口道具平常缩在管身里（水管不透明，看不见），hover 才升到管口上方；不做透明度变化。
## 右下角 ads 完全照 room/title.tscn 的 Ad 节点摆放，按钮区居中排布、不给它让位。

const PIPE_TEXTURE: Texture2D = preload("res://sprite/ui/pipe/warp_pipe.svg")
const ADS_TEXTURE: Texture2D = preload("res://sprite/mf_cn_community.png")
## 项目统一的马造字体（与标题同一个字体资源）
const FONT_MAKER: Font = preload("res://font/ui_maker_font.tres")


## PIPE_W 表示「帽檐宽度」。素材 SVG 左右各有 16.5px 透明边，
## 用下面三个值把纹理裁到 16..152，这样 PIPE_GAP 才是真正的帽檐间距。
const SOURCE_W: float = 169.0
const TRIM_LEFT: float = 16.0
const TRIM_W: float = 136.0

const PIPE_W: float = 190.0
const PIPE_GAP: float = 24.0
const PIPE_VISIBLE_H: float = 296.0
const PIPE_OVERFLOW: float = 150.0
const CAP_RATIO: float = 0.245
const ITEM_SIZE: float = 150.0
const ITEM_OUTLINE_PX: int = 5
const ITEM_PADDING: int = 8
const ITEM_HIDDEN_Y: float = 200.0
const ITEM_SHOWN_Y: float = -130.0
const HOVER_LIFT: float = 18.0

## 五根水管整体水平居中
const PIPE_LEFT: float = (1920.0 - (PIPE_W * 5.0 + PIPE_GAP * 4.0)) * 0.5

## 配色：组织=绿 / 加入=黄 / 记录=蓝 / 百人团=红 / 设置=白。
## 调色直接改下面 5 个十六进制值（顺序 = 入口顺序），其余由 PipeTint 换算。
const TARGET_COLORS: Array[String] = [
	"#00aa63",
	"#f2b81c",
	"#2f7fe0",
	"#d6342a",
	"#f2f2f2",
]

## 素材管身主色，用来算色相/饱和度/亮度的换算比例
const SOURCE_MAIN: Color = Color("00aa63")

static var _variants: Array[Texture2D] = []
static var _item_textures: Array[Texture2D] = []

var _items: Array[Texture2D] = []
var _item_nodes: Array[TextureRect] = []


## 道具贴图在运行时烘一次「整图外描边」，结果缓存，切换方案不会重复计算
func _item_texture(index: int) -> Texture2D:
	if _item_textures.size() != _items.size():
		_item_textures.clear()
		for source: Texture2D in _items:
			_item_textures.append(
				ItemOutline.bake(source, int(ITEM_SIZE), ITEM_OUTLINE_PX, ITEM_PADDING)
			)
	return _item_textures[index]


## 仅供截图/调试：把五根管口的道具一次性升起来（正常靠 hover 触发）
func show_all_items() -> void:
	for node: TextureRect in _item_nodes:
		if is_instance_valid(node):
			node.position.y = ITEM_SHOWN_Y


func build() -> void:
	TitleKit.prepare(self)
	TitleKit.add_background(self)
	TitleKit.add_title(self)
	TitleKit.add_version(self)
	_item_nodes.clear()
	_build_items()
	_build_pipes()
	_build_ads()


func _build_items() -> void:
	_items = [
		preload("res://sprite/ui/title/Artwork_-_SUPER_MUSHROOM_(Simple).svg"),
		preload("res://sprite/ui/title/Super_Mario_-_Art_-_1UP_Mushroom.svg"),
		preload("res://sprite/ui/title/smg_clock_cartoon.svg"),
		preload("res://sprite/ui/title/Artwork_-_SUPER_STAR_(Simple).svg"),
		preload("res://sprite/ui/title/Artwork_-_QUESTION_BOX_(Simple).svg"),
	]


func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _pipe_texture(index: int) -> Texture2D:
	if _variants.is_empty():
		_build_variants()
	return _variants[index]


static func _build_variants() -> void:
	_variants.clear()
	var source: Image = PIPE_TEXTURE.get_image()
	if source == null:
		return
	for hex_code: String in TARGET_COLORS:
		_variants.append(PipeTint.variant(source, Color(hex_code), SOURCE_MAIN))


func _build_pipes() -> void:
	var items: Array[Dictionary] = TitleKit.menu_items()
	var top: float = TitleKit.CANVAS.y - PIPE_VISIBLE_H
	for index: int in range(items.size()):
		var x: float = PIPE_LEFT + float(index) * (PIPE_W + PIPE_GAP)
		_build_pipe(items[index], index, x, top)


func _build_pipe(item: Dictionary, index: int, x: float, top: float) -> void:
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(self, holder, x, top, PIPE_W, PIPE_VISIBLE_H)

	# 道具先加、水管后加：平常整体藏在管身里，hover 时升到管口上方自然「钻」出来
	var item_node: TextureRect = TextureRect.new()
	item_node.texture = _item_texture(index)
	item_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(
		holder,
		item_node,
		(PIPE_W - ITEM_SIZE) * 0.5,
		ITEM_HIDDEN_Y,
		ITEM_SIZE,
		ITEM_SIZE
	)
	_item_nodes.append(item_node)

	var texture: Texture2D = _pipe_texture(index)
	var texture_size: Vector2 = texture.get_size()
	var trim_x: float = texture_size.x * TRIM_LEFT / SOURCE_W
	var trim_w: float = texture_size.x * TRIM_W / SOURCE_W
	var cap_px: float = texture_size.y * CAP_RATIO
	var cap_h: float = PIPE_VISIBLE_H * CAP_RATIO

	# 帽檐：原样缩放，不拉伸
	var cap: TextureRect = TextureRect.new()
	cap.texture = _atlas(texture, Rect2(trim_x, 0.0, trim_w, cap_px))
	cap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cap.stretch_mode = TextureRect.STRETCH_SCALE
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(holder, cap, 0.0, 0.0, PIPE_W, cap_h)

	# 管身：只纵向拉伸，底部再多伸 150px 到画面外
	var body: TextureRect = TextureRect.new()
	body.texture = _atlas(
		texture,
		Rect2(trim_x, cap_px, trim_w, texture_size.y - cap_px)
	)
	body.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	body.stretch_mode = TextureRect.STRETCH_SCALE
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(
		holder,
		body,
		0.0,
		cap_h,
		PIPE_W,
		PIPE_VISIBLE_H - cap_h + PIPE_OVERFLOW
	)

	_build_label(holder, item, index)

	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	TitleKit.fixed(
		holder,
		button,
		0.0,
		ITEM_SHOWN_Y,
		PIPE_W,
		PIPE_VISIBLE_H - ITEM_SHOWN_Y
	)
	TitleKit.bind_hover(holder, button, HOVER_LIFT, 1.0)
	button.mouse_entered.connect(_on_item_hover.bind(item_node, true))
	button.mouse_exited.connect(_on_item_hover.bind(item_node, false))
	button.pressed.connect(_on_pipe_pressed.bind(holder))


func _on_item_hover(item_node: TextureRect, entered: bool) -> void:
	if not is_instance_valid(item_node) or not item_node.is_inside_tree():
		return
	var target_y: float = ITEM_SHOWN_Y if entered else ITEM_HIDDEN_Y
	var tween: Tween = item_node.create_tween()
	tween.tween_property(item_node, "position:y", target_y, 0.2).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)


func _build_label(holder: Control, item: Dictionary, index: int) -> void:
	var primary: bool = index == 0
	var label: Label = TitleKit.text(
		str(item["label"]),
		38 if primary else 36,
		Color(1, 1, 1, 1),
		10,
		Color(0.04, 0.04, 0.04, 1.0)
	)
	label.add_theme_font_override("font", FONT_MAKER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(holder, label, 8.0, 160.0, PIPE_W - 16.0, 64.0)


func _on_pipe_pressed(holder: Control) -> void:
	if not is_instance_valid(holder) or not holder.is_inside_tree():
		return
	var base: Vector2 = holder.position
	var tween: Tween = holder.create_tween()
	tween.tween_property(holder, "position", base + Vector2(0.0, 8.0), 0.06)
	tween.tween_property(holder, "position", base, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_ads() -> void:
	# 与 room/title.tscn 的 Ad 节点同参数：右下角 300×200 容器、四周 16 内边距、
	# TextureButton 默认拉伸填满；不加底板、阴影、角标或说明文字。
	var ad: TextureButton = TextureButton.new()
	ad.texture_normal = ADS_TEXTURE
	ad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(self, ad, 1551.0, 896.0, 268.0, 168.0)
