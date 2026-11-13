extends Node

## 键盘 / 手柄 UI 操作（autoload 名：UiNavigator）。
##
## 方向控制分三组，定义与输入判定全部封装在 `script/utils/input_groups.gd`：
## - **POINTER 组**：IJKL / 左摇杆 → 移动虚拟鼠标
## - **FOCUS 组**：方向键 / 十字键（D-pad）→ 操作 UI 焦点
## - **CAMERA 组**：WASD / 右摇杆 → 移动镜头（编辑室）
##
## 唯一的场景限制：PLAY / HISTORY_PLAY / TEST / ADVENTURE 里方向键与十字键归角色移动，
## UI 只能用虚拟鼠标；CAMERA 组任何时候都不参与 UI。
##
## 操作：
## - 归 UI 的那一组方向：FOCUS 在一个个控件间跳转（长按重复、列表自动滚动），
##   POINTER 平滑平移真实鼠标（指哪点哪、可点空白处）。
## - Enter / 手柄 A：在"当前点击点"合成鼠标左键，**按住保持按下、松开才抬起**（可拖拽）。
## - Esc / 手柄 B：合成右键单击；焦点在 ScrollContainer 内时改为跳出容器。
##
## 点击点：FOCUS 取选中控件的矩形中心，POINTER 取虚拟鼠标位置，都走 `viewport.push_input`。
## 四角光标：FOCUS 框选中项，POINTER 框鼠标下的控件（空白处只剩系统指针）。
##
## 设备门控：移动端 / 鼠标主导不启用；游戏内默认不启用，除非有可见的 `ui_focus_modal`。

const META_SKIP: StringName = &"ui_focus_skip"
const META_TARGET: StringName = &"ui_focus_target"
const META_MODAL: StringName = &"ui_focus_modal"
## 指定"焦点框按哪个节点的矩形画"（NodePath，相对候选自身）。
## 用于按钮的实际热区比视觉本体大很多的情况（如标题页水管：Button 为了盖住 hover
## 上浮的道具，向上多出 130px，直接框它会把红框顶到管子上面去）。
const META_FOCUS_RECT: StringName = &"ui_focus_rect"

const CURSOR_SCENE_PATH: String = "res://ui/menu_cursor.tscn"
## UI 焦点移动音效（SMM2「通用-选择翻页」）
const MOVE_SOUND_PATH: String = "res://sound/ui/ui_move.wav"
## 按钮按下音效（SMM2「通用-大确定」），给没自己配 pressed_sound 的按钮兜底
const PRESS_SOUND_PATH: String = "res://sound/ui/ui_press.wav"
## 兜底重扫间隔（秒）。可交互控件的显隐变化不发信号，只能靠这个兜住。
const SCAN_INTERVAL: float = 0.3
## 游戏内探测"有没有模态 UI 出现"的间隔。
const MODAL_PROBE_INTERVAL: float = 0.4
## 虚拟鼠标移动速度（逻辑像素 / 秒）。摇杆幅度会等比缩放。
const MOUSE_SPEED: float = 900.0
## 方向查找时"横向偏移"惩罚的阈值（像素）
const AXIS_TOLERANCE: float = 96.0
## 长按方向键后，开始自动重复前的延迟（秒）
const REPEAT_DELAY: float = 0.4
## 自动重复的间隔（秒）
const REPEAT_INTERVAL: float = 0.12
## 四角光标所在 CanvasLayer，必须高于所有 UI 面板：
## 消息面板 message_overlay 是 110、全局通知 Notice 是 128，
## 光标作为"手在哪"的指示不能被它们盖住，所以取 200。
const CURSOR_LAYER: int = 200

const ACTION_ACCEPT: StringName = &"ui_menu_accept"
const ACTION_CANCEL: StringName = &"ui_menu_cancel"

## 方向控制分组见 script/utils/input_groups.gd（POINTER = WASD/左摇杆，FOCUS = 方向键/十字键）

enum InputMode {
	FOCUS,
	POINTER,
}

var _cursor_scene: PackedScene = null
## 当前可交互控件（两种模式共用这一份）
var _candidates: Array[Control] = []
var _dirty: bool = true
var _since_scan: float = 0.0

var _cursor_layer: CanvasLayer = null
var _cursor: UiMenuCursor = null
## 焦点移动音效播放器（单实例，每次移动重头播）
var _move_player: AudioStreamPlayer = null
## 按下音效兜底播放器：只服务没自己配 pressed_sound 的按钮
var _press_player: AudioStreamPlayer = null

## 当前模式
var _mode: InputMode = InputMode.FOCUS
## FOCUS：当前选中的候选下标
var _focus_index: int = 0
## FOCUS：选中项的 instance_id，重扫后用来找回同一项
var _selected_id: int = 0
## FOCUS：当前选中是否由玩家主动选出来的（方向键）。
## 系统兜底出来的选中一旦遇到新界面就让位，避免停在过渡期间的临时项上。
var _user_selected: bool = false
## 上一轮候选的 instance_id 集合，用来判断"这一轮新出现了谁"
var _known_ids: Dictionary[int, bool] = {}
## POINTER：虚拟鼠标位置（视口逻辑坐标）
var _virtual_mouse: Vector2 = Vector2.ZERO
var _mouse_ready: bool = false

