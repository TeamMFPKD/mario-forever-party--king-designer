class_name CommandStack
extends Node

## 编辑器撤销 / 重做栈（命令模式的中枢）。
##
## 用法：
##   var stack: CommandStack = CommandStack.find_in(get_tree())
##   stack.execute_command(cmd)          # 执行并压栈
##   stack.push_executed_command(cmd)    # 代码已经执行过，只压栈（拖动预览等）
##   stack.begin_group("Erase") / end_group()  # 把一次鼠标操作合并成一条历史
##
## 关卡加载、主题切换等会重建数据源的操作必须调用 clear()，
## 否则历史命令会操作已经不存在的节点。

signal stack_changed

const GROUP_NAME: StringName = &"command_stack"
const DEFAULT_HISTORY_LIMIT: int = 100

@export var history_limit: int = DEFAULT_HISTORY_LIMIT

## 关闭记录后仍然执行命令，只是不写入历史（用于加载关卡时批量重建）。
var recording_enabled: bool = true

var _undo_stack: Array[Command] = []
var _redo_stack: Array[Command] = []
var _group: CommandComposite = null

## 用于把一次鼠标操作里所有瓦片改动合并成一条 CmdPaintTile。
var _tile_map: TileMapLayer = null
var _tile_snapshot_before: PackedByteArray = PackedByteArray()

func _ready() -> void:
	add_to_group(GROUP_NAME)

## 在场景树里查找编辑器命令栈（不存在时返回 null，调用方应降级为直接执行）。
static func find_in(tree: SceneTree) -> CommandStack:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_NAME) as CommandStack

func bind_tile_map(tile_map: TileMapLayer) -> void:
	_tile_map = tile_map

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func get_undo_count() -> int:
	return _undo_stack.size()

func get_redo_count() -> int:
	return _redo_stack.size()

func get_undo_name() -> String:
	if _undo_stack.is_empty():
		return ""
	var command: Command = _undo_stack.back()
	return command.get_display_name()

func get_redo_name() -> String:
	if _redo_stack.is_empty():
		return ""
	var command: Command = _redo_stack.back()
	return command.get_display_name()

## 执行命令并写入历史。
func execute_command(command: Command) -> void:
	if command == null or not command.is_valid():
		return
	command.execute()
	push_executed_command(command)

## 命令已经被业务代码执行过（例如拖动预览），只负责记录历史。
func push_executed_command(command: Command) -> void:
	if command == null or not command.is_valid():
		return
	if not recording_enabled:
		return
	_redo_stack.clear()
	if _group != null:
		_group.add(command)
		return
	_push_to_undo(command)

## 开始一次用户操作分组（一次点击 / 一次拖动 / 一次右键擦除）。
## 重复调用是幂等的，避免双 InputHandler 实例重复开组。
func begin_group(label: String = "") -> void:
	if _group != null:
		return
	_group = CommandComposite.new(label)
	_tile_snapshot_before = _capture_tile_snapshot()

## 结束分组：自动补一条瓦片差分命令，然后把整个分组压成一条历史记录。
func end_group() -> void:
	if _group == null:
		return
	var group: CommandComposite = _group
	_group = null
	var tile_snapshot_after: PackedByteArray = _capture_tile_snapshot()
	if _tile_map != null and not _tile_snapshot_before.is_empty() and not tile_snapshot_after.is_empty() \
			and _tile_snapshot_before != tile_snapshot_after:
		var tile_command: CmdPaintTile = CmdPaintTile.from_snapshots(_tile_map, _tile_snapshot_before, tile_snapshot_after)
		if tile_command != null:
			group.add(tile_command)
	_tile_snapshot_before = PackedByteArray()
	if group.is_empty():
		return
	if recording_enabled:
		_push_to_undo(group)

func undo() -> bool:
	if _group != null:
		end_group()
	if _undo_stack.is_empty():
		return false
	var command: Command = _undo_stack.pop_back()
	command.undo()
	_redo_stack.append(command)
	stack_changed.emit()
	Log.i("CommandStack", ["撤销: ", command.get_display_name()])
	return true

func redo() -> bool:
	if _group != null:
		end_group()
	if _redo_stack.is_empty():
		return false
	var command: Command = _redo_stack.pop_back()
	command.execute()
	_undo_stack.append(command)
	stack_changed.emit()
	Log.i("CommandStack", ["重做: ", command.get_display_name()])
	return true

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_group = null
	_tile_snapshot_before = PackedByteArray()
	stack_changed.emit()

func set_recording_enabled(enabled: bool) -> void:
	recording_enabled = enabled
	if not enabled:
		_group = null
		_tile_snapshot_before = PackedByteArray()

func _push_to_undo(command: Command) -> void:
	# 任何新操作都必须让“重做”失效：撤销后继续编辑会形成新分支。
	# 这里统一清空，覆盖 end_group() 里由瓦片快照自动补出的命令。
	_redo_stack.clear()
	_undo_stack.append(command)
	while history_limit > 0 and _undo_stack.size() > history_limit:
		_undo_stack.pop_front()
	stack_changed.emit()

func _capture_tile_snapshot() -> PackedByteArray:
	if _tile_map == null or not is_instance_valid(_tile_map):
		return PackedByteArray()
	return _tile_map.tile_map_data.duplicate()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return
	var control_pressed: bool = key_event.ctrl_pressed or key_event.meta_pressed
	if not control_pressed:
		return
	if key_event.keycode == KEY_Z:
		if key_event.shift_pressed:
			redo()
		else:
			undo()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_Y:
		redo()
		get_viewport().set_input_as_handled()
