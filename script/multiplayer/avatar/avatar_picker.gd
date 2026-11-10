class_name AvatarPicker
extends Control

## 头像选择面板：点开头像按钮后，所有头像从按钮位置「炸开」，
## 沿随机角度 + 随机距离直线飞出去，落进面板里的随机位置（不排队、不对齐）。
##
## 动画规格：
##   - 每个头像的起点都相同 = 点击位置（按钮中心）；
##   - 落点 = 起点 + 随机角度 × 随机距离，且必须落在面板的散落区域内；
##   - 所有头像总时长一致（fly_duration），一起落位；
##   - 缓动用三次插值（TRANS_CUBIC + EASE_OUT）；
##   - 落点之间保持最小间距（约一个头像宽），避免互相压住点不到。
##
## 画面变暗 / 面板出现走同一段淡入（fade_duration），不做瞬间跳变。
## 面板比 Host / Join 页更大，用的是项目的大面积底板
## （ui/theme/panel_large.tres：深灰半透明、直角、无描边），面板里不放任何文字。

signal avatar_chosen(avatar_id: String)
signal picker_closed()

## 面板尺寸（视口更小时会在 _fit_to_viewport 里等比收进来）。
const PANEL_SIZE: Vector2 = Vector2(1000.0, 1040.0)
## 面板与屏幕边缘至少留出的距离。
const SCREEN_PADDING: float = 24.0

## 头像格子边长（同时是最小间距的基准）。
const CELL: float = 112.0
## 散落区域额外离 Items 边缘留的余量（另加半个格子）。
const EDGE_PADDING: float = 8.0
## 太挤时逐轮放宽间距的轮数，以及每轮间距的衰减系数。
const RELAX_STEPS: int = 6
const RELAX_RATIO: float = 0.85

## 画面变暗 + 面板出现的淡入时长。
@export var fade_duration: float = 0.22
## 所有头像统一的飞行时长。
@export var fly_duration: float = 0.42
## 起飞点到落点的最小距离。
@export var min_distance: float = 150.0
## 随机距离的上限；实际还会被散落区域的远端截断。
@export var max_distance: float = 640.0
## 落点之间的最小间距 = CELL × 该系数。
@export var min_gap_ratio: float = 1.15
## 单个落点最多重掷多少次。
@export var max_tries: int = 160

@onready var _backdrop: ColorRect = get_node_or_null("Backdrop") as ColorRect
@onready var _panel: Panel = get_node_or_null("Panel") as Panel
@onready var _items: Control = get_node_or_null("Panel/Margin/Items") as Control

var _cells: Array[Button] = []
## 与 _cells 一一对应的落点（Items 局部坐标）。
var _targets: Array[Vector2] = []
var _selected_id: String = ""
## 起飞点（Items 局部坐标），取落点时也要用。
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	visible = false
	# 父节点不一定是 Control（title 场景根是 Node2D），anchors 可能算不出铺满，
	# 这里显式把面板拉到视口大小，避免居中锚点退化到左上角 (0,0)。
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)
	if _backdrop != null:
		_backdrop.gui_input.connect(_on_empty_input)
	if _panel != null:
		_panel.gui_input.connect(_on_empty_input)


func _fit_to_viewport() -> void:
	var rect: Rect2 = get_viewport_rect()
	position = Vector2.ZERO
	size = rect.size
	if _panel == null:
		return
	# 小窗口下别让面板顶出屏幕（场景里存的是 1920x1080 下的尺寸）。
	var half: Vector2 = Vector2(
		minf(PANEL_SIZE.x, rect.size.x - SCREEN_PADDING) * 0.5,
		minf(PANEL_SIZE.y, rect.size.y - SCREEN_PADDING) * 0.5
	)
	_panel.offset_left = -half.x
	_panel.offset_top = -half.y
	_panel.offset_right = half.x
	_panel.offset_bottom = half.y


## 打开面板：from_global 是点击位置，current_id 是当前已选头像。
func open(from_global: Vector2, current_id: String) -> void:
	_selected_id = current_id
	visible = true
	# 从全透明开始，背景变暗和面板出现一起淡入。
	modulate.a = 0.0
	if _items == null:
		return
	# 先等布局稳定，再按 Items 的实际尺寸取散落点。
	await get_tree().process_frame
	await get_tree().process_frame
	_origin = _items.get_global_transform().affine_inverse() * from_global
	_rebuild_cells()
	_fade_in()
	_fling()


## 画面变暗（Backdrop）+ 面板出现的渐变；和头像飞行同时开始。
func _fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	visible = false
	picker_closed.emit()


## 点面板空白处 / 背景：关闭。
func _on_empty_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		close()


