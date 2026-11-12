extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 五套百人团 HUD 图标的并排对比截图。
## 运行：Godot（窗口化，不要 --headless）--path . res://tools/adventure_icon_styles_shot.tscn

const OUTPUT: String = "res://tools/adventure_icon_styles.png"
const ICON_DIR: String = "res://sprite/ui/adventure/"

const ICON_SIZE: float = 160.0
const COL_WIDTH: float = 200.0
const ROW_HEIGHT: float = 180.0
const TABLE_LEFT: float = 510.0
const TABLE_TOP: float = 150.0
const NAME_WIDTH: float = 300.0

const STYLES: Array = [
	["A · 贴纸厚描边", "深色粗边 + 亮色填充", "set_a_sticker"],
	["B · 8-bit 像素", "阶梯像素块，硬边平涂", "set_b_pixel"],
	["C · 扁平极简", "无描边，纯几何色块", "set_c_flat"],
	["D · 手绘涂鸦", "抖动线条 + 半透明水彩", "set_d_doodle"],
	["E · 霓虹线框", "多层描边模拟辉光", "set_e_neon"],
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

	_add_label("百人团 HUD 图标 · 五套风格", Vector2(0, 36), Vector2(1920, 60), 46, HORIZONTAL_ALIGNMENT_CENTER)

	for column: int in range(ITEMS.size()):
		var item: Array = ITEMS[column]
		_add_label(
			str(item[0]),
			Vector2(TABLE_LEFT + NAME_WIDTH + COL_WIDTH * float(column), TABLE_TOP - 58),
			Vector2(COL_WIDTH, 40),
			32,
			HORIZONTAL_ALIGNMENT_CENTER
		)

	for row_index: int in range(STYLES.size()):
		var style: Array = STYLES[row_index]
		var row_y: float = TABLE_TOP + ROW_HEIGHT * float(row_index)
		_add_label(str(style[0]), Vector2(TABLE_LEFT, row_y + 34), Vector2(NAME_WIDTH - 20, 44), 34, HORIZONTAL_ALIGNMENT_LEFT)
		_add_label(str(style[1]), Vector2(TABLE_LEFT, row_y + 82), Vector2(NAME_WIDTH - 20, 36), 22, HORIZONTAL_ALIGNMENT_LEFT)
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
