extends Button

@export var line_edit_frp_domain : LineEdit
@export var line_edit_remote_port : LineEdit

var multiplayer_manager : MultiplayerManager
var frp_domain : String = ""
var remote_port : int = 8914

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	pressed.connect(multiplayer_manager._on_join_button_pressed)

func _on_button_pressed() -> void:
	frp_domain = line_edit_frp_domain.text
	multiplayer_manager.frp_domain = frp_domain
	remote_port = line_edit_remote_port.text.to_int()
	multiplayer_manager.remote_port = remote_port
	
