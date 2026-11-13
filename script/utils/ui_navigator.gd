extends Node

## 通用键盘 / 手柄 UI 导航（autoload 名：UiNavigator）。
##
## 设计目标：**通用**。场景不需要摆光标节点、不需要给按钮打标记、不需要写导航代码，
## 只要按钮出现在屏幕上，就能用手柄十字键 / 键盘方向键选中，确认键按下。
##
## 工作方式：
## 1. **自动分域**：每个 Viewport（含 SubViewport）各算一个导航域，互不干扰。
##    SubViewport 里的弹窗（如冒险暂停菜单）由域内的光标自己画，坐标不会串。
## 2. **自动收集**：域内所有可见、未禁用的 BaseButton 即候选；
##    非按钮控件通过 metadata `ui_focus_target = true` 声明参与；
##    metadata `ui_focus_skip = true` 排除。
## 3. **模态独占**：某控件带 `ui_focus_modal = true` 且可见时，域内只有它的后代能被选中。
##    Notice 弹窗、导入导出弹窗用它。
## 4. **光标自动挂载**：实例化 `ui/menu_cursor.tscn`，挂在候选的最近公共祖先下，
##    父子关系变化（切页 / 重排）后自动重新挂。
## 5. **默认聚焦**：键盘或手柄主导时自动选中一项（优先沿用上次选中项）。
## 6. **确认 / 取消**：`ui_menu_accept`（含 ui_accept）触发选中控件，`ui_menu_cancel`
##    触发带 `ui_focus_cancel = true` 的控件。
##
## 设备门控：移动端不启用；`MenuGate.menu_actions_enabled` 为 false（PLAY / ADVENTURE /
## TEST 等游戏内）时不启用；鼠标主导时不启用（保持 hover 体验）。

const META_SKIP: StringName = &"ui_focus_skip"
const META_TARGET: StringName = &"ui_focus_target"
const META_MODAL: StringName = &"ui_focus_modal"
const META_CANCEL: StringName = &"ui_focus_cancel"

const CURSOR_SCENE_PATH: String = "res://ui/menu_cursor.tscn"
## 兜底全量重扫间隔（秒）。可见性变化不发信号，只能靠这个兜住。
const RESCAN_INTERVAL: float = 0.2
## 游戏内探测「有没有模态 UI 出现」的间隔。只在游戏模式跑，避免关卡里全树遍历太频繁。
const MODAL_PROBE_INTERVAL: float = 0.4
## 方向查找时"横向偏移"惩罚的阈值（像素）
const AXIS_TOLERANCE: float = 96.0
## 长按方向键后，开始自动重复前的延迟（秒）
const REPEAT_DELAY: float = 0.4
## 自动重复的间隔（秒）
const REPEAT_INTERVAL: float = 0.12

signal activated(control: Control)
signal cancelled()

## 一个导航域：一个 Viewport 内的候选集合 + 自己的光标
class Domain:
	var viewport: Viewport = null
	var parent: Node = null
	var cursor: UiMenuCursor = null
	var candidates: Array[Control] = []
	var index: int = -1
	var selected_id: int = 0
	var modal: Control = null

var _cursor_scene: PackedScene = null
var _domains: Dictionary[int, Domain] = {}
var _dirty: bool = true
var _since_scan: float = 0.0
var _active_key: int = 0
## 当前是否有可见的模态 UI（暂停菜单 / 通知弹窗）。游戏内靠它破例启用导航。
var _modal_visible: bool = false
var _modal_probe: float = 0.0

## 长按自动重复。只有 _unhandled_input 收到过方向键按下才武装，
## 这样输入框（LineEdit）消费掉方向键时不会误触发导航。
var _repeat_armed: bool = false
var _held_direction: Vector2 = Vector2.ZERO
var _repeat_timer: float = 0.0


