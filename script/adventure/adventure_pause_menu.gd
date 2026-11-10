extends CanvasLayer

## 百人团暂停菜单。节点在 adventure_play.tscn 里设为 PROCESS_MODE_ALWAYS，
## 这样 get_tree().paused = true 时仍然能响应输入。

var _is_open: bool = false
var _root: Control


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and Adventure.is_running():
		_toggle()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -250
	panel.offset_right = 300
	panel.offset_bottom = 250
	_root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "暂停"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_make_button("继续", _close))
	box.add_child(_make_button("本关不可能通过（永久排除）", _skip_hard))
	box.add_child(_make_button("我打不过，跳过本关", _skip_soft))
	box.add_child(_make_button("放弃本团", _abandon))
	box.add_child(_make_button("返回标题", _back_to_title))


func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	return button


func _toggle() -> void:
	if _is_open:
		_close()
	else:
		_is_open = true
		visible = true
		get_tree().paused = true


func _close() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false


func _skip_hard() -> void:
	Adventure.skip_current_level(true)
	_after_skip()


func _skip_soft() -> void:
	Adventure.skip_current_level(false)
	_after_skip()


func _after_skip() -> void:
	get_tree().paused = false
	visible = false
	_is_open = false
	var target: String = "" if Adventure.is_running() else Adventure.RESULT_SCENE
	Adventure.play_transition("skip", target)


func _abandon() -> void:
	Adventure.abandon_run()
	get_tree().paused = false
	visible = false
	_is_open = false
	Adventure.play_transition("finish", Adventure.RESULT_SCENE)


func _back_to_title() -> void:
	Adventure.abandon_run()
	get_tree().paused = false
	visible = false
	_is_open = false
	Adventure.play_transition("finish", "res://room/title.tscn")
