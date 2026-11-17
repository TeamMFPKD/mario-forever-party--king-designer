extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access", "untyped_declaration", "inferred_declaration")

## 无头探针：移动端 + 手柄时的纯手柄操作（三项检查清单）。
##
## 运行：
##   Godot --headless --path . res://tools/mobile_gamepad_nav_probe.tscn
##
## 伪装手段：PlatformUtils.set_debug_platform("Android") + InputDevice.set_debug_gamepad_present(true)。
## 手柄输入用 InputEventAction / Input.action_press 模拟（等价于按住对应 action 的摇杆或十字键）。
##
## 判据（关键行）：
##   1 标题画面   title_nav_enabled=true / title_pointer_moves=true / title_focus_moves=true
##   2 回放暂停   history_pause_nav=true / history_pause_focus_moves=true
##   3 编辑器     edit_nav_enabled=true / edit_stick_moves_cursor=true
##                / edit_cursor_reaches_input_handler=true / edit_dpad_moves_focus=true
##                / edit_rstick_moves_camera=true

const OUTPUT: String = "res://tools/mobile_gamepad_nav_probe_result.txt"
const TITLE_SCENE: String = "res://room/title.tscn"
const HISTORY_PLAY_SCENE: String = "res://room/history_play.tscn"
const EDIT_SCENE: String = "res://room/edit.tscn"

var _watch_mode: bool = false
var _log: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _watch_mode:
		set_process(false)
		_go()
		return
	_apply_fakes()
	# 引导器只负责把监听节点挂到 root 上，然后什么都不做。
	# 三个待测场景都必须由监听节点切（它活在 root 上，切场景不会跟着被释放）；
	# 引导器自己就是 current_scene，让它去切会把自己 free 掉，
	# 之后 _ready 里挂起的协程再碰 get_tree() 就是 null 了。
	var watcher: Node = Node.new()
	watcher.name = "MobileGamepadNavWatcher"
	watcher.set_script(get_script())
	watcher.set("_watch_mode", true)
	# _ready 期间 root 正在布局子节点，直接 add_child 会报 "Parent node is busy"，
	# 必须 deferred 挂上去。
	get_tree().root.add_child.call_deferred(watcher)


func _apply_fakes() -> void:
	PlatformUtils.set_debug_platform("Android")
	InputDevice.set_debug_gamepad_present(true)


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

func _go() -> void:
	_apply_fakes()
	await _phase_title()
	_apply_fakes()
	await _phase_history_pause()
	_apply_fakes()
	await _phase_edit()
	_release_all()
	await _phase_regressions()
	_finish()


## 回归：原有的"没手柄就不启用"必须原样保留，桌面端行为也不能变。
func _phase_regressions() -> void:
	_log.append("=== 4 regressions ===")
	# 移动端 + 无手柄：导航关闭、按钮焦点保持禁用（触屏点触即鼠标）
	PlatformUtils.set_debug_platform("Android")
	InputDevice.set_debug_gamepad_present(false)
	await _settle_frames(4)
	_log.append("mobile_no_pad_nav=%s" % str(UiNavigator.call("_navigation_enabled")))
	_log.append("mobile_no_pad_focus_policy=%s" % str(UiFocusPolicy.should_enable_gamepad_focus()))
	_log.append("mobile_no_pad_camera_axis_move_merged=%s"
		% str(InputGroups.edit_camera_axis() == InputGroups.camera_axis()))

	# 移动端 + 手柄：焦点策略放开、镜头轴不再并入 move_*
	InputDevice.set_debug_gamepad_present(true)
	await _settle_frames(4)
	_log.append("mobile_pad_focus_policy=%s" % str(UiFocusPolicy.should_enable_gamepad_focus()))

	# 桌面 + 手柄：与改动前一致
	PlatformUtils.clear_debug_platform()
	await _settle_frames(4)
	_log.append("desktop_is_mobile=%s" % str(PlatformUtils.is_mobile_platform()))
	_log.append("desktop_nav=%s" % str(UiNavigator.call("_navigation_enabled")))
	_log.append("desktop_focus_policy=%s" % str(UiFocusPolicy.should_enable_gamepad_focus()))
	_log.append("desktop_pointer_drawn=%s" % str(UiNavigator.call("_uses_drawn_pointer")))


