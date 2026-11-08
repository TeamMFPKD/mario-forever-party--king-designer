extends Node

## 已封存：自定义消息输入。当前版本只允许预置快捷用语（见 message_quick_sender.gd）。
## 恢复方式：把 archived 设为 false，并在 message_sidebar.tscn 里显示 MsgInput 节点。

@export var archived: bool = true

@export var line_edit: LineEdit
@export var send_button: Button

var multiplayer_manager: MultiplayerManager

func _ready() -> void:
	if archived:
		set_process_input(false)
		return
	multiplayer_manager = MPManager
	send_button.pressed.connect(_on_send_button_pressed)
	line_edit.text_changed.connect(_on_line_edit_text_changed)

func _on_line_edit_text_changed(new_text: String) -> void:
	if new_text == "":
		send_button.set_disabled(true)
	else:
		send_button.set_disabled(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER):
			if not send_button.is_disabled() and send_button.global_position.x > 0.0:
				send_message()
				await get_tree().process_frame
				line_edit.grab_focus()
				line_edit.edit()

func _on_send_button_pressed() -> void:
	send_message()

func send_message() -> void:
	if archived:
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
	line_edit.clear()
	send_button.set_disabled(true)