## 长按方向键的自动重复
var _repeat_armed: bool = false
var _held_direction: Vector2 = Vector2.ZERO
var _repeat_timer: float = 0.0

## 左键当前是否按下（按住保持，用于拖拽）
var _left_down: bool = false

var _modal_visible: bool = false
var _modal_probe: float = 0.0
## 按键时按需刷新模态的上次时间戳（节流用）
var _modal_refresh_ms: int = 0
## 上一轮扫描得到的模态节点，命中测试时用来过滤
var _current_modal: Control = null
## 有节点被移出树：候选数组里可能留下已释放的引用，下次处理输入前先清理
var _needs_prune: bool = false

signal activated(control: Control)
signal cancelled()


func _ready() -> void:
	# 暂停时也要能操作（暂停菜单本身要能点）
	process_mode = Node.PROCESS_MODE_ALWAYS
	var res: Resource = load(CURSOR_SCENE_PATH)
	if res is PackedScene:
		_cursor_scene = res as PackedScene
	get_tree().node_added.connect(_on_tree_changed)
	get_tree().node_removed.connect(_on_tree_changed)
	UiFocusPolicy.policy_changed.connect(_on_tree_changed)
	_setup_move_sound()
	_setup_press_sound()


## 焦点移动音效：一个常驻播放器，每次移动 play() 重头播。
## 用 PROCESS_MODE_ALWAYS，因为多数移动发生在暂停状态下的菜单里。
func _setup_move_sound() -> void:
	_move_player = _make_player("UiMoveSound", MOVE_SOUND_PATH)


## 按下音效兜底：按钮自己没配 pressed_sound 时由这里出声。
## 播放器挂在 autoload 上，切场景不会跟着按钮一起销毁。
func _setup_press_sound() -> void:
	_press_player = _make_player("UiPressSound", PRESS_SOUND_PATH)


func _make_player(node_name: String, stream_path: String) -> AudioStreamPlayer:
	var stream_res: Resource = load(stream_path)
	if not (stream_res is AudioStream):
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream_res as AudioStream
	player.bus = &"UI"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## 新节点入树时挂上按下音效兜底。用 node_added 而不是等 _rescan，
## 是因为扫描只在导航启用时跑，游戏内（暂停菜单等）会漏掉。
func _hook_button_sound(node: Node) -> void:
	if not (node is BaseButton):
		return
	var button: BaseButton = node
	if button.pressed.is_connected(_on_button_pressed):
		return
	button.pressed.connect(_on_button_pressed.bind(button))


## 按钮被按下：自己带了 pressed_sound 的（UiSoundButton）已经播过，这里跳过；
## 其余（裸 Button / TextureButton / 没配音效的 UiSoundButton）用统一音效兜底。
func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	if button is UiSoundButton:
		var sound_button: UiSoundButton = button
		if sound_button.pressed_sound != null:
			return
	if _press_player != null and _press_player.stream != null:
		_press_player.play()


## 焦点切到某个控件时出声：控件自己配了 focus_sound 就用它的，
## 没配（或不是 UiSoundButton）才退回全局默认的移动音效。
func _play_focus_sound(control: Control) -> void:
	if control.has_method("play_focus_sound"):
		var result: Variant = control.call("play_focus_sound")
		if result is bool:
			var played: bool = result
			if played:
				return
	_play_move_sound()


func _play_move_sound() -> void:
	if _move_player != null and _move_player.stream != null:
		_move_player.play()


func _on_tree_changed(node: Node) -> void:
	_dirty = true
	_needs_prune = true
	_hook_button_sound(node)


## 把已经 free 掉的控件从候选里剔除。
##
## 为什么必须有：节点被 queue_free 后，`node_removed` 那一刻对象还有效（prune 不掉），
## 真正释放发生在帧末；下一帧 `_input` / `_unhandled_input` 早于 `_process` 的定时重扫，
## 直接读 `Array[Control]` 里那一格会触发
## "The Object-derived class of argument 1 (previously freed) is not a subclass of ..."。
## 遍历时用 Variant 中转，避免类型化数组读取时就被类型检查拦下。
func _prune_if_needed() -> void:
	if not _needs_prune:
		return
	_needs_prune = false
	var alive: Array[Control] = []
	for i: int in range(_candidates.size()):
		var raw: Variant = _candidates[i]
		if not is_instance_valid(raw) or not (raw is Control):
			continue
		var control: Control = raw
		if is_instance_valid(control):
			alive.append(control)
	if alive.size() != _candidates.size():
		_candidates = alive
		_dirty = true


func _on_policy_changed() -> void:
	_dirty = true


