extends CanvasLayer

class_name MobileControl

const LEFT = preload("res://sprite/on_screen_controls/Left.png")
const LEFT_HELD = preload("res://sprite/on_screen_controls/LeftHeld.png")
const RIGHT = preload("res://sprite/on_screen_controls/Right.png")
const RIGHT_HELD = preload("res://sprite/on_screen_controls/RightHeld.png")
const UP = preload("res://sprite/on_screen_controls/Up.png")
const UP_HELD = preload("res://sprite/on_screen_controls/UpHeld.png")
const DOWN = preload("res://sprite/on_screen_controls/Down.png")
const DOWN_HELD = preload("res://sprite/on_screen_controls/DownHeld.png")

const A = preload("res://sprite/on_screen_controls/A.png")
const A_HELD = preload("res://sprite/on_screen_controls/AHeld.png")
const B = preload("res://sprite/on_screen_controls/B.png")
const B_HELD = preload("res://sprite/on_screen_controls/BHeld.png")

const START = preload("res://sprite/on_screen_controls/Start.png")
const START_HELD = preload("res://sprite/on_screen_controls/StartHeld.png")
const SELECT = preload("res://sprite/on_screen_controls/Select.png")
const SELECT_HELD = preload("res://sprite/on_screen_controls/SelectHeld.png")
const RUN_LOCK = preload("res://sprite/on_screen_controls/RunLock.png")
const RUN_LOCK_ON = preload("res://sprite/on_screen_controls/RunLockOn.png")

# array of known fake controller name prefixes
# contains uinput, to catch: uinput-goodix, uinput-silead, uinput_nav, ...
const BLACKLIST := ["uinput"]

enum ShowModeType {
	HIDE,
	SHOW,
	DPADS,
}
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

@export var control_d_pad : Control
@export var control_button : Control

@export var left : Sprite2D
@export var right : Sprite2D
@export var up : Sprite2D
@export var down : Sprite2D

@export var a : Sprite2D
@export var b : Sprite2D

@export var start : Sprite2D
@export var select : Sprite2D
@export var run_lock : Sprite2D

var run_lock_on := false
var vibration_thread: Thread
var should_show: bool

# debug cooldown of 5 seconds at 60 fps, 2,5 seconds at 120 fps
var counter := 300

func _ready() -> void:
	#should_show = true
	should_show = !PlatformUtils.is_desktop_platform()

func _process(_delta : float) -> void:
	var connected := detect_real_joysticks()
	#if false:
	if connected.size() > 0 || !should_show:
		hide()
		# this whole 5s interval debugging should prolly be removed eventually, if there are no further reports of missing touch controls coming in. 
		if false:
		#if counter == 300:
			print("connected: ", connected)
			print("connected/size(): ", connected.size())
			print("connected/should_show: ", should_show)
	else:
		show()
	counter = counter - 1 if counter > 0 else 300

func vibrate_asynchronously() -> void:
	if vibration_thread != null:
		if vibration_thread.is_alive():
			return
		vibration_thread.wait_to_finish()
	vibration_thread = Thread.new()
	vibration_thread.start(vibrate)

func vibrate() -> void:
	Input.vibrate_handheld(3, 0.5)

func virtual_key(button_index : JoyButton, pressed : bool) -> void:
	var inputEvent := InputEventJoypadButton.new()
	inputEvent.button_index = button_index
	inputEvent.pressed = pressed
	Input.parse_input_event(inputEvent)

func virtual_key_press(button_index : JoyButton) -> void:
	virtual_key(button_index, true)

func virtual_key_release(button_index : JoyButton) -> void:
	virtual_key(button_index, false)

func on_west_pressed() -> void:
	left.texture = LEFT_HELD
	vibrate_asynchronously()
	virtual_key_press(JOY_BUTTON_DPAD_LEFT)

func on_west_released() -> void:
	left.texture = LEFT
	virtual_key_release(JOY_BUTTON_DPAD_LEFT)

func on_east_pressed() -> void:
	right.texture = RIGHT_HELD
	vibrate_asynchronously()
	virtual_key_press(JOY_BUTTON_DPAD_RIGHT)

func on_east_released() -> void:
	right.texture = RIGHT
	virtual_key_release(JOY_BUTTON_DPAD_RIGHT)

func on_north_pressed() -> void:
	up.texture = UP_HELD
	vibrate_asynchronously()
	virtual_key_press(JOY_BUTTON_DPAD_UP)

func on_north_released() -> void:
	up.texture = UP
	virtual_key_release(JOY_BUTTON_DPAD_UP)

func on_south_pressed() -> void:
	down.texture = DOWN_HELD
	vibrate_asynchronously()
	virtual_key_press(JOY_BUTTON_DPAD_DOWN)

func on_south_released() -> void:
	down.texture = DOWN
	virtual_key_release(JOY_BUTTON_DPAD_DOWN)

func on_b_pressed() -> void:
	b.texture = B_HELD
	vibrate_asynchronously()
	virtual_key_press(JOY_BUTTON_B)

func on_b_released() -> void:
	b.texture = B
	virtual_key_release(JOY_BUTTON_B)

func on_a_pressed() -> void:
	a.texture = A_HELD
	vibrate_asynchronously()
	virtual_key_press(JOY_BUTTON_A)

func on_a_released() -> void:
	a.texture = A
	virtual_key_release(JOY_BUTTON_A)

func on_run_lock_pressed() -> void:
	if run_lock_on:
		run_lock.texture = RUN_LOCK
		Input.action_release("run_0")
	else:
		run_lock.texture = RUN_LOCK_ON
		Input.action_press("run_0")
	vibrate_asynchronously()
	run_lock_on = !run_lock_on

func on_start_pressed() -> void:
	start.texture = START_HELD
	vibrate_asynchronously()

func on_start_released() -> void:
	start.texture = START

func on_select_pressed() -> void:
	select.texture = SELECT_HELD
	vibrate_asynchronously()

func on_select_released() -> void:
	select.texture = SELECT

func detect_real_joysticks() -> Array:
	var realJoysticks: Array
	
	if !Input.get_connected_joypads().size(): return []

	for i in Input.get_connected_joypads():
		var joy_name = Input.get_joy_name(i)
		var is_fake := false
		for j in BLACKLIST:
			if joy_name.begins_with(j):
				is_fake = true
		if is_fake:
			if counter == 300: print(joy_name, " detected!")
		else:
			realJoysticks.append(i)
			if counter == 300: print(joy_name, " is valid!")
	return realJoysticks if (realJoysticks.size() > 0) else []

func _exit_tree():
	if vibration_thread != null and vibration_thread.is_alive():
		vibration_thread.wait_to_finish()
