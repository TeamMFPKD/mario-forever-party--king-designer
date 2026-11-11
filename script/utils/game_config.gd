extends Node

var config: ConfigFile

# 默认网络配置
const DEFAULT_FRP_DOMAIN: String = ""
const DEFAULT_REMOTE_PORT: int = 8914
const DEFAULT_LOCAL_PORT: int = 8914
const DEFAULT_PLAYER_NAME: String = "Player"
const DEFAULT_AVATAR_ID: String = ""

## 支持的语言，与 i18n/mfmp_translation.<locale>.po 一一对应
const SUPPORTED_LANGUAGES: PackedStringArray = ["en", "zh_CN", "ja"]
## 系统语言不受支持时的回退语言
const DEFAULT_LANGUAGE: String = "en"
const LANGUAGE_SECTION: String = "options"
const LANGUAGE_KEY: String = "language"

func _ready() -> void:
	config = ConfigFile.new()
	config.load("user://game_settings.cfg")
	_setup_language()
	_load_input_mappings()
	_load_network_settings()

# ---------------------------------------------------------------------------
# 语言
# ---------------------------------------------------------------------------

## 语言初始化：存档里已有设置就用存档的；初次运行（配置里没有该项）时
## 按本机系统语言选择，系统语言不在支持列表内则回退到 DEFAULT_LANGUAGE。
func _setup_language() -> void:
	var language: String
	if config.has_section_key(LANGUAGE_SECTION, LANGUAGE_KEY):
		language = normalize_language(str(config.get_value(LANGUAGE_SECTION, LANGUAGE_KEY, DEFAULT_LANGUAGE)))
	else:
		var system_locale: String = OS.get_locale()
		language = normalize_language(system_locale)
		config.set_value(LANGUAGE_SECTION, LANGUAGE_KEY, language)
		save()
		Log.i("设置", ["初次运行，按系统语言选择语言: ", system_locale, " -> ", language])
	TranslationServer.set_locale(language)

## 把任意语言标识归一化成受支持的 locale。
## 先按完整 locale 匹配（大小写不敏感），再按主语言子标签匹配，
## 例如 zh_TW / zh_HK / zh-SG → zh_CN，ja_JP → ja；都不匹配则回退 DEFAULT_LANGUAGE。
## 同时兼容旧版存档里写过的 "zh"。
static func normalize_language(raw: String) -> String:
	if raw.is_empty():
		return DEFAULT_LANGUAGE
	var tag: String = raw.replace("-", "_")
	for supported: String in SUPPORTED_LANGUAGES:
		if supported.to_lower() == tag.to_lower():
			return supported
	var base: String = tag.split("_")[0].to_lower()
	if base.is_empty():
		return DEFAULT_LANGUAGE
	for supported: String in SUPPORTED_LANGUAGES:
		if supported.split("_")[0].to_lower() == base:
			return supported
	return DEFAULT_LANGUAGE

## 本机系统语言归一化后的结果。
static func detect_system_language() -> String:
	return normalize_language(OS.get_locale())

## 当前生效的语言（已归一化为受支持的 locale）。
func get_language() -> String:
	return normalize_language(str(config.get_value(LANGUAGE_SECTION, LANGUAGE_KEY, DEFAULT_LANGUAGE)))

## 切换并保存语言，同时立即应用。
func set_language(language: String) -> void:
	var normalized: String = normalize_language(language)
	config.set_value(LANGUAGE_SECTION, LANGUAGE_KEY, normalized)
	TranslationServer.set_locale(normalized)
	save()

func _load_input_mappings() -> void:
	if not config.has_section("input_event"):
		return
	var input_events_section: PackedStringArray = config.get_section_keys("input_event")
	
	# 收集所有动作及其槽位
	var action_slots: Dictionary = {}
	for key: String in input_events_section:
		# 解析键名格式："action_name:slot_index"
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2 and parts[1].is_valid_int():
			var base_action: String = parts[0]
			var slot_index: int = parts[1].to_int()
			
			if not action_slots.has(base_action):
				action_slots[base_action] = []
			
			# 确保槽位数组足够大
			var slots_for_action: Array = action_slots[base_action]
			while slots_for_action.size() <= slot_index:
				slots_for_action.append(null)
			
			var saved_event_str: String = config.get_value("input_event", key, "")
			if saved_event_str != "":
				var saved_event: Variant = str_to_var(saved_event_str)
				if saved_event is InputEvent:
					slots_for_action[slot_index] = saved_event
	
	# 应用所有动作的槽位配置
	for base_action: String in action_slots.keys():
		var slots: Array = action_slots[base_action]
		InputMap.action_erase_events(base_action)
		for ev: Variant in slots:
			if ev != null:
				var input_event: InputEvent = ev
				InputMap.action_add_event(base_action, input_event)
				Log.i("设置", ["加载输入映射: ", base_action, " -> ", input_event.as_text()])

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
	config.set_value("network", "avatar_id", DEFAULT_AVATAR_ID)
	save()

func get_network_value(key: String, default_value: Variant = null) -> Variant:
	if not config.has_section("network"):
		_set_default_network_settings()
	return config.get_value("network", key, default_value)

func set_network_value(key: String, value: Variant) -> void:
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

func get_avatar_id() -> String:
	var value: Variant = get_network_value("avatar_id", DEFAULT_AVATAR_ID)
	return str(value)

func set_frp_domain(value: String) -> void:
	set_network_value("frp_domain", value)

func set_remote_port(value: int) -> void:
	set_network_value("remote_port", value)

func set_local_port(value: int) -> void:
	set_network_value("local_port", value)

func set_player_name(value: String) -> void:
	set_network_value("player_name", value)

func set_avatar_id(value: String) -> void:
	set_network_value("avatar_id", value)