func _phase_title() -> void:
	_log.append("=== 1 title ===")
	_change_scene(TITLE_SCENE)
	await _settle(90)
	_log.append("is_mobile=%s" % str(PlatformUtils.is_mobile_platform()))
	_log.append("has_gamepad=%s" % str(InputDevice.has_gamepad()))
	_log.append("title_nav_enabled=%s" % str(UiNavigator.call("_navigation_enabled")))
	_log.append("title_candidates=%d" % int(UiNavigator.call("describe_selection")["count"]))
	# 五根水管是主菜单的主体，必须都在候选里（Button 自身有 ui_focus_rect，
	# 焦点框画在整根管子上，见 ui/title/pipe_button.tscn）。
	var pipe_hits: int = 0
	for control: Control in _candidates():
		var path: String = str(control.get_path())
		if path.contains("PipeMenu/Pipe"):
			pipe_hits += 1
	_log.append("title_pipe_candidates=%d" % pipe_hits)
	_log.append("title_pipes_reachable=%s" % str(pipe_hits >= 5))

	# --- 十字键：焦点移动 ---
	var idx_before: int = int(UiNavigator.call("describe_selection")["index"])
	_dpad("ui_focus_right")
	await _settle_frames(8)
	var idx_after: int = int(UiNavigator.call("describe_selection")["index"])
	_log.append("title_focus_index=%d->%d" % [idx_before, idx_after])
	_log.append("title_focus_moves=%s" % str(idx_before != idx_after))

	# --- 左摇杆：虚拟光标 ---
	_switch_to_pointer()
	UiNavigator.call("set_virtual_mouse", Vector2(400.0, 400.0))
	await _settle_frames(2)
	var mouse_before: Vector2 = UiNavigator.call("describe_selection")["mouse"]
	_stick("ui_cursor_right")
	await _settle_frames(30)
	var mouse_after: Vector2 = UiNavigator.call("describe_selection")["mouse"]
	_release("ui_cursor_right")
	_log.append("title_mouse=%s->%s" % [str(mouse_before), str(mouse_after)])
	_log.append("title_pointer_moves=%s" % str(mouse_after.x > mouse_before.x + 4.0))
	_log.append("title_pointer_drawn=%s" % str(_pointer_visible()))

	# --- 悬停：合成 motion 能否驱动 hover ---
	await _settle_frames(4)
	var hovered: Control = get_viewport().gui_get_hovered_control()
	_log.append("title_hovered=%s" % (str(hovered.name) if hovered != null else "<null>"))


func _phase_history_pause() -> void:
	_log.append("=== 2 history pause ===")
	GameModeSingleton.game_mode = GameModeSingleton.GameModeType.HISTORY_PLAY
	_change_scene(HISTORY_PLAY_SCENE)
	await _settle(100)
	var scene: Node = get_tree().current_scene
	_log.append("history_scene=%s" % (str(scene.name) if scene != null else "<null>"))
	var menu: Node = scene.get_node_or_null("HistoryPauseMenu") if scene != null else null
	_log.append("pause_menu_found=%s" % str(menu != null))
	if menu == null:
		return
	menu.call("toggle_pause")
	await _settle(60)
	_log.append("paused=%s" % str(get_tree().paused))
	_log.append("menu_visible=%s" % str(menu.visible))
	_log.append("history_pause_nav=%s" % str(UiNavigator.call("_navigation_enabled")))
	var desc: Dictionary = UiNavigator.call("describe_selection")
	_log.append("history_pause_candidates=%d" % int(desc["count"]))
	_log.append("history_pause_selected=%s" % str(desc["selected"]))
	var idx_before: int = int(desc["index"])
	_dpad("ui_focus_right")
	await _settle_frames(10)
	var idx_after: int = int(UiNavigator.call("describe_selection")["index"])
	_log.append("history_pause_focus_index=%d->%d" % [idx_before, idx_after])
	_log.append("history_pause_focus_moves=%s" % str(idx_before != idx_after))
	_log.append("history_pause_pointer_drawn=%s" % str(_pointer_visible()))
	# 必须解冻：paused 是全局状态，会带到下一个场景，届时关卡的
	# Camera2D._physics_process / InputHandler._input 全都不会跑，
	# 后面的检查会被误判成"手柄无效"。
	get_tree().paused = false
	await _settle_frames(2)
	_log.append("history_unpaused=%s" % str(not get_tree().paused))


