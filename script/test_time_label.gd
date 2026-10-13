extends Label

var timer: Timer

func _ready() -> void:
	visible = false
	timer = get_tree().get_first_node_in_group("game_timer") as Timer
	var game_mode: GameMode = GameModeSingleton as GameMode
	if game_mode.game_mode == GameMode.GameModeType.TEST:
		visible = true

func _process(_delta: float) -> void:
	var game_mode: GameMode = GameModeSingleton as GameMode
	if game_mode.game_mode != GameMode.GameModeType.TEST:
		return
	if not timer:
		return
	text = str(ceili(timer.time_left))
