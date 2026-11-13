extends Node

## 全局 UI 焦点管理（autoload 名：NoButtonFocus，名字保留以免改动其他引用）。
##
## 本作 UI 原本一律用鼠标 / 触屏操作，键盘不允许选中或按下任何按钮。
## 手柄适配后策略变了：**只有被显式标记过的节点**才可能在游戏手柄激活时
## 恢复焦点，其余一律保持 FOCUS_NONE。
##
## 三类节点：
##
## | 情况 | 处理 |
## |---|---|
## | 带 gamepad_focus 标记 | 交给 UiFocusPolicy 按设备决定 |
## | 不带标记 | 永久 FOCUS_NONE（本脚本负责） |
## | 运行中强行 grab_focus | 焦点转移时立即释放（兜底） |
##
## 输入框（LineEdit / TextEdit / SpinBox 内部的 LineEdit）不是 BaseButton，
## 保持原样：键盘照常输入，Tab 照常可以在输入框之间切换。
##
## 注意：autoload 必须挂脚本本身（而不是 .tscn 场景），否则本项目的 GDScript
## 静态类型推断会把它退化成 Node。

func _ready() -> void:
	# 暂停（暂停菜单、通知面板）时也要继续压制焦点
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	# 本 autoload 之前已进入场景树的节点（例如其它 autoload 里的 UI）也要处理
	_block_subtree(get_tree().root)
	# 兜底：主窗口、关卡 SubViewport、弹窗各自的焦点变化都要经过检查
	_watch_viewport(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_block(node as BaseButton)
	elif node is Viewport:
		_watch_viewport(node as Viewport)


## 让指定 Viewport 的焦点变化都经过本节点检查
func _watch_viewport(viewport: Viewport) -> void:
	if not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)


func _on_gui_focus_changed(control: Control) -> void:
	if not (control is BaseButton):
		return
	var button: BaseButton = control as BaseButton
	# 带标记且当前策略允许时，保留焦点（手柄导航要用）
	if UiFocusPolicy.is_marked(button) and UiFocusPolicy.should_enable_gamepad_focus():
		return
	button.release_focus()


func _block_subtree(node: Node) -> void:
	if node is BaseButton:
		_block(node as BaseButton)
	for child: Node in node.get_children():
		_block_subtree(child)


## 处理单个按钮：带标记的交给策略层，不带标记的永久禁用。
func _block(button: BaseButton) -> void:
	if UiFocusPolicy.is_marked(button):
		# 记原值 + 按当前设备状态决定
		UiFocusPolicy.track(button)
		return
	button.focus_mode = Control.FOCUS_NONE
	if button.has_focus():
		button.release_focus()