func _phase_edit() -> void:
	_log.append("=== 3 edit ===")
	GameModeSingleton.game_mode = GameModeSingleton.GameModeType.EDIT
	_change_scene(EDIT_SCENE)
	await _settle(110)
	var scene: Node = get_tree().current_scene
	_log.append("edit_scene=%s" % (str(scene.name) if scene != null else "<null>"))
	if scene == null:
		return
	GameModeSingleton.game_mode = GameModeSingleton.GameModeType.EDIT
	await _settle_frames(10)
	_log.append("edit_has_player=%s" % str(UiNavigator.call("_has_player")))
	_log.append("edit_nav_enabled=%s" % str(UiNavigator.call("_navigation_enabled")))
	_log.append("edit_candidates=%d" % int(UiNavigator.call("describe_selection")["count"]))

	# --- 摇杆推动虚拟光标（并要到达关卡视口里的 InputHandler）---
	_switch_to_pointer()
	var container: Control = scene.find_child("SubViewportContainer", true, false) as Control
	var handler: Node = scene.find_child("InputHandler", true, false)
	_log.append("edit_handler_found=%s" % str(handler != null))
	var start_point: Vector2 = Vector2(500.0, 300.0)
	UiNavigator.call("set_virtual_mouse", start_point)
	await _settle_frames(3)
	var handler_before: Variant = handler.get("current_position") if handler != null else null
	_stick("ui_cursor_right")
	await _settle_frames(35)
	_release("ui_cursor_right")
	await _settle_frames(3)
	var mouse_after: Vector2 = UiNavigator.call("describe_selection")["mouse"]
	_log.append("edit_mouse=%s->%s" % [str(start_point), str(mouse_after)])
	_log.append("edit_stick_moves_cursor=%s" % str(mouse_after.x > start_point.x + 4.0))
	_log.append("edit_pointer_drawn=%s" % str(_pointer_visible()))
	if handler != null:
		var handler_after: Variant = handler.get("current_position")
		_log.append("edit_handler_pos=%s->%s" % [str(handler_before), str(handler_after)])
		_log.append("edit_cursor_reaches_input_handler=%s" % str(handler_after != handler_before))
	else:
		_log.append("edit_cursor_reaches_input_handler=false")

	# --- 十字键：UI 焦点 ---
	_switch_to_focus()
	await _settle_frames(4)
	var idx_before: int = int(UiNavigator.call("describe_selection")["index"])
	_dpad("ui_focus_right")
	await _settle_frames(10)
	var idx_after: int = int(UiNavigator.call("describe_selection")["index"])
	_log.append("edit_focus_index=%d->%d" % [idx_before, idx_after])
	_log.append("edit_dpad_moves_focus=%s" % str(idx_before != idx_after))
	_log.append("edit_focus_mode=%s" % str(UiNavigator.call("describe_selection")["mode"]))

	# --- 按 A（ui_menu_accept）在虚拟光标处真正放下一个图块 ---
	# 光标必须先停在关卡视口的空白处：若悬停在任何按钮上，A 会去点那个按钮，
	# 比如 PlayButton 会直接进测试游玩、把关卡场景释放掉。
	_switch_to_pointer()
	await _settle_frames(3)
	var tile_map: Node = scene.find_child("TileMapLayer", true, false)
	_log.append("edit_tilemap_found=%s" % str(tile_map != null))
	if container != null and tile_map != null and tile_map is TileMapLayer and handler != null:
		var level_tiles: TileMapLayer = tile_map
		var blank_point: Vector2 = container.get_global_transform_with_canvas() \
			* (container.size * Vector2(0.35, 0.55))
		UiNavigator.call("set_virtual_mouse", blank_point)
		_stick("ui_cursor_right")
		await _settle_frames(2)
		_release("ui_cursor_right")
		await _settle_frames(4)
		var hovered_now: Control = get_viewport().gui_get_hovered_control()
		_log.append("edit_place_hovered=%s"
			% (str(hovered_now.name) if hovered_now != null else "<null>"))
		var before_cells: int = level_tiles.get_used_cells().size()
		_log.append("edit_place_point=%s" % str(UiNavigator.call("describe_selection")["mouse"]))
		# 按住 A 几帧再松开：UiNavigator 在 _process 里 poll ui_menu_accept 合成鼠标按下
		Input.action_press("ui_menu_accept")
		await _settle_frames(3)
		Input.action_release("ui_menu_accept")
		await _settle_frames(6)
		var after_cells: int = level_tiles.get_used_cells().size()
		_log.append("edit_tile_cells=%d->%d" % [before_cells, after_cells])
		_log.append("edit_a_button_places_tile=%s" % str(after_cells > before_cells))

	# --- 虚拟光标悬停到具体按钮上，四角框要框住它 ---
	var play_button: Control = scene.get_node_or_null(
		"GameRoomSize/SaveLoad/VBoxContainer/PlayButton") as Control
	_log.append("edit_play_button_found=%s" % str(play_button != null))
	if play_button != null:
		UiNavigator.call("set_mode_pointer")
		await _settle_frames(3)
		var center: Vector2 = play_button.get_global_transform_with_canvas() \
			* (play_button.size * 0.5)
		UiNavigator.call("set_virtual_mouse", center)
		# 挪一点点再挪回来，逼出一条真实的 motion（位置没变会被节流掉）
		UiNavigator.call("set_virtual_mouse", center + Vector2(1.0, 0.0))
		_stick("ui_cursor_left")
		await _settle_frames(2)
		_release("ui_cursor_left")
		await _settle_frames(3)
		UiNavigator.call("set_virtual_mouse", center)
		_stick("ui_cursor_right")
		await _settle_frames(2)
		_release("ui_cursor_right")
		await _settle_frames(4)
		var desc: Dictionary = UiNavigator.call("describe_selection")
		_log.append("edit_hovered=%s" % str(desc["selected"]))
		_log.append("edit_hover_is_button=%s" % str(desc["selected"] == "PlayButton"))
		_log.append("edit_cursor_frames_hover=%s" % str(desc["cursor"]))

	# --- 右摇杆：镜头 ---
	var cam: Node = get_tree().get_first_node_in_group("level_camera")
	if cam == null:
		cam = _find_camera(scene)
	_log.append("edit_camera_found=%s" % str(cam != null))
	if cam != null and cam is Camera2D:
		var cam2d: Camera2D = cam
		await _settle_physics(4)
		var cam_before: Vector2 = cam2d.position
		_stick("ui_camera_right")
		# LevelCamera 在 _physics_process 里推镜头，必须等物理帧
		await _settle_physics(30)
		_release("ui_camera_right")
		var cam_after: Vector2 = cam2d.position
		_log.append("edit_camera_pos=%s->%s" % [str(cam_before), str(cam_after)])
		_log.append("edit_rstick_moves_camera=%s" % str(cam_after.x > cam_before.x + 4.0))
	# 十字键不应该同时推镜头（move_* 已不再并入 CAMERA 轴）
	_log.append("edit_camera_axis=%s" % str(InputGroups.edit_camera_axis()))


