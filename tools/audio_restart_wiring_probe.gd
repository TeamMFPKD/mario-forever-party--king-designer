extends Node

## 验证接入 Restart 策略的场景节点确实带上了 repeat_policy = 1，
## 并且同一帧连拨多次金币音时只留最后一次。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

const RESULT_PATH: String = "res://tools/audio_restart_wiring_probe_result.txt"


func _ready() -> void:
	var lines: Array[String] = []
	await _check_node(lines, "res://object/level/block/coin.tscn", "CoinSound")
	await _check_node(lines, "res://object/level/block/question_block.tscn", "BumpSound")
	await _check_node(lines, "res://object/level/block/question_block.tscn", "BreakSound")
	_write(lines)
	get_tree().quit()


func _check_node(lines: Array[String], scene_path: String, node_name: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		lines.append("%s_load=false" % node_name)
		return
	var root: Node = packed.instantiate()
	add_child(root)
	await get_tree().process_frame

	var player: Node = root.get_node_or_null(node_name)
	if player == null:
		lines.append("%s_missing=true" % node_name)
		root.queue_free()
		return
	lines.append("%s_is_continuous=%s" % [node_name, str(player is ContinuousAudioStream)])
	var cas: ContinuousAudioStream = player as ContinuousAudioStream
	if cas != null:
		lines.append("%s_repeat_policy=%d" % [node_name, cas.repeat_policy])
		lines.append("%s_policy_restart=%s" % [node_name, str(cas.repeat_policy == ContinuousAudioStream.RepeatPolicy.RESTART)])
		lines.append("%s_stream_set=%s" % [node_name, str(cas.stream != null)])
		if cas.stream != null:
			lines.append("%s_stream=%s" % [node_name, cas.stream.resource_path.get_file()])
	root.queue_free()
	await get_tree().process_frame


func _write(lines: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines))
		file.close()
