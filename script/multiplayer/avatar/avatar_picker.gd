class_name AvatarPicker
extends Control

## 头像选择面板：点开头像后，所有头像从点击位置「炸开」飞到网格里。
##
## 动画规格：
##   - 每个头像的起点 = 点击点 + 随机角度 × 随机距离；
##   - 起点到格位是直线运动；
##   - 所有头像总时长一致（fly_duration），一起落位；
##   - 缓动用三次插值（TRANS_CUBIC + EASE_OUT）。
##
## 面板比 Host / Join 面板（680 宽）更大，一屏铺开所有头像，点一下即选中。

signal avatar_chosen(avatar_id: String)
signal picker_closed()

const CELL: int = 120
const CELL_GAP: int = 14
const COLUMNS: int = 5

## 所有头像统一的飞行时长。
@export var fly_duration: float = 0.42
@export var min_distance: float = 120.0
@export var max_distance: float = 420.0

@onready var _backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
@onready var _items: Control = get_node_or_null("Panel/Margin/VBox/Items") as Control

var _cells: Array[Button] = []
var _selected_id: String = ""


func _ready() -> void:
	visible = false
	if _backdrop != null:
		_backdrop.gui_input.connect(_on_backdrop_input)


## 打开面板：from_global 是点击位置，current_id 是当前已选头像。
func open(from_global: Vector2, current_id: String) -> void:
	_selected_id = current_id
	visible = true
	# 先等布局稳定，再按 Items 的实际尺寸摆格位。
	await get_tree().process_frame
	await get_tree().process_frame
	_rebuild_cells()
	await get_tree().process_frame
	_fling_from(from_global)


func close() -> void:
	if not visible:
		return
	visible = false
	picker_closed.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close()


## 按 Items 的实际尺寸重新排布所有格子。
func _rebuild_cells() -> void:
	for cell: Button in _cells:
		if is_instance_valid(cell):
			cell.queue_free()
	_cells.clear()
	if _items == null:
		return

	var total: int = Avatars.count()
	var rows: int = ceili(float(total) / float(COLUMNS))
	var grid_w: float = float(COLUMNS * CELL + (COLUMNS - 1) * CELL_GAP)
	var grid_h: float = float(rows * CELL + (rows - 1) * CELL_GAP)
	var origin: Vector2 = Vector2(
		maxf((_items.size.x - grid_w) * 0.5, 0.0),
		maxf((_items.size.y - grid_h) * 0.5, 0.0)
	)

	for i: int in range(total):
		var avatar_id: String = Avatars.get_id(i)
		var texture: Texture2D = Avatars.get_texture(i)
		if texture == null:
			continue

		var cell: Button = Button.new()
		cell.name = "Cell_%s" % avatar_id
		cell.size = Vector2(CELL, CELL)
		cell.custom_minimum_size = Vector2(CELL, CELL)
		cell.focus_mode = Control.FOCUS_NONE
		cell.icon = texture
		cell.expand_icon = true
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_theme_stylebox_override("normal", _make_style(avatar_id == _selected_id, false))
		cell.add_theme_stylebox_override("hover", _make_style(false, true))
		cell.add_theme_stylebox_override("pressed", _make_style(true, true))
		cell.pressed.connect(_on_cell_pressed.bind(avatar_id))

		var col: int = i % COLUMNS
		var row: int = floori(float(i) / float(COLUMNS))
		cell.position = origin + Vector2(
			float(col) * float(CELL + CELL_GAP),
			float(row) * float(CELL + CELL_GAP)
		)

		_items.add_child(cell)
		_cells.append(cell)


func _make_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.72, 1.0) if hovered else Color(1, 1, 1, 1)
	style.set_corner_radius_all(10)
	var border: int = 4 if selected else 2
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.border_color = Color(0.97, 0.78, 0.16, 1.0) if selected else Color(0.55, 0.55, 0.6, 1.0)
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	return style


## 从点击点把全部头像甩到各自格位。
func _fling_from(from_global: Vector2) -> void:
	var from_local: Vector2 = _items.get_global_transform().affine_inverse() * from_global

	for cell: Button in _cells:
		if not is_instance_valid(cell):
			continue
		var target: Vector2 = cell.position
		var angle: float = randf() * TAU
		var distance: float = randf_range(min_distance, max_distance)
		var start: Vector2 = from_local + Vector2.from_angle(angle) * distance

		cell.position = start
		cell.pivot_offset = Vector2(CELL, CELL) * 0.5
		cell.scale = Vector2(0.5, 0.5)
		cell.modulate.a = 0.0

		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(cell, "position", target, fly_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(cell, "scale", Vector2.ONE, fly_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(cell, "modulate:a", 1.0, fly_duration * 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_cell_pressed(avatar_id: String) -> void:
	if avatar_id.is_empty():
		return
	_selected_id = avatar_id
	avatar_chosen.emit(avatar_id)
	close()
