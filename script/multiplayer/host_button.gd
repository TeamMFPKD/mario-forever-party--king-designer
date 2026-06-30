extends Button

@export var line_edit_local_port: LineEdit
@export var line_edit_player_name: LineEdit

@export var player_page: Control

@export var player_name_limit: int = 12

var multiplayer_manager: MultiplayerManager
var game_config: Node
var local_port: int = 8914
var player_name: String = ""

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	game_config = get_tree().get_first_node_in_group("game_config") as Node
	pressed.connect(multiplayer_manager._on_host_button_pressed)

	# 从配置加载默认值
	if game_config:
		line_edit_local_port.text = str(game_config.get_local_port())
		line_edit_player_name.text = game_config.get_player_name()

func _on_button_pressed() -> void:
	local_port = line_edit_local_port.text.to_int()
	multiplayer_manager.local_port = local_port
	player_name = line_edit_player_name.text
	# zqh：若f(x)在[a,b]上连续，则f(x)在[a,b]上一致连续。
	player_name = player_name.substr(0, player_name_limit)
	multiplayer_manager.player_name = player_name
	
	# 保存配置到GameConfig
	if game_config:
		game_config.set_local_port(local_port)
		game_config.set_player_name(player_name)
	
	player_page.visible = true