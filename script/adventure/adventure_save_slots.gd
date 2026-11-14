extends PanelContainer

## 通栏存档位栏：一排固定 5 个格子，没有单独的「＋ 新存档」按钮。
##
## 有团可续的格子显示「存档N」，并用该团难度档的主题色描边（选中时整块填该色）；
## 第一个可开新团的格子显示「新存档」；其余空格显示「空」，坏档显示「进度异常」。
## 例：存档1 / 存档2 / 新存档 / 空 / 空
##
## 卡片只留一行标题，进度 / 档位 / 命数等细节放进 tooltip，界面不再堆小字说明。
## 选择 ≠ 开始：点格子只改选中态并发出 selection_changed，由舞台决定是否开团/续团。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## selection：1..5 = 存档位，0 = 新存档，-1 = 无选中
signal selection_changed(selection: int)

const SLOT_COUNT: int = 5
const TIER_NAMES: Array[String] = ["简单", "普通", "困难", "超难"]
## 与舞台背景主题色同一套色值：存档卡按团的难度档上色。
const TIER_COLORS: Array[Color] = [
	Color("#CDEBFF"),
	Color("#3F8C5A"),
	Color("#C8A45C"),
	Color("#8E44AD"),
]
## 各主题色上的前景文字：浅底用深色，深底用白字（土黄底用深棕）。
const TIER_TEXT_COLORS: Array[Color] = [
	Color("#1A1A1A"),
	Color("#F5FBFF"),
	Color("#3A2A12"),
	Color("#F5FBFF"),
]
## 「随机」档没有主题色：存档卡用银白色（填充比描边浅一档，和四档规则一致）。
const RANDOM_TIER_COLOR: Color = Color("#DCE1E8")
const RANDOM_ACCENT: Color = Color("#C2C8D2")
const CARD_BG: Color = Color(1, 1, 1, 1)
const CARD_BG_HOVER: Color = Color(1, 0.976, 0.902, 1)
const CARD_TEXT: Color = Color(0.101961, 0.101961, 0.121569, 1)
const SELECTED_COLOR: Color = Color(1, 0.9, 0.6, 1)
const NORMAL_COLOR: Color = Color(1, 1, 1, 1)
## 空槽 / 坏档仍要看清「空」字，别淡到快看不见。
const DISABLED_COLOR: Color = Color(1, 1, 1, 0.72)

@onready var _slot_row: HBoxContainer = $Margin/Box/SlotRow

var _selection: int = -1
## 每格对应的 selection 值；-1 = 这一格不可选。
var _slot_selection: Array[int] = [-1, -1, -1, -1, -1]
var _slot_enabled: Array[bool] = [false, false, false, false, false]
## 有团可续的格子记团的难度档 1..4，其余 -1；用来给卡片上色。
var _slot_tier: Array[int] = [-1, -1, -1, -1, -1]


func _ready() -> void:
	for index: int in range(_slot_row.get_child_count()):
		var button: Button = _slot_row.get_child(index) as Button
		if button == null:
			continue
		button.pressed.connect(_on_slot_pressed.bind(index))


## slots 来自 Adventure.get_run_slots()，固定 5 项。
## new_run_slot = Adventure.store.first_free_slot()：新团会落进的槽位，0 表示 5 格已满。
## 「新存档」标签放在这个格子上，开团后的存档位和 UI 显示才对得上。
func setup(slots: Array[Dictionary], new_run_slot: int) -> void:
	for index: int in range(mini(SLOT_COUNT, _slot_row.get_child_count())):
		var button: Button = _slot_row.get_child(index) as Button
		if button == null:
			continue
		var slot: int = index + 1
		var data: Dictionary = slots[index] if index < slots.size() else {}
		var resumable: bool = bool(data.get("valid", false))
		var is_new: bool = not resumable and slot == new_run_slot
		var enabled: bool = resumable or is_new
		_slot_enabled[index] = enabled
		_slot_selection[index] = (0 if is_new else slot) if enabled else -1
		# 有团记 0..4（0 = 随机，没有专属档位色），其余 -1 表示不是团。
		_slot_tier[index] = clampi(int(data.get("tier", 0)), 0, TIER_COLORS.size()) if resumable else -1
		button.disabled = not enabled
		button.tooltip_text = _tooltip_for(resumable, is_new, bool(data.get("active", false)), data)
		if resumable:
			_set_card_title(button, "存档%d" % slot)
		elif is_new:
			_set_card_title(button, "新存档")
		else:
			_set_card_title(button, "进度异常" if bool(data.get("active", false)) else "空")
	# 已选中的格子如果变得不可用，回到「无选中」，避免【开始打团】误开。
	var still_valid: bool = false
	for value: int in _slot_selection:
		if value == _selection:
			still_valid = true
			break
	if not still_valid:
		_selection = -1
	_apply_highlight()


func _set_card_title(button: Button, content: String) -> void:
	var title: Label = button.get_node_or_null("Content/Title") as Label
	if title != null:
		title.text = content