func _ready() -> void:
	# 暂停时也要能用（暂停菜单本身要导航）
	process_mode = Node.PROCESS_MODE_ALWAYS
	var res: Resource = load(CURSOR_SCENE_PATH)
	if res is PackedScene:
		_cursor_scene = res as PackedScene
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	UiFocusPolicy.policy_changed.connect(_on_policy_changed)


func _on_tree_changed(_node: Node) -> void:
	_dirty = true


func _on_policy_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_modal_probe += delta
	if _modal_probe >= MODAL_PROBE_INTERVAL:
		_modal_probe = 0.0
		# 只有游戏模式才需要探模态（菜单界面本来就启用导航）
		_modal_visible = _is_gameplay_mode() and _any_visible_modal()
	# 未启用（鼠标主导 / 游戏内 / 移动端）时完全不扫树，避免关卡里动态对象拖累性能
	if not _navigation_enabled():
		_hide_all_cursors()
		_repeat_armed = false
		_dirty = true
		return
	_since_scan += delta
	if _dirty or _since_scan >= RESCAN_INTERVAL:
		_dirty = false
		_since_scan = 0.0
		_rebuild()
	_sync_visuals()
	_tick_repeat(delta)


func _hide_all_cursors() -> void:
	for key: int in _domains.keys():
		var item: Domain = _domains[key]
		if item.cursor != null and is_instance_valid(item.cursor):
			item.cursor.hide_cursor()
			item.cursor.set_highlight(false)


# ---------------------------------------------------------------------------
# 设备门控
# ---------------------------------------------------------------------------

## 当前是否应当显示光标并接受方向键。
##
## 游戏内（PLAY / ADVENTURE / TEST）默认关闭，避免和操作抢方向键；
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
	return MenuGate.menu_actions_enabled


func _is_gameplay_mode() -> bool:
	return GameMode.is_playing() or GameMode.is_adventure() or GameMode.is_testing()


## 树上是否存在可见的 ui_focus_modal 节点。每 RESCAN_INTERVAL 探一次。
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


## 调试 / 探针用：当前活动域的候选数与选中项名。
func describe_selection() -> Dictionary:
	var active: Domain = _active_domain()
	var result: Dictionary = {"count": 0, "selected": "", "cursor": false, "index": -1}
	if active == null:
		return result
	result["count"] = active.candidates.size()
	result["index"] = active.index
	if active.index >= 0 and active.index < active.candidates.size():
		result["selected"] = str(active.candidates[active.index].name)
	result["cursor"] = active.cursor != null and is_instance_valid(active.cursor)
	return result


# ---------------------------------------------------------------------------
# 输入
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _navigation_enabled():
		return
	if not _is_navigation_event(event):
		return
	_force_rescan()
	var domain: Domain = _active_domain()
	if domain == null or domain.candidates.is_empty():
		return

	var direction: Vector2 = _direction_of(event)
	if direction != Vector2.ZERO:
		_navigate_step(domain, direction)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_menu_cancel"):
		_cancel(domain)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_menu_accept") or event.is_action_pressed("ui_accept"):
		_accept(domain)
		get_viewport().set_input_as_handled()


## 事件对应的导航方向。
##
## 系统的键盘自动重复（echo）直接丢掉：长按节奏统一由 _tick_repeat 控制，
## 否则键盘会被系统重复和自己的重复叠成两倍速，而手柄又完全没有重复。
func _direction_of(event: InputEvent) -> Vector2:
	if event.is_echo():
		return Vector2.ZERO
	if event.is_action_pressed("ui_left"):
		return Vector2.LEFT
	if event.is_action_pressed("ui_right"):
		return Vector2.RIGHT
	if event.is_action_pressed("ui_up"):
		return Vector2.UP
	if event.is_action_pressed("ui_down"):
		return Vector2.DOWN
	return Vector2.ZERO


## 走一格并武装自动重复。
func _navigate_step(domain: Domain, direction: Vector2) -> void:
	_move(domain, direction)
	_repeat_armed = true
	_held_direction = direction
	_repeat_timer = REPEAT_DELAY


