extends Node

## 标题画面页面管理器。
##
## 五个"页面"互斥：
##   0 主菜单（水管排，不在本管理器的 pages 里）
##   1 HostPage
##   2 JoinPage
##   3 PlayerPage
##   4 Options
##
## 语义要点（用户明确要求）：
## - 切页时**旧页面不会立刻消失**：它先播完退出动画（掉落动画的反向），
##   播完才 visible = false。所以在过渡的 0.2 秒里画面上会短暂同时存在两个页面。
## - 过渡期间旧页面只是**失去交互**（禁用焦点 + 鼠标穿透），但仍然看得见。
## - 新页面从打开的那一帧起就可用。
##
## 为什么不直接用 visibility_changed 驱动：现有的连线（ControlVisibieSet._set_visible /
## _set_invisible）是在 `visible` 赋值的那一瞬间生效的，没有"退出动画播完"的时机。
## 所以由本管理器接管显隐，ControlVisibieSet 只在受管页面上转调过来（见其脚本）。
##
## 主菜单状态 = 没有任何页面处于活动状态（_current == null），水管由 PipeMenu 自己滑回来。

const GROUP: StringName = &"title_page_manager"
## 与 DropInAnimation 的 ui_focus_skip 约定一致
const META_SKIP: StringName = &"ui_focus_skip"

## 受管页面，按显示顺序排列（主菜单不在其中）
@export var page_paths: Array[NodePath] = []

var _pages: Array[Control] = []
## 当前活动页面；null 表示主菜单
var _current: Control = null
## 正在播退出动画的页面（instance_id -> true），防止退出期间被重复处理
var _exiting: Dictionary[int, bool] = {}
## 禁用交互前的 mouse_filter 原值（instance_id -> int）
var _mouse_backup: Dictionary[int, int] = {}


func _ready() -> void:
	add_to_group(GROUP)
	# 同步接管：_ready 自底向上，页面与 DropInAnimation 的 _ready 此时已经跑完。
	# 必须同步，否则同帧内 title_net_bridge 的 _sync_from_state 会因为 handles() 还是空而丢掉打开请求。
	_capture_initial_state()


func _capture_initial_state() -> void:
	for path: NodePath in page_paths:
		var node: Node = get_node_or_null(path)
		if not (node is Control):
			continue
		var page: Control = node as Control
		_pages.append(page)
		_connect_animation(page)
		if page.visible:
			_current = page
		else:
			_set_interactive(page, false)


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

## 该控件是否由本管理器负责显隐。ControlVisibieSet 用它决定要不要转调。
func handles(control: Control) -> bool:
	return _pages.has(control)


## 当前活动页面；主菜单时为 null。
func current_page() -> Control:
	return _current


## 是否有页面处于活动状态（含正在退出的不算）。
func is_main_menu() -> bool:
	return _current == null


# ---------------------------------------------------------------------------
# 打开 / 关闭
# ---------------------------------------------------------------------------

## 打开某页：旧页面开始退出（不 await），新页面立刻可用并播进入动画。
func open_page(page: Control) -> void:
	if not handles(page) or not is_instance_valid(page):
		return
	var was_exiting: bool = _exiting.has(int(page.get_instance_id()))
	_exiting.erase(int(page.get_instance_id()))
	if _current == page and not was_exiting:
		return
	var old: Control = _current
	_current = page
	if old != null and old != page:
		_begin_exit(old)
	page.visible = true
	_set_interactive(page, true)
	_play_enter(page)


## 关闭某页（回到主菜单）：播退出动画，播完才隐藏。
func close_page(page: Control) -> void:
	if not handles(page) or not is_instance_valid(page):
		return
	if _current == page:
		_current = null
	_begin_exit(page)


## 关闭所有页面回到主菜单。
func close_all() -> void:
	_current = null
	for page: Control in _pages:
		if is_instance_valid(page) and page.visible:
			_begin_exit(page)


# ---------------------------------------------------------------------------
# 退出 / 进入
# ---------------------------------------------------------------------------

func _begin_exit(page: Control) -> void:
	if not is_instance_valid(page):
		return
	if not page.visible:
		_set_interactive(page, true)
		return
	_set_interactive(page, false)
	var anim: DropInAnimation = _find_animation(page)
	if anim == null:
		# 没有掉落动画的页面（目前是 Options）直接隐藏
		page.visible = false
		_set_interactive(page, true)
		return
	_exiting[int(page.get_instance_id())] = true
	anim.play_drop_out()


func _on_drop_out_finished(page: Control) -> void:
	if not is_instance_valid(page):
		return
	var id: int = int(page.get_instance_id())
	if not _exiting.has(id):
		return
	_exiting.erase(id)
	# 退出途中又被打开：保持可见，由 open_page 负责重播进入动画
	if _current == page:
		return
	page.visible = false
	# 隐藏后把鼠标穿透恢复，避免下次打开时整页还是 IGNORE
	_set_interactive(page, true)


func _play_enter(page: Control) -> void:
	var anim: DropInAnimation = _find_animation(page)
	if anim == null:
		return
	# 页面"从隐藏变可见"时 watch_path 已被刻意断开（见 tscn），进入动画统一由这里触发，
	# 保证"退出途中重新打开"也能从当前位置平滑落回。
	anim.play_drop_in()


# ---------------------------------------------------------------------------
# 交互开关
# ---------------------------------------------------------------------------

## 禁用交互 = 打 ui_focus_skip（UiNavigator 会连同整棵子树排除）+ 鼠标穿透。
func _set_interactive(page: Control, enabled: bool) -> void:
	if not is_instance_valid(page):
		return
	page.set_meta(META_SKIP, not enabled)
	_apply_mouse_filter(page, enabled)
	if is_inside_tree():
		UiNavigator.refresh_now()


func _apply_mouse_filter(node: Node, enabled: bool) -> void:
	if node is Control:
		var control: Control = node as Control
		var id: int = int(control.get_instance_id())
		if enabled:
			if _mouse_backup.has(id):
				var original: int = _mouse_backup[id]
				@warning_ignore("int_as_enum_without_cast")
				control.mouse_filter = original
				_mouse_backup.erase(id)
		else:
			if not _mouse_backup.has(id):
				_mouse_backup[id] = int(control.mouse_filter)
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_apply_mouse_filter(child, enabled)


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _find_animation(page: Control) -> DropInAnimation:
	for child: Node in page.get_children():
		if child is DropInAnimation:
			return child as DropInAnimation
	return null


func _connect_animation(page: Control) -> void:
	var anim: DropInAnimation = _find_animation(page)
	if anim == null:
		return
	if not anim.drop_out_finished.is_connected(_on_drop_out_finished):
		anim.drop_out_finished.connect(_on_drop_out_finished.bind(page))
