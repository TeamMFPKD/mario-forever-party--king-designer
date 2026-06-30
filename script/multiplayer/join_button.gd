extends Button

@export var line_edit_frp_domain: LineEdit
@export var line_edit_remote_port: LineEdit
@export var line_edit_player_name: LineEdit

@export var player_page: Control

@export var player_name_limit: int = 12

var multiplayer_manager: MultiplayerManager
var game_config: Node
var frp_domain: String = ""
var remote_port: int
var player_name: String = ""

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	game_config = get_tree().get_first_node_in_group("game_config") as Node
	pressed.connect(multiplayer_manager._on_join_button_pressed)
	
	game_config = GameConfig
	
	# 从配置加载默认值
	if game_config:
		line_edit_frp_domain.text = game_config.get_frp_domain()
		line_edit_remote_port.text = str(game_config.get_remote_port())
		line_edit_player_name.text = game_config.get_player_name()

func _on_button_pressed() -> void:
	frp_domain = line_edit_frp_domain.text
	multiplayer_manager.frp_domain = frp_domain
	remote_port = line_edit_remote_port.text.to_int()
	multiplayer_manager.remote_port = remote_port
	player_name = line_edit_player_name.text
	# 冻双告诉我名字一定要长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长长
	player_name = player_name.substr(0, player_name_limit)
	multiplayer_manager.player_name = player_name
	
	# 保存配置到GameConfig
	if game_config:
		game_config.set_frp_domain(frp_domain)
		game_config.set_remote_port(remote_port)
		game_config.set_player_name(player_name)
	
	player_page.visible = true