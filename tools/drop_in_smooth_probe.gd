extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access")

## 无头探针：确认标题页 Host / Join / 使用须知都换成 DropInAnimation 的 SMOOTH 观感，
## 并把落位过程采样一遍 —— 起点在屏幕上沿之外、单调下降、越过落位点后不再回弹。
## 运行：Godot --headless --path . res://tools/drop_in_smooth_probe.tscn

const OUTPUT: String = "res://tools/drop_in_smooth_probe_result.txt"

var _lines: Array[String] = []


func _ready() -> void:
	var packed: PackedScene = load("res://room/title.tscn") as PackedScene
	if packed == null:
		_lines.append("title_load=false")
		_write()
		return
	# 本机配置里使用须知已接受，探针只在内存里改成未接受，让 UserNotice 真的播一次（不落盘）
	GameConfig.config.set_value("user_notice_v3", "accept", false)
	var title: Node = packed.instantiate()
	# 探针自己的 _ready 里根节点还在装配子节点，直接 add_child 会失败
	get_tree().root.add_child.call_deferred(title)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_lines.append("host_style=%d" % _style(title, "GameRoomSize/HostPage/DropInAnimation"))
	_lines.append("join_style=%d" % _style(title, "GameRoomSize/JoinPage/DropInAnimation"))
	_lines.append("notice_style=%d" % _style(title, "GameRoomSize/UserNotice/DropInAnimation"))

	# 1. 打开 HostPage：复用标题页的真实入口（页面管理器），采样整段落位动画
	var host: Control = title.get_node_or_null("GameRoomSize/HostPage") as Control
	var manager: Node = title.get_node_or_null("GameRoomSize/TitlePageManager")
	if host != null and manager != null:
		var host_rest: float = host.position.y
		manager.call("open_page", host)
		var host_panel: Control = host.get_node_or_null("MfpkdPanel") as Control
		if host_panel != null:
			_lines.append("host_panel_h=%.1f" % host_panel.size.y)
		await _sample(host, host_rest, "host")

	# 2. 使用须知：重播一次，采样面板
	var notice: Control = title.get_node_or_null("GameRoomSize/UserNotice") as Control
	var notice_panel: Control = title.get_node_or_null(
		"GameRoomSize/UserNotice/DropRoot/UiPanel"
	) as Control
	if notice != null and notice_panel != null and _style(
		title, "GameRoomSize/UserNotice/DropInAnimation"
	) >= 0:
		notice.visible = true
		notice.call("play_drop_in")
		await get_tree().process_frame
		_lines.append("notice_panel_h=%.1f" % notice_panel.size.y)
		await _sample(notice_panel, 0.0, "notice")

	title.queue_free()
	_write()


func _style(root: Node, path: String) -> int:
	var node: Node = root.get_node_or_null(path)
	if node == null:
		return -1
	var value: Variant = node.get("enter_style")
	if value is int:
		var style: int = value
		return style
	return -2


func _sample(node: Control, rest: float, label: String) -> void:
	var first: float = node.position.y
	var first_bottom: float = node.global_position.y + node.size.y
	var last: float = first
	var arrived: bool = false
	var after_min: float = rest
	var after_max: float = rest
	var frames: int = 0
	var deadline: int = Time.get_ticks_msec() + 1200
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		frames += 1
		var y: float = node.position.y
		last = y
		if arrived:
			after_min = minf(after_min, y)
			after_max = maxf(after_max, y)
		elif absf(y - rest) <= 1.0:
			arrived = true
	_lines.append("%s_first=%.1f" % [label, first])
	_lines.append("%s_first_bottom=%.1f" % [label, first_bottom])
	_lines.append("%s_rest=%.1f" % [label, rest])
	_lines.append("%s_start_above=%.1f" % [label, rest - first])
	_lines.append("%s_last=%.1f" % [label, last])
	_lines.append("%s_final_err=%.2f" % [label, absf(last - rest)])
	_lines.append("%s_arrived=%s" % [label, arrived])
	_lines.append("%s_bounce_after_arrival=%.2f" % [label, rest - after_min])
	_lines.append("%s_frames=%d" % [label, frames])


func _write() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()
	get_tree().quit()