## 长按方向键：延迟 REPEAT_DELAY 后每 REPEAT_INTERVAL 走一格。
func _tick_repeat(delta: float) -> void:
	if not _repeat_armed:
		return
	var held: Vector2 = _poll_direction()
	if held == Vector2.ZERO:
		# 全松开了
		_repeat_armed = false
		_held_direction = Vector2.ZERO
		return
	if held != _held_direction:
		# 换了方向（左 → 上）：立刻走一格并重新计时
		_held_direction = held
		_repeat_timer = REPEAT_DELAY
		var switched: Domain = _active_domain()
		if switched != null:
			_move(switched, held)
		return
	_repeat_timer -= delta
	if _repeat_timer > 0.0:
		return
	_repeat_timer = REPEAT_INTERVAL
	var domain: Domain = _active_domain()
	if domain != null:
		_move(domain, held)


## 当前按住的主方向（十字键 / 左摇杆 / WASD 都算）。
func _poll_direction() -> Vector2:
	var axis: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if axis.length_squared() < 0.04:
		return Vector2.ZERO
	if absf(axis.x) >= absf(axis.y):
		return Vector2(signf(axis.x), 0.0)
	return Vector2(0.0, signf(axis.y))


func _is_navigation_event(event: InputEvent) -> bool:
	const ACTIONS: Array[String] = [
		"ui_left", "ui_right", "ui_up", "ui_down",
		"ui_menu_accept", "ui_menu_cancel", "ui_accept",
	]
	for action: String in ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false


func _accept(domain: Domain) -> void:
	if domain.index < 0 or domain.index >= domain.candidates.size():
		return
	var control: Control = domain.candidates[domain.index]
	if not is_instance_valid(control):
		return
	if control is BaseButton:
		var button: BaseButton = control as BaseButton
		if button.disabled:
			_dirty = true
			return
		activated.emit(control)
		button.pressed.emit()
	else:
		activated.emit(control)
	# 触发后界面可能立刻变化（关弹窗 / 切场景），下一帧必须重算
	_dirty = true


func _cancel(domain: Domain) -> void:
	for control: Control in domain.candidates:
		if _meta_true(control, META_CANCEL):
			_trigger(control)
			_dirty = true
			return
	cancelled.emit()


func _trigger(control: Control) -> void:
	if control is BaseButton:
		(control as BaseButton).pressed.emit()
	activated.emit(control)


# ---------------------------------------------------------------------------
# 方向导航
# ---------------------------------------------------------------------------

func _move(domain: Domain, direction: Vector2) -> void:
	var count: int = domain.candidates.size()
	if count <= 1:
		return
	var from_rect: Rect2 = _canvas_rect_of(domain.candidates[domain.index])
	var from_center: Vector2 = from_rect.get_center()
	var best: int = -1
	var best_cost: float = INF
	for i: int in range(count):
		if i == domain.index:
			continue
		var rect: Rect2 = _canvas_rect_of(domain.candidates[i])
		var offset: Vector2 = rect.get_center() - from_center
		if offset.dot(direction) <= 0.0:
			continue
		var across: float = absf(offset.dot(Vector2(direction.y, direction.x)))
		var along: float = offset.dot(direction)
		var cost: float = along + across * (1.0 if across <= AXIS_TOLERANCE else 6.0)
		if cost < best_cost:
			best_cost = cost
			best = i
	if best < 0:
		var step: int = 1 if (direction.x > 0.0 or direction.y > 0.0) else -1
		best = posmod(domain.index + step, count)
	if best == domain.index:
		return
	_select(domain, best)


func _select(domain: Domain, index: int) -> void:
	if index < 0 or index >= domain.candidates.size():
		return
	domain.index = index
	domain.selected_id = int(domain.candidates[index].get_instance_id())
	_ensure_visible(domain.candidates[index])
	if domain.cursor != null and is_instance_valid(domain.cursor):
		domain.cursor.show_at(_rect_in_cursor_space(domain, domain.candidates[index]), false)


