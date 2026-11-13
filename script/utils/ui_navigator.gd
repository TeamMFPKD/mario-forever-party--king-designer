extends Node

## 键盘 / 手柄 UI 操作（autoload 名：UiNavigator）。
##
## 模式：**虚拟鼠标**。
## - WASD / 方向键 / D-pad / 左摇杆 → 平移真实鼠标位置（指哪点哪）
## - Enter / 手柄 A（ui_menu_accept）→ 模拟鼠标左键：按住保持按下，松开才抬起（可拖拽）
## - Esc / 手柄 B（ui_menu_cancel）→ 模拟鼠标右键：按下 + 抬起
##
## 为什么用真实鼠标而不是"焦点跳转"：
## 合成 InputEventMouseButton 走的是引擎完整的 GUI 链路，能触发只响应鼠标的控件
## （_gui_input、TextureButton、拖拽、hover），而直接 emit pressed 做不到。
##
## 四角光标退化为**悬停指示**：只在鼠标下面压着可交互控件时出现，框住它；
## 鼠标在空白处时只剩系统指针（鼠标贴图由 MouseSpriteManager 管理）。
##
## 设备门控：移动端不启用；鼠标主导不启用（不抢真实鼠标）；
## 游戏内（PLAY / ADVENTURE / TEST）不启用，除非屏幕上有可见的模态 UI（暂停菜单 / 通知）。

const META_SKIP: StringName = &"ui_focus_skip"
const META_TARGET: StringName = &"ui_focus_target"
const META_MODAL: StringName = &"ui_focus_modal"
const META_CANCEL: StringName = &"ui_focus_cancel"
## 指定"焦点框按哪个节点的矩形画"（NodePath，相对候选自身）。
## 用于按钮的实际热区比视觉本体大很多的情况（如标题页水管：Button 为了盖住 hover
## 上浮的道具，向上多出 130px，直接框它会把红框顶到管子上面去）。
const META_FOCUS_RECT: StringName = &"ui_focus_rect"

const CURSOR_SCENE_PATH: String = "res://ui/menu_cursor.tscn"
## 兜底重扫间隔（秒）。可交互控件的显隐变化不发信号，只能靠这个兜住。
const SCAN_INTERVAL: float = 0.2
## 游戏内探测"有没有模态 UI 出现"的间隔。只在游戏模式跑，避免关卡里全树遍历太频繁。
const MODAL_PROBE_INTERVAL: float = 0.4
## 虚拟鼠标移动速度（逻辑像素 / 秒）。摇杆幅度会等比缩放。
const MOUSE_SPEED: float = 900.0
## 四角光标所在 CanvasLayer，保证画在所有界面之上。
const CURSOR_LAYER: int = 100

## 左键 / 右键点击合成时用的按钮
const ACTION_ACCEPT: StringName = &"ui_menu_accept"
const ACTION_CANCEL: StringName = &"ui_menu_cancel"

signal activated(control: Control)
signal cancelled()

var _cursor_scene: PackedScene = null
## 当前可交互控件（命中测试用），树序靠后的压在上面
var _candidates: Array[Control] = []
var _dirty: bool = true
var _since_scan: float = 0.0

var _cursor_layer: CanvasLayer = null
var _cursor: UiMenuCursor = null

## 虚拟鼠标位置（视口逻辑坐标）
var _virtual_mouse: Vector2 = Vector2.ZERO
var _mouse_ready: bool = false
## 左键当前是否按下（按住保持，用于拖拽）
var _left_down: bool = false

var _modal_visible: bool = false
var _modal_probe: float = 0.0


func _ready() -> void:
	# 暂停时也要能操作（暂停菜单本身要能点）
	process_mode = Node.PROCESS_MODE_ALWAYS
	var res: Resource = load(CURSOR_SCENE_PATH)
	if res is PackedScene:
		_cursor_scene = res as PackedScene
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	UiFocusPolicy.policy_changed.connect(_on_tree_changed)


