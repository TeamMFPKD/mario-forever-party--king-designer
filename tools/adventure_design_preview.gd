extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团舞台 UI 方案预览器。
## 运行 res://tools/adventure_design_preview.tscn，按 1~4 或 ←/→ 切换四套方案。

const SCHEME_PATHS: Array[String] = [
	"res://tools/adventure_design/scheme_a_paper.gd",
	"res://tools/adventure_design/scheme_b_stage.gd",
	"res://tools/adventure_design/scheme_c_neon.gd",
	"res://tools/adventure_design/scheme_d_poster.gd",
]
const SCHEME_TITLES: Array[String] = [
	"方案 A · 纸片清单",
	"方案 B · 舞台路线",
	"方案 C · 街机霓虹",
	"方案 D · 海报排版",
]

var _canvas: Control
var _current: Control
var _badge: PanelContainer
var _badge_label: Label
var _index: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("1d1d1d")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_canvas = Control.new()
	_canvas.size = Vector2(1920, 1080)
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_canvas)
	resized.connect(_fit_canvas)
	_fit_canvas()
	_build_badge()
	show_scheme(0)


func _build_badge() -> void:
	_badge = DesignKit.card(Color(0.11, 0.11, 0.11, 0.82), 12, 0, Color(0, 0, 0, 0), 20, 8)
	DesignKit.fixed(_canvas, _badge, 630, 12, 660, 46)
	_badge_label = DesignKit.text("", 20, Color("f2ecd9"))
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_child(_badge_label)


func _fit_canvas() -> void:
	var factor: float = minf(size.x / 1920.0, size.y / 1080.0)
	if factor <= 0.0:
		factor = 1.0
	_canvas.scale = Vector2(factor, factor)
	_canvas.position = (size - Vector2(1920, 1080) * factor) * 0.5


func show_scheme(index: int) -> void:
	_index = clampi(index, 0, SCHEME_PATHS.size() - 1)
	if _current != null:
		_canvas.remove_child(_current)
		_current.queue_free()
		_current = null
	var script: GDScript = load(SCHEME_PATHS[_index]) as GDScript
	var scheme: Control = script.new() as Control
	scheme.size = Vector2(1920, 1080)
	_canvas.add_child(scheme)
	scheme.call("build")
	_current = scheme
	_badge_label.text = "%s    ← → 切换" % SCHEME_TITLES[_index]
	_badge.move_to_front()


func get_scheme_index() -> int:
	return _index


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
		KEY_LEFT:
			show_scheme(_index - 1)
		KEY_RIGHT:
			show_scheme(_index + 1)
