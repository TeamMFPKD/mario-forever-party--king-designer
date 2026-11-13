extends PanelContainer

## 舞台上的存档位栏：5 个槽位卡片，有进行中的团时点一下直接续团。
##
## 槽位卡片按子节点顺序对应 1..5；本脚本只做数据绑定与点击转发，布局全在场景里。

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

signal resume_requested(slot: int)

const TIER_NAMES: Array[String] = ["简单", "普通", "困难", "超难"]
const FULL_COLOR: Color = Color("#B33A3A")
const NORMAL_COLOR: Color = Color(0.301961, 0.329412, 0.407843, 1)

@onready var _count_label: Label = $Margin/Box/Header/CountLabel
@onready var _slot_row: HBoxContainer = $Margin/Box/SlotRow


func _ready() -> void:
	for index: int in range(_slot_row.get_child_count()):
		var button: Button = _slot_row.get_child(index) as Button
		if button == null:
			continue
		button.pressed.connect(_on_slot_pressed.bind(index + 1))


## slots 来自 Adventure.get_run_slots()，固定 5 项，空位也在内。
func setup(slots: Array[Dictionary]) -> void:
	var used: int = 0
	for index: int in range(_slot_row.get_child_count()):
		var slot: int = index + 1
		var data: Dictionary = slots[index] if index < slots.size() else {}
		var resumable: bool = bool(data.get("valid", false))
		if resumable:
			used += 1
		_fill_card(_slot_row.get_child(index) as Button, slot, data, resumable)
	_update_count(used, _slot_row.get_child_count())


func _fill_card(button: Button, slot: int, data: Dictionary, resumable: bool) -> void:
	if button == null:
		return
	button.disabled = not resumable
	button.modulate = Color(1, 1, 1) if resumable else Color(1, 1, 1, 0.55)
	var title: Label = button.get_node_or_null("Content/Title") as Label
	var line1: Label = button.get_node_or_null("Content/Line1") as Label
	var line2: Label = button.get_node_or_null("Content/Line2") as Label
	if title != null:
		title.text = "存档 %d" % slot
	if line1 == null or line2 == null:
		return
	if not resumable:
		line1.text = "空存档位" if not bool(data.get("active", false)) else "进度异常"
		line2.text = ""
		return
	var mode: String = str(data.get("mode", "finite"))
	var index: int = int(data.get("index", 0))
	var total: int = int(data.get("total_levels", -1))
	var cleared: int = int(data.get("cleared_count", 0))
	if mode == "finite":
		line1.text = "定量 · %d / %d 关" % [mini(index + 1, maxi(total, 1)), maxi(total, 1)]
	else:
		line1.text = "无尽 · 已通过 %d 关" % cleared
	line2.text = "%s · 剩 %d 命" % [_tier_text(int(data.get("tier", 0))), int(data.get("lives_left", 0))]


func _update_count(used: int, total: int) -> void:
	if _count_label == null:
		return
	var full: bool = used >= total
	_count_label.text = "%d / %d · 已满" % [used, total] if full else "%d / %d" % [used, total]
	_count_label.add_theme_color_override("font_color", FULL_COLOR if full else NORMAL_COLOR)


func _tier_text(tier: int) -> String:
	if tier >= 1 and tier <= TIER_NAMES.size():
		return TIER_NAMES[tier - 1]
	return "随机"


func _on_slot_pressed(slot: int) -> void:
	resume_requested.emit(slot)