func _process(delta: float) -> void:
	_modal_probe += delta
	if _modal_probe >= MODAL_PROBE_INTERVAL:
		_modal_probe = 0.0
		_update_modal_visible()

	if not _navigation_enabled():
		_release_left_button()
		_hide_cursor()
		_repeat_armed = false
		_dirty = true
		return
	_prune_if_needed()

	# 游戏内 FOCUS 组归角色，UI 只能用虚拟鼠标；带着 FOCUS 模式进来时强制掰回来。
	# 但模态 UI（暂停菜单 / 通知）盖在游戏上时不能掰——否则暂停菜单里方向键
	# 刚切到 FOCUS 就被下一帧改回 POINTER。
	if not _modal_visible and _is_character_control_mode():
		if _mode != InputMode.POINTER:
			_mode = InputMode.POINTER

	_since_scan += delta
	if _dirty or _since_scan >= SCAN_INTERVAL:
		_dirty = false
		_since_scan = 0.0
		_rescan()

	if _mode == InputMode.POINTER:
		_tick_virtual_mouse(delta)
	else:
		# 选中项一旦变成不可用（被 set_input_locked / 页面退出隐藏），立刻重扫，
		# 不等 0.3s 的兜底间隔——否则点开新面板后焦点会在旧位置停一拍。
		if not _focus_still_valid():
			_dirty = true
		_tick_repeat(delta)
	_tick_left_button()
	_sync_cursor()


# ---------------------------------------------------------------------------
# 设备门控
# ---------------------------------------------------------------------------

func _navigation_enabled() -> bool:
	if UiFocusPolicy.is_mobile_platform():
		return false
	if not (InputDevice.is_gamepad_active()
			or InputDevice.last_device == InputDevice.DEVICE_KEYBOARD):
		return false
	if _modal_visible:
		return true
	if _is_gameplay_mode():
		return false
	return true


## 重新探测屏幕上有没有可见的模态 UI。
##
## 模态开关会改变候选范围（有模态时只留它的后代），所以状态一变必须立刻重扫：
## 否则暂停菜单刚打开时方向键还在旧的 HUD 候选里跳，表现为"按了没反应"。
func _update_modal_visible() -> void:
	var previous: bool = _modal_visible
	_modal_visible = (_is_gameplay_mode() or GameMode.is_history_play()) and _any_visible_modal()
	_modal_probe = 0.0
	if _modal_visible != previous:
		_dirty = true


func _is_gameplay_mode() -> bool:
	return GameMode.is_playing() or GameMode.is_adventure() or GameMode.is_testing()


func _any_visible_modal() -> bool:
	var stack: Array[Node] = []
	stack.append(get_tree().root)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
			continue
		if node is Control and _meta_true(node, META_MODAL):
			return true
		for child: Node in node.get_children():
			stack.append(child)
	return false


# ---------------------------------------------------------------------------
# 输入来源分类（决定切到哪套操作）
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# 游戏内暂停菜单刚打开时，0.3s 的定时探测还没跑；按键瞬间补一次，
	# 否则第一下方向键会被判给角色、看起来像"暂停后 UI 操作不了"。
	if not _modal_visible and (_is_gameplay_mode() or GameMode.is_history_play()) \
			and (event is InputEventKey or event is InputEventJoypadButton
				or event is InputEventJoypadMotion or event is InputEventAction):
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - _modal_refresh_ms >= 100:
			_modal_refresh_ms = now_ms
			_update_modal_visible()
	if not _navigation_enabled():
		return
	_prune_if_needed()
	# 输入框打字时不抢模式（WASD 是打字，不是移动鼠标）
	if _text_focus_owner() != null:
		return
	var group: InputGroups.Group = InputGroups.classify(event)
	if group == InputGroups.Group.NONE:
		return
	if not _group_allowed(group):
		return
	if group == InputGroups.Group.FOCUS:
		_switch_to_focus()
	else:
		_switch_to_pointer()


## 这一组方向控制在当前场景是否归 UI 管。
##
## 唯一的场景限制：游戏内（PLAY / HISTORY_PLAY / TEST / ADVENTURE）方向键与十字键
## 归角色移动，UI 只能用虚拟鼠标。CAMERA 组任何时候都只归镜头。
func _group_allowed(group: InputGroups.Group) -> bool:
	if group == InputGroups.Group.FOCUS:
		# 模态 UI（暂停菜单 / 通知）盖在游戏上时，方向键与十字键优先给 UI，
		# 哪怕场上有玩家在跑。
		if _modal_visible:
			return true
		return not _is_character_control_mode()
	if group == InputGroups.Group.POINTER:
		return true
	return false


## 由方向键 / 十字键操作角色的模式。
func _is_character_control_mode() -> bool:
	return GameMode.is_playing() or GameMode.is_history_play() \
		or GameMode.is_testing() or GameMode.is_adventure()


func _switch_to_focus() -> void:
	if _mode == InputMode.FOCUS:
		return
	_mode = InputMode.FOCUS
	# 从鼠标位置接管：如果鼠标正好压着某个控件，就选它
	var hovered: Control = _hover_target()
	var index: int = _index_of(hovered)
	if index >= 0:
		_focus_index = index
		_user_selected = true
		_selected_id = int(_candidates[index].get_instance_id())