## 选中项滚出 ScrollContainer 可视区时把它滚回来（长按方向键时就是连续滚动）。
func _ensure_visible(control: Control) -> void:
	var node: Node = control.get_parent()
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node == null:
		return
	(node as ScrollContainer).ensure_control_visible(control)


func _canvas_rect_of(control: Control) -> Rect2:
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var top_left: Vector2 = transform * Vector2.ZERO
	var bottom_right: Vector2 = transform * control.size
	return Rect2(top_left, bottom_right - top_left).abs()


# ---------------------------------------------------------------------------
# 每帧表现同步
# ---------------------------------------------------------------------------

func _sync_visuals() -> void:
	var enabled: bool = _navigation_enabled()
	var active: Domain = _active_domain() if enabled else null
	var pressed: bool = false
	if enabled and active != null:
		pressed = Input.is_action_pressed("ui_menu_accept")

	for key: int in _domains.keys():
		var item: Domain = _domains[key]
		if item.cursor == null or not is_instance_valid(item.cursor):
			continue
		if item != active:
			item.cursor.hide_cursor()
			item.cursor.set_highlight(false)
			continue
		item.cursor.set_highlight(pressed)

	if active == null:
		return
	if active.cursor == null or not is_instance_valid(active.cursor):
		return
	if active.index < 0 or active.index >= active.candidates.size():
		return
	var control: Control = active.candidates[active.index]
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		# 界面正在变（切页 / 关弹窗），下一帧重算再定位
		_dirty = true
		return
	active.cursor.show_at(_rect_in_cursor_space(active, control), false)


## 光标所在域的父级局部坐标下的目标矩形。
func _rect_in_cursor_space(domain: Domain, control: Control) -> Rect2:
	var parent: Node = domain.parent
	if parent is CanvasItem:
		var invert: Transform2D = (parent as CanvasItem)\
			.get_global_transform_with_canvas().affine_inverse()
		var transform: Transform2D = control.get_global_transform_with_canvas()
		var top_left: Vector2 = invert * (transform * Vector2.ZERO)
		var bottom_right: Vector2 = invert * (transform * control.size)
		return Rect2(top_left, bottom_right - top_left).abs()
	return Rect2(control.global_position, control.size)


# ---------------------------------------------------------------------------
# 域构建
# ---------------------------------------------------------------------------

func _force_rescan() -> void:
	if _since_scan < 0.02 and not _dirty:
		return
	_dirty = false
	_since_scan = 0.0
	_rebuild()


func _rebuild() -> void:
	var alive: Dictionary = {}
	for viewport: Viewport in _collect_viewports():
		_build_domain(viewport, alive)
	var stale: Array[int] = []
	for key: int in _domains.keys():
		if not alive.has(key):
			stale.append(key)
	for key: int in stale:
		var item: Domain = _domains[key]
		_free_domain(item)
		_domains.erase(key)
	if not _domains.has(_active_key):
		_active_key = _pick_active_key(alive)


func _collect_viewports() -> Array[Viewport]:
	var out: Array[Viewport] = []
	var stack: Array[Node] = []
	stack.append(get_tree().root)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Viewport:
			out.append(node as Viewport)
		for child: Node in node.get_children():
			stack.append(child)
	return out


func _build_domain(viewport: Viewport, alive: Dictionary) -> void:
	var modal: Control = _find_modal(viewport)
	var candidates: Array[Control] = []
	_collect_from(viewport, modal, candidates)
	if candidates.is_empty():
		return
	var key: int = int(viewport.get_instance_id())
	alive[key] = true
	var domain: Domain
	if _domains.has(key):
		domain = _domains[key]
	else:
		domain = Domain.new()
		domain.viewport = viewport
		_domains[key] = domain
	domain.modal = modal
	domain.candidates = candidates
	if not _ensure_cursor(domain):
		return
	_resolve_index(domain)


