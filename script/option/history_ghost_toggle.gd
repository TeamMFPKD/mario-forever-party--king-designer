extends UiSoundButton

@warning_ignore_start("unsafe_property_access", "unsafe_method_access")

## 设置项：history（游玩记录）里是否显示联机幽灵。
## 配置项由 HistoryGhostView 在回放时读取。

const SECTION: String = "options"
const KEY: String = "history_ghost_enabled"


func _ready() -> void:
	super()
	pressed.connect(_on_button_pressed)
	_refresh_text()


func _is_enabled() -> bool:
	var value: Variant = GameConfig.config.get_value(SECTION, KEY, true)
	if value is bool:
		return value
	return true


func _on_button_pressed() -> void:
	GameConfig.config.set_value(SECTION, KEY, not _is_enabled())
	GameConfig.save()
	_refresh_text()


func _refresh_text() -> void:
	text = "显示" if _is_enabled() else "隐藏"
