extends CanvasLayer

## 百人团暂停菜单（卡片翻转版）。
##
## 关卡视口是一个面板：暂停时水平翻转 180°，背面是「双细线」面板，
## 菜单内容在背面。背面外层的 scale.x = -1 会让内容镜像，
## 所以内容层再 scale.x = -1 抵消，最终文字是正的。

@warning_ignore_start("unsafe_call_argument", "unsafe_cast")

const FLIP_IN_FRONT: float = 0.24
const FLIP_IN_BACK: float = 0.30
const FLIP_OUT_BACK: float = 0.22
const FLIP_OUT_FRONT: float = 0.26

var _is_open: bool = false
var _animating: bool = false

var _root: Control
var _back_panel: Panel
var _content: MarginContainer
var _level_panel: Control
var _level_original_scale: Vector2 = Vector2.ONE
var _flip_tween: Tween


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not Adventure.is_running():
		return
	# 按键在标题页「设置 → 输入映射 → 暂停」里可改。
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if not Adventure.is_running() or _animating:
		return
	if _is_open:
		_close_flip()
	else:
		_open_flip()


## 死亡/过关推进前强制关掉菜单，避免带着暂停状态重载场景。
func force_close() -> void:
	_animating = false
	_is_open = false
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	_flip_tween = null
	visible = false
	_reset_panels()
	get_tree().paused = false


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	_back_panel = Panel.new()
	_back_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_back_panel.add_theme_stylebox_override("panel", _make_double_border_style())
	_back_panel.visible = false
	_root.add_child(_back_panel)

	# SVG 自带双线较淡，再叠一层更清晰的内外细线。
	var outer_line: Panel = Panel.new()
	outer_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_line.offset_left = 3
	outer_line.offset_top = 3
	outer_line.offset_right = -3
	outer_line.offset_bottom = -3
	outer_line.add_theme_stylebox_override(
		"panel", _make_line_style(Color(0.169, 0.165, 0.157, 0.55), 2, 12)
	)
	_back_panel.add_child(outer_line)

	var inner_line: Panel = Panel.new()
	inner_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_line.offset_left = 12
	inner_line.offset_top = 12
	inner_line.offset_right = -12
	inner_line.offset_bottom = -12
	inner_line.add_theme_stylebox_override(
		"panel", _make_line_style(Color(0.169, 0.165, 0.157, 0.40), 2, 8)
	)
	_back_panel.add_child(inner_line)

	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.add_theme_constant_override("margin_left", 48)
	_content.add_theme_constant_override("margin_top", 32)
	_content.add_theme_constant_override("margin_right", 48)
	_content.add_theme_constant_override("margin_bottom", 32)
	# 抵消外层 scale.x = -1，保证背面文字是正的。
	_content.scale = Vector2(-1, 1)
	_back_panel.add_child(_content)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 0)
	_content.add_child(root_box)

	var title: Label = Label.new()
	title.text = "暂停"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#2B2A28"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(title)

	var center: CenterContainer = CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	box.add_child(_make_button("继续", _close_flip))
	var exclude_button: Button = _make_button("将本关从抽取数据中排除", _skip_hard)
	exclude_button.add_theme_color_override("font_color", Color("#C74343"))
	box.add_child(exclude_button)
	box.add_child(_make_button("跳过本关", _skip_soft))
	var abort_button: Button = _make_button("中断", _interrupt)
	abort_button.add_theme_color_override("font_color", Color("#2B2A28"))
	box.add_child(abort_button)


func _make_button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 76)
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_stylebox_override(
		"normal", _make_button_style(Color("#FFFFFF"), Color("#2B2A28"), 4)
	)
	button.add_theme_stylebox_override(
		"hover", _make_button_style(Color("#FFF9E6"), Color("#2B2A28"), 4)
	)
	button.add_theme_stylebox_override(
		"pressed", _make_button_style(Color("#EFEAD9"), Color("#FFC531"), 4)
	)
	button.add_theme_stylebox_override(
		"disabled", _make_button_style(Color("#E4DCC6"), Color("#B5AE9B"), 4)
	)
	var focus_style: StyleBoxFlat = _make_button_style(Color.TRANSPARENT, Color("#FFC531"), 4)
	focus_style.draw_center = false
	focus_style.expand_margin_left = 3.0
	focus_style.expand_margin_top = 3.0
	focus_style.expand_margin_right = 3.0
	focus_style.expand_margin_bottom = 3.0
	button.add_theme_stylebox_override("focus", focus_style)
	button.pressed.connect(callback)
	return button


