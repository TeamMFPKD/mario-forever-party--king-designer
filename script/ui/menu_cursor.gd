extends Control

## 菜单四角光标（手柄 / 键盘导航用）。
##
## 背景：本作 UI 一律鼠标 / 触屏操作，autoload `NoButtonFocus` 会把所有
## [BaseButton] 的 focus_mode 置为 FOCUS_NONE 并强制释放焦点，因此**不能**用
## Godot 原生的焦点系统做导航。本节点自己维护"当前选中项"，把四角光标画在
## 选中控件的四边外侧。
##
## 为什么用 4 个独立 Corner 而不是 NinePatchRect：
## NinePatchRect 会把四条边整体拉伸，四角光标的"臂"会被扯成整条线。
## 四角必须各自固定尺寸，只有**位置**跟着目标矩形走。
##
## 用法：把本节点放在目标控件所在的同一画布下（通常与按钮同属一个 GameRoomSize），
## target_root 指向装着按钮的容器。_ready 时按树序收集其中所有可见、未禁用的 Button。
##
## 输入：ui_left / ui_right / ui_up / ui_down 切换，ui_accept 触发。

signal selection_changed(index: int, button: Control)
signal activated(index: int, button: Control)

## 装按钮的容器；按钮在其中的树序即默认遍历顺序
@export var target_root: NodePath
## 光标相对控件外扩的像素
@export var padding: Vector2 = Vector2(10.0, 8.0)
## 移动到新位置用的时长
@export var move_duration: float = 0.14
## 走到两端是否环绕
@export var wrap: bool = true
## 空间查找时，垂直于目标方向的偏移惩罚阈值
@export var axis_tolerance: float = 96.0

var _buttons: Array[Control] = []
var _index: int = -1
var _tween: Tween

@onready var _tl: TextureRect = $CornerTL
@onready var _tr: TextureRect = $CornerTR
@onready var _bl: TextureRect = $CornerBL
@onready var _br: TextureRect = $CornerBR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for corner: TextureRect in [_tl, _tr, _bl, _br]:
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		corner.stretch_mode = TextureRect.STRETCH_KEEP
	visible = false
	_collect_buttons()
	if _buttons.is_empty():
		return
	select(0, true)


## 按树序收集 target_root 下所有可用 Button。
func _collect_buttons() -> void:
	_buttons.clear()
	var root: Node = get_node_or_null(target_root)
	if root == null:
		root = get_parent()
	if root == null:
		return
	_collect_into(root)
	var usable: Array[Control] = []
	for button: Control in _buttons:
		if not is_instance_valid(button):
			continue
		if not button.is_visible_in_tree():
			continue
		if button is BaseButton and (button as BaseButton).disabled:
			continue
		usable.append(button)
	_buttons = usable


func _collect_into(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Button:
			_buttons.append(child as Control)
		_collect_into(child)


## 当前选中索引；没有选中时为 -1。
func get_selection() -> int:
	return _index


## 当前选中的控件。
func get_selected_button() -> Control:
	if _index < 0 or _index >= _buttons.size():
		return null
	return _buttons[_index]


## 当前选中控件名（探针 / 调试用）。
func get_selected_label() -> String:
	var button: Control = get_selected_button()
	if button == null:
		return ""
	return str(button.name)


## 选中第 index 项并移动光标。instant 为 true 时不播动画（初始化用）。
func select(index: int, instant: bool = false) -> void:
	if _buttons.is_empty():
		visible = false
		return
	var clamped: int = clampi(index, 0, _buttons.size() - 1)
	_index = clamped
	visible = true
	var button: Control = _buttons[_index]
	_apply_rect(button, instant)
	# 手柄激活时把原生焦点也同步过去，方便依赖 focus_entered/exited 的控件
	if UiFocusPolicy.should_enable_gamepad_focus() and button is BaseButton:
		var base: BaseButton = button as BaseButton
		if base.focus_mode != Control.FOCUS_NONE:
			base.grab_focus()
	selection_changed.emit(_index, _buttons[_index])


## 把四角摆到目标控件的四边外侧。
func _apply_rect(button: Control, instant: bool) -> void:
	var target: Rect2 = _rect_of(button).grow_individual(padding.x, padding.y, padding.x, padding.y)
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var placements: Array[Rect2] = [
		Rect2(target.position, _corner_size(_tl)),
		Rect2(Vector2(target.end.x - _corner_size(_tr).x, target.position.y), _corner_size(_tr)),
		Rect2(Vector2(target.position.x, target.end.y - _corner_size(_bl).y), _corner_size(_bl)),
		Rect2(target.end - _corner_size(_br), _corner_size(_br)),
	]
	var corners: Array[TextureRect] = [_tl, _tr, _bl, _br]

	if instant or move_duration <= 0.0:
		for i: int in range(corners.size()):
			corners[i].position = placements[i].position
			corners[i].size = placements[i].size
		return

	_tween = create_tween()
	_tween.set_parallel(true)
	for i: int in range(corners.size()):
		_tween.tween_property(corners[i], "position", placements[i].position, move_duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _corner_size(corner: TextureRect) -> Vector2:
	if corner.texture == null:
		return Vector2(26.0, 26.0)
	return corner.texture.get_size()


## 把控件（可能在别的变换层级）的矩形换算到本节点的局部坐标。
func _rect_of(button: Control) -> Rect2:
	var inv: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var btn: Transform2D = button.get_global_transform_with_canvas()
	var top_left: Vector2 = inv * (btn * Vector2.ZERO)
	var bottom_right: Vector2 = inv * (btn * Vector2(button.size))
	return Rect2(top_left, bottom_right - top_left).abs()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _buttons.is_empty():
		return
	# 移动端不响应键盘/手柄导航（触屏操作）
	if UiFocusPolicy.is_mobile_platform():
		return
	if event.is_action_pressed("ui_left"):
		_move_in(Vector2.LEFT)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		_move_in(Vector2.RIGHT)
		accept_event()
	elif event.is_action_pressed("ui_up"):
		_move_in(Vector2.UP)
		accept_event()
	elif event.is_action_pressed("ui_down"):
		_move_in(Vector2.DOWN)
		accept_event()
	elif event.is_action_pressed("ui_menu_accept") or event.is_action_pressed("ui_accept"):
		var button: Control = get_selected_button()
		if button != null:
			activated.emit(_index, button)
			if button is BaseButton:
				(button as BaseButton).pressed.emit()
		accept_event()


## 朝 direction 方向找最近的候选控件。
func _move_in(direction: Vector2) -> void:
	if _buttons.size() <= 1:
		return
	var from: Rect2 = _rect_of(_buttons[_index])
	var from_center: Vector2 = from.get_center()

	var best_index: int = -1
	var best_cost: float = INF
	for i: int in range(_buttons.size()):
		if i == _index:
			continue
		var rect: Rect2 = _rect_of(_buttons[i])
		var center: Vector2 = rect.get_center()
		var delta: Vector2 = center - from_center
		if delta.dot(direction) <= 0.0:
			continue
		var across: float = absf(delta.dot(Vector2(direction.y, direction.x)))
		var along: float = delta.dot(direction)
		var cost: float = along + across * (1.0 if across <= axis_tolerance else 6.0)
		if cost < best_cost:
			best_cost = cost
			best_index = i

	if best_index < 0:
		var step: int = 1 if (direction.x > 0.0 or direction.y > 0.0) else -1
		var next: int = _index + step
		if wrap:
			next = posmod(next, _buttons.size())
		else:
			next = clampi(next, 0, _buttons.size() - 1)
		if next != _index:
			select(next)
		return

	select(best_index)
