extends Control

@warning_ignore_start("unsafe_cast", "unsafe_call_argument")

## 百人团过关转场的独立预览：模拟真实游玩画面（紫色外边 + 1280×960 关卡视口）。
## 直接运行 res://tools/adventure_clear_transition_preview.tscn，按 R 重播。

const START_LEVEL: int = 3
const TOTAL_LEVELS: int = 10

@onready var _transition: CanvasLayer = $GameWindow/SubViewport/AdventureClearTransition


func _ready() -> void:
	await get_tree().create_timer(0.4).timeout
	_replay()


func _replay() -> void:
	if _transition != null:
		_transition.call("play", START_LEVEL, TOTAL_LEVELS)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_R:
		_replay()