func _make_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 24.0
	style.content_margin_top = 10.0
	style.content_margin_right = 24.0
	style.content_margin_bottom = 10.0
	return style


func _make_line_style(color: Color, width: int, corner: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	return style


func _make_double_border_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = load("res://ui/theme/borders/panel_double_92.svg") as Texture2D
	style.texture_margin_left = 22.0
	style.texture_margin_top = 22.0
	style.texture_margin_right = 22.0
	style.texture_margin_bottom = 22.0
	style.content_margin_left = 26.0
	style.content_margin_top = 22.0
	style.content_margin_right = 26.0
	style.content_margin_bottom = 22.0
	return style


# ---------------------------------------------------------------------------
# 翻转
# ---------------------------------------------------------------------------

func _open_flip() -> void:
	if _animating:
		return
	_level_panel = _find_level_panel()
	if _level_panel == null:
		force_close()
		return

	_animating = true
	_is_open = true
	visible = true
	get_tree().paused = true

	var rect: Rect2 = _level_panel.get_global_rect()
	_level_original_scale = _level_panel.scale
	_level_panel.pivot_offset = _level_panel.size * 0.5
	_level_panel.visible = true
	_level_panel.scale = Vector2(_level_original_scale.x, _level_original_scale.y)

	_back_panel.position = rect.position
	_back_panel.size = rect.size
	_back_panel.pivot_offset = rect.size * 0.5
	_content.pivot_offset = rect.size * 0.5
	_back_panel.scale = Vector2(0.0, 1.0)
	_back_panel.visible = false

	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_property(_level_panel, "scale:x", 0.0, FLIP_IN_FRONT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _flip_tween.finished
	_flip_tween = null

	_level_panel.visible = false
	_back_panel.visible = true
	_back_panel.scale = Vector2(0.0, 1.0)

	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_property(_back_panel, "scale:x", -1.0, FLIP_IN_BACK) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _flip_tween.finished
	_flip_tween = null
	_back_panel.scale = Vector2(-1.0, 1.0)
	_animating = false


func _close_flip() -> void:
	if _animating:
		return
	if _level_panel == null:
		force_close()
		return
	_animating = true
	_is_open = false

	if _back_panel.visible:
		_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_flip_tween.tween_property(_back_panel, "scale:x", 0.0, FLIP_OUT_BACK) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await _flip_tween.finished
		_flip_tween = null
		_back_panel.visible = false

	_level_panel.visible = true
	_level_panel.scale = Vector2(0.0, _level_original_scale.y)
	_flip_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_flip_tween.tween_property(_level_panel, "scale:x", _level_original_scale.x, FLIP_OUT_FRONT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _flip_tween.finished
	_flip_tween = null
	_level_panel.scale = _level_original_scale
	_level_panel.pivot_offset = _level_panel.size * 0.5

	visible = false
	get_tree().paused = false
	_animating = false


func _reset_panels() -> void:
	if _back_panel != null:
		_back_panel.visible = false
		_back_panel.scale = Vector2(-1.0, 1.0)
	if _level_panel != null and is_instance_valid(_level_panel):
		_level_panel.visible = true
		_level_panel.scale = _level_original_scale


func _find_level_panel() -> Control:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("SubViewportContainer", true, false) as Control


# ---------------------------------------------------------------------------
# 输入 / 菜单动作
# ---------------------------------------------------------------------------

func _on_root_gui_input(event: InputEvent) -> void:
	if not _is_open or _animating:
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_close_flip()


func _skip_hard() -> void:
	Adventure.skip_current_level(true)
	_after_skip()


func _skip_soft() -> void:
	Adventure.skip_current_level(false)
	_after_skip()


func _after_skip() -> void:
	force_close()
	var target: String = "" if Adventure.is_running() else Adventure.RESULT_SCENE
	Adventure.play_transition("skip", target)


func _interrupt() -> void:
	# 保存进度并回到百人团舞台，稍后可点「继续上次的团」。
	Adventure.interrupt_run()
	force_close()
	GlobalTransition.change_scene_to_file(Adventure.STAGE_SCENE)
