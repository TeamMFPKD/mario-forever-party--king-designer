extends Control

@warning_ignore_start("unsafe_cast")

## 标题画面里的一根水管按钮。
## 节点结构（Item / Cap / Body / Label / Button）都在 ui/title/pipe_button.tscn 里摆好，
## 本脚本只负责：按 pipe_index 上色、给管口道具烘描边、hover 上浮、点击抛信号。
## 位置由父节点（pipe_menu.tscn）决定，hover 只动自身 position.y。

signal pipe_pressed(index: int)

const FONT_MAKER: Font = preload("res://font/ui_maker_font.tres")

const SOURCE_W: float = 169.0
const TRIM_LEFT: float = 16.0
const TRIM_W: float = 136.0
const SOURCE_MAIN: Color = Color("00aa63")
const CAP_RATIO: float = 0.245

const ITEM_SIZE: float = 150.0
const ITEM_OUTLINE_PX: int = 5
const ITEM_PADDING: int = 8
const ITEM_HIDDEN_Y: float = 200.0
const ITEM_SHOWN_Y: float = -130.0

const HOVER_LIFT: float = 18.0

## 管身上可用的字宽（Label 左右各留 6px 内边距，避免贴到描边）。
## 4 字标签（如「随心挑战」）在 36 号下会超出这个宽度，按实际字宽反推字号。
const LABEL_FIT_W: float = 162.0
const LABEL_FIT_MIN_SIZE: int = 24

## 顺序 = pipe_index：绿 / 黄 / 蓝 / 红 / 白
const TARGET_COLORS: Array[String] = [
	"#00aa63",
	"#f2b81c",
	"#2f7fe0",
	"#d6342a",
	"#f2f2f2",
]
const LABELS: Array[String] = ["组织游戏", "加入游戏", "游玩记录", "随心挑战", "设置界面"]
const ITEM_PATHS: Array[String] = [
	"res://sprite/ui/title/Artwork_-_SUPER_MUSHROOM_(Simple).svg",
	"res://sprite/ui/title/Super_Mario_-_Art_-_1UP_Mushroom.svg",
	"res://sprite/ui/title/smg_clock_cartoon.svg",
	"res://sprite/ui/title/Artwork_-_SUPER_STAR_(Simple).svg",
	"res://sprite/ui/title/Artwork_-_QUESTION_BOX_(Simple).svg",
]

@export var pipe_index: int = 0
## 由 pipe_menu.tscn 里每根实例指定（variant_green / yellow / blue / red / white），
## 这样编辑器里也能直接看到对应颜色；留空则回退到运行时从 warp_pipe.svg 生成。
@export var pipe_texture: Texture2D

@onready var _item: TextureRect = $Item
@onready var _cap: TextureRect = $Cap
@onready var _body: TextureRect = $Body
@onready var _label: Label = $Label
@onready var _button: Button = $Button

static var _pipe_variants: Array[Texture2D] = []
static var _item_variants: Dictionary = {}

var _base_y: float = 0.0
## 由 pipe_menu 控制：整排收起/升回期间锁掉点击与 hover 位移
var _input_locked: bool = false
var _hover_tween: Tween
var _item_tween: Tween


func _ready() -> void:
	_base_y = position.y
	_apply_label()
	_apply_pipe()
	_apply_item()
	_button.mouse_entered.connect(_on_hover.bind(true))
	_button.mouse_exited.connect(_on_hover.bind(false))
	_button.pressed.connect(_on_pressed)


## 由 pipe_menu 在重排后回填，保证 hover 用的是最新的静止 y
func set_base_position(y: float) -> void:
	_base_y = y


## 仅供截图/调试：把管口道具升起来
func show_item() -> void:
	_item.position.y = ITEM_SHOWN_Y


## 由 pipe_menu 调用：锁掉点击，并把 hover 抬起的位移与管口道具收回去
func set_input_locked(locked: bool) -> void:
	_input_locked = locked
	_button.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	)
	if locked:
		_stop_hover()


func _stop_hover() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null
	if _item_tween != null and _item_tween.is_valid():
		_item_tween.kill()
	_item_tween = null
	if _item != null:
		_item.position.y = ITEM_HIDDEN_Y


func _apply_label() -> void:
	if pipe_index < 0 or pipe_index >= LABELS.size():
		return
	_label.text = LABELS[pipe_index]
	_label.add_theme_font_override("font", FONT_MAKER)
	_label.add_theme_font_size_override("font_size", _fit_font_size(LABELS[pipe_index], 38 if pipe_index == 0 else 36))


## 字号按字宽反推：太长就整体缩小，保证不越过管身描边。
## 短标签（2~3 字）算出来的字号会比 MAX 还大，这里只往下压不往上放。
func _fit_font_size(text: String, preferred: int) -> int:
	var width: float = FONT_MAKER.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, preferred
	).x
	if width <= LABEL_FIT_W or width <= 0.0:
		return preferred
	var scaled: float = float(preferred) * LABEL_FIT_W / width
	return maxi(LABEL_FIT_MIN_SIZE, int(floorf(scaled)))


func _apply_pipe() -> void:
	var texture: Texture2D = pipe_texture
	if texture == null:
		texture = _pipe_texture()
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	var trim_x: float = texture_size.x * TRIM_LEFT / SOURCE_W
	var trim_w: float = texture_size.x * TRIM_W / SOURCE_W
	var cap_px: float = texture_size.y * CAP_RATIO
	_cap.texture = _atlas(texture, Rect2(trim_x, 0.0, trim_w, cap_px))
	_body.texture = _atlas(
		texture,
		Rect2(trim_x, cap_px, trim_w, texture_size.y - cap_px)
	)


func _apply_item() -> void:
	if pipe_index < 0 or pipe_index >= ITEM_PATHS.size():
		return
	_item.texture = _item_texture(pipe_index)
	_item.position = Vector2((size.x - ITEM_SIZE) * 0.5, ITEM_HIDDEN_Y)


func _pipe_texture() -> Texture2D:
	var source_path: String = "res://sprite/ui/pipe/warp_pipe.svg"
	if _pipe_variants.is_empty():
		var source_image: Image = (load(source_path) as Texture2D).get_image()
		if source_image == null:
			return null
		for hex_code: String in TARGET_COLORS:
			_pipe_variants.append(
				PipeTint.variant(source_image, Color(hex_code), SOURCE_MAIN)
			)
	if pipe_index < 0 or pipe_index >= _pipe_variants.size():
		return null
	return _pipe_variants[pipe_index]


func _item_texture(index: int) -> Texture2D:
	if _item_variants.has(index):
		return _item_variants[index] as Texture2D
	var source: Texture2D = load(ITEM_PATHS[index]) as Texture2D
	var baked: Texture2D = ItemOutline.bake(
		source, int(ITEM_SIZE), ITEM_OUTLINE_PX, ITEM_PADDING
	)
	_item_variants[index] = baked
	return baked


func _atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	return atlas


func _on_hover(entered: bool) -> void:
	if _input_locked:
		return
	var target_y: float = (_base_y - HOVER_LIFT) if entered else _base_y
	var item_target: float = ITEM_SHOWN_Y if entered else ITEM_HIDDEN_Y
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "position:y", target_y, 0.12).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	_item_tween = _item.create_tween()
	_item_tween.tween_property(_item, "position:y", item_target, 0.2).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)


func _on_pressed() -> void:
	pipe_pressed.emit(pipe_index)
