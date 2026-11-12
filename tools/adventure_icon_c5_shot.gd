extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## C5 修订版预览：改后的三个图标 + 五个「跳过」符号候选。
## 运行：Godot（窗口化，不要 --headless）--path . res://tools/adventure_icon_c5_shot.tscn

const OUTPUT: String = "res://tools/adventure_icon_c5.png"
const ICON_DIR: String = "res://sprite/ui/adventure/set_c5_cutout/"

const MAIN: Array = [
	["通过", "goal"],
	["死亡", "death"],
	["跳过（1）", "skip_variants/skip_1_fastbar"],
]

const SKIPS: Array = [
	["1 · 快进 + 竖条", "skip_variants/skip_1_fastbar"],
	["2 · 叉号", "skip_variants/skip_2_cross"],
	["3 · 越过横栏", "skip_variants/skip_3_hop"],
	["4 · 单箭头", "skip_variants/skip_4_arrow"],
	["5 · 纯双三角", "skip_variants/skip_5_fast"],
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

	_add_label("C5 · 镂空负空间（修订）", Vector2(0, 26), Vector2(1920, 56), 42, HORIZONTAL_ALIGNMENT_CENTER)

	# 第一组：通过 / 死亡 / 跳过
	var main_size: float = 168.0
	var main_gap: float = 250.0
	var main_start: float = 960.0 - main_gap
	for index: int in range(MAIN.size()):
		var item: Array = MAIN[index]
		var center_x: float = main_start + main_gap * float(index)
		_add_icon(ICON_DIR + str(item[1]) + ".svg", Vector2(center_x - main_size * 0.5, 120.0), main_size)
		_add_label(str(item[0]), Vector2(center_x - 100.0, 300.0), Vector2(200, 36), 26, HORIZONTAL_ALIGNMENT_CENTER)

	_add_label("跳过符号候选", Vector2(0, 372), Vector2(1920, 44), 30, HORIZONTAL_ALIGNMENT_CENTER)

	# 第二组：五个跳过符号
	var skip_size: float = 140.0
	var skip_gap: float = 200.0
	var skip_start: float = 960.0 - skip_gap * 2.0
	for index: int in range(SKIPS.size()):
		var item: Array = SKIPS[index]
		var center_x: float = skip_start + skip_gap * float(index)
		_add_icon(ICON_DIR + str(item[1]) + ".svg", Vector2(center_x - skip_size * 0.5, 440.0), skip_size)
		_add_label(str(item[0]), Vector2(center_x - 100.0, 596.0), Vector2(200, 34), 22, HORIZONTAL_ALIGNMENT_CENTER)

	# 第三组：把五个跳过符号按实机 56px 排一行，检查缩小后的辨识度
	_add_label("实机 56px", Vector2(0, 680), Vector2(1920, 40), 26, HORIZONTAL_ALIGNMENT_CENTER)
	var small_size: float = 56.0
	var small_gap: float = 96.0
	var small_start: float = 960.0 - small_gap * 2.0
	for index: int in range(SKIPS.size()):
		var item: Array = SKIPS[index]
		var center_x: float = small_start + small_gap * float(index)
		_add_icon(ICON_DIR + str(item[1]) + ".svg", Vector2(center_x - small_size * 0.5, 736.0), small_size)
		_add_label(str(index + 1), Vector2(center_x - 40.0, 800.0), Vector2(80, 30), 20, HORIZONTAL_ALIGNMENT_CENTER)


func _add_icon(path: String, pos: Vector2, size_value: float) -> void:
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = pos
	rect.size = Vector2(size_value, size_value)
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
