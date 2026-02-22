extends Node

var config: ConfigFile

func _ready() -> void:
	config = ConfigFile.new()
	config.load("user://game_settings.cfg")
	_load_input_mappings()

func _load_input_mappings() -> void:
	if not config.has_section("input_event"):
		return
	var input_events_section = config.get_section_keys("input_event")
	for action_name in input_events_section:
		var saved_event_str = config.get_value("input_event", action_name, "")
		if saved_event_str != "":
			var saved_event = str_to_var(saved_event_str)  # 修复：str2var → str_to_var
			if saved_event is InputEvent:
				InputMap.action_erase_events(action_name)
				InputMap.action_add_event(action_name, saved_event)
				print("加载输入映射: ", action_name, " -> ", saved_event.as_text())

func save() -> void:
	config.save("user://game_settings.cfg")