func _switch_to_pointer() -> void:
	if _mode == InputMode.POINTER:
		return
	_mode = InputMode.POINTER
	_ensure_mouse()
	# 从焦点接管：把鼠标直接放到选中项上，避免光标突然跳到屏幕中间
	var candidate: Control = _focus_candidate()
	if candidate != null:
		_virtual_mouse = _canvas_rect_of(candidate).get_center()
		_clamp_mouse()
		_warp_real_mouse()


# ---------------------------------------------------------------------------
# 输入处理
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# 文本输入状态优先：方向键 / 回车都归输入框自己，这里只负责"取消 = 退出输入"
	if _handle_text_input(event):
		return
	if not _navigation_enabled():
		return
	_prune_if_needed()

	if event.is_action_pressed(ACTION_CANCEL):
		# 焦点在滚动列表里时，取消键先"跳出列表"，而不是直接右键
		if _try_leave_scroll_container():
			get_viewport().set_input_as_handled()
			return
		_send_mouse_button(_click_point(), MOUSE_BUTTON_RIGHT, true)
		_send_mouse_button(_click_point(), MOUSE_BUTTON_RIGHT, false)
		cancelled.emit()
		get_viewport().set_input_as_handled()
		return

	if _mode != InputMode.FOCUS:
		return
	var direction: Vector2 = _direction_of(event)
	if direction == Vector2.ZERO:
		return
	_nudge_or_move(direction)
	_repeat_armed = true
	_held_direction = direction
	_repeat_timer = REPEAT_DELAY
	get_viewport().set_input_as_handled()


func _handle_text_input(event: InputEvent) -> bool:
	var focused: Control = _text_focus_owner()
	if focused == null:
		return false
	if event.is_action_pressed(ACTION_CANCEL):
		focused.release_focus()
		_dirty = true
		get_viewport().set_input_as_handled()
	return true


func _text_focus_owner() -> Control:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return null
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null and _is_text_input(focused):
		return focused
	return null


func _is_text_input(control: Control) -> bool:
	return control is LineEdit or control is TextEdit


## 事件对应的导航方向。系统的键盘自动重复（echo）丢掉，节奏统一由 _tick_repeat 控制。
func _direction_of(event: InputEvent) -> Vector2:
	if event.is_echo():
		return Vector2.ZERO
	if event.is_action_pressed("ui_focus_left"):
		return Vector2.LEFT
	if event.is_action_pressed("ui_focus_right"):
		return Vector2.RIGHT
	if event.is_action_pressed("ui_focus_up"):
		return Vector2.UP
	if event.is_action_pressed("ui_focus_down"):
		return Vector2.DOWN
	return Vector2.ZERO


## 长按方向键：延迟 REPEAT_DELAY 后每 REPEAT_INTERVAL 走一格。
func _tick_repeat(delta: float) -> void:
	if not _repeat_armed:
		return
	var held: Vector2 = _poll_direction()
	if held == Vector2.ZERO:
		_repeat_armed = false
		_held_direction = Vector2.ZERO
		return
	if held != _held_direction:
		_held_direction = held
		_repeat_timer = REPEAT_DELAY
		_nudge_or_move(held)
		return
	_repeat_timer -= delta
	if _repeat_timer > 0.0:
		return
	_repeat_timer = REPEAT_INTERVAL
	_nudge_or_move(held)


## 当前按住的主方向（FOCUS 组：方向键 / 十字键）。
func _poll_direction() -> Vector2:
	var axis: Vector2 = InputGroups.focus_axis()
	if axis.length_squared() < 0.04:
		return Vector2.ZERO
	if absf(axis.x) >= absf(axis.y):
		return Vector2(signf(axis.x), 0.0)
	return Vector2(0.0, signf(axis.y))


# ---------------------------------------------------------------------------
# FOCUS 模式：候选之间跳转
# ---------------------------------------------------------------------------

func _focus_candidate() -> Control:
	if _candidates.is_empty():
		return null
	if _focus_index < 0 or _focus_index >= _candidates.size():
		_focus_index = 0
	var raw: Variant = _candidates[_focus_index]
	if not is_instance_valid(raw) or not (raw is Control):
		_needs_prune = true
		return null
	var candidate: Control = raw
	if not is_instance_valid(candidate):
		_needs_prune = true
		return null
	return candidate


## 当前选中项是否仍然可用（没被禁用 / 没被隐藏 / 没离开候选集合）。
func _focus_still_valid() -> bool:
	if _candidates.is_empty():
		return true
	if _focus_index < 0 or _focus_index >= _candidates.size():
		return false
	var raw: Variant = _candidates[_focus_index]
	if not is_instance_valid(raw) or not (raw is Control):
		return false
	var control: Control = raw
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return false
	if control is BaseButton:
		var button: BaseButton = control as BaseButton
		if button.disabled:
			return false
		if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return false
	if control is Slider:
		var slider: Slider = control as Slider
		if not slider.editable:
			return false
	return true


