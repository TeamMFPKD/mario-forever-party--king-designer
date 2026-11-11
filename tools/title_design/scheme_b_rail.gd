extends Control

## 方案 B · 侧栏竖排
## 5 个入口收成左侧一条竖列（宽 470），右侧留一张玩家名片配平画面。
## 标题仍然居中完整露出，竖列从 506 才开始，和标题互不干扰。

const AVATAR_TEXTURE: Texture2D = preload("res://sprite/avatar/placeholder_1.png")


func build() -> void:
	TitleKit.prepare(self)
	TitleKit.add_background(self)
	TitleKit.add_title(self)
	TitleKit.add_version(self)
	_build_rail()
	_build_player_card()


func _build_rail() -> void:
	var items: Array[Dictionary] = TitleKit.menu_items()
	var item_w: float = 470.0
	var item_h: float = 96.0
	var gap: float = 14.0
	var shadow: float = 8.0
	var start_x: float = 104.0
	var start_y: float = 506.0
	for index: int in range(items.size()):
		var y: float = start_y + float(index) * (item_h + shadow + gap)
		_build_rail_item(items[index], index, start_x, y, item_w, item_h, shadow)


func _build_rail_item(
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
	TitleKit.fixed(self, holder, x, y, w + shadow + 14.0, h + shadow)
	var button: Button = TitleKit.button(holder, 0.0, 0.0, w, h, bg, 18, 5, shadow)
	var base_position: Vector2 = holder.position
	button.mouse_entered.connect(_slide.bind(holder, base_position + Vector2(14.0, 0.0)))
	button.mouse_exited.connect(_slide.bind(holder, base_position))

	var bar: Panel = Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", TitleKit.sb(accent, 4, 0, accent))
	TitleKit.fixed(button, bar, 20.0, 20.0, 8.0, h - 40.0)

	var label: Label = TitleKit.text(str(item["label"]), 38, TitleKit.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, label, 46.0, 12.0, 300.0, 46.0)

	var en: Label = TitleKit.text(
		str(item["en"]),
		16,
		TitleKit.INK_SOFT if primary else TitleKit.INK_MUTED
	)
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, en, 46.0, 56.0, 300.0, 24.0)

	var arrow: Label = TitleKit.text("›", 46, TitleKit.INK_SOFT)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(button, arrow, w - 76.0, 14.0, 54.0, 60.0)


func _slide(holder: Control, to_position: Vector2) -> void:
	if not is_instance_valid(holder) or not holder.is_inside_tree():
		return
	var tween: Tween = holder.create_tween()
	tween.tween_property(holder, "position", to_position, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_player_card() -> void:
	var x: float = 1240.0
	var y: float = 506.0
	var w: float = 580.0
	var h: float = 536.0

	var shadow: Panel = Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.add_theme_stylebox_override("panel", TitleKit.sb(TitleKit.INK, 24, 0, TitleKit.INK))
	TitleKit.fixed(self, shadow, x + 10.0, y + 10.0, w, h)

	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TitleKit.sb(TitleKit.PAPER, 24, 5, TitleKit.INK))
	TitleKit.fixed(self, panel, x, y, w, h)

	var caption: Label = TitleKit.text("当前玩家", 22, TitleKit.INK_MUTED)
	TitleKit.fixed(panel, caption, 32.0, 26.0, 200.0, 28.0)

	var rule_top: ColorRect = ColorRect.new()
	rule_top.color = Color(0.106, 0.106, 0.106, 0.16)
	rule_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(panel, rule_top, 32.0, 68.0, w - 64.0, 2.0)

	var avatar_size: float = 200.0
	var avatar: TextureRect = TextureRect.new()
	avatar.texture = AVATAR_TEXTURE
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(panel, avatar, (w - avatar_size) * 0.5, 86.0, avatar_size, avatar_size)

	var name_label: Label = TitleKit.text("MARIO", 46, TitleKit.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(panel, name_label, 32.0, 296.0, w - 64.0, 54.0)

	var tag_panel: Panel = Panel.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.add_theme_stylebox_override(
		"panel",
		TitleKit.sb(TitleKit.YELLOW, 19, 3, TitleKit.INK)
	)
	TitleKit.fixed(panel, tag_panel, (w - 260.0) * 0.5, 356.0, 260.0, 40.0)

	var tag: Label = TitleKit.text("HOST · 房主", 20, TitleKit.INK)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag_panel.add_child(tag)

	var rule_bottom: ColorRect = ColorRect.new()
	rule_bottom.color = Color(0.106, 0.106, 0.106, 0.16)
	rule_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TitleKit.fixed(panel, rule_bottom, 32.0, 420.0, w - 64.0, 2.0)

	var last: Label = TitleKit.text("最近游玩 · 3-1 云端漫步", 20, TitleKit.INK_SOFT)
	last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TitleKit.fixed(panel, last, 32.0, 438.0, w - 64.0, 28.0)

	var total: Label = TitleKit.text("累计通过 128 关 · 喜欢 36 关", 20, TitleKit.INK_SOFT)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TitleKit.fixed(panel, total, 32.0, 472.0, w - 64.0, 28.0)
