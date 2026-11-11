extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 无头探针：确认改造后的标题画面里水管菜单已就位、五个目标路径都能解析、
## 点击「组织游戏」能把 HostPage 打开。
## 运行：Godot --headless --path . res://tools/title_pipe_probe.tscn

const OUTPUT: String = "res://tools/title_pipe_probe_result.txt"

const EXPORTS: Array[String] = [
	"host_visible_set",
	"join_visible_set",
	"history_jump",
	"raid_jump",
	"options_visible_set",
]


func _ready() -> void:
	var lines: Array[String] = []
	var packed: PackedScene = load("res://room/title.tscn") as PackedScene
	if packed == null:
		lines.append("title_load=false")
	else:
		var instance: Node = packed.instantiate()
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var menu: Node = instance.get_node_or_null("GameRoomSize/PipeMenu")
		lines.append("menu=%s" % (menu != null))
		if menu != null:
			lines.append("menu_children=%d" % menu.get_child_count())
			for key: String in EXPORTS:
				var path: NodePath = menu.get(key) as NodePath
				var target: Node = menu.get_node_or_null(path)
				lines.append("%s=%s" % [key, target != null])
			menu.call("_on_pressed", 0)
			await get_tree().process_frame
			var host: CanvasItem = instance.get_node_or_null(
				"GameRoomSize/HostPage"
			) as CanvasItem
			lines.append("host_visible_after_click=%s" % (host != null and host.visible))
			instance.queue_free()
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
	get_tree().quit()
