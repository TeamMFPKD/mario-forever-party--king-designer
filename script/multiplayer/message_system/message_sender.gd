extends Node

@export var line_edit: LineEdit
@export var send_button: Button

var multiplayer_manager : MultiplayerManager

func _ready():
	multiplayer_manager = get_tree().get_first_node_in_group("multiplayer_manager") as MultiplayerManager
	send_button.pressed.connect(_on_send_button_pressed)
	line_edit.text_changed.connect(_on_line_edit_text_changed)

func _on_line_edit_text_changed(new_text: String) -> void:
	if new_text == "":
		send_button.set_disabled(true)
	else:
		send_button.set_disabled(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not send_button.is_disabled() and send_button.global_position.x > 0.0:
				send_message()

func _on_send_button_pressed():
	send_message()

func send_message():
	if not multiplayer_manager:
		push_error("MultiplayerManager not found")
		return
	if not line_edit:
		push_error("LineEdit not found")
		return
	if not send_button:
		push_error("SendButton not found")
		return
	if not line_edit.text:
		push_error("Message is empty")
		return
	multiplayer_manager.send_message.rpc_id(
		1,
		multiplayer_manager.player.id,
		multiplayer_manager.get_device_tag(),
		line_edit.text,
	)
	line_edit.text = ""  # 发送后清空输入框
	send_button.set_disabled(true)