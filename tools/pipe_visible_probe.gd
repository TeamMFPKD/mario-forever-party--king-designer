extends Node

@warning_ignore_start("unsafe_cast")

## 检查打开 / 关闭选项面板时，水管菜单的显隐是否能正确切换。
## 运行：Godot --headless --path . res://tools/pipe_visible_probe.tscn

const OUTPUT: String = "res://tools/pipe_visible_probe_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	var packed: PackedScene = load("res://room/title.tscn") as PackedScene
	if packed == null:
		lines.append("title_load=false")
	else:
		var title: Node = packed.instantiate()
		get_tree().root.add_child.call_deferred(title)
		await get_tree().process_frame
		await get_tree().process_frame
		for frame: int in range(8):
			await get_tree().process_frame
		var menu: CanvasItem = title.get_node_or_null("GameRoomSize/PipeMenu") as CanvasItem
		var options: CanvasItem = title.get_node_or_null("GameRoomSize/Options") as CanvasItem
		var visible_set: Node = title.get_node_or_null(
			"GameRoomSize/Options/ControlVisibieSet"
		)
		lines.append("start  menu=%s options=%s" % [
			_visible(menu), _visible(options)
		])
		if visible_set != null:
			visible_set.call("_set_visible")
			for frame: int in range(6):
				await get_tree().process_frame
			lines.append("open   menu=%s options=%s" % [
				_visible(menu), _visible(options)
			])
			visible_set.call("_set_invisible")
			for frame: int in range(6):
				await get_tree().process_frame
			lines.append("close  menu=%s options=%s" % [
				_visible(menu), _visible(options)
			])
		title.queue_free()
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()


func _visible(node: CanvasItem) -> String:
	if node == null:
		return "<missing>"
	return str(node.visible)
