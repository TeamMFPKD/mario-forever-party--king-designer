extends Node

@warning_ignore_start("unsafe_cast", "unsafe_call_argument", "unsafe_method_access", "unsafe_property_access")

## 无头探针：回放页暂停菜单的按钮显隐 + 排除落盘 / 置灰 / 保持暂停。
## 运行：Godot --headless --path . res://tools/history_pause_exclude_probe.tscn

const OUTPUT: String = "res://tools/history_pause_exclude_probe_result.txt"
const MENU: String = "res://object/ui/adventure_pause_menu.tscn"
const ROOM: String = "res://room/history_play.tscn"
const TEMP_INI: String = "user://history_pause_exclude_probe.ini"
const KEY: String = "history_pause_exclude_probe.lvl"
const BUTTONS: String = "Root/CardHolder/CardContainer/CardViewport/BackPanel/Content/VBox/Center/Buttons"

var _lines: Array[String] = []
var _original_store: AdventureStore
var _temp_store: AdventureStore


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_room_overrides()
	_original_store = Adventure.store
	_temp_store = AdventureStore.new(TEMP_INI)
	_temp_store.load()
	Adventure.store = _temp_store

	var setter: Node = get_tree().get_first_node_in_group("level_path_set")
	if setter != null:
		setter.set_meta("level_path_name", "user://" + KEY)

	await _run_menu()
	_write()
	_cleanup(setter)
	get_tree().quit()


## 直接读 SceneState 的属性覆写，不用把整个回放页塞进另一个 current_scene。
func _check_room_overrides() -> void:
	var packed: PackedScene = load(ROOM) as PackedScene
	if packed == null:
		_lines.append("room_scene=missing")
		return
	var state: SceneState = packed.get_state()
	var found: bool = false
	for index: int in range(state.get_node_count()):
		if state.get_node_name(index) != &"HistoryPauseMenu":
			continue
		found = true
		var overrides: Dictionary = {}
		for prop: int in range(state.get_node_property_count(index)):
			overrides[state.get_node_property_name(index, prop)] = state.get_node_property_value(index, prop)
		_lines.append("room_history_mode=%s" % str(overrides.get("history_mode", false)))
		_lines.append("room_usable_outside=%s" % str(overrides.get("usable_outside_adventure", false)))
		_lines.append("room_actions_visible=%s" % str(overrides.get("actions_visible", true)))
	_lines.append("room_node_found=%s" % str(found))