func _index_of(control: Control) -> int:
	if control == null:
		return -1
	for i: int in range(_candidates.size()):
		var raw: Variant = _candidates[i]
		if not is_instance_valid(raw) or not (raw is Control):
			continue
		var candidate: Control = raw
		if is_instance_valid(candidate) and candidate == control:
			return i
	return -1


## 方向键的统一入口：选中的是滑块就调值，否则才是移动焦点。
func _nudge_or_move(direction: Vector2) -> void:
	var current: Control = _focus_candidate()
	if current is Slider:
		var slider_control: Slider = current
		if _nudge_slider(slider_control, direction):
			return
	_move(direction)


## 水平滑块用左右调值、垂直滑块用上下调值；另一根轴仍然交给焦点移动，
## 这样滑块不会把上下方向键也吃掉。返回 true 表示这次输入已被滑块消费。
func _nudge_slider(slider: Slider, direction: Vector2) -> bool:
	var span: float = slider.max_value - slider.min_value
	if span <= 0.0:
		return false
	# step 为 0（连续滑块）时按量程的 1% 走一步
	var step: float = slider.step if slider.step > 0.0 else span * 0.01
	if slider is HSlider:
		if absf(direction.x) < 0.5:
			return false
		var delta_x: float = signf(direction.x) * step
		slider.value = clampf(slider.value + delta_x, slider.min_value, slider.max_value)
		return true
	if slider is VSlider:
		if absf(direction.y) < 0.5:
			return false
		# 垂直滑块的 value 越大越靠上，所以"向上"是加
		var delta_y: float = -signf(direction.y) * step
		slider.value = clampf(slider.value + delta_y, slider.min_value, slider.max_value)
		return true
	return false


func _move(direction: Vector2) -> void:
	var current: Control = _focus_candidate()
	if current == null or _candidates.size() <= 1:
		return
	var from_rect: Rect2 = _canvas_rect_of(current)
	var from_center: Vector2 = from_rect.get_center()
	var best: int = -1
	var best_cost: float = INF
	for i: int in range(_candidates.size()):
		if i == _focus_index:
			continue
		var raw: Variant = _candidates[i]
		if not is_instance_valid(raw) or not (raw is Control):
			continue
		var other: Control = raw
		if not is_instance_valid(other) or other == current:
			continue
		var rect: Rect2 = _canvas_rect_of(other)
		var offset: Vector2 = rect.get_center() - from_center
		if offset.dot(direction) <= 0.0:
			continue
		var across: float = absf(offset.dot(Vector2(direction.y, direction.x)))
		var along: float = offset.dot(direction)
		var cost: float = along + across * (1.0 if across <= AXIS_TOLERANCE else 6.0)
		if cost < best_cost:
			best_cost = cost
			best = i
	if best < 0:
		var step: int = 1 if (direction.x > 0.0 or direction.y > 0.0) else -1
		best = posmod(_focus_index + step, _candidates.size())
	if best == _focus_index:
		return
	_focus_index = best
	# 玩家主动选的：重扫时不能被"新出现的候选"抢走
	_user_selected = true
	_selected_id = int(_candidates[best].get_instance_id())
	_ensure_visible(_candidates[best])
	_play_focus_sound(_candidates[best])


## 取消键的特殊语义：焦点困在滚动列表（ScrollContainer）里时，先跳到容器外的某个 UIControl。
##
## 用途：列表页按 Esc / 手柄 B 应该"退回上一层"，而不是在列表里右键。
## 选容器外**几何最近**的那个候选；一个有效的都找不到就返回 false，调用方退回原行为。
func _try_leave_scroll_container() -> bool:
	if _mode != InputMode.FOCUS:
		return false
	var current: Control = _focus_candidate()
	if current == null or not is_instance_valid(current):
		return false
	var scroll: ScrollContainer = _scroll_container_of(current)
	if scroll == null:
		return false
	var center: Vector2 = _canvas_rect_of(current).get_center()
	var best: int = -1
	var best_distance: float = INF
	for i: int in range(_candidates.size()):
		var raw: Variant = _candidates[i]
		if not is_instance_valid(raw) or not (raw is Control):
			continue
		var candidate: Control = raw
		if not is_instance_valid(candidate):
			continue
		if _scroll_container_of(candidate) == scroll:
			continue
		var distance: float = _canvas_rect_of(candidate).get_center().distance_to(center)
		if distance < best_distance:
			best_distance = distance
			best = i
	if best < 0:
		return false
	_focus_index = best
	_user_selected = true
	_selected_id = int(_candidates[best].get_instance_id())
	return true


## 控件所属的最近一层 ScrollContainer；不在滚动容器里返回 null。
func _scroll_container_of(control: Control) -> ScrollContainer:
	var node: Node = control.get_parent()
	while node != null and not (node is Viewport):
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null





## 选中项滚出 ScrollContainer 可视区时把它滚回来。
func _ensure_visible(control: Control) -> void:
	var node: Node = control.get_parent()
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node == null:
		return
	(node as ScrollContainer).ensure_control_visible(control)


# ---------------------------------------------------------------------------
# POINTER 模式：虚拟鼠标
# ---------------------------------------------------------------------------

