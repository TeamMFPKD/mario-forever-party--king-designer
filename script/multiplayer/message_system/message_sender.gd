extends Node

## 已封存：自定义消息输入。当前版本只允许预置快捷用语（见 message_quick_sender.gd）。
## 恢复方式：把 archived 设为 false，并在 message_sidebar.tscn 里显示 MsgInput 节点。

@export var archived: bool = true

@export var line_edit: LineEdit
@export var send_button: Button


func _ready() -> void:
	if archived:
		set_process_input(false)
		return
	send_button.pressed.connect(_on_send_button_pressed)
	line_edit.text_changed.connect(_on_line_edit_text_changed)


func _on_line_edit_text_changed(new_text: String) -> void:
	send_button.set_disabled(new_text == "")


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
	if not line_edit or not send_button:
		push_error("MessageSender: line_edit / send_button not found")
		return
	if line_edit.text.is_empty():
		return
	MPManager.chat.send_custom_text(line_edit.text)
	line_edit.clear()
	send_button.set_disabled(true)
