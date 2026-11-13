extends Node

## 输入设备监测（autoload 名：InputDevice）。
##
## 回答两个问题：
##   1. 现在插着手柄吗？（`has_gamepad`）
##   2. 用户最后一次操作来自哪类设备？（`last_device`）
##
## 为什么需要第 2 个：
## `Input.get_connected_joypads()` 只能回答"插没插"，回答不了"用户在不在用"。
## PC 玩家插着手柄但一直点鼠标时，如果因为"有手柄"就放开 UI 焦点，
## 方向键会在菜单里乱跳，反而更糟。
##
## 摇杆漂移：很多手柄空闲时持续输出 InputEventJoypadMotion（axis_value 不为 0）。
## 如果照单全收，设备判定会被反复抢成 gamepad。所以这里对摇杆加了幅度阈值。

## 手柄插拔 / 主导设备变化时发出
signal gamepad_presence_changed(present: bool)
signal last_device_changed(device: StringName)

const DEVICE_KEYBOARD: StringName = &"keyboard"
const DEVICE_MOUSE: StringName = &"mouse"
const DEVICE_GAMEPAD: StringName = &"gamepad"

## 摇杆需要超过这个幅度才算"手柄活动"（对抗漂移）
const JOY_AXIS_THRESHOLD: float = 0.35
## 手柄需要持续活动这么久才抢占主导权（毫秒），防止误触
const GAMEPAD_CLAIM_DELAY_MS: int = 150
## 鼠标相对位移小于这个值视为"没动"（避免鼠标轻微抖动抢回）
const MOUSE_MOVE_THRESHOLD: float = 2.0

var last_device: StringName = DEVICE_KEYBOARD

var _has_gamepad: bool = false
## 手柄首次活动的时间戳；为 0 表示当前没有待确认的手柄活动
var _gamepad_claim_since: int = 0
var _hooked: bool = false


func _ready() -> void:
	# 暂停时也要能响应（暂停菜单里同样要用方向键）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_refresh_gamepad_presence()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_hooked = true


func _exit_tree() -> void:
	if _hooked and Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
		_hooked = false


# ---------------------------------------------------------------------------
# 查询
# ---------------------------------------------------------------------------

## 当前是否有手柄连接（不判断是否在用）。
func has_gamepad() -> bool:
	return _has_gamepad


## 当前主导设备是否为手柄（结合"插着"和"在用"）。
func is_gamepad_active() -> bool:
	return _has_gamepad and last_device == DEVICE_GAMEPAD


## 当前主导设备是否键盘。
func is_keyboard_active() -> bool:
	return last_device == DEVICE_KEYBOARD


## 当前主导设备是否鼠标（鼠标主导时不抢 UI 焦点，保留 hover 体验）。
func is_mouse_active() -> bool:
	return last_device == DEVICE_MOUSE


# ---------------------------------------------------------------------------
# 内部
# ---------------------------------------------------------------------------

func _refresh_gamepad_presence() -> void:
	var present: bool = not Input.get_connected_joypads().is_empty()
	if present == _has_gamepad:
		return
	_has_gamepad = present
	# 手柄拔掉时立即回到键盘，不能停在 gamepad 状态
	if not present:
		_gamepad_claim_since = 0
		_set_last_device(DEVICE_KEYBOARD)
	gamepad_presence_changed.emit(_has_gamepad)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_gamepad_presence()


func _set_last_device(device: StringName) -> void:
	if device == last_device:
		return
	last_device = device
	last_device_changed.emit(device)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var button_event: InputEventJoypadButton = event
		if button_event.pressed:
			_claim_gamepad()
	elif event is InputEventJoypadMotion:
		var motion_event: InputEventJoypadMotion = event
		if absf(motion_event.axis_value) >= JOY_AXIS_THRESHOLD:
			_claim_gamepad()
	elif event is InputEventKey:
		var key_event: InputEventKey = event
		# 按键抬起不算活动，按住不放的重复事件也不算
		if key_event.pressed and not key_event.echo:
			_claim_keyboard()
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed:
			_claim_mouse()
	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if motion_event.relative.length() >= MOUSE_MOVE_THRESHOLD:
			_claim_mouse()


func _claim_gamepad() -> void:
	if not _has_gamepad:
		return
	if last_device == DEVICE_GAMEPAD:
		return
	# 延迟确认：必须持续活动一小段时间才抢占，防止单次误触
	var now: int = Time.get_ticks_msec()
	if _gamepad_claim_since == 0:
		_gamepad_claim_since = now
		return
	if now - _gamepad_claim_since >= GAMEPAD_CLAIM_DELAY_MS:
		_gamepad_claim_since = 0
		_set_last_device(DEVICE_GAMEPAD)


func _claim_keyboard() -> void:
	_claim_pointer_device(DEVICE_KEYBOARD)


func _claim_mouse() -> void:
	_claim_pointer_device(DEVICE_MOUSE)


## 键鼠切回来是即时的（手柄抢过去才需要延迟确认）。
func _claim_pointer_device(device: StringName) -> void:
	_gamepad_claim_since = 0
	if last_device == device:
		return
	_set_last_device(device)