func _find_modal(viewport: Viewport) -> Control:
	var stack: Array[Node] = []
	for child: Node in viewport.get_children():
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


func _collect_from(viewport: Viewport, modal: Control, out: Array[Control]) -> void:
	for child: Node in viewport.get_children():
		_collect_node(child, modal, out)


func _collect_node(node: Node, modal: Control, out: Array[Control]) -> void:
	# 另一个 Viewport 的内容属于它自己的域
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
		return not (control as BaseButton).disabled
	return _meta_true(control, META_TARGET)


## 只要自己或任一祖先带 ui_focus_skip，就整组不参与导航。
## 给组容器打一次标记即可排除整片按钮（编辑室物品组、翻转中的卡片等）。
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


func _resolve_index(domain: Domain) -> void:
	var found: int = -1
	if domain.selected_id != 0:
		for i: int in range(domain.candidates.size()):
			if int(domain.candidates[i].get_instance_id()) == domain.selected_id:
				found = i
				break
	if found < 0:
		found = 0
	var changed: bool = found != domain.index
	domain.index = found
	domain.selected_id = int(domain.candidates[found].get_instance_id())
	# 只在选中项真正变化时滚动，避免用户手动滚动列表后被定时重扫拉回去
	if changed:
		_ensure_visible(domain.candidates[found])


func _pick_active_key(alive: Dictionary) -> int:
	var first: int = 0
	for key: int in _domains.keys():
		if not alive.has(key):
			continue
		var item: Domain = _domains[key]
		if item.candidates.is_empty():
			continue
		if item.modal != null:
			return key
		if first == 0:
			first = key
	return first


func _active_domain() -> Domain:
	if _domains.has(_active_key):
		var current: Domain = _domains[_active_key]
		if not current.candidates.is_empty():
			return current
	for key: int in _domains.keys():
		var item: Domain = _domains[key]
		if item.candidates.is_empty():
			continue
		if item.modal != null:
			_active_key = key
			return item
	return null


# ---------------------------------------------------------------------------
# 光标挂载
# ---------------------------------------------------------------------------

func _ensure_cursor(domain: Domain) -> bool:
	var parent: Node = _resolve_cursor_parent(domain.candidates)
	if parent == null:
		return false
	if domain.cursor != null and is_instance_valid(domain.cursor):
		if domain.cursor.get_parent() == parent:
			domain.parent = parent
			return true
		domain.cursor.queue_free()
		domain.cursor = null
	if _cursor_scene == null:
		return false
	var created: Node = _cursor_scene.instantiate()
	if not (created is UiMenuCursor):
		created.queue_free()
		return false
	var cursor: UiMenuCursor = created as UiMenuCursor
	cursor.name = "UiNavigatorCursor"
	parent.add_child(cursor)
	domain.parent = parent
	domain.cursor = cursor
	return true


## 候选的最近公共祖先；若它本身是 Container（会重排子节点位置），往上退一层。
func _resolve_cursor_parent(candidates: Array[Control]) -> Node:
	if candidates.is_empty():
		return null
	var lca: Node = candidates[0]
	var guard: int = 0
	while lca != null and not _contains_all(lca, candidates) and guard < 64:
		lca = lca.get_parent()
		guard += 1
	if lca == null:
		return null
	guard = 0
	while lca is Container and lca.get_parent() != null and guard < 16:
		lca = lca.get_parent()
		guard += 1
	return lca


func _contains_all(root: Node, nodes: Array[Control]) -> bool:
	for control: Control in nodes:
		if not is_instance_valid(control):
			return false
		if control != root and not root.is_ancestor_of(control):
			return false
	return true


func _free_domain(domain: Domain) -> void:
	if domain.cursor != null and is_instance_valid(domain.cursor):
		domain.cursor.queue_free()
	domain.cursor = null
	domain.candidates.clear()
