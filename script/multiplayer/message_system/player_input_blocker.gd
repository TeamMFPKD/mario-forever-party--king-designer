extends Node

class_name PlayerInputBlocker

## 快捷消息面板打开期间屏蔽玩家操作：临时移除 InputMap 里的玩家动作事件，关闭时恢复。
## 思路与 ui_line_edit_input_blocker.gd 相同，额外覆盖手柄事件，并主动释放已按下的动作。

const PLAYER_ACTIONS: Array[String] = [
	"move_up",
	"move_down",
	"move_left",
	"move_right",
	"move_fire",
	"move_jump",
	"restart",
	"photo",
]

var _saved_events: Dictionary = {}
var _blocked: bool = false


func is_blocked() -> bool:
	return _blocked


func block() -> void:
	if _blocked:
		return
	_blocked = true
	_saved_events.clear()
	for action: String in PLAYER_ACTIONS:
		var action_name: StringName = StringName(action)
		var saved: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(action_name):
			saved.append(event)
			InputMap.action_erase_event(action_name, event)
		if saved.is_empty():
			continue
		_saved_events[action] = saved
		# 已经按住的方向键不会因为移除映射而自动松开，这里主动清零
		Input.action_release(action_name)


func unblock() -> void:
	if not _blocked:
		return
	_blocked = false
	for action: String in _saved_events:
		var events: Array[InputEvent] = _saved_events[action]
		for event: InputEvent in events:
			InputMap.action_add_event(StringName(action), event)
	_saved_events.clear()
