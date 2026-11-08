extends Button

## 关卡主题按钮：点击切换主题，并通过 CmdChangeLevelTheme 写入撤销历史。

@export var target_theme: LevelManager.LevelThemeEnum

var level_manager: LevelManager
var _command_stack: CommandStack = null

func _ready() -> void:
	level_manager = get_tree().get_first_node_in_group("level_manager") as LevelManager
	_command_stack = CommandStack.find_in(get_tree())
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	if level_manager == null:
		return
	if _command_stack == null:
		_command_stack = CommandStack.find_in(get_tree())

	var command: CmdChangeLevelTheme = CmdChangeLevelTheme.create(
		level_manager, level_manager.level_theme, target_theme)
	if command == null:
		return
	if _command_stack != null:
		_command_stack.execute_command(command)
	else:
		# 没有命令栈时（非编辑场景）退化为直接应用。
		level_manager.level_theme = target_theme
