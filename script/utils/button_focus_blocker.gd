extends Node

## 全局禁用按钮的键盘焦点（autoload 名：NoButtonFocus）。
##
## 本作 UI 一律用鼠标 / 触屏操作，键盘不允许选中或按下任何按钮：
## - 节点进入场景树时，把 [BaseButton] 及其子类（Button / TextureButton /
##   CheckBox / CheckButton / OptionButton / MenuButton / LinkButton）的
##   focus_mode 统一置为 [constant Control.FOCUS_NONE]：Tab、方向键、Enter / Space
##   都不会再选中或触发它们；
## - 运行中若有代码强行 grab_focus，焦点一旦转移就会被立即释放。
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
	if control is BaseButton:
		(control as BaseButton).release_focus()

func _block_subtree(node: Node) -> void:
	if node is BaseButton:
		_block(node as BaseButton)
	for child: Node in node.get_children():
		_block_subtree(child)

func _block(button: BaseButton) -> void:
	button.focus_mode = Control.FOCUS_NONE
