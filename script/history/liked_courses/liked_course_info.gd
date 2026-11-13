extends Control

## 收藏关卡卡片：默认只显示封面，点击封面后封面略微上移，三个按钮从封面背后滑出到封面下方。

const CARD_GROUP: String = "liked_course_card"

@export var cover_root: Control
@export var cover_button: TextureButton
@export var buttons_root: VBoxContainer

@export var expand_duration: float = 0.24
@export var collapse_duration: float = 0.18
@export var cover_lift: float = 12.0
@export var buttons_gap: float = 8.0
@export var hover_tint: Color = Color(0.88, 0.88, 0.88, 1.0)
## 点封面（展开/收起按钮组）时播放的音效；留空则不出声。
## 封面是 TextureButton，不是 UiSoundButton，所以借用它的静态音效池播放。
@export var cover_pressed_sound: AudioStream

var _expanded: bool = false
var _tween: Tween
var _hover_tween: Tween

var _cover_rest_y: float = 0.0
var _cover_lifted_y: float = 0.0
var _buttons_start_y: float = 0.0
var _buttons_final_y: float = 0.0
var _buttons_height: float = 0.0
var _collapsed_height: float = 0.0
var _expanded_height: float = 0.0

func _ready() -> void:
	add_to_group(CARD_GROUP)
	if cover_root == null or cover_button == null or buttons_root == null:
		push_error("[LikedCourseInfo] cover_root / cover_button / buttons_root 未指定")
		return
	cover_button.pressed.connect(_on_cover_button_pressed)
	cover_button.mouse_entered.connect(_on_cover_mouse_entered)
	cover_button.mouse_exited.connect(_on_cover_mouse_exited)
	_update_layout_metrics()
	_apply_collapsed_state()

func is_expanded() -> bool:
	return _expanded

func expand(instant: bool = false) -> void:
	if _expanded:
		return
	_expanded = true
	_kill_tween()
	buttons_root.visible = true
	if instant:
		cover_root.position.y = _cover_lifted_y
		buttons_root.position.y = _buttons_final_y
		buttons_root.modulate = Color(1, 1, 1, 1)
		custom_minimum_size = Vector2(custom_minimum_size.x, _expanded_height)
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(cover_root, "position:y", _cover_lifted_y, expand_duration)
	_tween.tween_property(buttons_root, "position:y", _buttons_final_y, expand_duration)
	_tween.tween_property(buttons_root, "modulate:a", 1.0, expand_duration * 0.6)
	_tween.tween_property(self, "custom_minimum_size:y", _expanded_height, expand_duration)
	_tween.finished.connect(_on_expand_tween_finished)

func collapse(instant: bool = false) -> void:
	if not _expanded:
		return
	_expanded = false
	_kill_tween()
	if instant:
		_apply_collapsed_state()
		return
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(cover_root, "position:y", _cover_rest_y, collapse_duration)
	_tween.tween_property(buttons_root, "position:y", _buttons_start_y, collapse_duration)
	_tween.tween_property(buttons_root, "modulate:a", 0.0, collapse_duration * 0.7)
	_tween.tween_property(self, "custom_minimum_size:y", _collapsed_height, collapse_duration)
	_tween.finished.connect(_on_collapse_tween_finished)

func _on_collapse_tween_finished() -> void:
	if _expanded:
		return
	buttons_root.visible = false

func _on_expand_tween_finished() -> void:
	var scroll: ScrollContainer = _find_scroll_container()
	if scroll != null:
		scroll.ensure_control_visible(self)

func _find_scroll_container() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null

func _on_cover_button_pressed() -> void:
	UiSoundButton.play_stream(cover_pressed_sound)
	if _expanded:
		collapse()
		return
	_collapse_other_cards()
	expand()

func _collapse_other_cards() -> void:
	for card: Node in get_tree().get_nodes_in_group(CARD_GROUP):
		if card == self:
			continue
		if card.has_method("collapse"):
			card.call("collapse")

func _on_cover_mouse_entered() -> void:
	_set_cover_tint(hover_tint)

func _on_cover_mouse_exited() -> void:
	_set_cover_tint(Color(1, 1, 1, 1))

func _set_cover_tint(color: Color) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(cover_root, "self_modulate", color, 0.12)

func _update_layout_metrics() -> void:
	_buttons_height = buttons_root.get_combined_minimum_size().y
	var cover_height: float = cover_root.size.y
	_cover_rest_y = cover_root.position.y
	_cover_lifted_y = _cover_rest_y - cover_lift
	# 收起时按钮完全藏在封面背后（底边对齐封面底边），展开时滑到抬起的封面下方
	_buttons_start_y = _cover_rest_y + cover_height - _buttons_height
	_buttons_final_y = _cover_lifted_y + cover_height + buttons_gap
	_collapsed_height = _cover_rest_y * 2.0 + cover_height
	_expanded_height = _buttons_final_y + _buttons_height + _cover_rest_y

func _apply_collapsed_state() -> void:
	_expanded = false
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	cover_root.self_modulate = Color(1, 1, 1, 1)
	cover_root.position.y = _cover_rest_y
	buttons_root.position.y = _buttons_start_y
	buttons_root.modulate = Color(1, 1, 1, 0)
	buttons_root.visible = false
	custom_minimum_size = Vector2(custom_minimum_size.x, _collapsed_height)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
