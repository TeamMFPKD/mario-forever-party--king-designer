extends HBoxContainer

## 编辑器界面的撤销 / 重做按钮。
##
## 绑定场景中的 CommandStack，按历史状态自动切换按钮可用性。
## CommandStack 由 LevelControl 在场景初始化时创建，本节点位于 UI 层，
## _ready 通常已晚于它；若仍找不到则延迟一帧重试。

@export var undo_button: Button
@export var redo_button: Button

var _command_stack: CommandStack = null

func _ready() -> void:
	if undo_button != null:
		undo_button.pressed.connect(_on_undo_pressed)
	if redo_button != null:
		redo_button.pressed.connect(_on_redo_pressed)
	_bind_command_stack()

func _bind_command_stack() -> void:
	_command_stack = CommandStack.find_in(get_tree())
	if _command_stack == null:
		await get_tree().process_frame
		_command_stack = CommandStack.find_in(get_tree())
	if _command_stack != null and not _command_stack.stack_changed.is_connected(_update_buttons):
		_command_stack.stack_changed.connect(_update_buttons)
	_update_buttons()

func _on_undo_pressed() -> void:
	if _command_stack == null:
		_command_stack = CommandStack.find_in(get_tree())
	if _command_stack != null:
		_command_stack.undo()

func _on_redo_pressed() -> void:
	if _command_stack == null:
		_command_stack = CommandStack.find_in(get_tree())
	if _command_stack != null:
		_command_stack.redo()

func _update_buttons() -> void:
	var can_undo: bool = _command_stack != null and _command_stack.can_undo()
	var can_redo: bool = _command_stack != null and _command_stack.can_redo()
	if undo_button != null:
		undo_button.disabled = not can_undo
	if redo_button != null:
		redo_button.disabled = not can_redo
