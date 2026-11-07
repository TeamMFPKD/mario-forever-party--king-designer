@abstract
class_name Command
extends RefCounted

## 编辑器操作命令基类（命令模式）。
##
## 所有可撤销的编辑操作都必须继承本类并实现 execute() / undo()。
## execute() 同时用于“首次执行”和“重做”，因此必须是可重复执行的。
## undo() 必须把数据精确还原到 execute() 之前的状态。
##
## 命令本身不持有场景节点指针作为“唯一标识”，一律保存
## object_name / position / door_id 等可重建的描述数据，
## 避免 undo 之后节点被 queue_free 造成悬空引用。

## 显示名称，用于调试与将来的历史记录面板。
func get_display_name() -> String:
	return "Command"

## 应用这次操作（首次执行与 redo 共用）。
@abstract
func execute() -> void

## 逆向还原这次操作。
@abstract
func undo() -> void

## 命令是否仍然有效（例如目标节点已随场景销毁）。
func is_valid() -> bool:
	return true
