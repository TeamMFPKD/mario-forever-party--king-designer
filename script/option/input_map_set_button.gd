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
	text = tr("请按下一个键")

func _input(event: InputEvent) -> void:
	if not is_waiting_for_input:
		return
	if event.is_pressed():
		InputMap.action_erase_events(input_map_name)
		InputMap.action_add_event(input_map_name, event)
		
		config.set_value("input_event", input_map_name, var_to_str(event))
		GameConfig.save()
		
		_update_button_text()
		is_waiting_for_input = false

func _update_button_text() -> void:
	var saved_event_str = config.get_value("input_event", input_map_name, "")
	if saved_event_str != "":
		var saved_event = str_to_var(saved_event_str)
		if saved_event is InputEvent:
			text = saved_event.as_text().replace(" - Physical", "")
			return
	
	# 配置里没有，从 InputMap 读取默认值
	var events = InputMap.action_get_events(input_map_name)
	if events.size() > 0:
		text = events[0].as_text().replace(" - Physical", "")
	else:
		text = tr("未设置")