## POINTER 组的方向向量：WASD + 左摇杆。
func _input_axis() -> Vector2:
	return InputGroups.pointer_axis()


func _mouse_point() -> Vector2:
	if _mouse_ready:
		return _virtual_mouse
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_mouse_position()


func _ensure_mouse() -> void:
	if _mouse_ready:
		return
	var viewport: Viewport = get_viewport()
	_virtual_mouse = viewport.get_mouse_position() if viewport != null else Vector2.ZERO
	_mouse_ready = true


func _tick_virtual_mouse(delta: float) -> void:
	var axis: Vector2 = _input_axis()
	if axis.length_squared() <= 0.0001:
		return
	_ensure_mouse()
	_virtual_mouse += axis * MOUSE_SPEED * delta
	_clamp_mouse()
	_warp_real_mouse()


func _clamp_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_virtual_mouse = _virtual_mouse.clamp(Vector2.ZERO, size - Vector2.ONE)


## 把真实鼠标挪到虚拟位置：hover 状态、get_mouse_position()、系统光标贴图都会跟着走。
func _warp_real_mouse() -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	# warp 会让系统产生鼠标移动事件，不抑制的话 InputDevice 会判定"用户在用鼠标"
	# 从而把导航自己关掉。
	InputDevice.suppress_mouse_activity()
	Input.warp_mouse(viewport.get_screen_transform() * _virtual_mouse)


# ---------------------------------------------------------------------------
# 点击
# ---------------------------------------------------------------------------

## 两模式共用的点击位置：FOCUS 取选中项中心，POINTER 取鼠标位置。
func _click_point() -> Vector2:
	if _mode == InputMode.FOCUS:
		var candidate: Control = _focus_candidate()
		if candidate != null:
			return _canvas_rect_of(candidate).get_center()
	return _mouse_point()


func _tick_left_button() -> void:
	var want_down: bool = Input.is_action_pressed(ACTION_ACCEPT)
	if want_down == _left_down:
		return
	_left_down = want_down
	if _mode == InputMode.POINTER:
		_ensure_mouse()
	_send_mouse_button(_click_point(), MOUSE_BUTTON_LEFT, want_down)


func _release_left_button() -> void:
	if not _left_down:
		return
	_left_down = false
	_send_mouse_button(_click_point(), MOUSE_BUTTON_LEFT, false)


func _send_mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	# 合成事件同样会经过场景的 _input，别让它把主导设备抢回鼠标
	InputDevice.suppress_mouse_activity()
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	event.global_position = point
	event.button_mask = _mask_of(button) if pressed else 0
	viewport.push_input(event)


func _mask_of(button: MouseButton) -> int:
	match button:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_MASK_RIGHT
		MOUSE_BUTTON_MIDDLE:
			return MOUSE_BUTTON_MASK_MIDDLE
	return 0


# ---------------------------------------------------------------------------
# 光标表现
# ---------------------------------------------------------------------------

func _sync_cursor() -> void:
	if _mode == InputMode.FOCUS:
		var candidate: Control = _focus_candidate()
		if candidate == null:
			_hide_cursor()
			return
		# 必须用非 instant：instant 会每帧把 _base_rect 直接赋成目标、并且重置呼吸相位，
		# 表现就是"位置瞬移 + 呼吸停住"。
		_show_cursor_at(_canvas_rect_of(candidate), false)
		return
	# POINTER：框住鼠标下的控件，空白处只剩系统指针
	var hovered: Control = _hover_target()
	if hovered == null:
		_hide_cursor()
		return
	_show_cursor_at(_canvas_rect_of(hovered), false)


func _show_cursor_at(rect: Rect2, instant: bool) -> void:
	_ensure_cursor_node()
	if _cursor == null:
		return
	_cursor.show_at(rect, instant)
	_cursor.set_highlight(_left_down)


func _hide_cursor() -> void:
	if _cursor != null and is_instance_valid(_cursor):
		_cursor.hide_cursor()
		_cursor.set_highlight(false)


func _ensure_cursor_node() -> void:
	if _cursor != null and is_instance_valid(_cursor):
		return
	if _cursor_scene == null:
		return
	if _cursor_layer == null or not is_instance_valid(_cursor_layer):
		_cursor_layer = CanvasLayer.new()
		_cursor_layer.name = "UiNavigatorCursorLayer"
		_cursor_layer.layer = CURSOR_LAYER
		# 暂停菜单里红框也要继续呼吸 / 跟手，不能跟着 tree.paused 停下
		_cursor_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child(_cursor_layer)
	var created: Node = _cursor_scene.instantiate()
	if not (created is UiMenuCursor):
		created.queue_free()
		return
	var cursor: UiMenuCursor = created as UiMenuCursor
	cursor.name = "UiNavigatorCursor"
	cursor.process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor_layer.add_child(cursor)
	_cursor = cursor


# ---------------------------------------------------------------------------
# 悬停判定
# ---------------------------------------------------------------------------

