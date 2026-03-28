extends CanvasLayer

class_name MobileControl

# ──────────────────────────────────────────────
# 纹理配置：普通态 / 按下态，全部在编辑器里赋值
# ──────────────────────────────────────────────
@export_group("D-Pad Textures")
@export var tex_left        : Texture2D
@export var tex_left_held   : Texture2D
@export var tex_right       : Texture2D
@export var tex_right_held  : Texture2D
@export var tex_up          : Texture2D
@export var tex_up_held     : Texture2D
@export var tex_down        : Texture2D
@export var tex_down_held   : Texture2D

@export_group("Action Button Textures")
@export var tex_a           : Texture2D
@export var tex_a_held      : Texture2D
@export var tex_b           : Texture2D
@export var tex_b_held      : Texture2D

@export_group("Menu Button Textures")
@export var tex_start       : Texture2D
@export var tex_start_held  : Texture2D
@export var tex_select      : Texture2D
@export var tex_select_held : Texture2D
@export var tex_run_lock    : Texture2D
@export var tex_run_lock_on : Texture2D

# ──────────────────────────────────────────────
# 控件引用
# ──────────────────────────────────────────────
@export_group("Controls")
@export var control_d_pad  : Control
@export var control_button : Control

@export_group("D-Pad Sprites")
@export var left  : Sprite2D
@export var right : Sprite2D
@export var up    : Sprite2D
@export var down  : Sprite2D

@export_group("Action Button Sprites")
@export var a : Sprite2D
@export var b : Sprite2D

@export_group("Menu Button Sprites")
@export var start    : Sprite2D
@export var select   : Sprite2D
@export var run_lock : Sprite2D

# ──────────────────────────────────────────────
# 显示模式
# ──────────────────────────────────────────────
enum ShowModeType { HIDE, SHOW, DPADS }

@export var show_mode := ShowModeType.SHOW:
	set(value):
		show_mode = value
		match value:
			ShowModeType.HIDE:
				control_d_pad.visible = false
				control_button.visible = false
			ShowModeType.SHOW:
				control_d_pad.visible = true
				control_button.visible = true
			ShowModeType.DPADS:
				control_d_pad.visible = true
				control_button.visible = false

# ──────────────────────────────────────────────
# 黑名单：已知的假手柄前缀
# ──────────────────────────────────────────────
const BLACKLIST := ["uinput"]

# ──────────────────────────────────────────────
# 内部状态
# ──────────────────────────────────────────────
var run_lock_on       := false
var vibration_thread  : Thread
var should_show       : bool
var counter           := 300  # 约 5 秒（60 fps）

# ──────────────────────────────────────────────
# 按钮配置表
# 结构：{ sprite, tex_normal, tex_held, joy_button }
# joy_button 为 -1 表示该按键有自定义逻辑，不走通用路径
# ──────────────────────────────────────────────
var _button_config : Dictionary

func _ready() -> void:
	should_show = !PlatformUtils.is_desktop_platform()
	_build_button_config()

func _build_button_config() -> void:
	_button_config = {
		"west":   { "sprite": left,     "normal": tex_left,        "held": tex_left_held,    "joy": JOY_BUTTON_DPAD_LEFT  },
		"east":   { "sprite": right,    "normal": tex_right,       "held": tex_right_held,   "joy": JOY_BUTTON_DPAD_RIGHT },
		"north":  { "sprite": up,       "normal": tex_up,          "held": tex_up_held,      "joy": JOY_BUTTON_DPAD_UP    },
		"south":  { "sprite": down,     "normal": tex_down,        "held": tex_down_held,    "joy": JOY_BUTTON_DPAD_DOWN  },
		"a":      { "sprite": a,        "normal": tex_a,           "held": tex_a_held,       "joy": JOY_BUTTON_A          },
		"b":      { "sprite": b,        "normal": tex_b,           "held": tex_b_held,       "joy": JOY_BUTTON_B          },
		"start":  { "sprite": start,    "normal": tex_start,       "held": tex_start_held,   "joy": -1 },
		"select": { "sprite": select,   "normal": tex_select,      "held": tex_select_held,  "joy": -1 },
	}

