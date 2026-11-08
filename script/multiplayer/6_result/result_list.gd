extends VBoxContainer

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

signal result_list_updated

@export var result_list_scene: PackedScene

const RandomCaptureManagerType: GDScript = preload("res://script/multiplayer/random_capture/random_capture_manager.gd")

var random_capture_manager: RandomCaptureManagerType


func _ready() -> void:
	MPManager.result_updated.connect(_on_result_list_updated)
	random_capture_manager = RandomCaptureManager
	# 主机的结算广播可能先用 RESULT 阶段切场景、再实例化本节点，
	# 这里补读一次已保存的结算数据。
	if not MPManager.flow.last_results.is_empty():
		# 等同一场景内其它节点的 _ready 完成再发 result_list_updated，
		# 否则监听者（ControlVisibieSet）的导出引用还没解析好。
		_on_result_list_updated.call_deferred(MPManager.flow.last_results)


func _on_result_list_updated(results: Array) -> void:
	# Clear
	for child: Node in get_children():
		child.free()

	# Re-add
	for entry: Variant in results:
		if not (entry is Dictionary):
			continue
		var result: Dictionary = entry
		var result_list_line: Node = result_list_scene.instantiate()

		var player_id: int = int(result.get("id", 0))
		var capture_rect: TextureRect = result_list_line.get_node("CaptureTextureRect") as TextureRect
		capture_rect.texture = random_capture_manager.get_capture(player_id)

		var player_name_label: Label = result_list_line.get_node("PlayerNameLabel") as Label
		player_name_label.text = str(result.get("name", ""))

		var level_cause_pass_label: Label = result_list_line.get_node("LevelCausePassLabel") as Label
		level_cause_pass_label.text = str(result.get("cause_pass", 0))

		var level_cause_death_label: Label = result_list_line.get_node("LevelCauseDeathLabel") as Label
		level_cause_death_label.text = str(result.get("cause_death", 0))

		var player_clear_rate: float = float(result.get("clear_rate", 0.0))
		var clear_rate_label: Label = result_list_line.get_node("ClearRateLabel") as Label
		clear_rate_label.text = str(round(player_clear_rate * 100000.0) / 1000.0) + "%"

		var level_pass_count_label: Label = result_list_line.get_node("LevelPassCountLabel") as Label
		level_pass_count_label.text = str(result.get("pass_count", 0))

		var score_label: Label = result_list_line.get_node("ScoreLabel") as Label
		score_label.text = str(result.get("score", 0))
		add_child(result_list_line)

	random_capture_manager.clear_captures()

	emit_signal("result_list_updated")