## 鼠标下面压着的可交互控件。
##
## 优先问引擎：`gui_get_hovered_control()` 是每帧本来就要算的悬停结果，O(1)；
## 自己遍历全部候选做矩形命中是 O(n)，列表页有上千个按钮时每帧都要遍历一遍，会掉帧。
func _hover_target() -> Control:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var hovered: Control = viewport.gui_get_hovered_control()
		if hovered != null:
			return _find_candidate_ancestor(hovered)
	return _pick_at(_mouse_point())


func _find_candidate_ancestor(control: Control) -> Control:
	var node: Node = control
	while node != null and not (node is Viewport):
		if node is Control:
			var candidate: Control = node as Control
			if _meta_true(candidate, META_SKIP):
				return null
			if _is_candidate(candidate, true):
				return candidate
		node = node.get_parent()
	return null


func _pick_at(point: Vector2) -> Control:
	var best: Control = null
	for i: int in range(_candidates.size()):
		var raw: Variant = _candidates[i]
		if not is_instance_valid(raw) or not (raw is Control):
			continue
		var control: Control = raw
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if _canvas_rect_of(control).has_point(point):
			best = control
	return best


# ---------------------------------------------------------------------------
# 候选收集
# ---------------------------------------------------------------------------

func refresh_now() -> void:
	_dirty = true


func _rescan() -> void:
	_current_modal = null
	var raw: Array[Control] = []
	for child: Node in get_tree().root.get_children():
		_collect_node(child, false, false, raw)
	var modal: Control = _current_modal
	if modal != null:
		var filtered: Array[Control] = []
		for control: Control in raw:
			if control == modal or modal.is_ancestor_of(control):
				filtered.append(control)
		raw = filtered
	var previous_ids: Dictionary[int, bool] = _known_ids
	_candidates = raw
	var current_ids: Dictionary[int, bool] = {}
	for control: Control in raw:
		current_ids[int(control.get_instance_id())] = true
	_known_ids = current_ids
	_resolve_focus(previous_ids)


## 决定焦点落在谁身上。
##
## 原来选中的控件如果还在候选里就保持（方向键导航不该被打断）；
## 一旦它失效（被禁用 / 随页面退出 / 移出模态范围），**优先跳到这一轮新出现的控件**——
## 标题页点开 Host/Join/设置时，水管被 set_input_locked 排除，焦点应当立刻落到新面板上，
## 而不是退回下标 0（那里往往是树序最靠前的广告/版本号按钮）。
func _resolve_focus(previous_ids: Dictionary[int, bool]) -> void:
	if _candidates.is_empty():
		_focus_index = 0
		_selected_id = 0
		return
	var found: int = -1
	if _selected_id != 0:
		for i: int in range(_candidates.size()):
			var raw: Variant = _candidates[i]
			if not is_instance_valid(raw) or not (raw is Control):
				continue
			var candidate: Control = raw
			if not is_instance_valid(candidate):
				continue
			if int(candidate.get_instance_id()) == _selected_id:
				found = i
				break
	# 玩家自己用方向键选的要保住；系统兜底项遇到新界面就让位
	var keep_user: bool = found >= 0 and _user_selected
	if found >= 0 and not keep_user:
		var fresh: int = _first_new_candidate(previous_ids)
		if fresh >= 0:
			found = fresh
	if found < 0:
		found = _first_new_candidate(previous_ids)
	if found < 0:
		found = 0
	var chosen_raw: Variant = _candidates[found]
	if not (chosen_raw is Control):
		_focus_index = 0
		_selected_id = 0
		return
	var chosen: Control = chosen_raw
	if not is_instance_valid(chosen):
		_focus_index = 0
		_selected_id = 0
		_needs_prune = true
		return
	var changed: bool = found != _focus_index
	_focus_index = found
	_selected_id = int(chosen.get_instance_id())
	if not keep_user:
		_user_selected = false
	if changed:
		_ensure_visible(chosen)


## 这一轮新出现的候选里的第一个（树序），也就是新打开界面上最早的可交互控件。
func _first_new_candidate(previous_ids: Dictionary[int, bool]) -> int:
	for i: int in range(_candidates.size()):
		var raw: Variant = _candidates[i]
		if not is_instance_valid(raw) or not (raw is Control):
			continue
		var control: Control = raw
		if not is_instance_valid(control):
			continue
		if not previous_ids.has(int(control.get_instance_id())):
			return i
	return -1


