extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 标题画面按钮重做方案的预览器。
## 运行 res://tools/title_design_preview.tscn，按 1~6 或 ←/→ 切换六套方案。
## 前五套是布局探索，方案 6「水管五连」是按参考图 1:1 复刻的水管按钮。
## 所有方案共用同一张背景、同一个标题，只有按钮区不同，方便横向对比。

const SCHEME_PATHS: Array[String] = [
	"res://tools/title_design/scheme_a_arcade.gd",
	"res://tools/title_design/scheme_b_rail.gd",
	"res://tools/title_design/scheme_c_hero.gd",
	"res://tools/title_design/scheme_d_ring.gd",
	"res://tools/title_design/scheme_e_grid.gd",
	"res://tools/title_design/scheme_f_pipe.gd",
]
const SCHEME_NAMES: Array[String] = [
	"街机底栏",
	"侧栏竖排",
	"主次焦点",
	"派对圆环",
	"紧凑网格",
	"水管五连",
]
const SCHEME_NOTES: Array[String] = [
	"5 张等宽卡片横排贴底，按钮区只占 200px 高，标题完整露出。",
	"入口收成左侧一条竖列，右侧配一张玩家名片；按钮不再横跨画面。",
	"1 个大的主按钮 + 4 个次按钮，整块只占中间一竖列。",
	"5 个圆形徽章绕中央圆盘摆一圈，扫过徽章时中央实时换说明。",
	"深色砖块 3+2 两行居中，占地约等于现在面板的三分之一。",
	"官方 Warp Pipe 素材 1:1 当按钮 + 五色变体；hover 道具上蹿（水管贴底不动），ads 与原版一致。",
]

var _canvas: Control
var _current: Control
var _backdrop: ColorRect
var _badge_panel: Panel
var _badge_index: Label
var _badge_label: Label
var _badge_note: Label
var _index: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("1d1d1d")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_backdrop = backdrop

	_canvas = Control.new()
	_canvas.size = TitleKit.CANVAS
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)
	resized.connect(_fit_canvas)
	get_viewport().size_changed.connect(_fit_canvas)
	_fit_canvas()
	_build_badge()
	show_scheme(0)


func _build_badge() -> void:
	var panel: Panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", TitleKit.sb(Color(0.09, 0.09, 0.09, 0.86), 14, 2, Color(0.42, 0.42, 0.42, 1)))
	TitleKit.fixed(_canvas, panel, 22.0, 22.0, 348.0, 214.0)
	_badge_panel = panel

	_badge_index = TitleKit.text("方案 1 / 5", 18, TitleKit.YELLOW)
	TitleKit.fixed(panel, _badge_index, 22.0, 16.0, 300.0, 26.0)

	_badge_label = TitleKit.text("街机底栏", 32, TitleKit.CREAM)
	TitleKit.fixed(panel, _badge_label, 22.0, 44.0, 300.0, 44.0)

	_badge_note = TitleKit.text(SCHEME_NOTES[0], 17, Color(0.78, 0.78, 0.74, 1), 0, Color(0, 0, 0, 0), 300.0)
	TitleKit.fixed(panel, _badge_note, 22.0, 96.0, 304.0, 76.0)

	var hint: Label = TitleKit.text("1~5 切换 · ← → 翻页", 15, Color(0.58, 0.58, 0.55, 1))
	TitleKit.fixed(panel, hint, 22.0, 176.0, 300.0, 24.0)


func set_badge_visible(value: bool) -> void:
	if is_instance_valid(_badge_panel):
		_badge_panel.visible = value


## 仅供截图：让当前方案把管口道具全摆出来（正常靠 hover 触发）
func debug_show_items() -> void:
	if _current != null and _current.has_method("show_all_items"):
		_current.call("show_all_items")


func _fit_canvas() -> void:
	var view: Vector2 = get_viewport_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		view = TitleKit.CANVAS
	var factor: float = minf(view.x / TitleKit.CANVAS.x, view.y / TitleKit.CANVAS.y)
	if factor <= 0.0:
		factor = 1.0
	_canvas.scale = Vector2(factor, factor)
	_canvas.position = (view - TitleKit.CANVAS * factor) * 0.5
	if is_instance_valid(_backdrop):
		_backdrop.size = view
		_backdrop.position = Vector2.ZERO


func show_scheme(index: int) -> void:
	_index = clampi(index, 0, SCHEME_PATHS.size() - 1)
	if _current != null:
		_canvas.remove_child(_current)
		_current.queue_free()
		_current = null
	var script: GDScript = load(SCHEME_PATHS[_index]) as GDScript
	if script == null:
		return
	var instance: Object = script.new()
	var scheme: Control = instance as Control
	if scheme == null:
		return
	scheme.size = TitleKit.CANVAS
	_canvas.add_child(scheme)
	scheme.call("build")
	_current = scheme
	_badge_label.text = SCHEME_NAMES[_index]
	_badge_note.text = SCHEME_NOTES[_index]
	_badge_index.text = "方案 %d / %d" % [_index + 1, SCHEME_PATHS.size()]


func get_scheme_index() -> int:
	return _index


func debug_state() -> String:
	var scheme_size: Vector2 = Vector2.ZERO
	var child_count: int = 0
	if _current != null:
		scheme_size = _current.size
		child_count = _current.get_child_count()
	return "canvas pos=%s scale=%s size=%s scheme=%s children=%d view=%s owner_size=%s" % [
		_canvas.position,
		_canvas.scale,
		_canvas.size,
		scheme_size,
		child_count,
		get_viewport_rect().size,
		size,
	]


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_1:
			show_scheme(0)
		KEY_2:
			show_scheme(1)
		KEY_3:
			show_scheme(2)
		KEY_4:
			show_scheme(3)
		KEY_5:
			show_scheme(4)
		KEY_6:
			show_scheme(5)
		KEY_LEFT:
			show_scheme(_index - 1)
		KEY_RIGHT:
			show_scheme(_index + 1)
