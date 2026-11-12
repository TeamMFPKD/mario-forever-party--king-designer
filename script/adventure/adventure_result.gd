extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团结算页。数据来自 Adventure.last_summary（内存），不读 MPManager。

const STAGE_SCENE: String = "res://room/adventure_stage.tscn"
const TITLE_SCENE: String = "res://room/title.tscn"

var _summary: Dictionary = {}


func _ready() -> void:
	# 结算页是冻结着关卡切进来的，这里负责解冻。
	get_tree().paused = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary = Adventure.last_summary
	_build_ui()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#EAF3FF")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_bottom", 72)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	var title: Label = Label.new()
	title.text = "本团结束"
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)

	var result_label: Label = Label.new()
	result_label.text = _result_text()
	result_label.add_theme_font_size_override("font_size", 34)
	box.add_child(result_label)

	if _summary.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "没有可显示的团数据。"
		box.add_child(empty_label)
	else:
		var mode: String = str(_summary.get("mode", "finite"))
		var cleared: int = int(_summary.get("cleared_count", 0))
		var total: int = int(_summary.get("total_levels", -1))
		var lives_left: int = int(_summary.get("lives_left", 0))
		var tier: int = int(_summary.get("tier", 0))
		if mode == "finite":
			box.add_child(_make_label("已通过：%d / %d" % [cleared, maxi(total, 0)]))
		else:
			box.add_child(_make_label("已通过：%d 关" % cleared))
		box.add_child(_make_label("剩余命数：%d" % lives_left))
		box.add_child(_make_label("档位：%d" % tier if tier > 0 else "档位：随机"))
		box.add_child(_make_label(
			"跳过：我打不过 %d 次 / 永久排除 %d 次"
			% [int(_summary.get("skipped_soft", 0)), int(_summary.get("skipped_hard", 0))]
		))

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	buttons.add_child(_make_button("再来一团", _again))
	buttons.add_child(_make_button("返回舞台", _back_to_stage))
	buttons.add_child(_make_button("返回标题", _back_to_title))


func _make_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	return label


func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 62)
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(callback)
	return button


func _result_text() -> String:
	var result: String = str(_summary.get("result", ""))
	match result:
		"completed":
			return "走完了整条路线。"
		"failed":
			return "命数耗尽，本团失败。"
		"abandoned":
			return "你放弃了本团。"
		"no_levels":
			return "没有可玩的关卡了。"
		_:
			return ""


func _again() -> void:
	var settings: Dictionary = Adventure.get_settings()
	if Adventure.start_run(settings):
		GlobalTransition.change_scene_to_file(Adventure.PLAY_SCENE)
	else:
		GlobalTransition.change_scene_to_file(STAGE_SCENE)


func _back_to_stage() -> void:
	GlobalTransition.change_scene_to_file(STAGE_SCENE)


func _back_to_title() -> void:
	GlobalTransition.change_scene_to_file(TITLE_SCENE)
