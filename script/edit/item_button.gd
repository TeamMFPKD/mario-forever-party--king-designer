extends Button

class_name ItemButton

## 物品被选中时发出（在 LevelControl 切换完绘制模式之后），由所属面板做收尾。
signal selected(button: ItemButton)

enum ItemType {
	TILE,
	OBJECT,
	ERASER,
	CLEAR_PIPE,
	OTHER,
}

@export var item_type: ItemType = ItemType.OBJECT
@export var object_name: String = ""

var level_control: LevelControl

# _ready 时采样，收尾结束后按原样还原
var _default_alpha: float = 1.0
var _default_mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP
var _default_focus_mode: Control.FocusMode = Control.FOCUS_ALL

func _ready() -> void:
	level_control = get_tree().get_first_node_in_group("level_control") as LevelControl
	pressed.connect(_on_button_pressed)
	_default_alpha = modulate.a
	_default_mouse_filter = mouse_filter
	_default_focus_mode = focus_mode

func _on_button_pressed() -> void:
	if level_control:
		level_control._on_item_button_pressed(item_type, self)
	selected.emit(self)

## 面板收起动画期间调用：
## keep_visible=true 保留外观（播完自己的选中动画），false 视觉隐藏；
## 两者都保留布局占位（不触发容器重排，选中项不会跳位），并立刻退出鼠标拾取。
func prepare_selection_close(keep_visible: bool) -> void:
	modulate.a = _default_alpha if keep_visible else 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	if has_focus():
		release_focus()

func reset_selection_close() -> void:
	modulate.a = _default_alpha
	mouse_filter = _default_mouse_filter
	focus_mode = _default_focus_mode