func _on_tree_changed(_node: Node) -> void:
	_dirty = true


func _on_policy_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_modal_probe += delta
	if _modal_probe >= MODAL_PROBE_INTERVAL:
		_modal_probe = 0.0
		# 只有游戏模式才需要探模态（菜单界面本来就启用）
		_modal_visible = _is_gameplay_mode() and _any_visible_modal()

	if not _navigation_enabled():
		_release_left_button()
		_hide_cursor()
		_dirty = true
		return

	_since_scan += delta
	if _dirty or _since_scan >= SCAN_INTERVAL:
		_dirty = false
		_since_scan = 0.0
		_rescan()

	_tick_virtual_mouse(delta)
	_tick_left_button()
	_sync_cursor()


# ---------------------------------------------------------------------------
# 设备门控
# ---------------------------------------------------------------------------

## 当前是否应当由导航器接管鼠标。
##
## 游戏内（PLAY / ADVENTURE / TEST）默认关闭，避免和操作抢 WASD；
## 但只要屏幕上有可见的模态 UI（暂停菜单、通知弹窗），就破例启用。
func _navigation_enabled() -> bool:
	if UiFocusPolicy.is_mobile_platform():
		return false
	if not (InputDevice.is_gamepad_active()
			or InputDevice.last_device == InputDevice.DEVICE_KEYBOARD):
		return false
	if _modal_visible:
		return true
	if _is_gameplay_mode():
		return false
	return true


func _is_gameplay_mode() -> bool:
	return GameMode.is_playing() or GameMode.is_adventure() or GameMode.is_testing()


## 树上是否存在可见的 ui_focus_modal 节点。每 MODAL_PROBE_INTERVAL 探一次。
func _any_visible_modal() -> bool:
	var stack: Array[Node] = []
	stack.append(get_tree().root)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			continue
		if node is Control and _meta_true(node, META_MODAL):
			return true
		for child: Node in node.get_children():
			stack.append(child)
	return false


# ---------------------------------------------------------------------------
# 虚拟鼠标
# ---------------------------------------------------------------------------

## WASD 走 move_*，方向键 / D-pad / 左摇杆走 ui_*；两套都接受。
func _input_axis() -> Vector2:
	var axis: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if axis.length_squared() > 0.0001:
		return axis
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _mouse_point() -> Vector2:
	if _mouse_ready:
		return _virtual_mouse
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_mouse_position()


func _ensure_mouse() -> void:
	if _mouse_ready:
		return
	var viewport: Viewport = get_viewport()
	_virtual_mouse = viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	_mouse_ready = true


func _tick_virtual_mouse(delta: float) -> void:
	var axis: Vector2 = _input_axis()
	if axis.length_squared() <= 0.0001:
		return
	_ensure_mouse()
	_virtual_mouse += axis * MOUSE_SPEED * delta
	_clamp_mouse()
	_warp_real_mouse()


func _clamp_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_virtual_mouse = _virtual_mouse.clamp(Vector2.ZERO, size - Vector2.ONE)


## 把真实鼠标挪到虚拟位置：这样 hover 状态、get_mouse_position()、
## 系统光标（MouseSpriteManager 的自定义贴图）全都自动跟着走。
func _warp_real_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	# warp 会让系统产生鼠标移动事件，不抑制的话 InputDevice 会判定"用户在用鼠标"
	# 从而把导航自己关掉。
	InputDevice.suppress_mouse_activity()
	# get_screen_transform 自动处理窗口缩放、letterbox 偏移与 DPI 缩放
	Input.warp_mouse(viewport.get_screen_transform() * _virtual_mouse)


## 左键按下 / 抬起：按住 ACTION_ACCEPT 期间保持按下，可实现拖拽。
func _tick_left_button() -> void:
	var want_down: bool = Input.is_action_pressed(ACTION_ACCEPT)
	if want_down == _left_down:
		return
	_ensure_mouse()
	_left_down = want_down
	_send_mouse_button(_mouse_point(), MOUSE_BUTTON_LEFT, want_down)


