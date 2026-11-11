extends Control

## 方案 D · 派对圆环
## 5 个入口做成圆徽章，绕中央「当前选择」圆盘摆一圈（Mario Party 转盘感）。
## 圆环最外接 1520×760，标题区完全空出来；鼠标扫过徽章时中央圆盘实时改文字。

const CENTER: Vector2 = Vector2(960.0, 806.0)
const RADIUS_X: float = 400.0
const RADIUS_Y: float = 196.0
const BADGE: float = 150.0
const ANGLES: Array[float] = [-90.0, -18.0, 54.0, 126.0, 198.0]

var _center_title: Label
var _center_note: Label


class RingLayer extends Control:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = Vector2.ZERO

	func _draw() -> void:
		var line_color: Color = Color(0.106, 0.106, 0.106, 0.26)
		draw_arc(center, 121.0, 0.0, TAU, 128, line_color, 3.0, true)
		for index: int in range(points.size()):
			var direction: Vector2 = (points[index] - center).normalized()
			var from: Vector2 = center + direction * 132.0
			var to: Vector2 = points[index] - direction * 86.0
			draw_dashed_line(from, to, line_color, 3.0, 12.0)


func build() -> void:
	TitleKit.prepare(self)
	TitleKit.add_background(self)
	TitleKit.add_title(self)
	TitleKit.add_version(self)
	_build_center()
	_build_badges()


func _build_center() -> void:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TitleKit.sb(Color(1, 1, 1, 0.72), 119, 5, TitleKit.INK))
	TitleKit.fixed(self, panel, CENTER.x - 119.0, CENTER.y - 119.0, 238.0, 238.0)

	var caption: Label = TitleKit.text("当前选择", 18, TitleKit.INK_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TitleKit.fixed(panel, caption, 20.0, 44.0, 198.0, 24.0)

	_center_title = TitleKit.text("组织游戏", 42, TitleKit.INK)
	_center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	TitleKit.fixed(panel, _center_title, 8.0, 78.0, 222.0, 56.0)

	_center_note = TitleKit.text("开个房间，等朋友进来", 17, TitleKit.INK_SOFT, 0, TitleKit.INK, 190.0)
	_center_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	TitleKit.fixed(panel, _center_note, 14.0, 142.0, 210.0, 56.0)


func _build_badges() -> void:
	var items: Array[Dictionary] = TitleKit.menu_items()
	var layer: RingLayer = RingLayer.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(items.size()):
		points.append(_point_of(index))
	layer.points = points
	layer.center = CENTER
	TitleKit.fixed(self, layer, 0.0, 0.0, TitleKit.CANVAS.x, TitleKit.CANVAS.y)

	var shadow: float = 8.0
	for index: int in range(items.size()):
		var item: Dictionary = items[index]
		var point: Vector2 = points[index]
		var primary: bool = index == 0
		var bg: Color = TitleKit.YELLOW if primary else TitleKit.PAPER
		var holder: Control = Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		TitleKit.fixed(
			self,
			holder,
			point.x - BADGE * 0.5,
			point.y - BADGE * 0.5,
			BADGE + shadow,
			BADGE + shadow
		)
		var button: Button = TitleKit.button(holder, 0.0, 0.0, BADGE, BADGE, bg, 75, 6, shadow)
		button.pivot_offset = Vector2(BADGE * 0.5, BADGE * 0.5)
		TitleKit.bind_hover(holder, button, 6.0, 1.06)
		button.mouse_entered.connect(_on_badge_hover.bind(item))

		var number: Label = TitleKit.text(
			TitleKit.index_text(index),
			16,
			TitleKit.INK_SOFT if primary else TitleKit.INK_MUTED
		)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		TitleKit.fixed(button, number, 10.0, 30.0, BADGE - 20.0, 22.0)

		var label: Label = TitleKit.text(str(item["label"]), 25, TitleKit.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		TitleKit.fixed(button, label, 6.0, 54.0, BADGE - 12.0, 38.0)

		var en: Label = TitleKit.text(str(item["en"]), 11, TitleKit.INK_SOFT if primary else TitleKit.INK_MUTED)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		TitleKit.fixed(button, en, 6.0, 96.0, BADGE - 12.0, 18.0)


func _point_of(index: int) -> Vector2:
	var radians: float = deg_to_rad(ANGLES[index])
	return Vector2(
		CENTER.x + RADIUS_X * cos(radians),
		CENTER.y + RADIUS_Y * sin(radians)
	)


func _on_badge_hover(item: Dictionary) -> void:
	if not is_instance_valid(_center_title) or not is_instance_valid(_center_note):
		return
	_center_title.text = str(item["label"])
	_center_note.text = str(item["note"])
