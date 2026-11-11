extends Control

## 方案 A · 街机底栏
## 标题保持原位、尺寸不变；5 个入口压成一条等宽卡片横排贴在底部。
## 按钮区高度从原来的 ~590px 降到 ~200px，标题下方留出完整背景。

func build() -> void:
	TitleKit.prepare(self)
	TitleKit.add_background(self)
	TitleKit.add_title(self)
	TitleKit.add_version(self)
	_build_bar()


func _build_bar() -> void:
	var items: Array[Dictionary] = TitleKit.menu_items()
	var card_w: float = 320.0
	var card_h: float = 190.0
	var gap: float = 24.0
	var shadow: float = 10.0
	var total: float = (card_w + shadow) * float(items.size()) + gap * float(items.size() - 1)
	var start_x: float = (TitleKit.CANVAS.x - total) * 0.5
	var y: float = 812.0
	for index: int in range(items.size()):
		var x: float = start_x + float(index) * (card_w + shadow + gap)
		_build_card(items[index], index, x, y, card_w, card_h, shadow)


func _build_card(
	item: Dictionary,
	index: int,
	x: float,
	y: float,
	w: float,
	h: float,
	shadow: float
) -> void:
	var primary: bool = index == 0
	var accent: Color = item["accent"]
	var bg: Color = TitleKit.YELLOW if primary else TitleKit.PAPER

	var holder: Control = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(self, holder, x, y, w + shadow, h + shadow)
	var button: Button = TitleKit.button(holder, 0.0, 0.0, w, h, bg, 20, 5, shadow)
	TitleKit.bind_hover(holder, button, 10.0, 1.03)

	var bar: Panel = Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", TitleKit.sb(accent, 5, 0, accent))
	TitleKit.fixed(button, bar, 22.0, 20.0, w - 44.0, 10.0)

	var number: Label = TitleKit.text(
		TitleKit.index_text(index),
		18,
		TitleKit.INK_SOFT if primary else TitleKit.INK_MUTED
	)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, number, w - 82.0, 140.0, 60.0, 26.0)

	var label: Label = TitleKit.text(str(item["label"]), 46, TitleKit.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, label, 12.0, 74.0, w - 24.0, 64.0)

	var en: Label = TitleKit.text(
		str(item["en"]),
		16,
		TitleKit.INK_SOFT if primary else TitleKit.INK_MUTED
	)
	en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, en, 12.0, 140.0, w - 24.0, 26.0)
