extends UiSoundButton

@export var item_group: Control

## AnimationPlayer 缺失时的兜底等待时长（物品按钮选中动画最后一帧在 0.18s）
const SELECT_ANIM_FALLBACK_TIME: float = 0.2

## item_group 与所属 GroupButton 的关联，供“关掉其它组”时找到真正的主人
const GROUP_OWNER_META: StringName = &"_group_button_owner"

var _item_buttons: Array[ItemButton] = []

## 清点收尾期间被改成 IGNORE 的 Control，恢复时按原值写回
var _mouse_filter_backup: Dictionary = {}

## 展开/收起代际：只有“本轮仍有效”的收尾协程才有权隐藏面板
var _close_token: int = 0
var _selection_pending: bool = false

func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)
	if item_group == null:
		push_error("item_group is not assigned in GroupButton")
		return
	item_group.set_meta(GROUP_OWNER_META, self)
	item_group.visible = false
	_collect_item_buttons(item_group)
	for button: ItemButton in _item_buttons:
		button.selected.connect(_on_item_selected)

func _collect_item_buttons(node: Node) -> void:
	for child: Node in node.get_children():
		if child is ItemButton:
			_item_buttons.append(child)
		_collect_item_buttons(child)

func _on_button_pressed() -> void:
	if item_group == null:
		return
	if item_group.visible:
		close_group_immediately()
		return

	# 收起其它已展开的组：交给它的 GroupButton，保证临时状态被清理
	for node: Node in get_tree().get_nodes_in_group("item_group"):
		if node == item_group:
			continue
		var meta_value: Variant = node.get_meta(GROUP_OWNER_META, null)
		if meta_value is Node:
			var group_owner: Node = meta_value
			if group_owner.has_method("close_group_immediately"):
				group_owner.call("close_group_immediately")
				continue
		if node is Control:
			var other_group: Control = node
			other_group.visible = false

	_close_token += 1
	_selection_pending = false
	_reset_group_state()
	item_group.visible = true

## 立即收起面板（不等按钮动画），并清理收尾期间留下的透明/鼠标状态。
func close_group_immediately() -> void:
	_close_token += 1
	_selection_pending = false
	if item_group != null:
		item_group.visible = false
		_reset_group_state()

func _on_item_selected(button: ItemButton) -> void:
	if item_group == null or not item_group.visible:
		return
	if _selection_pending:
		# 收尾期间按钮已不可拾取，这里只是程序化调用时的保险
		button.prepare_selection_close(false)
		return

	_selection_pending = true
	var token: int = _close_token

	# 1) 先记录整组原始 mouse_filter，再改外观：
	#    反过来会把按钮的临时 IGNORE 记成“原值”，收尾后无法恢复。
	_set_group_mouse_ignored(true)
	# 立刻只保留被点按钮：其它按钮不可视但保留占位
	for other: ItemButton in _item_buttons:
		other.prepare_selection_close(other == button)

	# 2) 等被点按钮的选中动画播完（动画已由场景连线在 pressed 时启动）
	var anim: AnimationPlayer = null
	var anim_node: Node = button.get_node_or_null("AnimationPlayer")
	if anim_node is AnimationPlayer:
		anim = anim_node
	if anim != null and anim.has_animation(&"new_animation"):
		if not anim.is_playing():
			anim.play(&"new_animation")
		await anim.animation_finished
	else:
		await get_tree().create_timer(SELECT_ANIM_FALLBACK_TIME).timeout

	# 3) 本轮未被关闭或重新展开，才真正隐藏
	if token != _close_token:
		return
	_selection_pending = false
	item_group.visible = false
	_reset_group_state()

func _reset_group_state() -> void:
	for button: ItemButton in _item_buttons:
		button.reset_selection_close()
	_set_group_mouse_ignored(false)

func _set_group_mouse_ignored(ignored: bool) -> void:
	if item_group == null:
		return
	if ignored:
		_ignore_mouse_of(item_group)
		for node: Node in item_group.find_children("*", "Control", true, false):
			if node is Control:
				var control: Control = node
				_ignore_mouse_of(control)
	else:
		for control: Variant in _mouse_filter_backup.keys():
			if is_instance_valid(control):
				control.mouse_filter = _mouse_filter_backup[control]
		_mouse_filter_backup.clear()

func _ignore_mouse_of(control: Control) -> void:
	if _mouse_filter_backup.has(control):
		return
	_mouse_filter_backup[control] = control.mouse_filter
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
