extends Button

@export var line_edit_frp_domain : LineEdit
@export var line_edit_remote_port : LineEdit
@export var line_edit_player_name : LineEdit

@export var player_page : Control

var multiplayer_manager : MultiplayerManager
var frp_domain : String = ""
var remote_port : int
var player_name : String = ""

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	pressed.connect(multiplayer_manager._on_join_button_pressed)

func _on_button_pressed() -> void:
	frp_domain = line_edit_frp_domain.text
	multiplayer_manager.frp_domain = frp_domain
	remote_port = line_edit_remote_port.text.to_int()
	multiplayer_manager.remote_port = remote_port
	player_name = line_edit_player_name.text
	multiplayer_manager.player_name = player_name
	player_page.visible = true
