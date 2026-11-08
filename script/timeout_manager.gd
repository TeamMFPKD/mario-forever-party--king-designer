extends Node

signal timeout_save

@export var level_transfer_scene_uid: String = "uid://brg4yepawdra3"

var timer_singleton: Timer
var multiplayer_manager: MultiplayerManager
## 防止倒计时结束与“全员准备完毕”同时触发，重复切换场景
var is_finishing: bool = false

func _ready() -> void:
	timer_singleton = get_tree().get_first_node_in_group("timer_singleton") as Timer
	if timer_singleton:
		timer_singleton.timeout.connect(_on_time_out)
	multiplayer_manager = MPManager
	multiplayer_manager.timeout_save.connect(_on_edit_timeout_save)
	# 只有编辑房间才关心“全员准备完毕”；游玩房间复用本脚本，不能提前切场景
	var game_mode: GameMode = GameModeSingleton
	if game_mode.game_mode == GameMode.GameModeType.EDIT:
		multiplayer_manager.edit_all_ready.connect(_on_edit_all_ready)

func _on_time_out() -> void:
	_finish_edit("倒计时结束")

func _on_edit_all_ready() -> void:
	if is_finishing:
		return
	# 提前结束倒计时，避免切换场景后计时器继续跑
	if timer_singleton and not timer_singleton.is_stopped():
		timer_singleton.stop()
	_finish_edit("所有玩家已准备完毕，提前结束倒计时")

func _finish_edit(reason: String) -> void:
	if is_finishing:
		return
	is_finishing = true
	emit_signal("timeout_save")
	if multiplayer_manager.multiplayer.is_server():
		Log.i("主机", "%s！进入等待房间。开始收集关卡……" % [reason])
		multiplayer_manager.edit_time_out.rpc()
	GlobalTransition.change_scene_to_file(level_transfer_scene_uid)

func _on_edit_timeout_save() -> void:
	if is_finishing:
		return
	is_finishing = true
	emit_signal("timeout_save")
	Log.i("客户端", "倒计时结束！进入等待房间。开始收集关卡……")
	GlobalTransition.change_scene_to_file(level_transfer_scene_uid)