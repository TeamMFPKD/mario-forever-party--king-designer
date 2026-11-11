extends Control

## 方案 E · 紧凑网格
## 深色砖块 3+2 两行收在中间：宽度 966，高度 344。
## 相比现在 900×590 的双列大面板，占地缩到约三分之一，标题彻底让开。

const CARD_W: float = 320.0
const CARD_H: float = 164.0
const GAP: float = 24.0
const TOP_Y: float = 692.0

const BRICK: Color = Color("3a3830")
const BRICK_SOFT: Color = Color("8f8874")


func build() -> void:
	TitleKit.prepare(self)
	TitleKit.add_background(self)
	TitleKit.add_title(self)
	TitleKit.add_version(self)
	var items: Array[Dictionary] = TitleKit.menu_items()
	var row_one: int = 3
	var row_one_width: float = CARD_W * float(row_one) + GAP * float(row_one - 1)
	var row_one_left: float = (TitleKit.CANVAS.x - row_one_width) * 0.5
	for index: int in range(row_one):
		_build_card(items[index], index, row_one_left + float(index) * (CARD_W + GAP), TOP_Y)
	var row_two: int = items.size() - row_one
	var row_two_width: float = CARD_W * float(row_two) + GAP * float(row_two - 1)
	var row_two_left: float = (TitleKit.CANVAS.x - row_two_width) * 0.5
	for index: int in range(row_two):
		_build_card(
			items[row_one + index],
			row_one + index,
			row_two_left + float(index) * (CARD_W + GAP),
			TOP_Y + CARD_H + GAP
		)


func _build_card(item: Dictionary, index: int, x: float, y: float) -> void:
	var primary: bool = index == 0
	var accent: Color = item["accent"]
	var bg: Color = TitleKit.YELLOW if primary else BRICK
	var shadow: float = 8.0

	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(self, holder, x, y, CARD_W + shadow, CARD_H + shadow)
	var button: Button = TitleKit.button(holder, 0.0, 0.0, CARD_W, CARD_H, bg, 16, 0, shadow)
	TitleKit.bind_hover(holder, button, 8.0, 1.03)

	var bar: Panel = Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", TitleKit.sb(accent, 4, 0, accent))
	TitleKit.fixed(button, bar, 20.0, 22.0, 10.0, CARD_H - 44.0)

	var title_color: Color = TitleKit.INK if primary else TitleKit.CREAM
	var sub_color: Color = TitleKit.INK_SOFT if primary else BRICK_SOFT

	var label: Label = TitleKit.text(str(item["label"]), 40, title_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, label, 46.0, 30.0, CARD_W - 120.0, 54.0)

	var en: Label = TitleKit.text(str(item["en"]), 16, sub_color)
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, en, 48.0, 92.0, CARD_W - 120.0, 24.0)

	var number: Label = TitleKit.text(TitleKit.index_text(index), 18, sub_color)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, number, CARD_W - 78.0, 20.0, 56.0, 26.0)
