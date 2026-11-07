class_name CmdPaintTile
extends Command

## 瓦片笔划命令。
##
## set_cells_terrain_connect() 会重算连通地形，一次绘制可能改动大量
## 不相邻的 cell，逐格 diff 不可靠，所以统一以 TileMapLayer.tile_map_data
## 的“整包快照 + 差异片段”记录：
##   - 只保存第一个差异字节到最后一个差异字节之间的片段；
##   - 还原时用片段替换当前数据中的同一区间。
## 这样既能精确撤销连通重算的副作用，又不会为每一步存整关数据。

var _tile_map: TileMapLayer = null
var _offset: int = -1
var _before: PackedByteArray = PackedByteArray()
var _after: PackedByteArray = PackedByteArray()
var _whole_data: bool = false

static func from_snapshots(tile_map: TileMapLayer, before: PackedByteArray, after: PackedByteArray) -> CmdPaintTile:
	if tile_map == null or not is_instance_valid(tile_map):
		return null
	if before == after:
		return null

	var command: CmdPaintTile = CmdPaintTile.new()
	command._tile_map = tile_map

	if before.size() != after.size():
		command._whole_data = true
		command._before = before.duplicate()
		command._after = after.duplicate()
		return command

	var first_diff: int = -1
	var last_diff: int = -1
	for i: int in range(before.size()):
		if before[i] != after[i]:
			if first_diff < 0:
				first_diff = i
			last_diff = i

	if first_diff < 0:
		return null

	command._offset = first_diff
	command._before = before.slice(first_diff, last_diff + 1)
	command._after = after.slice(first_diff, last_diff + 1)
	return command

func get_display_name() -> String:
	if _whole_data:
		return "PaintTile(whole)"
	return "PaintTile(%d bytes)" % _before.size()

func execute() -> void:
	_apply(_after)

func undo() -> void:
	_apply(_before)

func is_valid() -> bool:
	return _tile_map != null and is_instance_valid(_tile_map)

func _apply(chunk: PackedByteArray) -> void:
	if not is_valid():
		return

	if _whole_data:
		_tile_map.tile_map_data = chunk.duplicate()
		return

	var current: PackedByteArray = _tile_map.tile_map_data
	var result: PackedByteArray = PackedByteArray()
	result.append_array(current.slice(0, _offset))
	result.append_array(chunk)
	result.append_array(current.slice(_offset + chunk.size()))
	_tile_map.tile_map_data = result