func _release_left_button() -> void:
	if not _left_down:
		return
	_left_down = false
	_send_mouse_button(_mouse_point(), MOUSE_BUTTON_LEFT, false)


func _send_mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	# 合成事件同样会经过场景的 _input，别让它把主导设备抢回鼠标
	InputDevice.suppress_mouse_activity()
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	event.global_position = point
	event.button_mask = _mask_of(button) if pressed else 0
	viewport.push_input(event)


func _mask_of(button: MouseButton) -> int:
	match button:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_MASK_RIGHT
		MOUSE_BUTTON_MIDDLE:
			return MOUSE_BUTTON_MASK_MIDDLE
	return 0


# ---------------------------------------------------------------------------
# 输入
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# 文本输入状态优先：方向键 / 回车都归输入框自己，这里只负责"取消 = 退出输入"
	if _handle_text_input(event):
		return
	if not _navigation_enabled():
		return
	if event.is_action_pressed(ACTION_CANCEL):
		_ensure_mouse()
		# 右键单击：按下 + 抬起
		_send_mouse_button(_mouse_point(), MOUSE_BUTTON_RIGHT, true)
		_send_mouse_button(_mouse_point(), MOUSE_BUTTON_RIGHT, false)
		cancelled.emit()
		get_viewport().set_input_as_handled()


## 当前是否有输入框正持有键盘焦点（处于打字状态）。
func _text_focus_owner() -> Control:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var owner: Control = viewport.gui_get_focus_owner()
	if owner != null and _is_text_input(owner):
		return owner
	return null


func _is_text_input(control: Control) -> bool:
	return control is LineEdit or control is TextEdit


## 打字状态下吞掉导航逻辑。
##
## 方向键与回车会被 LineEdit / TextEdit 自己在 GUI 阶段消费，本来就不会走到这里；
## 真正需要处理的是"取消"：Esc / 手柄 B 退出输入，把键盘还给界面。
func _handle_text_input(event: InputEvent) -> bool:
	var owner: Control = _text_focus_owner()
	if owner == null:
		return false
	if event.is_action_pressed(ACTION_CANCEL):
		owner.release_focus()
		_dirty = true
		get_viewport().set_input_as_handled()
	return true


# ---------------------------------------------------------------------------
# 悬停指示（四角光标）
# ---------------------------------------------------------------------------

func _sync_cursor() -> void:
	var target: Control = _hover_target()
	if target == null:
		_hide_cursor()
		return
	var rect: Rect2 = _canvas_rect_of(target)
	_ensure_cursor_node()
	if _cursor == null:
		return
	_cursor.show_at(rect, false)
	_cursor.set_highlight(_left_down)


## 鼠标下面压着的可交互控件；没有就返回 null（此时不画四角框）。
func _hover_target() -> Control:
	var point: Vector2 = _mouse_point()
	var best: Control = null
	for control: Control in _candidates:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if _canvas_rect_of(control).has_point(point):
			# 树序靠后的绘制在上层，直接覆盖
			best = control
	return best


func _ensure_cursor_node() -> void:
	if _cursor != null and is_instance_valid(_cursor):
		return
	if _cursor_scene == null:
		return
	if _cursor_layer == null or not is_instance_valid(_cursor_layer):
		_cursor_layer = CanvasLayer.new()
		_cursor_layer.name = "UiNavigatorCursorLayer"
		_cursor_layer.layer = CURSOR_LAYER
		get_tree().root.add_child(_cursor_layer)
	var created: Node = _cursor_scene.instantiate()
	if not (created is UiMenuCursor):
		created.queue_free()
		return
	var cursor: UiMenuCursor = created as UiMenuCursor
	cursor.name = "UiNavigatorCursor"
	_cursor_layer.add_child(cursor)
	_cursor = cursor


func _hide_cursor() -> void:
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.hide_cursor()
		_cursor.set_highlight(false)


# ---------------------------------------------------------------------------
# 候选收集（只用于鼠标命中测试）
# ---------------------------------------------------------------------------

