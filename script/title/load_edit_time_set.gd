extends Node

@export var path_to_bar: NodePath = ".."

var config: ConfigFile
var bar: HScrollBar

func _ready() -> void:
	config = GameConfig.get("config")
	if not config.has_section_key("game_settings", "host_set_edit_time_limit"):
		return
	bar = get_node(path_to_bar) as HScrollBar
	var edit_time: float = config.get_value("game_settings", "host_set_edit_time_limit", 120)
	bar.value = edit_time
	