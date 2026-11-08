extends Button

@export var line_edit_local_port: LineEdit
@export var line_edit_player_name: LineEdit

@export var player_page: Control

@export var player_name_limit: int = 12

const GameConfigType: GDScript = preload("res://script/utils/game_config.gd")

var game_config: GameConfigType
var local_port: int = 8914
var player_name: String = ""


func _ready() -> void:
	pressed.connect(_on_button_pressed)
	game_config = get_tree().get_first_node_in_group("game_config")

	# 从配置加载默认值
	if game_config:
		line_edit_local_port.text = str(game_config.get_local_port())
		line_edit_player_name.text = game_config.get_player_name()


func _on_button_pressed() -> void:
	local_port = line_edit_local_port.text.to_int()
	player_name = line_edit_player_name.text.substr(0, player_name_limit)

	var manager: MultiplayerManager = MPManager
	manager.local_port = local_port
	manager.player_name = player_name
	manager.player.name = player_name

	# 测试启动不写全局配置：同机三份实例会并发写同一个 user://game_settings.cfg，
	# 既可能互相覆盖，也会污染开发机上的默认端口/玩家名。
	if game_config and not MpTest.is_test_launch():
		game_config.set_local_port(local_port)
		game_config.set_player_name(player_name)

	manager.host_game(local_port)
