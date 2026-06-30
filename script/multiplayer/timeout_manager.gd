extends Node

signal timeout_save

@export var level_transfer_scene_uid: String = "uid://brg4yepawdra3"

var timer_singleton: Timer
var multiplayer_manager: MultiplayerManager
var fc = func():
	get_tree().change_scene_to_file(level_transfer_scene_uid)

func _ready():
	timer_singleton = get_tree().get_first_node_in_group("timer_singleton") as Timer
	if timer_singleton:
		timer_singleton.timeout.connect(_on_time_out)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	if multiplayer_manager:
		multiplayer_manager.timeout_save.connect(_on_edit_timeout_save)

func _on_time_out():
	emit_signal("timeout_save")
	if multiplayer_manager.multiplayer.is_server():
		print("[%s] [主机] 倒计时结束！进入等待房间。开始收集关卡……" % Time.get_time_string_from_system())
		multiplayer_manager.edit_time_out.rpc()
	fc.call_deferred()

func _on_edit_timeout_save() -> void:
	emit_signal("timeout_save")
	print("[%s] [客户端] 倒计时结束！进入等待房间。开始收集关卡……" % Time.get_time_string_from_system())
	fc.call_deferred()