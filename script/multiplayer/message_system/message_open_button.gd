extends Control

class_name MessageOpenButton

## 打开快捷消息面板的圆形按钮。
## 默认位置：画面垂直居中、靠左。
## 长按约 0.2 秒后可拖动；松开时按视口比例把位置写入 GameConfig，下次启动恢复。

signal open_requested

const LONG_PRESS_TIME: float = 0.2
const BUTTON_SIZE: float = 72.0
const CONFIG_SECTION: String = "message_ui"
const CONFIG_KEY: String = "open_button_position"

var _pressing: bool = false
var _drag_ready: bool = false
var _dragging: bool = false
var _press_time: float = 0.0
var _grab_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_load_position()


func _process(delta: float) -> void:
	if not _pressing or _drag_ready:
		return
	_press_time += delta
	if _press_time >= LONG_PRESS_TIME:
		_drag_ready = true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_begin_press()
			accept_event()


func _input(event: InputEvent) -> void:
	if not _pressing:
		return
	if event is InputEventMouseMotion:
		_move_press()
	elif event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_end_press()


func _begin_press() -> void:
	_pressing = true
	_drag_ready = false
	_dragging = false
	_press_time = 0.0
	_grab_offset = global_position - get_viewport().get_mouse_position()


func _move_press() -> void:
	if not _drag_ready:
		return
	_dragging = true
	global_position = get_viewport().get_mouse_position() + _grab_offset
	_clamp_to_viewport()


func _end_press() -> void:
	if not _pressing:
		return
	var was_dragging: bool = _dragging
	_pressing = false
	_drag_ready = false
	_dragging = false
	_press_time = 0.0
	if was_dragging:
		_save_position()
	else:
		open_requested.emit()


func _default_position() -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	return Vector2(32.0, (viewport_size.y - BUTTON_SIZE) * 0.5)


func _clamp_to_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	position.x = clampf(position.x, 0.0, maxf(viewport_size.x - BUTTON_SIZE, 0.0))
	position.y = clampf(position.y, 0.0, maxf(viewport_size.y - BUTTON_SIZE, 0.0))


func _load_position() -> void:
	var config: ConfigFile = GameConfig.config
	var saved: String = config.get_value(CONFIG_SECTION, CONFIG_KEY, "")
	if saved.is_empty():
		position = _default_position()
		return
	var saved_value: Variant = str_to_var(saved)
	if saved_value is Vector2:
		var ratio: Vector2 = saved_value
		position = ratio * get_viewport_rect().size
	else:
		position = _default_position()
	_clamp_to_viewport()


func _save_position() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	GameConfig.config.set_value(CONFIG_SECTION, CONFIG_KEY, var_to_str(position / viewport_size))
	GameConfig.save()


func _on_viewport_resized() -> void:
	if _pressing:
		return
	_load_position()
