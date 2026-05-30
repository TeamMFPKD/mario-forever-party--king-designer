extends Node

var multiplayer_manager: MultiplayerManager
var _file_path: String
var _ready_to_save: bool = false

func _ready() -> void:
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	if not multiplayer_manager:
		push_error("MessageCache: MultiplayerManager not found")
		return

	var now = Time.get_datetime_dict_from_system()
	var time_str = "%04d-%02d-%02d_%02d-%02d" % [now.year, now.month, now.day, now.hour, now.minute]

	var dir = DirAccess.open("user://")
	if not dir.dir_exists("messages"):
		dir.make_dir("messages")

	_file_path = "user://messages/%s_messages.txt" % time_str

	multiplayer_manager.messages_updated.connect(_on_messages_updated)
	_ready_to_save = true

	if multiplayer_manager.messages.size() > 0:
		_save()

func _on_messages_updated() -> void:
	if not _ready_to_save:
		return
	_save()

func _save() -> void:
	var file = FileAccess.open(_file_path, FileAccess.WRITE)
	if not file:
		push_error("MessageCache: cannot open file: %s" % _file_path)
		return

	for m in multiplayer_manager.messages:
		var cnt = m.get("cnt", 0)
		var unique_id = m.get("unique_id", "")
		var player_name = m.get("player_name", "")
		var msg = m.get("msg", "")
		var time_str = m.get("time", "")
		file.store_line("[=%d=] [%s] %s (%s)" % [cnt + 1, unique_id, player_name, time_str])
		file.store_line(msg)
		file.store_line("")

	file.close()
