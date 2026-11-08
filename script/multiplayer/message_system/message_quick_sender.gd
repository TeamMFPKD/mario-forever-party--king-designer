extends Node

## 快捷用语发送组件。
## 运行时按 QuickMessageTable 生成 21 个按钮，点击后只把用语序号交给主机，
## 由各端按自己的语言显示。


@export var target_container: Container
@export var button_scene: PackedScene


func _ready() -> void:
	if not target_container:
		push_error("QuickMessageSender: target_container not found")
		return
	if not button_scene:
		push_error("QuickMessageSender: button_scene not found")
		return
	_build_buttons()


func _build_buttons() -> void:
	for quick_id: int in range(1, QuickMessageTable.COUNT + 1):
		var button: Button = button_scene.instantiate() as Button
		if not button:
			push_error("QuickMessageSender: button_scene is not a Button")
			return
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 24)
		# 直接把翻译 key 当文本，语言切换时引擎会自动重译
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		button.text = QuickMessageTable.key_of(quick_id)
		button.tooltip_text = QuickMessageTable.key_of(quick_id)
		button.pressed.connect(_on_quick_button_pressed.bind(quick_id))
		target_container.add_child(button)


func _on_quick_button_pressed(quick_id: int) -> void:
	MPManager.chat.send_quick(quick_id)