func _tooltip_for(resumable: bool, is_new: bool, has_data: bool, data: Dictionary) -> String:
	if resumable:
		var parts: Array[String] = ["继续这个团", _tier_text(int(data.get("tier", 0)))]
		var total: int = maxi(int(data.get("total_levels", 1)), 1)
		if str(data.get("mode", "finite")) == "finite":
			parts.append("定量 %d / %d 关" % [mini(int(data.get("index", 0)) + 1, total), total])
		else:
			parts.append("无尽 · 已通过 %d 关" % int(data.get("cleared_count", 0)))
		parts.append("剩 %d 命" % int(data.get("lives_left", 0)))
		return " · ".join(parts)
	if is_new:
		return "用侧边栏的设置开一个新团"
	if has_data:
		return "这个存档位进度异常，无法继续"
	return "存档位为空"


## 再次点击已选中的格子不取消选中，避免【开始打团】突然变灰。
func _on_slot_pressed(index: int) -> void:
	if index < 0 or index >= _slot_selection.size():
		return
	var selection: int = _slot_selection[index]
	if selection < 0:
		return
	if selection == _selection:
		_apply_highlight()
		return
	_selection = selection
	_apply_highlight()
	selection_changed.emit(selection)


func get_selection() -> int:
	return _selection


func set_selection(selection: int) -> void:
	_selection = selection
	_apply_highlight()


func card_titles() -> Array[String]:
	var result: Array[String] = []
	for index: int in range(mini(SLOT_COUNT, _slot_row.get_child_count())):
		var button: Button = _slot_row.get_child(index) as Button
		if button == null:
			result.append("")
			continue
		var title: Label = button.get_node_or_null("Content/Title") as Label
		result.append(title.text if title != null else "")
	return result


func button_at(index: int) -> Button:
	if index < 0 or index >= _slot_row.get_child_count():
		return null
	return _slot_row.get_child(index) as Button


func _apply_highlight() -> void:
	for index: int in range(_slot_row.get_child_count()):
		var button: Button = _slot_row.get_child(index) as Button
		if button == null or index >= SLOT_COUNT:
			continue
		var value: int = _slot_selection[index]
		var selected: bool = value >= 0 and value == _selection
		button.button_pressed = selected
		if _slot_tier[index] >= 0:
			# 有团的卡（含「随机」档）：档位色描边，选中时整块填该色，不叠黄色 modulate。
			_apply_tier_card(button, _slot_tier[index], selected)
			button.modulate = NORMAL_COLOR
		else:
			_clear_tier_card(button)
			button.modulate = SELECTED_COLOR if selected else NORMAL_COLOR
		if not _slot_enabled[index]:
			button.modulate = DISABLED_COLOR


func _apply_tier_card(button: Button, tier: int, selected: bool) -> void:
	var accent: Color = _tier_accent(tier)
	var fill: Color = _tier_fill(tier) if selected else CARD_BG
	var hover_fill: Color = fill if selected else CARD_BG_HOVER
	button.add_theme_stylebox_override("normal", _card_style(button, "normal", accent, fill))
	button.add_theme_stylebox_override("hover", _card_style(button, "hover", accent, hover_fill))
	var pressed: StyleBoxFlat = _card_style(button, "pressed", accent, fill)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	var title: Label = button.get_node_or_null("Content/Title") as Label
	if title != null:
		title.add_theme_color_override(
			"font_color", _tier_font_color(tier) if selected else CARD_TEXT
		)


func _clear_tier_card(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		button.remove_theme_stylebox_override(state)
	var title: Label = button.get_node_or_null("Content/Title") as Label
	if title != null:
		# 不能 remove_theme_color_override：场景里的深色本身也是一层 override，
		# 移掉会落到主题 Label 的白色默认值（选中「新存档」时字就变成白字）。
		title.add_theme_color_override("font_color", CARD_TEXT)


func _card_style(button: Button, state: String, accent: Color, fill: Color) -> StyleBoxFlat:
	# 复制主题同态样式，只换底色与描边，圆角 / 内边距与其它按钮一致。
	var source: StyleBox = button.get_theme_stylebox(state)
	var style: StyleBoxFlat = null
	if source != null:
		style = source.duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = accent
	return style


## 淡蓝那档直接当描边会糊在白底上，压一档明度、提一档饱和，色相不变。
## 「随机」档（tier = 0）没有主题色，用银白描边。
func _tier_accent(tier: int) -> Color:
	if tier < 1 or tier > TIER_COLORS.size():
		return RANDOM_ACCENT
	var theme_color: Color = TIER_COLORS[tier - 1]
	return Color.from_hsv(theme_color.h, maxf(theme_color.s, 0.5), minf(theme_color.v, 0.7))


func _tier_fill(tier: int) -> Color:
	if tier < 1 or tier > TIER_COLORS.size():
		return RANDOM_TIER_COLOR
	return TIER_COLORS[tier - 1]


func _tier_font_color(tier: int) -> Color:
	if tier < 1 or tier > TIER_TEXT_COLORS.size():
		return CARD_TEXT
	return TIER_TEXT_COLORS[tier - 1]


func _tier_text(tier: int) -> String:
	if tier >= 1 and tier <= TIER_NAMES.size():
		return TIER_NAMES[tier - 1]
	return "随机"