## 外部主动请求重算：页面切换时立刻更新可交互控件集合。
func refresh_now() -> void:
	_dirty = true


func _rescan() -> void:
	var modal: Control = _find_modal()
	var candidates: Array[Control] = []
	for child: Node in get_tree().root.get_children():
		_collect_node(child, modal, candidates)
	_candidates = candidates


func _find_modal() -> Control:
	var stack: Array[Node] = []
	for child: Node in get_tree().root.get_children():
		stack.append(child)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Viewport:
			continue
		if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			continue
		if node is Control and _meta_true(node, META_MODAL):
			return node as Control
		for child: Node in node.get_children():
			stack.append(child)
	return null


func _collect_node(node: Node, modal: Control, out: Array[Control]) -> void:
	# 另一个 Viewport 的内容由它自己的输入转发处理，不参与 root 的命中测试
	if node is Viewport:
		return
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if _is_candidate(node, modal):
		out.append(node as Control)
	for child: Node in node.get_children():
		_collect_node(child, modal, out)


func _is_candidate(node: Node, modal: Control) -> bool:
	if not (node is Control):
		return false
	var control: Control = node as Control
	if modal != null and control != modal and not modal.is_ancestor_of(control):
		return false
	if _is_skipped(control):
		return false
	if control is BaseButton:
		var button: BaseButton = control as BaseButton
		if button.disabled:
			return false
		# mouse_filter = IGNORE 等于"现在不可点"，也就没有悬停指示
		if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return false
		return true
	if _is_text_input(control):
		return control.mouse_filter != Control.MOUSE_FILTER_IGNORE
	return _meta_true(control, META_TARGET)


## 只要自己或任一祖先带 ui_focus_skip，就整组不参与。
func _is_skipped(control: Control) -> bool:
	var node: Node = control
	while node != null and not (node is Viewport):
		if _meta_true(node, META_SKIP):
			return true
		node = node.get_parent()
	return false


func _meta_true(node: Node, key: StringName) -> bool:
	if not node.has_meta(key):
		return false
	var value: Variant = node.get_meta(key)
	if value is bool:
		var flag: bool = value
		return flag
	return true


# ---------------------------------------------------------------------------
# 矩形换算
# ---------------------------------------------------------------------------

## 控件在视口坐标下的矩形（考虑 ui_focus_rect 换框）。
func _canvas_rect_of(control: Control) -> Rect2:
	var target: Control = _focus_rect_control(control)
	var transform: Transform2D = target.get_global_transform_with_canvas()
	var top_left: Vector2 = transform * Vector2.ZERO
	var bottom_right: Vector2 = transform * target.size
	return Rect2(top_left, bottom_right - top_left).abs()


## 焦点框要框的节点：默认就是候选自己，可用 ui_focus_rect 换成别的节点。
func _focus_rect_control(control: Control) -> Control:
	if not control.has_meta(META_FOCUS_RECT):
		return control
	var value: Variant = control.get_meta(META_FOCUS_RECT)
	if value is NodePath:
		var path: NodePath = value
		var node: Node = control.get_node_or_null(path)
		if node is Control:
			return node as Control
	return control


# ---------------------------------------------------------------------------
# 调试 / 探针
# ---------------------------------------------------------------------------

## 当前鼠标下的控件、候选数量与虚拟鼠标位置。
func describe_selection() -> Dictionary:
	var target: Control = _hover_target()
	var point: Vector2 = _mouse_point()
	return {
		"count": _candidates.size(),
		"selected": str(target.name) if target != null else "",
		"cursor": _cursor != null and is_instance_valid(_cursor) and _cursor.visible,
		"index": -1,
		"mouse": point,
		"left_down": _left_down,
	}


## 直接改虚拟鼠标位置（探针用，避免依赖真实 warp）。
func set_virtual_mouse(position: Vector2) -> void:
	_virtual_mouse = position
	_mouse_ready = true
	_clamp_mouse()