## 热路径：判定逻辑全部内联，并用 get_child_count/get_child 避免每个节点分配一个子节点数组。
func _collect_node(node: Node, skipped: bool, in_modal: bool, out: Array[Control]) -> void:
	# 别的 Viewport 里的内容默认不参与（坐标系不同，靠 SubViewportContainer 自己转发）。
	# 例外：模态 UI 自己就建在 SubViewport 里——百人团暂停卡片为了翻转效果把
	# 整张卡（含 4 个按钮）放在 CardViewport 中，不进去收的话菜单里一个候选都没有。
	if node is Viewport and not in_modal:
		return
	# 祖先不可见时上面已经 return，所以这里只查自身 visible 就够
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	var now_skipped: bool = skipped
	# 注意必须判值：TitlePageManager 用 set_meta(key, false) 来"取消跳过"，
	# 此时 has_meta() 仍为 true，只看 key 存在会把整棵子树误排除。
	if not now_skipped and node.has_meta(META_SKIP):
		now_skipped = _meta_true(node, META_SKIP)
	var now_modal: bool = in_modal
	if node is Control:
		var control: Control = node as Control
		if _current_modal == null and control.has_meta(META_MODAL) \
				and _meta_true(control, META_MODAL):
			_current_modal = control
			now_modal = true
		if not now_skipped:
			if control is BaseButton:
				var button: BaseButton = control as BaseButton
				if not button.disabled and button.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					out.append(control)
			elif control is LineEdit or control is TextEdit:
				if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					out.append(control)
			elif control is Slider:
				# 滑块也纳入焦点：设置页的音量条要能用方向键选到并调节
				var slider: Slider = control as Slider
				if slider.editable and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
					out.append(control)
			elif control.has_meta(META_TARGET):
				out.append(control)
	var child_count: int = node.get_child_count()
	for i: int in range(child_count):
		_collect_node(node.get_child(i), now_skipped, now_modal, out)


func _is_candidate(node: Node, skip_checked: bool = false) -> bool:
	if not (node is Control):
		return false
	var control: Control = node as Control
	if not skip_checked and _is_skipped(control):
		return false
	if control is BaseButton:
		var button: BaseButton = control as BaseButton
		if button.disabled:
			return false
		if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return false
		return true
	if _is_text_input(control):
		return control.mouse_filter != Control.MOUSE_FILTER_IGNORE
	if control is Slider:
		var slider: Slider = control as Slider
		return slider.editable and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
	return _meta_true(control, META_TARGET)


func _is_skipped(control: Control) -> bool:
	var node: Node = control
	while node != null and not (node is Viewport):
		if _meta_true(node, META_SKIP):
			return true
		node = node.get_parent()
	return false


func _meta_true(node: Node, key: StringName) -> bool:
	if not node.has_meta(key):
		return false
	var value: Variant = node.get_meta(key)
	if value is bool:
		var flag: bool = value
		return flag
	return true


# ---------------------------------------------------------------------------
# 矩形换算
# ---------------------------------------------------------------------------

func _canvas_rect_of(control: Control) -> Rect2:
	var target: Control = _focus_rect_control(control)
	var transform: Transform2D = target.get_global_transform_with_canvas()
	var top_left: Vector2 = transform * Vector2.ZERO
	var bottom_right: Vector2 = transform * target.size
	var rect: Rect2 = Rect2(top_left, bottom_right - top_left).abs()
	return _to_root_canvas_rect(rect, target)


## SubViewport 里的控件，坐标是相对那个视口的，必须换算到 root 画布上。
## 百人团暂停卡片的按钮就在 CardViewport 内，不换算焦点框会画到别处。
func _to_root_canvas_rect(rect: Rect2, control: Control) -> Rect2:
	var viewport: Viewport = control.get_viewport()
	var root_viewport: Viewport = get_viewport()
	if viewport == null or root_viewport == null or viewport == root_viewport:
		return rect
	var inner: Vector2 = viewport.get_visible_rect().size
	if inner.x <= 0.0 or inner.y <= 0.0:
		return rect
	var holder: Node = viewport.get_parent()
	if not (holder is Control):
		return rect
	var holder_control: Control = holder
	var holder_rect: Rect2 = holder_control.get_global_rect()
	# SubViewportContainer 开了 stretch 时两者等大，scale 为 1
	var scale: Vector2 = holder_control.size / inner
	return Rect2(holder_rect.position + rect.position * scale, rect.size * scale)


func _focus_rect_control(control: Control) -> Control:
	if not control.has_meta(META_FOCUS_RECT):
		return control
	var value: Variant = control.get_meta(META_FOCUS_RECT)
	if value is NodePath:
		var path: NodePath = value
		var node: Node = control.get_node_or_null(path)
		if node is Control:
			return node as Control
	return control


# ---------------------------------------------------------------------------
# 调试 / 探针
# ---------------------------------------------------------------------------

func describe_selection() -> Dictionary:
	var selected: Control = null
	if _mode == InputMode.FOCUS:
		selected = _focus_candidate()
	else:
		selected = _hover_target()
	return {
		"count": _candidates.size(),
		"selected": str(selected.name) if selected != null else "",
		"path": str(selected.get_path()) if selected != null else "",
		"cursor": _cursor != null and is_instance_valid(_cursor) and _cursor.visible,
		"index": _focus_index,
		"mode": "focus" if _mode == InputMode.FOCUS else "pointer",
		"mouse": _mouse_point(),
		"left_down": _left_down,
	}


## 直接改虚拟鼠标位置（探针用，避免依赖真实 warp）。
func set_virtual_mouse(position: Vector2) -> void:
	_virtual_mouse = position
	_mouse_ready = true
	_clamp_mouse()


## 探针用：强制切换模式。
func set_mode_focus() -> void:
	_switch_to_focus()


func set_mode_pointer() -> void:
	_switch_to_pointer()
