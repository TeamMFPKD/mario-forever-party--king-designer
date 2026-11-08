extends Node

## 编辑房间倒计时。本脚本只负责“到点 / 全员完成”两个事件；
## 保存关卡与阶段推进分别交给 save_level_requested 与 MatchFlowService。

signal timeout_save

var _timer: Timer
var is_finishing: bool = false


func _ready() -> void:
	_timer = get_tree().get_first_node_in_group("timer_singleton") as Timer
	if _timer:
		_timer.timeout.connect(_on_time_out)
	MPManager.edit_all_ready.connect(_on_edit_all_ready)


func _on_time_out() -> void:
	if MPManager.phase != RoomPhase.Phase.EDIT:
		return
	_finish_edit("倒计时结束")


func _on_edit_all_ready() -> void:
	if is_finishing:
		return
	if MPManager.phase != RoomPhase.Phase.EDIT:
		return
	if _timer and not _timer.is_stopped():
		_timer.stop()
	_finish_edit("所有玩家已准备完毕，提前结束倒计时")


func _finish_edit(reason: String) -> void:
	if is_finishing:
		return
	is_finishing = true
	Log.i("编辑阶段结束：%s" % reason)
	MPManager.save_level_requested.emit()
	if MPManager.net.is_server():
		MPManager.flow.finish_edit(reason)
