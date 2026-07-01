extends UiAnimationAbstract


var target_scale: Vector2
var duration: float = 0.3
var elapsed: float = 0.0


func _ui_init() -> void:
	target_scale = ui.scale
	ui.scale = Vector2.ZERO


func _animation_process(delta: float) -> void:
	elapsed += delta
	var t = minf(elapsed / duration, 1.0)
	# ease-out cubic
	t = 1.0 - pow(1.0 - t, 3.0)
	ui.scale = target_scale * t
	if elapsed >= duration:
		ui.scale = target_scale
		start = false
		_on_ui_animation_finished()