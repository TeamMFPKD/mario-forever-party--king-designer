class_name CommandComposite
extends Command

## 复合命令：把一次“用户操作”产生的多条命令打包成一条历史记录。
## 例如橡皮擦一次可能同时删除瓦片、物件与管道折线。
##
## 注意：组内子命令通常已经由业务代码即时执行（编辑器需要实时反馈），
## 因此 CommandStack 在“结束分组”时直接把本对象压栈，不会再次 execute()。
## 只有在 redo() 时本对象才会被 execute()，届时按顺序重放子命令。

var _label: String = ""
var _commands: Array[Command] = []

func _init(label: String = "") -> void:
	_label = label

func get_display_name() -> String:
	if _label != "":
		return _label
	return "Composite(%d)" % _commands.size()

func add(command: Command) -> void:
	if command != null:
		_commands.append(command)

func is_empty() -> bool:
	return _commands.is_empty()

func size() -> int:
	return _commands.size()

func execute() -> void:
	for command: Command in _commands:
		command.execute()

func undo() -> void:
	for i: int in range(_commands.size() - 1, -1, -1):
		_commands[i].undo()

func is_valid() -> bool:
	for command: Command in _commands:
		if not command.is_valid():
			return false
	return true
