extends Label

@export var path_to_timer: NodePath

var timer: Timer
var smaller_font: bool

func _ready() -> void:
	timer = get_node(path_to_timer)

func _process(_delta: float) -> void:
	if not timer:
		return
	var time_left: float = ceil(timer.time_left)
	text = str(int(time_left))
	if int(time_left) == 0:
		text = "START!"
		if not smaller_font:
			smaller_font = true
			self_modulate = Color("ffe900ff")
			add_theme_font_size_override("font_size", 100)