func _run_menu() -> void:
	await _check_default_menu()
	var packed: PackedScene = load(MENU) as PackedScene
	if packed == null:
		_lines.append("menu=missing")
		return
	var menu: Node = packed.instantiate()
	menu.set("history_mode", true)
	menu.set("usable_outside_adventure", true)
	add_child(menu)
	await get_tree().process_frame

	var exclude: Button = menu.get_node(BUTTONS + "/ExcludeButton") as Button
	var skip: Button = menu.get_node(BUTTONS + "/SkipButton") as Button
	var abort: Button = menu.get_node(BUTTONS + "/AbortButton") as Button
	var cont: Button = menu.get_node(BUTTONS + "/ContinueButton") as Button
	var buttons: Control = menu.get_node(BUTTONS) as Control
	if exclude == null or skip == null or abort == null or cont == null or buttons == null:
		_lines.append("buttons=missing")
		return

	_lines.append("buttons_visible=%s" % str(buttons.visible))
	_lines.append("continue_visible=%s" % str(cont.visible))
	_lines.append("exclude_visible=%s" % str(exclude.visible and exclude.is_visible_in_tree()))
	_lines.append("skip_visible=%s" % str(skip.visible))
	_lines.append("abort_visible=%s" % str(abort.visible))
	_lines.append("exclude_connected=%s" % str(_has_press_callback(exclude, &"_on_exclude_pressed")))
	_lines.append("continue_connected=%s" % str(_has_press_callback(cont, &"_close_flip")))
	_lines.append("exclude_disabled_before=%s" % str(exclude.disabled))

	menu.call("toggle_pause")
	var waited: float = 0.0
	while bool(menu.get("_animating")) and waited < 2.0:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	_lines.append("menu_open=%s" % str(bool(menu.get("_is_open"))))
	_lines.append("flip_finished=%s" % str(not bool(menu.get("_animating"))))
	_lines.append("paused_before=%s" % str(get_tree().paused))

	# 点在卡片上不能被 Root 当成"点空白处继续"（排除按钮变灰后尤其重要）。
	var root: Control = menu.get_node("Root") as Control
	var holder: Control = menu.get_node("Root/CardHolder") as Control
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = holder.size * 0.5
	click.global_position = holder.get_global_rect().position + holder.size * 0.5
	root.gui_input.emit(click)
	_lines.append("paused_after_card_click=%s" % str(get_tree().paused))

	exclude.pressed.emit()
	_lines.append("excluded=%s" % str(_temp_store.is_excluded(KEY)))
	_lines.append("exclude_reason=%s" % str(_temp_store.get_level_data(KEY).get("exclude_reason", "")))
	_lines.append("in_excluded_list=%s" % str(_has_excluded_entry(KEY)))
	_lines.append("solo_skip=%d" % int(_temp_store.get_level_data(KEY).get("solo_skip", -1)))
	_lines.append("exclude_disabled_after=%s" % str(exclude.disabled))
	_lines.append("font_disabled=%s" % str(exclude.get_theme_color(&"font_disabled_color")))
	_lines.append("paused_after=%s" % str(get_tree().paused))
	_lines.append("menu_open_after=%s" % str(bool(menu.get("_is_open"))))
	_lines.append("second_exclude=%s" % str(Adventure.exclude_level(KEY)))
	_lines.append("run_active=%s" % str(Adventure.is_running()))


## Godot 4 的连接字典用 "callable"（不是 "method"），这里只看方法名有没有连上。
## 回归：默认（百人团）实例仍显示四个按钮，排除按钮不会莫名其妙置灰。
func _check_default_menu() -> void:
	var packed: PackedScene = load(MENU) as PackedScene
	if packed == null:
		return
	var menu: Node = packed.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var buttons: Control = menu.get_node(BUTTONS) as Control
	var skip: Button = menu.get_node(BUTTONS + "/SkipButton") as Button
	var abort: Button = menu.get_node(BUTTONS + "/AbortButton") as Button
	var exclude: Button = menu.get_node(BUTTONS + "/ExcludeButton") as Button
	if buttons == null or skip == null or abort == null or exclude == null:
		_lines.append("adventure_buttons=missing")
		return
	_lines.append("adventure_buttons_visible=%s" % str(buttons.visible))
	_lines.append("adventure_skip_visible=%s" % str(skip.visible))
	_lines.append("adventure_abort_visible=%s" % str(abort.visible))
	_lines.append("adventure_exclude_disabled=%s" % str(exclude.disabled))
	menu.queue_free()


func _has_press_callback(button: BaseButton, method: StringName) -> bool:
	for entry: Dictionary in button.get_signal_connection_list(&"pressed"):
		if str(entry).contains(str(method)):
			return true
	return false


func _has_excluded_entry(key: String) -> bool:
	for entry: Dictionary in _temp_store.get_excluded_levels():
		if str(entry.get("key", "")) == key:
			return true
	return false


func _write() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines))
		file.close()


func _cleanup(setter: Node) -> void:
	get_tree().paused = false
	Adventure.store = _original_store
	if setter != null:
		setter.remove_meta("level_path_name")
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for file_name: String in ["history_pause_exclude_probe.ini", "history_pause_exclude_probe.ini.tmp"]:
		if FileAccess.file_exists("user://" + file_name):
			dir.remove(file_name)