## 重排全部头像：先算出随机落点，再把每个格子都摆在起飞点，等 _fling() 甩出去。
func _rebuild_cells() -> void:
	for cell: Button in _cells:
		if is_instance_valid(cell):
			cell.queue_free()
	_cells.clear()
	_targets.clear()
	if _items == null:
		return

	var ids: PackedStringArray = PackedStringArray()
	var textures: Array[Texture2D] = []
	for index: int in range(Avatars.count()):
		var texture: Texture2D = Avatars.get_texture(index)
		if texture == null:
			continue
		ids.append(Avatars.get_id(index))
		textures.append(texture)
	if ids.is_empty():
		return

	_targets = _place_targets(ids.size())

	for index: int in range(ids.size()):
		var avatar_id: String = ids[index]
		var cell: Button = Button.new()
		cell.name = "Cell_%s" % avatar_id
		cell.size = Vector2(CELL, CELL)
		cell.custom_minimum_size = Vector2(CELL, CELL)
		cell.focus_mode = Control.FOCUS_NONE
		cell.icon = textures[index]
		cell.expand_icon = true
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_theme_stylebox_override("normal", _make_style(avatar_id == _selected_id, false))
		cell.add_theme_stylebox_override("hover", _make_style(false, true))
		cell.add_theme_stylebox_override("pressed", _make_style(true, true))
		cell.pressed.connect(_on_cell_pressed.bind(avatar_id))

		# 起点统一在按钮位置，_fling() 再把它们甩到各自的落点。
		cell.pivot_offset = Vector2(CELL, CELL) * 0.5
		cell.position = _origin
		cell.scale = Vector2(0.5, 0.5)
		cell.modulate.a = 0.0

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


## 从按钮位置把全部头像甩到各自落点：直线、总时长一致、三次缓出。
func _fling() -> void:
	for index: int in range(_cells.size()):
		var cell: Button = _cells[index]
		if not is_instance_valid(cell) or index >= _targets.size():
			continue
		var target: Vector2 = _targets[index]
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(cell, "position", target, fly_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(cell, "scale", Vector2.ONE, fly_duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(cell, "modulate:a", 1.0, fly_duration * 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## 在散落区域里挑出 count 个随机落点：随机角度 + 随机距离，且互相保持间距。
func _place_targets(count: int) -> Array[Vector2]:
	var rect: Rect2 = _scatter_rect()
	var gap: float = CELL * min_gap_ratio
	var points: Array[Vector2] = []
	var relax: int = 0
	# 头像太多、区域太小时逐轮放宽间距，别让某个头像干脆飞不出去。
	while relax < RELAX_STEPS:
		points.clear()
		var enough: bool = true
		for index: int in range(count):
			if not _try_add_target(rect, points, gap):
				enough = false
				break
		if enough:
			return points
		gap *= RELAX_RATIO
		relax += 1
	# 兜底：整块区域内均匀取点，宁可挨着也要全部摆出来。
	points.clear()
	for index: int in range(count):
		points.append(Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		))
	return points


## 掷一个落点并放进 points；掷不出来返回 false（调用方放宽间距重来）。
func _try_add_target(rect: Rect2, points: Array[Vector2], gap: float) -> bool:
	var gap_sq: float = gap * gap
	var attempt: int = 0
	while attempt < max_tries:
		var candidate: Vector2 = _random_fly_point(rect)
		var clear: bool = true
		for placed: Vector2 in points:
			if candidate.distance_squared_to(placed) < gap_sq:
				clear = false
				break
		if clear:
			points.append(candidate)
			return true
		attempt += 1
	return false


## 从起飞点按随机角度 / 随机距离取一个点；落到区域外就重掷。
func _random_fly_point(rect: Rect2) -> Vector2:
	var reach: float = _max_reach(rect)
	var low: float = minf(min_distance, reach * 0.5)
	var attempt: int = 0
	while attempt < 16:
		var angle: float = randf() * TAU
		var distance: float = randf_range(low, reach)
		var candidate: Vector2 = _origin + Vector2.from_angle(angle) * distance
		if rect.has_point(candidate):
			return candidate
		attempt += 1
	# 起飞点离面板太远（或面板太小）时退化成整块区域均匀取点。
	return Vector2(
		randf_range(rect.position.x, rect.end.x),
		randf_range(rect.position.y, rect.end.y)
	)


## 起飞点到散落区域四个角的最远距离，用来限制随机距离的上限。
func _max_reach(rect: Rect2) -> float:
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var reach: float = 0.0
	for corner: Vector2 in corners:
		reach = maxf(reach, _origin.distance_to(corner))
	return maxf(minf(reach, max_distance), min_distance + 1.0)


## 头像可以落位的区域（Items 局部坐标），四周留出半个格子 + 余量。
func _scatter_rect() -> Rect2:
	var pad: float = CELL * 0.5 + EDGE_PADDING
	var area: Vector2 = _items.size if _items != null else Vector2.ZERO
	if area.x < pad * 4.0 or area.y < pad * 4.0:
		# 布局还没算好时的兜底，尽量别把头像叠成一坨。
		var fallback: Vector2 = _panel.size if _panel != null else Vector2(PANEL_SIZE)
		area = Vector2(maxf(fallback.x, pad * 4.0), maxf(fallback.y, pad * 4.0))
	var inner: Vector2 = area - Vector2(pad, pad) * 2.0
	return Rect2(Vector2(pad, pad), inner)


func _on_cell_pressed(avatar_id: String) -> void:
	if avatar_id.is_empty():
		return
	_selected_id = avatar_id
	avatar_chosen.emit(avatar_id)
	close()
