extends Node

## UI 焦点策略（autoload 名：UiFocusPolicy）。
##
## 决定一个 BaseButton 该不该可聚焦。决策表：
##
## | 平台     | 手柄在用 | 有 gamepad_focus 标记 | 无标记 |
## |----------|---------|----------------------|--------|
## | 移动端   | —       | FOCUS_NONE           | FOCUS_NONE |
## | PC/主机  | 否      | FOCUS_NONE           | FOCUS_NONE |
## | PC/主机  | **是**  | **复原原值**          | FOCUS_NONE |
##
## 设计要点：
## - 只放开**显式标记过**的节点。没标记的一律保持禁用，避免布局里大量
##   装饰性按钮突然变得可聚焦。
## - 复原用"原值"而不是统一 FOCUS_ALL：原场景里可能有节点本来设的就是
##   FOCUS_CLICK。
## - 移动端即使插着手柄也不放开：触屏布局的按钮间距按手指设计，
##   手柄光标在上面跳来跳去体验很差。
##
## 依赖：InputDevice（autoload）、PlatformUtils（autoload）。

## 参与手柄/键盘导航的标记；值可为 true 或字典（预留扩展）
const META_GAMEPAD_FOCUS: StringName = &"gamepad_focus"
## 标记该节点已被本策略接管（对应需求①「用 metadata 记录被取消聚焦的节点」）
const META_POLICY_APPLIED: StringName = &"ui_focus_policy_applied"
## 标记该节点的 focus 样式已被替换成空（去掉黄色描边）
const META_FOCUS_RING_SUPPRESSED: StringName = &"ui_focus_ring_suppressed"

## 手柄/键盘导航时用来顶替 focus 样式的空框。
## 主题 mfmp_theme.tres 的 Button/styles/focus 是 #FFC531 黄色描边（expand 5px）。
## 手柄导航已经有四角光标做选中指示，再叠一层黄框会重复，所以手柄模式下换成空框。
## 鼠标/触摸的 hover 样式（浅黄底）走的是另一条通道，不受影响。
static var _empty_focus_box: StyleBoxEmpty = null

## 策略变化（手柄插拔 / 主导设备切换）时发出，供场景刷新
signal policy_changed()

## 实例 id -> 被接管前的 focus_mode 原值。
## 用 Dictionary 而不是 metadata 存原值：metadata 取出是 Variant，
## 在本项目的 @warning_as_error 下无法安全转成 int。
var _original_focus_mode: Dictionary[int, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputDevice.gamepad_presence_changed.connect(_on_device_changed)
	InputDevice.last_device_changed.connect(_on_last_device_changed)


func _on_device_changed(_present: bool) -> void:
	refresh_all()


func _on_last_device_changed(_device: StringName) -> void:
	refresh_all()


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

## 是否应当放开被标记节点的焦点。
func should_enable_gamepad_focus() -> bool:
	if is_mobile_platform():
		return false
	return InputDevice.has_gamepad() and InputDevice.is_gamepad_active()


## 是否移动端。直接用 PlatformUtils 的现成实现，保证 debug 伪装平台也生效。
func is_mobile_platform() -> bool:
	return PlatformUtils.is_mobile_platform()


## 该节点是否带标记。
func is_marked(control: Control) -> bool:
	return control.has_meta(META_GAMEPAD_FOCUS)


# ---------------------------------------------------------------------------
# 应用
# ---------------------------------------------------------------------------

## 把一个节点纳入策略管理。幂等。
func track(button: BaseButton) -> void:
	var id: int = int(button.get_instance_id())
	if not _original_focus_mode.has(id):
		_original_focus_mode[id] = int(button.focus_mode)
		button.tree_exiting.connect(_on_tracked_exiting.bind(id), CONNECT_ONE_SHOT)
	button.set_meta(META_POLICY_APPLIED, true)
	apply_to(button)


func _on_tracked_exiting(id: int) -> void:
	_original_focus_mode.erase(id)


## 手柄导航时去掉按钮的 focus 黄框（四角光标已经指示选中了）。
func _suppress_focus_ring(button: BaseButton) -> void:
	if button.has_meta(META_FOCUS_RING_SUPPRESSED):
		return
	if _empty_focus_box == null:
		_empty_focus_box = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("focus", _empty_focus_box)
	button.set_meta(META_FOCUS_RING_SUPPRESSED, true)


## 恢复主题自带的 focus 样式。
func _restore_focus_ring(button: BaseButton) -> void:
	if not button.has_meta(META_FOCUS_RING_SUPPRESSED):
		return
	button.remove_theme_stylebox_override("focus")
	button.remove_meta(META_FOCUS_RING_SUPPRESSED)


## 按当前策略设置单个节点的 focus_mode。
func apply_to(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	if should_enable_gamepad_focus() and is_marked(button):
		_restore(button)
		# 手柄/键盘导航：去掉 focus 黄框，选中由四角光标表达
		_suppress_focus_ring(button)
	else:
		button.focus_mode = Control.FOCUS_NONE
		# 回到键鼠/触屏：恢复主题的黄框，鼠标 hover 时照旧显示
		_restore_focus_ring(button)
		# 如果它当前持有焦点但已不允许聚焦，立刻释放
		if button.has_focus():
			button.release_focus()


## 复原为可聚焦状态。
##
## ★ 注意：本项目 ui_button.tscn 模板本身就写着 focus_mode = 0（FOCUS_NONE），
## 所以"记下的原值"往往就是 NONE。照原值复原等于什么都没变。
## 因此：原值为 NONE 时用 FOCUS_ALL，否则用原值。
## 理由：一个按钮被打上 gamepad_focus 标记，本身就表达了"它应当可被手柄选中"。
func _restore(button: BaseButton) -> void:
	var id: int = int(button.get_instance_id())
	if not _original_focus_mode.has(id):
		button.focus_mode = Control.FOCUS_ALL
		return
	var original: int = _original_focus_mode[id]
	if original == int(Control.FOCUS_NONE):
		button.focus_mode = Control.FOCUS_ALL
	else:
		button.focus_mode = original as Control.FocusMode


## 扫描整棵树并应用（视口切换 / 设备变化时调用）。
func refresh_all() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	_refresh_subtree(tree.root)
	policy_changed.emit()


func _refresh_subtree(node: Node) -> void:
	if node is BaseButton and node.has_meta(META_POLICY_APPLIED):
		apply_to(node as BaseButton)
	for child: Node in node.get_children():
		_refresh_subtree(child)
