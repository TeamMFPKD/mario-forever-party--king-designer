extends Label

@export var path_to_timer: NodePath

var timer: Timer
var smaller_font: bool

func _ready() -> void:
	timer = get_node(path_to_timer)

func _process(_delta: float) -> void:
	if not timer:
		return
	text = str(int(ceil(timer.time_left)))
	if int(ceil(timer.time_left)) == 0:
		text = "START!"
		if not smaller_font:
			smaller_font = true
			self_modulate = Color("ffe900ff")
			add_theme_font_size_override("font_size", 100)