# ──────────────────────────────────────────────
# 通用按键处理（由场景中各按钮信号连接）
# ──────────────────────────────────────────────
func _on_button_pressed(key: String) -> void:
	var cfg : Dictionary = _button_config.get(key, {})
	if cfg.is_empty():
		return
	cfg["sprite"].texture = cfg["held"]
	vibrate_asynchronously()
	if cfg["joy"] >= 0:
		_virtual_key_press(cfg["joy"])

func _on_button_released(key: String) -> void:
	var cfg : Dictionary = _button_config.get(key, {})
	if cfg.is_empty():
		return
	cfg["sprite"].texture = cfg["normal"]
	if cfg["joy"] >= 0:
		_virtual_key_release(cfg["joy"])

# ──────────────────────────────────────────────
# run_lock 保留独立逻辑（toggle 行为与其他键不同）
# ──────────────────────────────────────────────
func on_run_lock_pressed() -> void:
	run_lock_on = !run_lock_on
	run_lock.texture = tex_run_lock_on if run_lock_on else tex_run_lock
	if run_lock_on:
		Input.action_press("run_0")
	else:
		Input.action_release("run_0")
	vibrate_asynchronously()

# ──────────────────────────────────────────────
# 供场景按钮信号直接调用的具名包装
# （如果你的场景信号已经连好这些函数名，保持不变即可）
# ──────────────────────────────────────────────
func on_west_pressed()   -> void: _on_button_pressed("west")
func on_west_released()  -> void: _on_button_released("west")
func on_east_pressed()   -> void: _on_button_pressed("east")
func on_east_released()  -> void: _on_button_released("east")
func on_north_pressed()  -> void: _on_button_pressed("north")
func on_north_released() -> void: _on_button_released("north")
func on_south_pressed()  -> void: _on_button_pressed("south")
func on_south_released() -> void: _on_button_released("south")
func on_a_pressed()      -> void: _on_button_pressed("a")
func on_a_released()     -> void: _on_button_released("a")
func on_b_pressed()      -> void: _on_button_pressed("b")
func on_b_released()     -> void: _on_button_released("b")
func on_start_pressed()  -> void: _on_button_pressed("start")
func on_start_released() -> void: _on_button_released("start")
func on_select_pressed() -> void: _on_button_pressed("select")
func on_select_released()-> void: _on_button_released("select")

# ──────────────────────────────────────────────
# 帧更新：检测真实手柄
# ──────────────────────────────────────────────
func _process(_delta: float) -> void:
	var connected := _detect_real_joysticks()
	if connected.size() > 0 || !should_show:
		hide()
	else:
		show()
	counter = counter - 1 if counter > 0 else 300

# ──────────────────────────────────────────────
# 振动（异步，避免阻塞主线程）
# ──────────────────────────────────────────────
func vibrate_asynchronously() -> void:
	if vibration_thread != null:
		if vibration_thread.is_alive():
			return
		vibration_thread.wait_to_finish()
	vibration_thread = Thread.new()
	vibration_thread.start(_vibrate)

func _vibrate() -> void:
	Input.vibrate_handheld(3, 0.5)

# ──────────────────────────────────────────────
# 虚拟手柄按键注入
# ──────────────────────────────────────────────
func _virtual_key(button_index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)

func _virtual_key_press(button_index: JoyButton)   -> void: _virtual_key(button_index, true)
func _virtual_key_release(button_index: JoyButton) -> void: _virtual_key(button_index, false)

# ──────────────────────────────────────────────
# 检测真实（非黑名单）手柄
# ──────────────────────────────────────────────
func _detect_real_joysticks() -> Array:
	if Input.get_connected_joypads().is_empty():
		return []

	var real_joysticks: Array = []
	for i in Input.get_connected_joypads():
		var joy_name := Input.get_joy_name(i)
		var is_fake  := BLACKLIST.any(func(prefix): return joy_name.begins_with(prefix))

		if is_fake:
			if counter == 300:
				print(joy_name, " detected!")
		else:
			real_joysticks.append(i)
			if counter == 300:
				print(joy_name, " is valid!")

	return real_joysticks

func _exit_tree() -> void:
	if vibration_thread != null and vibration_thread.is_alive():
		vibration_thread.wait_to_finish()