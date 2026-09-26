extends LineEdit

class_name UiLineEditInputBlocker

const PLAYER_ACTIONS: Array[String] = ["move_up", "move_down", "move_left", "move_right", "move_fire", "move_jump", "restart", "photo"]

var _saved_events: Dictionary = {}

func _ready() -> void:
	focus_entered.connect(_block)
	focus_exited.connect(_restore)
	tree_exiting.connect(_restore)

func _block() -> void:
	_saved_events.clear()
	for action: String in PLAYER_ACTIONS:
		var key_events: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(StringName(action)):
			if event is InputEventKey:
				key_events.append(event)
				InputMap.action_erase_event(StringName(action), event)
		if not key_events.is_empty():
			_saved_events[action] = key_events

func _restore() -> void:
	for action: String in _saved_events:
		var events: Array[InputEvent] = _saved_events[action]
		for event: InputEvent in events:
			InputMap.action_add_event(StringName(action), event)
	_saved_events.clear()