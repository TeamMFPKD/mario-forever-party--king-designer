extends UiSoundButton

## 把“输入映射”面板里的按键恢复为项目默认值（project.godot 的 [input] 定义）。

## GameConfig 中保存自定义按键的节名
const INPUT_EVENT_SECTION: String = "input_event"
## InputMapSetButton 注册的分组名
const INPUT_MAP_BUTTON_GROUP: String = "input_map_set_button"

func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	var actions: Dictionary = _collect_actions()
	_clear_saved_mappings()
	for action_name: String in actions.keys():
		_restore_action_default(action_name)
	GameConfig.save()
	_refresh_buttons()
	Log.i("重置按键映射", ["已恢复默认按键：", actions.size(), " 个动作"])

## 需要重置的动作 = 配置里改动过的 + 面板上展示的
func _collect_actions() -> Dictionary:
	var actions: Dictionary = {}
	var config: ConfigFile = GameConfig.config
	if config.has_section(INPUT_EVENT_SECTION):
		for key: String in config.get_section_keys(INPUT_EVENT_SECTION):
			var parts: PackedStringArray = key.split(":")
			if parts.size() == 2 and parts[1].is_valid_int():
				actions[parts[0]] = true
	for node: Node in get_tree().get_nodes_in_group(INPUT_MAP_BUTTON_GROUP):
		var action_value: Variant = node.get("input_map_name")
		if action_value is String:
			var action_text: String = action_value
			if not action_text.is_empty():
				actions[action_text] = true
	return actions

## 清空 GameConfig 里的自定义按键；下次启动不再覆盖 InputMap
func _clear_saved_mappings() -> void:
	var config: ConfigFile = GameConfig.config
	if config.has_section(INPUT_EVENT_SECTION):
		config.erase_section(INPUT_EVENT_SECTION)

## 按 project.godot 的 [input] 定义还原单个动作
func _restore_action_default(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		return
	var setting_key: String = "input/" + action_name
	if not ProjectSettings.has_setting(setting_key):
		return
	var setting_value: Variant = ProjectSettings.get_setting(setting_key)
	if not (setting_value is Dictionary):
		return
	var action_setting: Dictionary = setting_value

	InputMap.action_erase_events(action_name)

	var deadzone_value: Variant = action_setting.get("deadzone", 0.2)
	if deadzone_value is float or deadzone_value is int:
		var deadzone: float = deadzone_value
		InputMap.action_set_deadzone(action_name, deadzone)

	var events_value: Variant = action_setting.get("events", [])
	if events_value is Array:
		var events: Array = events_value
		for event_value: Variant in events:
			if event_value is InputEvent:
				var source_event: InputEvent = event_value
				var copied_resource: Resource = source_event.duplicate()
				if copied_resource is InputEvent:
					var copied_event: InputEvent = copied_resource
					InputMap.action_add_event(action_name, copied_event)

## 刷新所有按键显示文本
func _refresh_buttons() -> void:
	for node: Node in get_tree().get_nodes_in_group(INPUT_MAP_BUTTON_GROUP):
		if node.has_method("refresh_display"):
			node.call("refresh_display")
