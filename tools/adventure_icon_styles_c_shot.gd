extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## C 系（扁平极简）五个变体的并排对比截图，第一行是 C 基准。
## 运行：Godot（窗口化，不要 --headless）--path . res://tools/adventure_icon_styles_c_shot.tscn

const OUTPUT: String = "res://tools/adventure_icon_styles_c.png"
const ICON_DIR: String = "res://sprite/ui/adventure/"

const ICON_SIZE: float = 128.0
const COL_WIDTH: float = 200.0
const ROW_HEIGHT: float = 150.0
const TABLE_LEFT: float = 510.0
const TABLE_TOP: float = 140.0
const NAME_WIDTH: float = 300.0

const STYLES: Array = [
	["C · 扁平极简", "基准：三色、无描边", "set_c_flat"],
	["C1 · 单色剪影", "全部同色，只靠轮廓", "set_c1_solid"],
	["C2 · 双色", "白 + 一点黄做强调", "set_c2_duotone"],
	["C3 · 超圆角柔和", "圆眼圆鼻、叶形旗", "set_c3_soft"],
	["C4 · 长投影", "45° 长影，扁平实体感", "set_c4_shadow"],
	["C5 · 镂空负空间", "圆角贴片里挖出符号", "set_c5_cutout"],
]

const ITEMS: Array = [
	["通过", "goal"],
	["死亡", "death"],
	["跳过", "skip"],
]


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_build()
	await get_tree().create_timer(0.7).timeout
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(OUTPUT)
	get_tree().quit()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.180392, 0.141176, 0.278431, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_add_label("百人团 HUD 图标 · C 系五变体", Vector2(0, 22), Vector2(1920, 54), 42, HORIZONTAL_ALIGNMENT_CENTER)

	for column: int in range(ITEMS.size()):
		var item: Array = ITEMS[column]
		_add_label(
			str(item[0]),
			Vector2(TABLE_LEFT + NAME_WIDTH + COL_WIDTH * float(column), TABLE_TOP - 50),
			Vector2(COL_WIDTH, 36),
			30,
			HORIZONTAL_ALIGNMENT_CENTER
		)

	for row_index: int in range(STYLES.size()):
		var style: Array = STYLES[row_index]
		var row_y: float = TABLE_TOP + ROW_HEIGHT * float(row_index)
		_add_label(str(style[0]), Vector2(TABLE_LEFT, row_y + 22), Vector2(NAME_WIDTH - 20, 40), 32, HORIZONTAL_ALIGNMENT_LEFT)
		_add_label(str(style[1]), Vector2(TABLE_LEFT, row_y + 66), Vector2(NAME_WIDTH - 20, 32), 20, HORIZONTAL_ALIGNMENT_LEFT)
		for column: int in range(ITEMS.size()):
			var item: Array = ITEMS[column]
			var path: String = "%s%s/%s.svg" % [ICON_DIR, str(style[2]), str(item[1])]
			var texture: Texture2D = load(path) as Texture2D
			if texture == null:
				continue
			var rect: TextureRect = TextureRect.new()
			rect.texture = texture
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.position = Vector2(
				TABLE_LEFT + NAME_WIDTH + COL_WIDTH * float(column) + (COL_WIDTH - ICON_SIZE) * 0.5,
				row_y
			)
			rect.size = Vector2(ICON_SIZE, ICON_SIZE)
			add_child(rect)


func _add_label(text_value: String, pos: Vector2, box: Vector2, font_size: int, align: HorizontalAlignment) -> void:
	var label: Label = Label.new()
	label.text = text_value
	label.position = pos
	label.size = box
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
