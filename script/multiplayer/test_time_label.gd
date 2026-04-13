extends Label

var timer : Timer

func _ready() -> void:
	visible = false
	timer = get_tree().get_first_node_in_group("game_timer")
	if GameModeSingleton.game_mode == GameModeSingleton.GameModeType.TEST:
		visible = true

func _process(_delta: float) -> void:
	if GameModeSingleton.game_mode != GameModeSingleton.GameModeType.TEST:
		return
	if not timer:
		return
	text = str(int(ceil(timer.time_left)))
