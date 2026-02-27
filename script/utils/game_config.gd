extends Node

var config: ConfigFile

# 默认网络配置
const DEFAULT_FRP_DOMAIN: String = ""
const DEFAULT_REMOTE_PORT: int = 8914
const DEFAULT_LOCAL_PORT: int = 8914
const DEFAULT_PLAYER_NAME: String = "Player"

func _ready() -> void:
	config = ConfigFile.new()
	config.load("user://game_settings.cfg")
	_load_input_mappings()
	_load_network_settings()

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

# 网络配置相关方法
func _load_network_settings() -> void:
	# 确保网络配置节存在
	if not config.has_section("network"):
		_set_default_network_settings()

func _set_default_network_settings() -> void:
	config.set_value("network", "frp_domain", DEFAULT_FRP_DOMAIN)
	config.set_value("network", "remote_port", DEFAULT_REMOTE_PORT)
	config.set_value("network", "local_port", DEFAULT_LOCAL_PORT)
	config.set_value("network", "player_name", DEFAULT_PLAYER_NAME)
	save()

func get_network_value(key: String, default_value = null):
	if not config.has_section("network"):
		_set_default_network_settings()
	return config.get_value("network", key, default_value)

func set_network_value(key: String, value) -> void:
	config.set_value("network", key, value)
	save()

# 具体的网络配置获取方法
func get_frp_domain() -> String:
	return get_network_value("frp_domain", DEFAULT_FRP_DOMAIN)

func get_remote_port() -> int:
	return get_network_value("remote_port", DEFAULT_REMOTE_PORT)

func get_local_port() -> int:
	return get_network_value("local_port", DEFAULT_LOCAL_PORT)

func get_player_name() -> String:
	return get_network_value("player_name", DEFAULT_PLAYER_NAME)

func set_frp_domain(value: String) -> void:
	set_network_value("frp_domain", value)

func set_remote_port(value: int) -> void:
	set_network_value("remote_port", value)

func set_local_port(value: int) -> void:
	set_network_value("local_port", value)

func set_player_name(value: String) -> void:
	set_network_value("player_name", value)