# ---------------------------------------------------------------------------
# 模拟输入
# ---------------------------------------------------------------------------

## 模拟"持续按住某个方向 action"（摇杆推住 / 十字键按住）。
func _stick(action: String) -> void:
	Input.action_press(action)


func _release(action: String) -> void:
	Input.action_release(action)


func _release_all() -> void:
	for action: String in ["ui_cursor_left", "ui_cursor_right", "ui_cursor_up", "ui_cursor_down",
			"ui_focus_left", "ui_focus_right", "ui_focus_up", "ui_focus_down",
			"ui_camera_left", "ui_camera_right", "ui_camera_up", "ui_camera_down",
			"ui_menu_accept", "ui_menu_cancel"]:
		Input.action_release(action)


## 模拟"按一下"某个方向 action：先清掉按下态，再送一个独立的按下事件。
## 用 InputEventAction 而不是 Input.action_press，是因为 FOCUS 的移动发生在
## _unhandled_input 里（处理的是"事件"），不是每帧轮询。
func _dpad(action: String) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var up: InputEventAction = InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## 读 UiNavigator 当前的候选列表（探针用；正常代码不该碰私有字段）。
func _candidates() -> Array:
	var raw: Variant = UiNavigator.get("_candidates")
	if raw is Array:
		var list: Array = raw
		return list
	return []


func _switch_to_pointer() -> void:
	UiNavigator.call("set_mode_pointer")


func _switch_to_focus() -> void:
	UiNavigator.call("set_mode_focus")


func _pointer_visible() -> bool:
	var layer: Node = get_tree().root.get_node_or_null("UiNavigatorCursorLayer")
	if layer == null:
		return false
	var pointer: Node = layer.get_node_or_null("UiNavigatorPointer")
	if pointer == null or not (pointer is CanvasItem):
		return false
	var item: CanvasItem = pointer
	return item.visible


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _change_scene(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	if err != OK:
		_log.append("change_scene_error=%s=%d" % [path, err])


func _settle(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame


func _settle_frames(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame


func _settle_physics(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().physics_frame


func _find_camera(node: Node) -> Node:
	if node is Camera2D:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_camera(child)
		if found != null:
			return found
	return null


func _finish() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log))
		file.close()
	PlatformUtils.clear_debug_platform()
	InputDevice.set_debug_gamepad_present(false)
	get_tree().quit()
