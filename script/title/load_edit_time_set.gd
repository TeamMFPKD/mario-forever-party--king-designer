extends Node

@export var path_to_bar : NodePath = ".."

var config
var bar : HScrollBar

func _ready() -> void:
	config = GameConfig.config
	if not config.has_section_key("game_settings", "host_set_edit_time_limit"):
		return
	bar = get_node(path_to_bar) as HScrollBar
	bar.value = config.get_value("game_settings", "host_set_edit_time_limit", 120)
	