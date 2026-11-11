extends Control

## 方案 C · 主次焦点
## 一个大的主按钮「组织游戏」占住视觉中心，其余 4 个入口退成 2×2 次按钮。
## 整块只占中间 640px 宽的一条竖列，左右全是背景，标题不再被压。

const HERO_W: float = 640.0
const HERO_H: float = 180.0
const SUB_W: float = 306.0
const SUB_H: float = 136.0
const GAP: float = 20.0
const COLUMN_LEFT: float = 640.0
const HERO_Y: float = 548.0


func build() -> void:
	TitleKit.prepare(self)
	TitleKit.add_background(self)
	TitleKit.add_title(self)
	TitleKit.add_version(self)
	var items: Array[Dictionary] = TitleKit.menu_items()
	_build_hero(items[0])
	for index: int in range(1, items.size()):
		var slot: int = index - 1
		var column: int = slot % 2
		var row: int = floori(float(slot) / 2.0)
		var x: float = COLUMN_LEFT + float(column) * (SUB_W + 22.0)
		var y: float = HERO_Y + HERO_H + 34.0 + float(row) * (SUB_H + 14.0)
		_build_sub(items[index], x, y)


func _build_hero(item: Dictionary) -> void:
	var shadow: float = 14.0
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(self, holder, COLUMN_LEFT, HERO_Y, HERO_W + shadow, HERO_H + shadow)
	var button: Button = TitleKit.button(holder, 0.0, 0.0, HERO_W, HERO_H, TitleKit.YELLOW, 24, 8, shadow)
	TitleKit.bind_hover(holder, button, 10.0, 1.02)

	var bar: Panel = Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", TitleKit.sb(TitleKit.RED, 4, 0, TitleKit.RED))
	TitleKit.fixed(button, bar, 40.0, 26.0, 92.0, 8.0)

	var label: Label = TitleKit.text(str(item["label"]), 64, TitleKit.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, label, 40.0, 46.0, 420.0, 76.0)

	var en: Label = TitleKit.text(str(item["en"]), 20, TitleKit.INK_SOFT)
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, en, 42.0, 122.0, 420.0, 30.0)

	var arrow: Label = TitleKit.text("›", 96, TitleKit.INK)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, arrow, HERO_W - 140.0, 30.0, 100.0, 120.0)


func _build_sub(item: Dictionary, x: float, y: float) -> void:
	var shadow: float = 8.0
	var accent: Color = item["accent"]
	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(self, holder, x, y, SUB_W + shadow, SUB_H + shadow)
	var button: Button = TitleKit.button(holder, 0.0, 0.0, SUB_W, SUB_H, TitleKit.PAPER, 18, 5, shadow)
	TitleKit.bind_hover(holder, button, 8.0, 1.03)

	var bar: Panel = Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", TitleKit.sb(accent, 4, 0, accent))
	TitleKit.fixed(button, bar, 18.0, 18.0, SUB_W - 36.0, 8.0)

	var label: Label = TitleKit.text(str(item["label"]), 36, TitleKit.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, label, 10.0, 44.0, SUB_W - 20.0, 48.0)

	var en: Label = TitleKit.text(str(item["en"]), 15, TitleKit.INK_MUTED)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, en, 10.0, 98.0, SUB_W - 20.0, 24.0)
