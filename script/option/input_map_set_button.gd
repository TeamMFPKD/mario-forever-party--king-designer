extends Button

@export var input_map_name: String

var is_waiting_for_input: bool = false
var config: ConfigFile

func _ready() -> void:
	config = GameConfig.config
	pressed.connect(_on_button_pressed)
	_update_button_text()

func _on_button_pressed() -> void:
	is_waiting_for_input = true
	text = "请按下一个键"

func _input(event: InputEvent) -> void:
	if not is_waiting_for_input:
		return
	if event.is_pressed():
		InputMap.action_erase_events(input_map_name)
		InputMap.action_add_event(input_map_name, event)
		
		# 修复：用 var_to_str 序列化完整 InputEvent，存到 input_event section
		config.set_value("input_event", input_map_name, var_to_str(event))
		# 同时存可读文本用于显示
		config.set_value("input_display", input_map_name, event.as_text().replace(" - Physical", ""))
		GameConfig.save()
		
		_update_button_text()
		is_waiting_for_input = false

func _update_button_text() -> void:
	# 从 input_display section 读取显示用的文本
	var saved_text = config.get_value("input_display", input_map_name, "")
	if saved_text != "":
		text = saved_text
	else:
		var events = InputMap.action_get_events(input_map_name)
		if events.size() > 0:
			var display = events[0].as_text().replace(" - Physical", "")
			text = display
			config.set_value("input_event", input_map_name, var_to_str(events[0]))
			config.set_value("input_display", input_map_name, display)
			GameConfig.save()
		else:
			text = "未设置"