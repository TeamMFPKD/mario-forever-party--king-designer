extends Button

@export var line_edit_local_port : LineEdit
@export var line_edit_player_name : LineEdit

@export var player_page : Control

var multiplayer_manager : MultiplayerManager
var local_port : int = 8914
var player_name : String = ""

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	pressed.connect(multiplayer_manager._on_host_button_pressed)

func _on_button_pressed() -> void:
	local_port = line_edit_local_port.text.to_int()
	multiplayer_manager.local_port = local_port
	player_name = line_edit_player_name.text
	multiplayer_manager.player_name = player_name
	player_page.visible = true
